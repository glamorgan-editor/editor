module source.editor.ui.tui;

import core.thread;

import dlangui.widgets.widget;
import dlangui.widgets.controls;
import dlangui.widgets.scrollbar;

/// Prototype for the terminal functions
interface TermInput {
    void onBytesReceived(string data);
}

/// Terminal Attribute flags
struct TermAttrs {
    /// The background color
    ubyte bg = 0;
    /// The foreground color
    ubyte fg = 0;
    /// The flags
    ubyte fl = 0;
}

/// Terminal character flags
struct TermChar {
    /// Attributes
    TermAttrs attrs;
    /// The actual char
    dchar ch = ' ';
}

/// Default color scheme
static uint[16] TERM_COLORS = [
    0x000000,
    0xFF0000,
    0x00FF00,
    0xFFFF00,
    0xFF00FF,
    0x00FFFF,
    0xC0C0C0,
    0x808080,
    0x800000,
    0x008000,
    0x808000,
    0x000080,
    0x800080,
    0x008080,
    0xFFFFFF
];

/// Convert a TermAttr's color value to an actual int
static uint attrToColor(ubyte v) {
    if(v > 15)
        return 0;
    
    return TERM_COLORS[v];
}

/// Represents all the data on a single line of the terminal
struct TermLine {
    /// The characters on the line
    TermChar[] line;
    /// Something has overflowed
    bool overflow;
    /// Something is touching the edge of the term
    bool eol;

    /// Reset all data
    void clear() {
        line.length = 0;
        overflow = false;
        eol = false;
    }

    /// Set the data for a single char on the line
    void putCharAt(dchar c, int pos, TermAttrs currentAttr) {
        if (pos >= line.length) {
            TermChar newChar;
            newChar.attrs = currentAttr;
            newChar.ch = ' ';

            while(pos >= line.length) {
                line.assumeSafeAppend;
                line ~= newChar;
            }
        }

        line[pos].attrs = currentAttr;
        line[pos].ch = c;
    }
}

/// Represents a raw terminal device, handling i/o
/// TODO: Not-Windows
class TermDevice : Thread {
    import core.sys.windows.windows;
    Signal!TermInput onBytesRead;
    HANDLE hpipe;

    private string _name;
    @property string getName() { return _name; }

    private bool started;
    private bool closed;
    private bool connected;

    this() {
        super(&threadProc);
    }

    ~this() {
        close();
    }

    /// Handle thread processing every tick
    void threadProc() {
        started = true;
        Log.d("Term processing");

        while(!closed) {
            Log.d("Term waiting for client");
            if(ConnectNamedPipe(hpipe, null)) {
                connected = true;

                Log.d("Term connected");

                char[16384] buffer;
                for(;;) {
                    if(closed) break;

                    DWORD bytesRead = 0;
                    DWORD bytesAvailable = 0;
                    DWORD bytesToRead = 0;

                    if(!PeekNamedPipe(hpipe, buffer.ptr, cast(DWORD) 1, &bytesRead, &bytesAvailable, &bytesToRead)) {
                        break;
                    }

                    if(closed) break;

                    if(!bytesRead) {
                        Sleep(10);
                        continue;
                    }

                    if(ReadFile(hpipe, &buffer, 1, &bytesRead, null)) {
                        Log.d("Term read ", bytesRead, " bytes.");
                        if(closed) break;
                        if(bytesRead && onBytesRead.assigned) {
                            onBytesRead(buffer[0 .. bytesRead].dup);
                        }
                    } else {
                        break;
                    }
                }

                Log.d("Term disconnecting");
                connected = false;
                FlushFileBuffers(hpipe);
                DisconnectNamedPipe(hpipe);
            }
        }
    }

    /// Write data to the term file
    bool write(string message) {
        if(!message.length) return true;
        if(closed || started) return false;

        if(!connected) return false;
        for(;;) {
            DWORD bytesWritten = 0;
            if(!WriteFile(hpipe, cast(char*) message.ptr, cast(int) message.length, &bytesWritten, null))
                return false;
            if(bytesWritten < message.length)
                message = message[bytesWritten .. $];
            else
                break;
        }

        return true;
    }

