module source.editor.ui.frame;

import dlangui;
import dlangui.dialogs.dialog;
import dlangui.dialogs.filedlg;

import source.editor.actions.commands;
import source.editor.widgets.newfilediag;
import source.editor.component.text;
import source.editor.workspace.types;
import source.editor.workspace.project;

import std.utf;
import std.ascii;
import std.random;
import std.conv;
import std.path;

import source.editor.component.text;

/**
 * The frame containing the whole window.
 * Everything on screen is a child of this element.
 */

class EditorFrame : AppFrame {
    private ToolBarComboBox _currentProjectConfig;

    /// The item struct containing the main menu buttons.
    MenuItem mainMenu;

    /// The struct containing the currently available tabs in the editor.
    TabWidget _tabs;

    /// The struct handling the layout of the items
    DockHost _dockHost;

    private auto _workspaceOpened = false;

    /// Main constructor, taking the parent window and setting all the callbacks
    this(Window window) {
        super();
        window.mainWidget = this;
        window.onFilesDropped = &onFileDropped;
        window.onCanClose = &onCanClose;
        window.onClose = &onClose;

    }

    @property bool getWorkspaceOpened() {
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

        fileNewItem.add(ACTION_GFILE_NEW_SOURCE_FILE);
        fileItem.add(fileNewItem);

        fileItem.add(ACTION_GFILE_OPEN, ACTION_GFILE_SAVE, ACTION_GFILE_SAVE_AS, ACTION_GFILE_EXIT);

        // The "Edit" button
        MenuItem editItem = new MenuItem(new Action(2, "MENU_EDIT"));


        editItem.add(ACTION_EDITOR_UNDO, ACTION_EDITOR_REDO);
        editItem.addSeparator();
        editItem.add(ACTION_EDITOR_CUT, ACTION_EDITOR_COPY, ACTION_EDITOR_PASTE);
        editItem.addSeparator();
        editItem.add(ACTION_EDITOR_FIND, ACTION_EDITOR_REPLACE);
        editItem.addSeparator();
        editItem.add(ACTION_EDITOR_TOGGLE_LINE_COMMENT, ACTION_EDITOR_TOGGLE_BLOCK_COMMENT, ACTION_GEDIT_TOGGLE_INDENT);
        editItem.addSeparator();
        editItem.add(ACTION_GEDIT_PREFERENCES);

        // The "View" button

        MenuItem viewItem = new MenuItem(new Action(3, "MENU_VIEW"));

        viewItem.add(ACTION_GWINDOW_SHOW_HOME);
        viewItem.addSeparator();
        viewItem.addCheck(ACTION_GVIEW_TOGGLE_TOOLBAR);
        viewItem.addCheck(ACTION_GVIEW_TOGGLE_STATUS);
        

        // The "Help" button

        MenuItem helpItem = new MenuItem(new Action(4, "MENU_HELP"));

        helpItem.add(ACTION_GHELP_VIEW, ACTION_GHELP_ABOUT);

        mainMenu.add(fileItem);
        mainMenu.add(editItem);
        mainMenu.add(viewItem);
        mainMenu.add(helpItem);

        MainMenu menu = new MainMenu(mainMenu);

        return menu;

    }

    override protected Widget createBody() {
        _dockHost = new DockHost();

        _tabs = new TabWidget("tabs");
        _tabs.hiddenTabsVisibility = Visibility.Gone;
        _dockHost.bodyWidget = _tabs;
        _tabs.setStyles(STYLE_DOCK_WINDOW, STYLE_TAB_UP_DARK, STYLE_TAB_UP_BUTTON_DARK, 
                STYLE_TAB_UP_BUTTON_DARK_TEXT, STYLE_DOCK_HOST_BODY);

        _tabs.tabClose = &onTabClose;

        return _dockHost;
    }

    @property ProjectSourceFile currentOpenSourceFile() {
        TabItem tab = _tabs.selectedTab;
        if (tab) {
            return cast(ProjectSourceFile)tab.objectParam;
        }
        return null;
    }


    protected void onTabClose(string tabID) {
        Log.i("Closing tab " ~ tabID);
        const int index = _tabs.tabIndex(tabID);
        if (index >= 0) {
            FileEditor editor = cast(FileEditor) _tabs.tabBody(tabID);
            if(editor && editor.content.modified) {
                window.showMessageBox(UIString.fromId("CLOSE_MODIFIED_TAB"c), 
                    UIString.fromId("MSG_TAB_CHANGED") ~ ": " ~ toUTF32(baseName(tabID)),
                    [ACTION_SAVE, ACTION_DISCARD_CHANGES, ACTION_CANCEL],
                    0,
                    delegate(const Action result) {
                        if(result == StandardAction.Save) {
                            editor.save();
                            closeTab(tabID);
                        } else if (result == StandardAction.DiscardChanges) {
                            closeTab(tabID);
                        }
                        return true;
                    }
                );
            } else {
                closeTab(tabID);
            }
        }
        
        requestActionsUpdate();
    }

