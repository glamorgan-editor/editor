module source.editor.actions.EditorCommands;

import dlangui;

/**
 * An enum containing IDs for every Action the program is
 *  equipped to handle.
 */

enum EditorActions : int {
    FileNew = 1010000,

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

const Action ACTION_GFILE_NEW_SOURCE_FILE = new Action(EditorActions.FileNew, "MENU_FILE_NEW_SOURCE_FILE"c, "document-new", KeyCode.KEY_N, KeyFlag.Control);
const Action ACTION_GFILE_OPEN            = new Action(EditorActions.FileOpen, "MENU_FILE_OPEN_FILE"c, "document-open", KeyCode.KEY_O, KeyFlag.Control);
const Action ACTION_GCANCEL               = new Action(EditorActions.Cancel, "MENU_CANCEL"c, "menu-cancel");
const Action ACTION_GFILE_SAVE            = (new Action(EditorActions.FileSave, "MENU_FILE_SAVE"c, "document-save", KeyCode.KEY_S, KeyFlag.Control)).disableByDefault();
const Action ACTION_GFILE_SAVE_AS         = (new Action(EditorActions.FileSaveAs, "MENU_FILE_SAVE_AS"c)).disableByDefault();
const Action ACTION_GFILE_EXIT            = new Action(EditorActions.FileExit, "MENU_FILE_EXIT"c, "document-close", KeyCode.KEY_X, KeyFlag.Alt);

const Action ACTION_GEDIT_PREFERENCES     = (new Action(EditorActions.EditSettings, "MENU_EDIT_PREFERENCES"c, null)).disableByDefault();
const Action ACTION_GEDIT_TOGGLE_INDENT   = (new Action(EditorActions.EditIndent, "MENU_EDIT_INDENT"c, "edit-indent", KeyCode.TAB, 0)).addAccelerator(KeyCode.KEY_BRACKETOPEN, KeyFlag.Control).disableByDefault();

const Action ACTION_GWINDOW_SHOW_HOME     = new Action(EditorActions.WindowShowHome, "MENU_WINDOW_SHOW_HOME"c);

const Action ACTION_GVIEW_TOGGLE_TOOLBAR  = (new Action(EditorActions.ViewToolbar, "MENU_VIEW_SHOW_TOOLBAR"c, null)).disableByDefault();
const Action ACTION_GVIEW_TOGGLE_STATUS   = (new Action(EditorActions.ViewStatus, "MENU_VIEW_SHOW_TOOLBAR"c, null)).disableByDefault();

const Action ACTION_GHELP_VIEW            = new Action(EditorActions.HelpView, "MENU_HELP_VIEW"c);
const Action ACTION_GHELP_ABOUT           = new Action(EditorActions.HelpAbout, "MENU_HELP_ABOUT"c);