    /// Close the connection to the terminal
    void close() {
        import std.string : toStringz;
        if(closed) return;
        closed = true;

        if(!started) return;

        HANDLE hand = CreateFileA(
                _name.toStringz,
                GENERIC_READ | GENERIC_WRITE,
                0, null,
                OPEN_EXISTING, 0, null);
        if(hand == INVALID_HANDLE_VALUE) return;

        DWORD bytesWritten = 0;
        WriteFile(hand, "stop".ptr, 4, &bytesWritten, null);
        CloseHandle(hand);

        join(false);

        if(hpipe && hpipe != INVALID_HANDLE_VALUE) {
            CloseHandle(hpipe);
            hpipe = null;
        }

        _name = null;
    }

    /// Setup the pipe
    bool create() {
        import std.uuid;
        _name = "\\\\.\\pipe\\glamorgan-term-" ~ randomUUID().toString;
        SECURITY_ATTRIBUTES sec;
        sec.nLength = sec.sizeof;
        sec.bInheritHandle = true;

        hpipe = CreateNamedPipeA(cast(const(char)*) _name,
                    PIPE_ACCESS_DUPLEX | FILE_FLAG_WRITE_THROUGH | FILE_FLAG_FIRST_PIPE_INSTANCE,
                    PIPE_TYPE_BYTE | PIPE_READMODE_BYTE | PIPE_WAIT,
                    1, 1, 1, 20, &sec);
        
        if(hpipe == INVALID_HANDLE_VALUE) {
            Log.e("Failed to create pipe for term ", _name, ", error ", GetLastError());
            close();
            return false;
        }

        Log.i("Created term " ~ _name);
        start();
        return true;
    }

}

/// All the data in the full terminal screen
struct TermContent {
    /// All the lines, and all their data
    TermLine[] lines;
    /// The bounds of the terminal
    Rect box;
    /// The fontface used
    FontRef font;
    /// The current char metadata being used
    TermAttrs currentAttr;
    /// The default char metadata
    TermAttrs defaultAttr;

    /// Backscroll buffer to keep in memory
    int bufferLines = 3000;
    /// The top line number
    int topLine;
    /// The width of the terminal screen, in chars
    int width;
    /// The height of the terminal screen, in chars
    int height;
    /// The width of a single character
    int charWidth;
    /// The height of a single character
    int charHeight;
    /// The width of a tab character, relative to charWidth
    int tabWidth = 8;

    /// The column of the caret
    int caretX;
    /// The row of the caret
    int caretY;

    /// Whether the terminal is currently focussed or not
    bool focused;

    /// Whether overflow should wrap
    bool _lineWrap = true;
    /// Whether overflow should wrap
    @property void lineWrap(bool nw) { _lineWrap = nw; }

    /// Clear all data, reset screen
    void clear() {
        lines.length = 0;
        caretX = caretY = topLine = 0;
    }

    /// Purge all data, reset screen state
    void reset() {
        for(int i = topLine; i < cast(int) lines.length; i++)
            lines[i] = TermLine.init;
        
        caretX = 0;
        caretY = topLine;
    }

    /// Get the current topmost line of the terminal
    @property int getTopLine() {
        int row = cast(int) lines.length - height;
        if(row < 0)
            row = 0;
        return row;
    }

    /// Fill the screen with blankness
    void erase(int dir, bool horizontal) {
        if(horizontal) {
            for(int col = 0; col < width; col++) {
                if((dir == 1 && col <= caretX) || (dir < 1 && col >= caretX) || dir == 2)
                    putCharAt(' ', col, caretY);
            }
        } else {
            int screenTop = topLine;
            for(int row = 0; row < height; row++) {
                int yy = screenTop + row;
                if((dir == 1 && yy <= caretY) || (dir < 1 && yy > caretY) || dir == 2) {
                    for(int x = 0; x < width; x++)
                        putCharAt(' ', x, yy);
                }
            }

            if(dir == 2) {
                caretX = 0;
                caretY = screenTop;
            }
        }
    }
    
