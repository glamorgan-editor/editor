module source.editor.ui.frame;

import dlangui;
import dlangui.dialogs.dialog;
import dlangui.dialogs.filedlg;

import source.editor.actions.EditorCommands;
import source.editor.widgets.NewFileDiag;
import source.editor.workspace.types;
import source.editor.workspace.project;

import std.utf;
import std.conv;
import std.path;

import source.editor.component.FileEditor;

/**
 * The frame containing the whole window.
 * Everything on screen is a child of this element.
 */

class EditorFrame : AppFrame /*, ProgramExecutionStatusListener, BreakpointListChangeListener, BookmarkListChangeListener */ {
    private ToolBarComboBox _currentProjectConfig;

    // The item struct containing the main menu buttons.
    MenuItem mainMenu;

    // The struct containing the currently available tabs in the editor.
    TabWidget _tabs;

    private auto _workspaceOpened = false;

    this(Window window) {
        super();
        window.mainWidget = this;
        window.onFilesDropped = &onFileDropped;
        window.onCanClose = &onCanClose;
        window.onClose = &onClose;

    }

    @property bool isWorkspaceOpened() {
        return _workspaceOpened;
    }

    @property bool setWorkspaceOpened(bool status) {
        this._workspaceOpened = status;
        return true;
    }

    override protected void initialize() {
        _appName = "Glamorgan";

        super.initialize();
    }

    /*override protected Widget createBody() {
        _tabs = new TabWidget("TABS");
        _tabs.hiddenTabsVisibility = Visibility.Gone;
        _tabs.setStyles(STYLE_DOCK_WINDOW, STYLE_TAB_UP_DARK, STYBLE_TAB_UP_BUTTON_DARK, STYLE_TAB_UP_BUTTON_DARK_TEXT, STYLE_DOCK_HOST_BODY);
        
    } */

    override protected MainMenu createMainMenu() {
        mainMenu = new MenuItem();

        // The "File" button
        MenuItem fileItem = new MenuItem(new Action(1, "MENU_FILE"));
        MenuItem fileNewItem = new MenuItem(new Action(1, "MENU_NEW_FILE"));

        fileNewItem.add(ACTION_FILE_NEW_SOURCE_FILE);
        fileItem.add(fileNewItem);

        fileItem.add(ACTION_FILE_OPEN, ACTION_FILE_SAVE, ACTION_FILE_SAVE_AS, ACTION_FILE_EXIT);

        // The "Edit" button
        MenuItem editItem = new MenuItem(new Action(2, "MENU_EDIT"));


        editItem.add(ACTION_EDITOR_UNDO, ACTION_EDITOR_REDO);
        editItem.addSeparator();
        editItem.add(ACTION_EDITOR_CUT, ACTION_EDITOR_COPY, ACTION_EDITOR_PASTE);
        editItem.addSeparator();
        editItem.add(ACTION_EDITOR_FIND, ACTION_EDITOR_REPLACE);
        editItem.addSeparator();
        editItem.add(ACTION_EDITOR_TOGGLE_LINE_COMMENT, ACTION_EDITOR_TOGGLE_BLOCK_COMMENT, ACTION_EDIT_TOGGLE_INDENT);
        editItem.addSeparator();
        editItem.add(ACTION_EDIT_PREFERENCES);

        // The "View" button

        MenuItem viewItem = new MenuItem(new Action(3, "MENU_VIEW"));

        viewItem.add(ACTION_WINDOW_SHOW_HOME);
        viewItem.addSeparator();
        viewItem.addCheck(ACTION_VIEW_TOGGLE_TOOLBAR);
        viewItem.addCheck(ACTION_VIEW_TOGGLE_STATUS);
        

        // The "Help" button

        MenuItem helpItem = new MenuItem(new Action(4, "MENU_HELP"));

        helpItem.add(ACTION_HELP_VIEW, ACTION_HELP_ABOUT);

        mainMenu.add(fileItem);
        mainMenu.add(editItem);
        mainMenu.add(viewItem);
        mainMenu.add(helpItem);

        MainMenu menu = new MainMenu(mainMenu);

        return menu;

    }