    /// Remove the selected tab and return focus to the currently active tab, or the last.
    void closeTab(string tabID) {
        _tabs.removeTab(tabID);
        _tabs.focusSelectedTab();
    }

    override bool handleAction(const Action a) {
        import source.editor.actions.commands : EditorActions;
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
        import std.ascii : letters;
        import std.path : buildPath;
        import std.file : FileException, write, tempDir;
        /*Dialog createNewFileDialog(Project project, ProjectFolder folder) {
            NewFileDiag diag = new NewFileDiag(this, project, folder);
            diag.dialogResult = delegate(Dialog dlg, const Action result) {
                if(result.id == ACTION_GFILE_NEW_SOURCE_FILE.id) {
                    FileCreationResult res = cast(FileCreationResult) result.objectParam;
                    if(res) {
                        res.project.refresh();
                        //updateTreeGraph();
                        Log.i("Created file ", res.filename);
                        openSourceFile(res.filename);
                    }
                }
            };
            return diag;
        }*/


        const auto tempID = letters.byCodeUnit.randomSample(10).to!string;
        auto filename = tempDir.buildPath(tempID ~ "New.txt");
        // Touch the file with empty contents so the editor can see it
        try {
            write(filename, "");
        } catch(FileException e) {
            Log.i("Unable to touch temp file! " ~ e.msg 
                    ~ "\n" ~ e.errno.to!string ~ "\n" ~ e.file ~ ":" ~ e.line.to!string);
        }

        Log.i("Created temporary file " ~ filename ~ " for the editor to open");

        ProjectSourceFile source = new ProjectSourceFile(filename);
        source.setTemp(true);

        openSourceFile(filename, source);
        
    }

    private void addProjectItem(Dialog delegate(Project, ProjectFolder) dialogFactory, Object obj) {
        Project project;
        ProjectFolder folder;

        if(cast(ProjectSourceFile)obj) {
            Log.i("Adding a new source file to the project..");
            ProjectSourceFile source = cast(ProjectSourceFile) obj;
            folder = cast(ProjectFolder) source.getParent();
            project = source.getProject();
        } else {
            Log.i("Unable to determine type of obj");
            ProjectSourceFile source = currentOpenSourceFile();
            Log.i("Assuming contextless action. Current file is %s", source.getFileName());
            if(source) {
                folder = cast(ProjectFolder) source.getParent();
                project = source.getProject();
            }
        }

        if(project) {
            Dialog diag = dialogFactory(project, folder);
            Log.i("Showing new file diag..");
            diag.show();
        }
    } 

    /// Construct the "New File" dialog with some optional defaults
    FileDialog createFileDialog(UIString caption, int flags = DialogFlag.Modal | 
                            DialogFlag.Resizable | FileDialogFlag.FileMustExist) {

        FileDialog diag = new FileDialog(caption, window, null, flags);
        
        return diag;
    }

    /// When a file is dropped onto the window..
    void onFileDropped(string[] fileNames) {

        bool first = true;
        for(int i = 0; i < fileNames.length; i++) {
            openSourceFile(fileNames[i], null, first);
            first = false;
        }
    }

    /// Given a filename, or an existing SourceFile, open it in a tab. If chosen, also make it the active tab.
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

            if(!(file ? editor.load(file) : editor.load(filename))) {
                Log.d("file ", filename, " can't be opened.");
                if(filename != "New File") {
                    if(window)
                        window.showMessageBox(UIString.fromId("ERROR_OPEN_FILE"c), 
                            UIString.fromId("ERROR_OPENING_FILE_1"c) ~ " " ~ toUTF32(filename) ~ " " ~ UIString.fromId("ERROR_OPENING_FILE_2"c));
                }
                Log.w("Aborting file open operation");
                return false;
            }
            
            _tabs.addTab(editor, toUTF32(baseName(filename)), null, true, filename.toUTF32);
            tabLocation = _tabs.tabIndex(filename);
            TabItem tab = _tabs.tab(filename);
            tab.objectParam = file;
            _tabs.selectTab(tabLocation, true);
            _tabs.layout(_tabs.pos);
        }

        if(focus) {
            focusEditor(filename);
        }

        //requestLayout();
        return true;
    }

    /// Can this frame close? AKA, do we have unsaved changes?
    bool onCanClose() {
        //TODO: check for unsaved edits
        return true;
    }

    /// Cleanup state after closing, either by choice or by sigterm
    void onClose() {
        // TODO: save window state
        // TODO: save settings
        // TODO: stop subprocesses
    }

    /// Change the focussed tab
    void focusEditor(string ID) {
        Widget widget = _tabs.tabBody(ID);
        if(widget) {
            if(widget.visible)
                widget.setFocus();
        }
    }


}