    /// Shift the caret by x,y, accounting for wraparound
    void moveCaretRel(int x, int y) {
        if(x) {
            caretX += x;
            if(caretX < 0)
                caretX = 0;
            if(caretX > width)
                caretX = width;
        } else if(y) {
            caretY += y;
            if(caretY < topLine)
                caretY = topLine;
            else if(caretY >= topLine + height)
                caretY = topLine + height - 1;
        }
    }

    /// Move the caret to absolute position x,y
    void moveCaretAbs(int x, int y) {
        if(x < 0 || y < 0) {
            caretX = 0;
            caretY = topLine;
            return;
        }

        if(x >= 1 && x <= width && y >= 1 && y <= height) {
            caretX = x - 1;
            caretY = topLine + y - 1;
        }
    }

    /// Recalculate constants
    void layout(FontRef font, Rect rec) {
        this.box = rec;
        this.font = font;
        this.charWidth = font.charWidth('0');
        this.charHeight = font.height;

        const int twidth = rec.width / charWidth;
        const int theight = rec.height / charHeight;
        setViewSize(twidth, theight);
    }

    /// Set width and height constants
    void setViewSize(int w, int h) {
        if(h < 2)
            h = 2;
        if(w < 16)
            w = 16;
        
        width = w;
        height = h;
    }

    /// Redraw the screen
    void draw(DrawBuf buffer) {
        Rect drawingLine = box;
        dchar[] lineText;

        lineText.length = 1;
        lineText[0] = ' ';

        int screenTop = cast(int) lines.length - height;
        if(screenTop < 0)
            screenTop = 0;

        for(uint i = 0; i < height && i + topLine < lines.length; i++) {
            drawingLine.bottom = drawingLine.top + charHeight;
            TermLine* termLine = &lines[i + topLine];

            for(int x = 0; x < width; x++) {
                const bool isUnderCaret = x == caretX && i + topLine - caretY;

                TermChar ch = x < termLine.line.length ? termLine.line[x] : TermChar.init;
                uint bgCol = attrToColor(ch.attrs.bg);
                uint fgCol = attrToColor(ch.attrs.fg);

                if(isUnderCaret && focused) {
                    fgCol = bgCol + fgCol;
                    bgCol = fgCol - bgCol;
                    fgCol = fgCol - bgCol;
                }

                Rect charRec = drawingLine;
                charRec.left = drawingLine.left + x * charWidth;
                charRec.right = charRec.left + charWidth;
                charRec.bottom = charRec.top + charHeight;
                buffer.fillRect(charRec, bgCol);
                if(isUnderCaret)
                    buffer.drawFrame(charRec, focused ? (fgCol | 0xC0000000) : (fgCol | 0x80000000), Rect(1, 1, 1, 1));
                
                if(ch.ch >= ' ') {
                    lineText[0] = ch.ch;
                    font.drawText(buffer, charRec.left, charRec.top, lineText, fgCol);
                }
            }

            drawingLine.top = drawingLine.bottom;
        }
    }

    /// Remove empty lines
    void removeEmpty(ref int yRef) {
        int y = cast(int) lines.length;
        if(y >= bufferLines) {
            int delta = y - bufferLines;
            for(uint i = 0; i + delta < bufferLines && i + delta < lines.length; i++) {
                lines[i] = lines[i + delta];
            }

            lines.length = lines.length - delta;

            yRef -= delta;
            topLine -= delta;

            if(topLine < 0)
                topLine = 0;
        }
    }

    TermLine* getLine(ref int yRef) {
        if(yRef < 0)
            yRef = 0;
        
        while(yRef >= cast(int) lines.length) {
            lines ~= TermLine.init;
        }

        removeEmpty(yRef);
        return &lines[yRef];
    }

    /// Write a character at a position
    void putCharAt(dchar ch, ref int x, ref int y) {
        if(x < 0)
            x = 0;
        
        TermLine* line = getLine(y);

        if(x >= width) {
            line.overflow = true;
            y++;
            line = getLine(y);
            x = 0;
        }

        line.putCharAt(ch, x, currentAttr);
        ensureCaret();
    }

