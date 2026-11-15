/*
 * src/cdbgUi.cw — Status line, toolbar sensitivity, and diagnostics.
 *
 * Created: 2026-10-30
 * Author: Charles Tilbury
 *
 * Changelog:
 *   2026-10-30  Split debugger methods into modules.
 *   2026-11-15  Apply the Cwhip coding standard.
 */

// Return the source tab that is selected.
//
// Parameters: none.
// Returns: The tab, or null when the message page is showing.
DebugSource Cdbg.currentSource() {
    int64 page = sourceTabs.currentPage()
    if (page < 0 || page >= sourceFiles.length) {
        return(null)
    }
    DebugSource file = sourceFiles[page] as DebugSource
    if (file.path.equals("")) {
        return(null)
    }
    return(file)
}

// Remember the source view of the selected tab and refresh command
// sensitivity.
//
// Parameters: none.
// Returns: Nothing.
void Cdbg.sourceChanged() {
    int64 page = sourceTabs.currentPage()
    if (page >= 0 && page < sourceFiles.length) {
        source = (sourceFiles[page] as DebugSource).view
    }
    controls()
}

// Select a source line from a gutter or text click. Positioning clicks do not
// change breakpoints; F9 or Breakpoint > Set/Clear does that.
//
// line: 1-based line that was clicked.
// Returns: Nothing.
void Cdbg.sourceLineClicked(int64 line) {
    DebugSource file = currentSource()
    if (file != null && line > 0) {
        file.view.centerCursor(line, 1)
    }
    controls()
}

// Enable or disable menu items and toolbar buttons from the session. Execution
// controls stay live while a stop refresh is pending; execute discards that
// refresh and reports presses it cannot accept.
//
// Parameters: none.
// Returns: Nothing.
void Cdbg.controls() {
    if (window == null || window.disposed()) {
        return
    }
    bool ready = loaded && !running && !executing && active == null && requests.length == 0
    bool canBreak = ready && currentSource() != null
    menu.setItemEnabled(toggleBreakItem, canBreak)
    menu.setItemEnabled(toggleEnableItem, canBreak)
    // Execution controls stay live while a stop refresh is pending; execute()
    // discards that refresh and reports presses it cannot accept.
    bool canExecute = loaded && !running && !restarting
    runButton.setSensitive(canExecute)
    stepButton.setSensitive(canExecute && hasRun)
    nextButton.setSensitive(canExecute && hasRun)
    finishButton.setSensitive(canExecute && hasRun)
    interruptButton.setSensitive(loaded && running)
    restartButton.setSensitive(
            loaded && active == null && requests.length == 0 && !restarting)
}

// Append program output to the history kept for the output pane, trimming old
// text.
//
// previous: Text already in the pane.
// text: Text just read from the program.
// Returns: The combined history.
String Cdbg.outputHistory(String previous, String text) {
    previous.append(text)
    if (previous.length <= 65536) {
        return(previous)
    }
    int64 first = previous.length - 65536
    while (first < previous.length && previous[first] >= 128u &&
            previous[
            first] <= 191u) {
        first = first + 1
    }
    return(byteSpan(previous, first, previous.length))
}

// Append a line to the Debugger Console.
//
// text: Text to append. A newline is added when it has none.
// Returns: Nothing.
void Cdbg.log(String text) {
    console.setText(outputHistory(console.text(), text))
}

// Append inferior output to the Program Output pane.
//
// text: Text just read from the program terminal.
// Returns: Nothing.
void Cdbg.programLog(String text) {
    if (text.equals("")) {
        return
    }
    text = text.replace(Process.OutputDecoder().decode(buffer[0u]), "\\0")
    programOutput.setText(outputHistory(programOutput.text(), text))
}

// Drain the program terminal into the Program Output pane.
//
// Parameters: none.
// Returns: Nothing.
void Cdbg.readProgramOutput() {
    if (terminal == null) {
        return
    }
    programLog(terminal.read())
    if (!terminal.error().equals("")) {
        failWith("CDBG3003", format("Program output transport for {} failed: {}; reload the target to retry",
                targetPath, terminal.error()))
    }
}

// Report a press that was refused because an execution command is pending.
// That is expected user activity, so it is status text rather than an error.
//
// text: Status message.
// Returns: Nothing.
void Cdbg.ignored(String text) {
    status.setText(text)
    log(format("{}\n", text))
}

// Show a failure in the status line and the Debugger Console without a
// diagnostic code.
//
// text: Failure message.
// Returns: Nothing.
void Cdbg.fail(String text) {
    failWith("CDBG1000", text)
}

// Show a failure in the status line, the Debugger Console, and stderr under a
// CDBG code.
//
// code: Diagnostic code, such as CDBG3003.
// text: Failure message, without the code prefix.
// Returns: Nothing.
void Cdbg.failWith(String code, String text) {
    failure = text
    String message = DebugDiagnostic().emit("error", code, text)
    if (window != null && !window.disposed()) {
        status.setText(message)
        log(format("{}\n", message))
    }
}

// Report a target-load failure and leave any existing session in place.
//
// text: Failure message.
// Returns: Nothing.
void Cdbg.loadFailure(String text) {
    fileFailure("CDBG1001", text)
}

// Report a file-open or compile failure with a CDBG code and a parented
// dialog.
//
// code: Diagnostic code.
// text: Failure message.
// Returns: Nothing.
void Cdbg.fileFailure(String code, String text) {
    failWith(code, text)
    if (window != null && !window.disposed()) {
        Gtk.AlertDialog().show(window, "Could not load file",
                DebugDiagnostic().header(
                "error",
                code,
                text))
    }
}

// Clamp a half-open index into a string.
//
// value: Requested index.
// length: String length.
// Returns: An index in range, from 0 through length.
int64 Cdbg.byteSpanBound(int64 value, int64 length) {
    int64 index = value
    if (index < 0) {
        index = index + length
    }
    if (index < 0) {
        return(0)
    }
    if (index > length) {
        return(length)
    }
    return(index)
}

// Copy a half-open byte span of a string.
//
// text: Source string.
// first: Inclusive start index.
// last: Exclusive end index.
// Returns: The span, or an empty string when the range is empty.
String Cdbg.byteSpan(String text, int64 first, int64 last) {
    int64 lower = byteSpanBound(first, text.length)
    int64 end = byteSpanBound(last, text.length)
    if (end <= lower) {
        return("")
    }
    return(text[lower..(end - 1)])
}
