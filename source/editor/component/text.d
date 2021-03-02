module source.editor.component.text;

import source.editor.workspace.types;

import dlangui.widgets.srcedit;

/// The main text editor component at the heart of the operation.
class FileEditor : SourceEdit {
    /// Constructor taking the name of the tab.
    this(string ID) {
        super(ID);

    }

    /// Default constructor - initialises to the landing page
    this() {
        this("GLEDIT");
    }

    protected ProjectSourceFile _projectSourceFile;
    @property ProjectSourceFile getProjectSourceFile() { return _projectSourceFile; }


    override bool load(string filename) {
        _projectSourceFile = null;
        const bool result = super.load(filename);
        return result;
    }

    /// Load the data of the current file from disk
    bool load(ProjectSourceFile file) {
        if(!load(file.getFileName())) {
            _projectSourceFile = null;
            return false;
        }

        _projectSourceFile = file;
        return true;
    }

    /// Save changes to disk
    bool save() {
        return _content.save();
    }

}