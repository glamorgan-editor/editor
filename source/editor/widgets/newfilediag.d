module source.editor.widgets.newfilediag;

import dlangui.dialogs.dialog;
import dlangui.dialogs.filedlg;

import dlangui.dialogs.dialog;
import dlangui.widgets.widget;
import dlangui.widgets.controls;
import dlangui.widgets.lists;
import dlangui.widgets.editors;
import dlangui.widgets.layouts;

import dlangui.dml.parser;

import dlangui.core.i18n;
import std.conv;
import std.path;
import std.file;
import std.utf : toUTF32;
import std.algorithm;
import std.range;

import source.editor.workspace.project;
import source.editor.workspace.types;
import source.editor.actions.commands;
import source.editor.ui.frame;

class FileCreationResult {
    Project project;
    string filename;

    this(Project project, string filename) {
        this.project = project;
        this.filename = filename;
    }
}

class NewFileDiag : Dialog {

    EditorFrame _frame;
    Project _project;
    ProjectFolder _folder;

    string _fileName = "newFile.txt";
    string _location;
    string _fullPath;
    string[] _sourcePaths;

    StringListWidget _projectTemplateList;
    EditBox _templateDescription;
    DirEditLine _editLocation;

    EditLine _editFileName;
    TextWidget _statusText;

    int _currentTemplateIndex = -1;
    ProjectTemplate _currentTemplate;
    ProjectTemplate[] _templates;


    this(EditorFrame parent, Project currProject, ProjectFolder folder) {
        super(UIString.fromId("OPTION_GNEW_SOURCE_FILE"c), parent.window, 
                DialogFlag.Modal | DialogFlag.Resizable | DialogFlag.Popup, 
                500, 400);
            
        _frame = parent;
        _icon = "dlangui-logo1";
        this._project = currProject;
        this._folder = folder;
        _location = folder ? folder.getFileName() : currProject.getDir();

        _sourcePaths = currProject.getSourcePaths();

        if(_sourcePaths.length)
            _location = _sourcePaths[0];
        if(folder)
            _location = folder.getFileName();

    }

    override void initialize() {
        super.initialize();

        Widget content; 

        try {
            content = parseML(q{
                VerticalLayout {
                    id: layoutV
                        padding: Rect {5, 5, 5, 5}
                    
                    layoutWidth: fill; layoutHeight: fill
                        HorizontalLayout {
                            layoutWidth: fill; layoutHeight: fill
                            VerticalLayout {
                                margins: 5
                                    layoutWidth: 50%; layoutHeight: fill
                                    TextWidget { text: OPTION_PROJECT_TEMPLATE }
                                    StringListWidget {
                                        id: projectTemplateList
                                        layoutWidth: wrap; layoutHeight: fill
                                    }
                            }

                            VerticalLayout {
                                margins: 5
                                    layoutWidth: 50%; layoutHeight: fill
                                    TextWidget { text: OPTION_PROJECT_DESCRIPT }
                                    EditBox {
                                        id: templateDescription; readOnly: true
                                        layoutWidth: fill; layoutHeight: fill
                                    }
                            }
                        }

                        TableLayout {
                            margins: 5
                            colCount: 2

                            layoutWidth: fill; layoutHeight: wrap

                            TextWidget { text: NAME }
                            EditLine( 
                                id: editName;
                                text: "newFile";
                                layoutWidth: fill
                            )

                            TextWidget { text: LOCATION }
                            DirEditLine {
                                id: editLocation;
                                layoutWidth: fill
                            }
                        }

                        TextWidget {
                            id: statusText;
                            text: "";
                            layoutWidth: fill;
                            textColor: 0xFF0000
                        }
                }
            });
        } catch (Exception except) {
            Log.e("Exception parsing New File DML", except);
            throw except;
        }

        _projectTemplateList = content.childById!StringListWidget("projectTemplateList");
        _templateDescription = content.childById!EditBox("templateDescription");
        _editFileName        = content.childById!EditLine("editName");
        _editLocation        = content.childById!DirEditLine("editLocation");
        _editLocation.text   = toUTF32(_location);

        _statusText          = content.childById!TextWidget("statusText");

        _editLocation.caption = "Select Folder"d;

        _editFileName.enterKey.connect(&onEnter);
        _editLocation.enterKey.connect(&onEnter);

        _editFileName.setDefaultPopupMenu();
        _editLocation.setDefaultPopupMenu();


        dstring[] templateNames;

        foreach(temp; _templates) {
            templateNames ~= temp.name;
        }

        _projectTemplateList.items = templateNames;
        _projectTemplateList.selectedItemIndex = 0;

        templateSelected(0);

        _editLocation.contentChange = delegate (EditableContent source) {
            _location = toUTF8(source.text);
            validate();
        };

        _editFileName.contentChange = delegate (EditableContent source) {
            _fileName = toUTF8(source.text);
            validate();
        };

        _projectTemplateList.itemSelected = delegate (Widget source, int itemIndex) {
            templateSelected(itemIndex);
            return true;
        };

        _projectTemplateList.itemClick = delegate (Widget source, int itemIndex) {
            templateSelected(itemIndex);
            return true;
        };

        addChild(content);
        addChild(createButtonsPanel([ACTION_GFILE_NEW_SOURCE_FILE, ACTION_GCANCEL], 0, 0));
    }

    protected bool onEnter(EditWidgetBase edit) {
        if(!validate())
            return false;
        close(_buttonActions[0]);

        return true;
    }

    bool error(dstring message) {
        _statusText.text = message;
        return message.empty;
    }

    bool validate() {
        string fileName = _fileName;
        string fullFileName = fileName;

        if(!_currentTemplate.fileExtension.empty && fileName.endsWith(_currentTemplate.fileExtension))
            fileName = fileName[0 .. $ - _currentTemplate.fileExtension.length];
        else 
            fullFileName = fullFileName ~ _currentTemplate.fileExtension;
        
        _fullPath = buildNormalizedPath(_location, fullFileName);

        if(!isValidFilename(fileName))
            return error("Invalid file");
        if(!exists(_location)||!isDir(_location))
            return error("Location does not exist");
        
        string projectPath = _project.getDir();
        if(!isSubdirOf(_location, projectPath))
            return error("location is outside project folder");
        
        return true;
        
    }

    protected void templateSelected(int index) {
        if(_currentTemplateIndex == index)
            return;

        _currentTemplateIndex = index;
        _currentTemplate = _templates[index];
        _templateDescription.text = _currentTemplate.description;

        validate();
    }

    private bool isSubdirOf(string path, string basePath) {
        if(path.equal(basePath))
            return true;
        
        if(path.length > basePath.length + 1 && path.startsWith(basePath)) {
            char c = path[basePath.length];
            return c == '/' || c == '\\';
        }

        return false;
    }

}


class ProjectTemplate {
    dstring name;
    dstring description;
    string fileExtension;
    string sourceCode;

    this(dstring name, dstring desc, string ext, string source) {
        this.name = name;
        this.description = desc;
        this.fileExtension = ext;
        this.sourceCode = source;
    }
}