module app;

import dlangui;
import std.stdio;

import source.editor.ui.frame;

mixin APP_ENTRY_POINT;

extern (C) int UIAppMain(string[] args) {
    
    // TODO: Setup text antialiasing

    Window window = Platform.instance.createWindow("Glamorgan", null, WindowFlag.Resizable, 1280, 720);

    Platform.instance.resourceDirs = [ "views" ];

    Platform.instance.uiLanguage = "en";
    //TODO: Textmode!

    window.windowIcon = drawableCache.getImage("glamorgan-logo");   
    EditorFrame frame = new EditorFrame(window);
    
    //TODO: Allow opening files from command line

    window.show();

    return Platform.instance.enterMessageLoop();
}
