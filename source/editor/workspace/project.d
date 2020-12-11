module source.editor.workspace.project;

import dlangui.core.settings;

import source.editor.workspace.workspace;
import source.editor.workspace.defs;
import source.editor.workspace.types;

import std.path;
import std.utf;

string[] includePath;

class Project : WorkspaceItem {
    protected Workspace _workspace;
    protected ProjectFolder _items;

    protected ProjectSourceFile _mainFile;
    protected SettingsFile _projectFile;

    protected bool _isSubproject;
    protected bool _isEmbeddedSubproject;

    protected dstring _rootProjectName;

    protected string[] _sourcePaths;
    

    this(Workspace ws, string filename = null) {
        super(filename);
        _workspace = ws;

        if(_workspace) {
            foreach(obj; _workspace.includePath.array) {
                includePath ~= obj.str;
            }
        }

        _items = new ProjectFolder(filename.dirName);
        _projectFile = new SettingsFile(filename);
    }

    void setRootProject(Project p) {
        if(p) {
            _isSubproject = true;
            _rootProjectName = p._name;
        } else {
            _isSubproject = false;
        }
    }

    string relativeToAbsolutePath(string path) {
        if (isAbsolute(path))
            return path;
        return buildNormalizedPath(_directory, path);
    }

    string absoluteToRelativePath(string path) {
        if (!isAbsolute(path))
            return path;
        return relativePath(path, _directory);
    }

    @property string settingsFileName() {
        return buildNormalizedPath(_directory, toUTF8(_name) ~ ".settings");
    }

    @property SettingsFile getContent() {
        return _projectFile;
    }

    override @property dstring getName() {
        return super.getName();
    }

    override @property void setName(dstring newName) {
        super.setName(newName);
        _projectFile.setString("name", toUTF8(newName));
    }

    override @property dstring getDescription() {
        return _description;
    }

    @property string[] getSourcePaths() {
        return _sourcePaths;
    }
}