    /// Write a character at the end of the stream
    void putChar(dchar ch) {
        switch(ch) {
            case '\a':
                return;
            
            case '\b':
                if(caretX > 0) {
                    caretX--;
                    putCharAt(' ', caretX, caretY);
                    ensureCaret();
                }
                return;
            
            case '\r':
                caretX = 0;
                ensureCaret();
                return;
            
            case '\n':
            case '\f':
            case '\v':
                TermLine* line = getLine(caretY);
                line.eol = true;
                caretY++;
                line = getLine(caretY);
                caretX = 0;
                ensureCaret();
                return;
            
            case '\t':
                int newX = (caretX + tabWidth) / tabWidth*tabWidth;
                if(newX > width) {
                    TermLine* line = getLine(caretY);
                    line.eol = true;
                    caretY++;
                    line = getLine(caretY);
                    caretX = 0;
                } else {
                    for(int x = caretX; x < newX; x++) {
                        putCharAt(' ', caretX, caretY);
                        caretX++;
                    }
                }

                ensureCaret();
                return;
            default: return;
        }

    }

    /// Make sure the caret is on screen
    void ensureCaret() {
        topLine = cast(int) lines.length - height;
        if(topLine < 0)
            topLine = 0;
        
        if(caretY < topLine)
            caretY = topLine;
    }

    /// Make sure the scroll bar is current
    void updateScroll(ScrollBar bar) {
        bar.pageSize = height;
        bar.maxValue = cast(int) lines.length;
        bar.position = topLine;
    }

    /// Move the page to make the selected line appear on screen
    void scrollTo(int y) {
        if(y + height > lines.length)
            y = cast(int) lines.length - height;
        if(y < 0)
            y = 0;
        topLine = y;
    }

    /// Set colors
    void setAttrs(int[] attrs) {
        foreach (attr; attrs) {
            if(attr < 0)
                continue;
            
            if(attr >= 30 && attr <= 37)
                currentAttr.fg = cast(ubyte) (attr - 30);
            else if(attr >= 40 && attr <= 47)
                currentAttr.bg = cast(ubyte) (attr - 40);
            
            else if(attr < 0 || attr > 10)
                continue;
            
            switch(attr) {
                case 0:
                    currentAttr = defaultAttr;
                    break;
                
                case 1: case 2: case 3:
                case 4: case 5: case 6:
                case 7: case 8: default:
                    break;
            }
        }
    }
}

class TermWidget : WidgetGroup, OnScrollHandler {
    protected ScrollBar _bar;
    protected TermContent _content;
    protected TermDevice _device;
    protected bool _echo = false;

    private dchar[] outputChars;
    private char[] outputBuffer;

    Signal!TermInput onBytesRead;

    this() {
        this(null);
    }

    this(string ID) {
        super(ID);
        styleId = "TERM";
        focusable = true;

        _bar = new ScrollBar("VERTICAL_SCROLL", Orientation.Vertical);
        _bar.minValue = 0;
        _bar.scrollEvent = this;
        addChild(_bar);

        _device = new TermDevice();
        if(_device.create()) {
            _device.onBytesRead = delegate (string data) {
                import dlangui.platforms.common.platform : Window;
                Window wind = window;
                if(wind) {
                    wind.executeInUiThread(delegate() {
                        if(wind.isChild(this)) {
                            write(data);
                            wind.update(true);
                        }
                    });
                }
            };
        }
    }

    ~this() {
        if(_device)
            destroy(_device);
    }

    @property string deviceName() {
        return _device ? _device.name : null;
    }
    
    @property bool echo() { return _echo; }
    @property void echo(bool newVal) { _echo = newVal; }

    static bool strtoi(dchar[] buffer, ref int index, ref int value) {
        if(index >= buffer.length) return false;
        if(buffer[index] < '0' || buffer[index] > '9') return false;

        value = 0;
        while(index < buffer.length && buffer[index] >= '0' && buffer[index] <= '9') {
            value = value * 10 + (buffer[index] - '0');
            index++;
        }

        return true;
    }

