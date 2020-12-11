module source.editor.workspace.workspace;

import dlangui.core.settings;

import source.editor.workspace.defs;
import source.editor.ui.frame;

import std.string;
import std.utf;
import std.file;


class Workspace : WorkspaceItem {

    protected SettingsFile _workspaceFile;
    protected EditorFrame _frame;

    this(EditorFrame frame, string fileName = null) {
        super(fileName);

        this._workspaceFile = new SettingsFile(fileName);
        this._frame = frame;
    }

    @property WorkspaceFile[] getFiles() {
        return new WorkspaceFile[4]; // TODO: Settings!
    }

    @property void setFiles(WorkspaceFile[] files) {
        //TODO: When we get settings working!
    }

    /**
     * The saved "Include Path" setting.
     * Used for intelligent autocomplete and symbol parsing.
     * 
     * Newline delimited.
     */
    @property Setting includePath() {
        return _workspaceFile.objectByPath("includePath", true);
    }



    override bool save(string fileName = null) {
        if(fileName.length > 0)
            this._fileName = fileName;
        
        if(_fileName.empty)
            return false;

        immutable auto nameZero = this._name.empty;
        immutable auto descZero = this._description.empty;

        if(nameZero || descZero) {
            this._name = nameZero ? "" : this._name;
            this._description = descZero ? "" : this._description;
            // TODO: Settingssss!
        }

        _workspaceFile.setString("name", toUTF8(_name));
        _workspaceFile.setString("description", toUTF8(_description));

        if(!_workspaceFile.save(_fileName, true)) {
            return false;
        }

        return true;

    }

    override bool load(string fileName = null) {
        if(fileName.length > 0)
            this._fileName = fileName;
        
        if(!exists(_fileName) || !isFile(_fileName))
            return false;
        
        // TODO: settings

        if(!_workspaceFile.load(_fileName)) {
            return false;
        }

        _name = toUTF32(_workspaceFile["name"].str);
        _description = toUTF32(_workspaceFile["description"].str);

        if(_name.empty) {
            return false;
        }
        return true;
    }

    void close() {

    }

    void refresh() {

    }

}

/// Global variable; the currently active workspace.
__gshared Workspace currentWorkspace;