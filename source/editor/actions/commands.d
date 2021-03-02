module source.editor.actions.commands;

import dlangui;

/**
 * An enum containing IDs for every Action the program is
 *  equipped to handle.
 */

enum EditorActions : int {
    FileNew = 1_010_000,

    FileOpen,

    FileSave,
    FileSaveAs,

    //CloseFile,

    FileExit,

    EditSettings,
    EditIndent,

    WindowShowHome,

    ViewHome,
    ViewToolbar,
    ViewStatus,

    HelpView,
    HelpAbout,

    Cancel

}

/// Open a new, empty tab
const Action ACTION_GFILE_NEW_SOURCE_FILE = new Action(EditorActions.FileNew, "MENU_FILE_NEW_SOURCE_FILE"c,
                                                "document-new", KeyCode.KEY_N, KeyFlag.Control);
/// Open a tab from a file on disk
const Action ACTION_GFILE_OPEN            = new Action(EditorActions.FileOpen, "MENU_FILE_OPEN_FILE"c, "document-open",
                                                KeyCode.KEY_O, KeyFlag.Control);
/// Cancel whatever action was chosen last.
const Action ACTION_GCANCEL               = new Action(EditorActions.Cancel, "MENU_CANCEL"c, "menu-cancel");

/// Save the active tab to the file backing it
const Action ACTION_GFILE_SAVE            = (new Action(EditorActions.FileSave, "MENU_FILE_SAVE"c, "document-save",
                                                KeyCode.KEY_S, KeyFlag.Control)).disableByDefault();

/// Save the active tab to a new file
const Action ACTION_GFILE_SAVE_AS         = (new Action(EditorActions.FileSaveAs, "MENU_FILE_SAVE_AS"c))
                                                .disableByDefault();

/// Close the current tab
const Action ACTION_GFILE_EXIT            = new Action(EditorActions.FileExit, "MENU_FILE_EXIT"c, "document-close", 
                                                KeyCode.KEY_X, KeyFlag.Alt);

/// Open the Preferences menu
const Action ACTION_GEDIT_PREFERENCES     = (new Action(EditorActions.EditSettings, "MENU_EDIT_PREFERENCES"c, null))
                                                .disableByDefault();

/// Toggle auto-indentation features
const Action ACTION_GEDIT_TOGGLE_INDENT   = (new Action(EditorActions.EditIndent, "MENU_EDIT_INDENT"c, "edit-indent", 
                                            KeyCode.TAB, 0)).addAccelerator(KeyCode.KEY_BRACKETOPEN, KeyFlag.Control)
                                                            .disableByDefault();

/// Close all tabs and show the landing window
const Action ACTION_GWINDOW_SHOW_HOME     = new Action(EditorActions.WindowShowHome, "MENU_WINDOW_SHOW_HOME"c);

/// Toggle the command toolbar
const Action ACTION_GVIEW_TOGGLE_TOOLBAR  = (new Action(EditorActions.ViewToolbar, "MENU_VIEW_SHOW_TOOLBAR"c, null))
                                                .disableByDefault();
/// Toggle the lower status bar
const Action ACTION_GVIEW_TOGGLE_STATUS   = (new Action(EditorActions.ViewStatus, "MENU_VIEW_SHOW_TOOLBAR"c, null))
                                                .disableByDefault();

/// Show documentation
const Action ACTION_GHELP_VIEW            = new Action(EditorActions.HelpView, "MENU_HELP_VIEW"c);
/// Show information about the Ameliorator
const Action ACTION_GHELP_ABOUT           = new Action(EditorActions.HelpAbout, "MENU_HELP_ABOUT"c);


