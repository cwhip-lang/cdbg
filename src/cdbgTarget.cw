/*
 * src/cdbgTarget.cw — Load Executable and Open Source Code.
 *
 * Created: 2026-10-30
 * Author: Charles Tilbury
 *
 * Changelog:
 *   2026-10-30  Split debugger methods into modules.
 *   2026-11-15  Apply the Cwhip coding standard.
 */

// Choose the directory a file dialog should open in.
//
// Parameters: none.
// Returns: The target's directory, or the working directory when no target is
// loaded.
String Cdbg.initialPath() {
    if (!targetPath.equals("")) {
        return(System.FileSystem().absolutePath(targetPath))
    }
    if (source != null) {
        int64 i = 0
        while (i < sourceFiles.length) {
            DebugSource file = sourceFiles[i] as DebugSource
            if (file.view == source && !file.path.equals("")) {
                return(file.path)
            }
            i = i + 1
        }
    }
    return("")
}

// Open the file dialog used by Load Executable.
//
// Parameters: none.
// Returns: Nothing.
void Cdbg.chooseExecutable() {
    if (fileDialog != null && fileDialog.pending()) {
        return
    }
    fileDialog = Gtk.FileDialog(
            window,
            false,
            initialPath(),
            _self().executableChosen)
}

// Open the file dialog used by Open Source Code.
//
// Parameters: none.
// Returns: Nothing.
void Cdbg.chooseSource() {
    if (fileDialog != null && fileDialog.pending()) {
        return
    }
    fileDialog = Gtk.FileDialog(
            window,
            false,
            initialPath(),
            _self().sourceChosen)
}

// Load the executable the file dialog returned.
//
// path: Chosen path. An empty path means the dialog was cancelled.
// Returns: Nothing.
void Cdbg.executableChosen(String path) {
    fileDialog = null
    if (!path.equals("")) {
        loadTarget(path)
    }
}

// Open the source file the file dialog returned.
//
// path: Chosen path. An empty path means the dialog was cancelled.
// Returns: Nothing.
void Cdbg.sourceChosen(String path) {
    fileDialog = null
    if (!path.equals("")) {
        openSource(path)
    }
}

// Close the main window, which ends the session.
//
// Parameters: none.
// Returns: Nothing.
void Cdbg.quit() {
    if (window != null && !window.disposed()) {
        window.close()
    }
}

// Start a fresh GDB session for a local executable or .cw file, with
// breakpoints cleared and the program not run. A path that is not a regular
// file is rejected before the current session or source tabs are touched. A
// .cw path is compiled with -g first.
//
// path: Path the user chose or passed on the command line.
// Returns: Nothing.
void Cdbg.loadTarget(String path) {
    String absolute = System.FileSystem().absolutePath(path)
    if (absolute.equals("")) {
        absolute = path
    }
    if (path.equals("") || !System.FileSystem().isFile(absolute)) {
        loadFailure(format("Target is not a local file: {}", absolute))
        return
    }
    targetPath = path
    launch()
}

// Show a text file read-only without compiling it or touching the debug
// session. Binary, invalid UTF-8, and executable files are rejected with an
// error dialog and no tab change.
//
// path: Path the user chose.
// Returns: True when a tab is showing the file.
bool Cdbg.openSource(String path) {
    String absolute = System.FileSystem().absolutePath(path)
    if (absolute.equals("")) {
        absolute = path
    }
    if (!System.FileSystem().isFile(absolute)) {
        loadFailure(format("Source is not a local file: {}", absolute))
        return(false)
    }
    if (executableImage(absolute)) {
        loadFailure(format(
                "{} is an executable, not source code; use File > Load Executable...",
                absolute))
        return(false)
    }
    return(showSource(absolute, ""))
}

// Report whether a path looks like a native executable rather than source.
//
// path: File to test.
// Returns: True when the file starts with a binary image header.
bool Cdbg.executableImage(String path) {
    System.File file = null
    try {
        file = System.File(path, "rb")
        String magic = file.read(4)
        file.close()
        return (magic.length == 4 && magic[0] == 127u && magic[1] == 69u &&
                magic[
                2] == 76u && magic[
                3] == 70u)
    }
    except(Exception) {
        if (file != null && file.isOpen()) {
            file.close()
        }
    }
    return(false)
}
