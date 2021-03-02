module source.editor.workspace.defs;

import std.utf;
import std.path;

/**
 * This object represents a file that has been opened in the current workspace.
 * 
 * This exists to allow persistence between window openings.
 *
 */
class WorkspaceFile {
    private string _fileName;
    private int _caretColumn;
    private int _caretRow;



    @property string getFileName() {
        return _fileName;
    }

    /**
     * Set the name of the file relevant to this WorkspaceItem.
     * Use this when the name of the file is changed - via a refactor->rename or via a SaveAs.
     */

    @property void setFileName(string newName) {
        this._fileName = newName;
    }


    @property int getColumn() {
        return _caretColumn;
    }

    /**
     * Set the column of the caret in this file.
     */
    @property void setColumn(int newColumn) {
        this._caretColumn = newColumn;
    }

    /**
     * Get the row that the caret is/was on, in this file.
     */
    @property int getRow() {
        return _caretRow;
    }

    /**
     * Set the row of the caret in this file.
     * 
     * @Param _row: The new row number.
     */
    @property void setRow(int newRow) {
        this._caretRow = newRow;
    }
}

/**
 * This class represents a Workspace by itself.
 * It allows you to define where the Workspace is on disk,
 *  the name and a short description of the Workspace.
 * 
 * It provides some helper methods to help display the
 *  name on platforms with less full font support.
 */
class WorkspaceItem {
    protected string _fileName;
    protected string _directory;
    protected dstring _name;
    protected dstring _originalName;
    protected dstring _description;

    /// Construct a new WorkspaceItem out of the given filename.
    this(string fileName = null) {
        this._fileName = fileName;
    }


    @property string getFileName() {
        return this._fileName;
    }

    @property string getDir(){ 
        return this._directory;
    }

    /**
     * Given a full path in the form of:
     *  C:/Workspace/src/thing.c            - WINDOWS
     *  ~/src/thing.c                       - LINUX
     *  /User/Home/Desktop/Files/program.h  - MACOS
     *  boot$home:files/program.c           - CHROMA
     *
     * we extract the directory and the filename,
     *  and set the relevant fields.
     */
    @property void setFileInfo(string fullPath) {
        if(fullPath.length > 0) {
            // TODO: Normalise! DlangUI is cross platform but WINDOWS is not!
            this._fileName = buildNormalizedPath(fullPath);
            //this._directory = getDir(newName);
        } else {
            this._fileName = null;
            this._directory = null;
        }
    }

    @property dstring getName() {
        return _name;
    }

    @property string getNameUTF8() {
        return _name.toUTF8;
    }

    @property void setName(dstring newName) {
        this._name = newName;
    }

    @property dstring getDescription() {
        return this._description;
    }

    @property void setDescription(dstring newDesc) {
        this._description = newDesc;
    }

    /**
     * Load this class from a file.
     * This is a prototype stub declaration and is meant to be overriden.
     */

    bool load(string filename) {
        return false;
    }

    /**
     * Save this class to a file.
     * This is a prototype stub declaration and is meant to be overriden.
     */

    bool save(string filename = null) {
        return false;
    }

}