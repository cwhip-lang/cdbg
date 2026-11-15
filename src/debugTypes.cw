/*
 * src/debugTypes.cw — Diagnostic, request, source, and breakpoint records.
 *
 * Created: 2026-10-30
 * Author: Charles Tilbury
 *
 * Changelog:
 *   2026-10-30  Split debugger methods into modules.
 *   2026-11-15  Apply the Cwhip coding standard.
 */

// Formats the cdbg: severity[code]: text lines written to stderr.
class DebugDiagnostic {
    public:
    String header(String severity, String code, String text)
    String emit(String severity, String code, String text)
}

// Format one cdbg diagnostic line.
//
// severity: error or warning.
// code: Stable CDBG code.
// text: Message body.
// Returns: The line cdbg: severity[code]: text, without a trailing newline.
String DebugDiagnostic.header(String severity, String code, String text) {
    return(format("cdbg: {}[{}]: {}", severity, code, text))
}

// Write one diagnostic to stderr and return the same line.
//
// severity: error or warning.
// code: Stable CDBG code.
// text: Message body.
// Returns: The formatted line.
String DebugDiagnostic.emit(String severity, String code, String text) {
    String message = header(severity, code, text)
    System.StandardIO().writeErrorLine(message)
    return(message)
}


// One MI command waiting on GDB, with the purpose the response handler uses.
class DebugRequest {
    public:
    String token
    String command
    String purpose
    String expression
    // Remember one queued MI command and why it was sent.
    //
    // number: MI token.
    // text: MI command text.
    // kind: Purpose string the response handler switches on.
    // watch: Expression carried with the command, or empty.
    // Returns: Nothing.
    DebugRequest(String number, String text, String kind, String watch) {
        token = number
        command = text
        purpose = kind
        expression = watch
    }
}

// One source tab: the path, the read-only view, and the scroller around it.
class DebugSource {
    public:
    DebugSource _self()
    String path
    GtkSource.View view
    Gtk.ScrolledWindow scroll
    int64 centeredStop
    void<DebugSource> closeAction
    // Remember one open source tab.
    //
    // filename: Path shown in the tab, or empty for the message page.
    // text: View that displays the file.
    // container: Scroller that holds the view.
    // Returns: Nothing.
    DebugSource(
            String filename,
            GtkSource.View text,
            Gtk.ScrolledWindow container) {
        path = filename
        view = text
        scroll = container
    }
    void close()
}

// Run the tab's close callback.
//
// Parameters: none.
// Returns: Nothing.
void DebugSource.close() {
    closeAction(_self())
}

// Return this source tab as the callback receiver the GTK bindings require.
//
// Parameters: none.
// Returns: This DebugSource instance.
DebugSource DebugSource._self() from "cwhip_gtk_self"

// One breakpoint location the editor tracks for marks and the Breakpoints tab.
class DebugBreakpoint {
    public:
    String number
    String path
    String line
    bool enabled
    String condition
    int64 ignoreCount
    // Remember one breakpoint location the editor is tracking.
    //
    // id: GDB breakpoint number.
    // file: Source path.
    // row: 1-based line text.
    // active: True when the breakpoint is enabled.
    // Returns: Nothing.
    DebugBreakpoint(String id, String file, String row, bool active) {
        number = id
        path = file
        line = row
        enabled = active
        condition = ""
        ignoreCount = 0
    }
}

