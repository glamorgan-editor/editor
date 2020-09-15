module source.editor.ui.frame;

import dlangui;

import source.editor.actions.EditorCommands;

class EditorFrame : AppFrame /*, ProgramExecutionStatusListener, BreakpointListChangeListener, BookmarkListChangeListener */ {
    private ToolBarComboBox _currentProjectConfig;


    MenuItem mainMenu;
    TabWidget _tabs;

    private auto workspaceOpened = false;

    this(Window window) {
        super();
        window.mainWidget = this;
        window.onFilesDropped = &onFileDropped;
        window.onCanClose = &onCanClose;
        window.onClose = &onClose;

    }

    @property bool isWorkspaceOpened() {
        return workspaceOpened;
    }

    @property bool setWorkspaceOpened(bool status) {
        workspaceOpened = status;
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
        if(a) {
            switch(a.id) {
                default: return true;
                // TODO!
            }
        }

        return true;
    }

    void onFileDropped(string[] fileNames) {

        bool first = true;
        for(int i = 0; i < fileNames.length; i++) {
            //openSourcefile(fileNames[i], null, first);
            first = false;
        }
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


}