    override bool handleAction(const Action a) {
        import source.editor.actions.EditorCommands;
        import dlangui.core.i18n : UIString;
        if(a) {
            switch(a.id) {
                case EditorActions.FileNew:
                    Log.i("Making a new file!");
                    addNewFile(cast(Object)a.objectParam);
                    return true;

                case EditorActions.FileOpen:
                    Log.i("Opening a file..");
                    UIString caption;
                    caption = UIString.fromId("HEADER_OPEN_FILE"c);
                    FileDialog diag = createFileDialog(caption);

                    diag.addFilter(FileFilterEntry(UIString.fromId("TEXT_FILES"c), "*.txt;*.log"));
                    diag.addFilter(FileFilterEntry(UIString.fromId("ALL_FILES"c), "*.*"));

                    diag.path = "C:/";

                    diag.dialogResult = delegate(Dialog d, const Action result) {
                        if(result.id == ACTION_OPEN.id) {
                            string filename = result.stringParam;
                            Log.i("Opening " ~ filename);
                            openSourceFile(filename);
                        }
                    };
                    diag.show();
                    return true;
                case EditorActions.FileExit:
                    if(onCanClose())
                        window.close();
                    return true;

                default: return true;
                // TODO!
            }
        }

        return true;
    }

    private void addNewFile(Object obj) {
        Dialog createNewFileDialog(Project project, ProjectFolder folder) {
            NewFileDiag diag = new NewFileDiag(this, project, folder);
            diag.dialogResult = delegate(Dialog dlg, const Action result) {
                if(result.id == ACTION_FILE_NEW_SOURCE_FILE.id) {
                    FileCreationResult res = cast(FileCreationResult) result.objectParam;
                    if(res) {
                        //res.project.refresh();
                        //updateTreeGraph();
                        Log.i("Created file ", res.filename);
                        openSourceFile(res.filename);
                    }
                }
            };
            return diag;
        }

        addProjectItem(&createNewFileDialog, obj);
        
    }

    private void addProjectItem(Dialog delegate(Project, ProjectFolder) dialogFactory, Object obj) {
        Project project;
        ProjectFolder folder;

        if(cast(ProjectSourceFile)obj) {
            Log.i("Adding a new source file to the project..");
            ProjectSourceFile source = cast(ProjectSourceFile) obj;
            folder = cast(ProjectFolder) source.getParent();
            project = source.getProject();
        }

        if(project) {
            Dialog diag = dialogFactory(project, folder);
            Log.i("Showing new file diag..");
            diag.show();
        }
    }

    FileDialog createFileDialog(UIString caption, int flags = DialogFlag.Modal | DialogFlag.Resizable | FileDialogFlag.FileMustExist) {
        FileDialog diag = new FileDialog(caption, window, null, flags);
        
        return diag;
    }

    void onFileDropped(string[] fileNames) {

        bool first = true;
        for(int i = 0; i < fileNames.length; i++) {
            //openSourcefile(fileNames[i], null, first);
            first = false;
        }
    }

    bool openSourceFile(string filename, ProjectSourceFile file = null, bool focus = true) {
        if(!file && !filename) 
            return false;
        
        //if(!file)
            //file = _workspace.findSourceFile(filename, false);
        
        if(file)
            filename = file.getFileName();

        int tabLocation = _tabs.tabIndex(filename);
        Log.i("tabl " ~ to!string(tabLocation));
        if(tabLocation >= 0) {
            _tabs.selectTab(tabLocation, true);
        } else {
            Log.i("Creating new editor window");
            FileEditor editor = new FileEditor(filename);
            Log.i("Editor constructed");

            if(file ? editor.load(file) : editor.load(filename)) {
                _tabs.addTab(editor, toUTF32(baseName(filename)), null, true, filename.toUTF32);
                tabLocation = _tabs.tabIndex(filename);
                TabItem tab = _tabs.tab(filename);
                tab.objectParam = file;

                _tabs.selectTab(tabLocation, true);

                _tabs.layout(_tabs.pos);
            } else {
                Log.d("file ", filename, " can't be opened.");
                destroy(editor);
                if(window)
                    window.showMessageBox(UIString.fromId("ERROR_OPEN_FILE"c), UIString.fromId("ERROR_OPENING_FILE"c) ~ " " ~ toUTF32(filename));
                return false;
            }
        }

        if(focus) {
            focusEditor(filename);
        }

        //requestLayout();
        return true;
    }

    bool onCanClose() {
        //TODO: check for unsaved edits
        return true;
    }

    void onClose() {
        // TODO: save window state
        // TODO: save settings
        // TODO: stop subprocesses
    }

    void focusEditor(string ID) {
        Widget widget = _tabs.tabBody(ID);
        if(widget) {
            if(widget.visible)
                widget.setFocus();
        }
    }


}