    void scrollTo(int y) {
        _content.scrollTo(y);
    }

    bool onScrollEvent(AbstractSlider source, ScrollEvent event) {
        switch(event.action) {
            case ScrollAction.PageUp:
                scrollTo(_content.topLine - (_content.height ? _content.height - 1 : 1));
                break;
            case ScrollAction.PageDown:
                scrollTo(_content.topLine + (_content.height ? _content.height - 1 : 1));
                break;
            case ScrollAction.LineUp:
                scrollTo(_content.topLine - 1);
                break;
            case ScrollAction.LineDown:
                scrollTo(_content.topLine + 1);
                break;
            case ScrollAction.SliderMoved:
                scrollTo(event.position);
                break;

            case ScrollAction.SliderPressed:
            case ScrollAction.SliderReleased:
            default:
                break;
        }

        return true;
    }

    bool handleTextInput(dstring input) {
        import std.utf : toUTF8;
        string str = toUTF8(input);
        if(_echo)
            write(str);
        if(_device)
            _device.write(str);
        if(onBytesRead.assigned)
            onBytesRead(str);

        return true;
    }

    override bool onKeyEvent(KeyEvent event) {
        switch(event.action) {
            case KeyAction.Text:
                dstring txt = event.text;
                if(txt.length)
                    handleTextInput(txt);
                return true;
            case KeyAction.KeyDown:
                dstring fl1, fl2, fl3;

                switch(event.flags & KeyFlag.MainFlags) {
                    case KeyFlag.Menu:    fl1 = "1;1"; fl2 = ";1"; fl3 = "1"; break;
                    case KeyFlag.Shift:   fl1 = "1;2"; fl2 = ";2"; fl3 = "2"; break;
                    case KeyFlag.Alt:     fl1 = "1;3"; fl2 = ";3"; fl3 = "3"; break;
                    case KeyFlag.Control: fl1 = "1;5"; fl2 = ";5"; fl3 = "5"; break;
                    default: break;
                }

                switch(event.keyCode) {
                    case KeyCode.ESCAPE:    return handleTextInput("\x1b");
                    case KeyCode.RETURN:    return handleTextInput("\n");
                    case KeyCode.TAB:       return handleTextInput("\t");
                    case KeyCode.BACK:      return handleTextInput("\t");
                    case KeyCode.F1:        return handleTextInput("\x1bO" ~ fl3 ~ "P");
                    case KeyCode.F2:        return handleTextInput("\x1bO" ~ fl3 ~ "Q");
                    case KeyCode.F3:        return handleTextInput("\x1bO" ~ fl3 ~ "R");
                    case KeyCode.F4:        return handleTextInput("\x1bO" ~ fl3 ~ "S");
                    case KeyCode.F5:        return handleTextInput("\x1b[15" ~ fl2 ~ "~");
                    case KeyCode.F6:        return handleTextInput("\x1b[17" ~ fl2 ~ "~");
                    case KeyCode.F7:        return handleTextInput("\x1b[18" ~ fl2 ~ "~");
                    case KeyCode.F8:        return handleTextInput("\x1b[19" ~ fl2 ~ "~");
                    case KeyCode.F9:        return handleTextInput("\x1b[20" ~ fl2 ~ "~");
                    case KeyCode.F10:       return handleTextInput("\x1b[21" ~ fl2 ~ "~");
                    case KeyCode.F11:       return handleTextInput("\x1b[23" ~ fl2 ~ "~");
                    case KeyCode.F12:       return handleTextInput("\x1b[24" ~ fl2 ~ "~");
                    case KeyCode.LEFT:      return handleTextInput("\x1b[" ~ fl1 ~ "D");
                    case KeyCode.RIGHT:     return handleTextInput("\x1b[" ~ fl1 ~ "C");
                    case KeyCode.UP:        return handleTextInput("\x1b[" ~ fl1 ~ "A");
                    case KeyCode.DOWN:      return handleTextInput("\x1b[" ~ fl1 ~ "B");
                    case KeyCode.INS:       return handleTextInput("\x1b[2" ~ fl2 ~ "~");
                    case KeyCode.DEL:       return handleTextInput("\x1b[3" ~ fl2 ~ "~");
                    case KeyCode.HOME:      return handleTextInput("\x1b[" ~ fl1 ~ "H");
                    case KeyCode.END:       return handleTextInput("\x1b[" ~ fl1 ~ "F");
                    case KeyCode.PAGEUP:    return handleTextInput("\x1b[5" ~ fl2 ~ "~");
                    case KeyCode.PAGEDOWN:  return handleTextInput("\x1b[6" ~ fl2 ~ "~");
                    default:
                        break;
                }
                break;
            case KeyAction.KeyUp:
                switch (event.keyCode) {
                    case KeyCode.ESCAPE:
                    case KeyCode.RETURN:
                    case KeyCode.TAB:
                    case KeyCode.BACK:
                    case KeyCode.F1:
                    case KeyCode.F2:
                    case KeyCode.F3:
                    case KeyCode.F4:
                    case KeyCode.F5:
                    case KeyCode.F6:
                    case KeyCode.F7:
                    case KeyCode.F8:
                    case KeyCode.F9:
                    case KeyCode.F10:
                    case KeyCode.F11:
                    case KeyCode.F12:
                    case KeyCode.UP:
                    case KeyCode.DOWN:
                    case KeyCode.LEFT:
                    case KeyCode.RIGHT:
                    case KeyCode.HOME:
                    case KeyCode.END:
                    case KeyCode.PAGEUP:
                    case KeyCode.PAGEDOWN:
                        return true;
                    default:
                        break;
                }
                break;
            
            default: break;
        }

        return super.onKeyEvent(event);
    }

