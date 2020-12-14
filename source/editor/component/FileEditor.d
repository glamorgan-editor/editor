module source.editor.component.FileEditor;

import source.editor.workspace.types;

import dlangui.widgets.srcedit;


class FileEditor : SourceEdit {
    this(string ID) {
        super(ID);

    }

    this() {
        this("GLEDIT");
    }

    protected ProjectSourceFile _projectSourceFile;
    @property ProjectSourceFile getProjectSourceFile() { return _projectSourceFile; }


    override bool load(string filename) {
        _projectSourceFile = null;
        bool result = super.load(filename);
        return result;
    }

    bool load(ProjectSourceFile file) {
        if(!load(file.getFileName())) {
            _projectSourceFile = null;
            return false;
        }

        _projectSourceFile = file;
        return true;
    }

    bool save() {
        return _content.save();
    }

}