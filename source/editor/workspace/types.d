module source.editor.workspace.types;

import std.path;
import std.algorithm;
import std.utf;
import std.conv;
import std.file;
import std.utf;

import dlangui.core.collections;

import source.editor.workspace.project;

/// A Project item without an implementation
class AbstractProjectItem {

    protected Project _project;
    protected AbstractProjectItem _parent;

    protected string _fileName;
    protected dstring _name;

    /// Is this file created by a temp operation
    protected bool _temp;

    /// Constructor with a file name. Can be a path.
    this(string fileName) {
        _fileName = buildNormalizedPath(fileName);
        _name = toUTF32(baseName(_fileName));
    }

    /// Default constructor. Constructs constructively. I hate dscanner.
    this() {
    }

    @property AbstractProjectItem getParent() {
        return _parent;
    }

    @property Project getProject() {
        return _project;
    }

    @property void setProject(Project newProject) {
        _project = newProject;
    }

    @property bool getTemp() {
        return _temp;
    }

    @property void setTemp(bool temp) {
        _temp = temp;
    }

    /// Is path/fileName the current file?
    ProjectSourceFile findSourceFile(string fileName, string path) {
        if(path.equal(_fileName))
            return cast(ProjectSourceFile) this;

        if(_project && fileName.equal(_project.absoluteToRelativePath(_fileName)))
            return cast(ProjectSourceFile) this;
        return null;
    }

    @property string getFileName() {
        return _fileName;
    }

    @property string getDirectory() {
        import std.path : dirName;
        return _fileName.dirName;
    }

    @property dstring getName() {
        return _name;
    }

    @property string getNameUTF8() {
        return _name.toUTF8;
    }


    /// Does the current ProjectItem represent a folder?
    @property bool isFolder() const {
        return false;
    }

    /// How many children does the current ProjectItem have?
    /// Useful for folders / nodes.
    @property int childCount() {
        return 0;
    }

    AbstractProjectItem getChild(int index) {
        return null;
    }

    /// Handles a forced refresh. Updates child nodes if they were modified on disk externally.
    void refresh() {
    }

}

/// Represents a folder in the project bar.
class ProjectFolder : AbstractProjectItem {
    protected ObjectList!AbstractProjectItem _children;

    /// Constructor that takes a file name.
    this(string fileName) {
        super(fileName);
    }

    @property override bool isFolder() const {
        return true;
    }

    @property override int childCount() {
        return _children.count;
    }

    override AbstractProjectItem getChild(int index) {
        return _children[index];
    }

    /// Add a subfolder or a file to this Folder.
    void addChild(AbstractProjectItem item) {
        _children.add(item);
        item._parent = this;
        item._project = _project;
    }

    AbstractProjectItem getChildByPath(string path) {
        for(int i = 0; i < childCount(); i++) {
            if(_children[i]._fileName.equal(path))
                return _children[i];
        }
        return null;
    }

    AbstractProjectItem getChildByName(dstring name) {
        for(int i = 0; i < childCount(); i++) {
            if(_children[i]._name.equal(name))
                return _children[i];
        }
        return null;
    }
    
    override ProjectSourceFile findSourceFile(string fileName, string path) {
        for (int i = 0; i < _children.count; i++) {
            if(ProjectSourceFile result = _children[i].findSourceFile(fileName, path))
                return result;
        }

        return null;
    }

    /// Load all of the files in the folder
    bool loadFolder(string path) {
        string source = relativeToAbsolutePath(path);

        if(exists(source) && isDir(source)) {
            ProjectFolder existing = cast(ProjectFolder) getChildByPath(source);

            if(existing) {
                if(existing.isFolder)
                    existing.loadItems();
                return true;
            }

            auto folder = new ProjectFolder(source);
            addChild(folder);

            folder.loadItems();
            return true;
        }
        return false;
    }

    /// Load a specified item into the editor.
    bool loadFile(string path) {
        string source = relativeToAbsolutePath(path);

        if(exists(source) && isFile(source)) {
            const AbstractProjectItem existing = getChildByPath(source);
            if(existing)
                return true;
            
            auto file = new ProjectSourceFile(source);
            addChild(file);
            return true;
        }

        return false;
    }


    /// Load all of the items in the folder, including subfolders.
    void loadItems() {
        bool[string] loaded;
        string path = _fileName;

        if(exists(path) && isFile(path))
            path = dirName(path);
        
        foreach(entry; dirEntries(path, SpanMode.shallow)) {
            string filename = baseName(entry.name);
            if(entry.isDir) {
                loadFolder(filename);
                loaded[filename] = true;
            } else if(entry.isFile) {
                loadFile(filename);
                loaded[filename] = true;
            }
        }

        for(int i = _children.count - 1; i >= 0; i--) {
            if(!(toUTF8(_children[i]._name) in loaded)) {
                _children.remove(i);
            }
        }

        sortItems();
    }


    /// sortItems() Predicate
    static bool compareProjectItems(AbstractProjectItem item1, AbstractProjectItem item2) {
        return ((item1.isFolder && !item2.isFolder) || 
               ((item1.isFolder == item2.isFolder) && (item1._name < item2._name)));
    }


    /// Sort items by type and name
    void sortItems() {
        import std.algorithm.sorting : sort;
        sort!compareProjectItems(_children.asArray);
    }


    /// Convert a relative (./file.c) to an absolute (C:/files/file.c) path.
    string relativeToAbsolutePath(string path) {
        if(isAbsolute(path))
            return path;

        string filename = _fileName;
        if(exists(filename) && isFile(filename)) {
            filename = dirName(filename);
        }

        return buildNormalizedPath(filename, path);
    }

    override void refresh() {
        loadItems();
    }
}

/// Represents a source file within a project.
class ProjectSourceFile : AbstractProjectItem {
    /// Constructor that takes a file name.
    this(string filename) {
        super(filename);
    }

    /// Get the path of the project this file is in.
    @property string projectFilePath() {
        return _project.absoluteToRelativePath(_fileName);
    }

    void setFilename(string fileName) {
        _fileName = buildNormalizedPath(fileName);
        _name = toUTF32(baseName(_fileName));
    }
}