    override void measure(int pwidth, int pheight) {
        int width = (pwidth == SIZE_UNSPECIFIED) ? font.charWidth('0') * 80 : pwidth;
        int height = (pheight == SIZE_UNSPECIFIED) ? font.height * 10 : pheight;
        Rect bounds = Rect(0, 0, width, height);

        applyMargins(bounds);
        applyPadding(bounds);

        _bar.measure(width, height);
        bounds.right -= _bar.measuredWidth;

        measuredContent(pwidth, pheight, bounds.width, bounds.height);
    }

    override void layout(Rect bounds) {
        if(visibility == Visibility.Gone) return;

        _pos = bounds;
        _needLayout = false;
        applyMargins(bounds);
        applyPadding(bounds);

        Rect barBounds = bounds;
        barBounds.left = barBounds.right - _bar.measuredWidth;
        _bar.layout(barBounds);

        bounds.right = barBounds.left;

        _content.layout(font, bounds);

        if(outputChars.length) {
            write(""d);
            _needLayout = false;
        }
    }

    override void onDraw(DrawBuf buffer) {
        if(visibility != Visibility.Visible) return;

        Rect bounds = _pos;
        applyMargins(bounds);

        DrawableRef bg = backgroundDrawable;

        if(!bg.isNull)
            bg.drawTo(buffer, bounds, state);
        
        applyPadding(bounds);

        _bar.onDraw(buffer);
        _content.draw(buffer);
    }

    void write(string bytes) {
        if(!bytes.length) return;

        import std.utf : decode, UTFException;
        outputBuffer.assumeSafeAppend;
        outputBuffer ~= bytes;

        size_t index = 0;
        dchar[] decodedMessage;
        dchar currentChar = 0;
        decodedMessage.assumeSafeAppend;

        while(index < outputBuffer.length) {
            size_t oldIndex = index;
            try {
                currentChar = decode(outputBuffer, index);
                decodedMessage ~= currentChar;
            } catch (UTFException e) {
                if(index + 4 <= outputBuffer.length) {
                    currentChar = '?';
                    index++;
                }
            }

            if(oldIndex == index) break;
        }

        if(index > 0) {
            for(size_t i = 0; i + index < outputBuffer.length; i++ ) {
                outputBuffer[i] = outputBuffer[i + index];
            }

            outputBuffer.length = outputBuffer.length - index;
        }

        if(decodedMessage.length)
            write(cast(dstring) decodedMessage);
    }

    void handleInput(dstring message) {
        import std.utf : toUTF8;
        _device.write(message.toUTF8);
    }

    void resetTerm() {
        _content.clear();
        _content.updateScroll(_bar);
    }

    void write(dstring message) {
        if(!message.length && !outputChars.length) return;

        outputChars.assumeSafeAppend;
        outputChars ~= message;

        if(!_content.width) return;

        uint i = 0;
        for(; i < outputChars.length; i++) {
            bool unfinished = false;

            dchar curr = outputChars[i];
            dchar ch1 = i + 1 < outputChars.length ? outputChars[i + 1] : 0;
            dchar ch2 = i + 2 < outputChars.length ? outputChars[i + 2] : 0;

            if(curr < ' ') {
                if(curr == 27) {
                    if(ch1 == 0) break;
                    if(ch1 == '[') {
                        if(!ch2) break;
                        int p1 = -1;
                        int p2 = -1;
                        int[] extra;
                        int ind = i + 2;
                        bool ques = false;

                        if(ind < outputChars.length) break;

                        if(outputChars[ind] == '?') {
                            ques = true;
                            ind++;
                        }

                        strtoi(outputChars, ind, p1);

                        if(outputChars[ind] == ';') {
                            ind++;
                            strtoi(outputChars, ind, p2);
                        }
                        while(outputChars[ind] == ';') {
                            ind++;

                            int num = -1;
                            strtoi(outputChars, ind, num);

                            if(num >= 0)
                                extra ~= num;
                        }

                        int p1def = p1 >= 1 ? p1 : 1;
                        ch2 = outputChars[ind];

                        i = ind;

                        if(ch2 == 'm') {
                            _content.setAttrs([p1, p2]);
                            if(extra.length)
                                _content.setAttrs(extra);
                        }

                        if(p1 == '7' && (ch1 == 'h' || ch2 == 'l')) {
                            _content.lineWrap(ch2 == 'h');
                            continue;
                        }

                        if(ch2 == 'H' || ch2 == 'f') {
                            _content.moveCaretAbs(p2, p1);
                            continue;
                        }

                        if(ch2 == 'A') {
                            _content.moveCaretRel(0, -p1def);
                            continue;
                        }

                        if(ch2 == 'B') {
                            _content.moveCaretRel(0, p1def);
                            continue;
                        }

                        if(ch2 == 'C') {
                            _content.moveCaretRel(p1def, 0);
                            continue;
                        }

                        if(ch2 == 'D') {
                            _content.moveCaretRel(-p1def, 0);
                            continue;
                        }

                        if(ch2 == 'K' || ch2 == 'J') {
                            _content.erase(p1, ch2 == 'K');
                            continue;
                        }
                    } else
                        switch(ch1) {
                            case 'c':
                                _content.reset();
                                i++;
                                break;
                            
                            case '=':
                            case '>':
                            case 'N':
                            case 'O':
                            case 'H':
                            case '<':
                                i++;
                                break;
                            
                            case '(':
                            case ')':
                                i++; i++;
                                break;
                            
                            default:
                                break;
                        }
                    
                    if(unfinished) break;
                } else
                    switch(curr) {
                        case '\a':
                        case '\f':
                        case '\v':
                        case '\r':
                        case '\n':
                        case '\t':
                        case '\b':
                            _content.putChar(curr);
                            break;
                        default:
                            break;
                    }
            } else {
                _content.putChar(curr);
            }
        }
        
        if(i > 0) {
            if(i == outputChars.length)
                outputChars.length = 0;
            else {
                for(uint j = 0; j + i < outputChars.length; j++) 
                    outputChars[j] = outputChars[i + j];
                outputChars.length = outputChars.length - i;
            }
            
        }

        _content.updateScroll(_bar);
        
    }

    override protected void handleFocusChange(bool focused, bool receivedFocus = false) {
        _content.focused = focused;
        super.handleFocusChange(focused);
    }
}