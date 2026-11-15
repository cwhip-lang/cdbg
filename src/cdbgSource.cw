/*
 * src/cdbgSource.cw — Source display and the stopped-line highlight.
 *
 * Created: 2026-10-30
 * Author: Charles Tilbury
 *
 * Changelog:
 *   2026-10-30  Split debugger methods into modules.
 *   2026-11-15  Apply the Cwhip coding standard.
 */

// Report whether a request is a locals, watches, or runtime-value refresh.
//
// request: Queued or active MI request.
// Returns: True for value-inspector requests that may be discarded when
// execution starts.
bool Cdbg.inspection(DebugRequest request) {
    return (request.purpose.equals("location") || request.purpose.equals(
            "locals") ||
            request.purpose.equals(
            "stack") || request.purpose.equals(
            "watch") ||
            request.purpose.equals(
            "threads"))
}

// Queue a stop refresh: locals, watches, stack, threads, and the current
// frame.
//
// Parameters: none.
// Returns: Nothing.
void Cdbg.refresh() {
    if (!loaded || running || !hasRun || executing) {
        return
    }
    list pendingRequests = []
    int64 requestIndex = 0
    while (requestIndex < requests.length) {
        DebugRequest request = requests[requestIndex] as DebugRequest
        if (!inspection(request)) {
            pendingRequests.append(request)
        }
        requestIndex = requestIndex + 1
    }
    requests = pendingRequests
    if (active != null && inspection(active)) {
        active.purpose = "stale"
    }
    watches.setText("")
    runtimeLocals = "(Refreshing locals)"
    runtimeWatches = ""
    updateRuntimeValues()
    enqueue("-stack-info-frame", "location", "")
    if (valueInspector) {
        enqueue("-cdbg-inspect locals", "locals", "")
    }
        else {
        enqueue("-stack-list-variables --all-values", "locals", "")
    }
    enqueue("-stack-list-frames 0 30", "stack", "")
    enqueue("-thread-info", "threads", "")

    int64 i = 0
    while (i < expressions.length) {
        String expression = expressions[i] as String
        if (valueInspector) {
            enqueue(format("-cdbg-inspect watch {}", MiParser().quote(
                    expression)), "watch", expression)
        }
        else {
            watches.setText(format(
                    "{}{} = <value inspector unavailable>\n",
                    watches.text(),
                    expression))
            runtimeWatches.append(format(
                    "{} = <value inspector unavailable>\n",
                    expression))
        }
        i = i + 1
    }

    updateRuntimeValues()
}

// Rebuild the Runtime Values pane from the last locals and watches text.
//
// Parameters: none.
// Returns: Nothing.
void Cdbg.updateRuntimeValues() {
    runtimeValues.setText(format(
            "Locals / Arguments (GDB types and raw values)\n{}\nWatches (GDB types and raw values)\n{}",
            runtimeLocals,
            runtimeWatches))
}

// Open the stopped frame's source, center its line, and update the status.
//
// frame: MI frame tuple from the stop or a stack selection.
// Returns: Nothing.
void Cdbg.showLocation(MiValue frame) {
    String path = frame.field("fullname").text
    if (path.equals("")) {
        path = frame.field("file").text
    }
    String line = frame.field("line").text
    location = format("{}:{} ({})", path, line, frame.field("func").text)
    if (atStart) {
        status.setText(format("Stopped at start: {}", location))
    }
        else {
        status.setText(format("Stopped: {}", location))
    }
    if (selectedFrame == 0 && !stopDetail.equals("")) {
        status.setText(format("{}; {}", status.text(), stopDetail))
    }

    if (path.equals("")) {
        sourceMessage("Source unavailable: stopped frame has no source path")
    }
        else {
        showSource(path, line)
        // New tabs schedule revealPendingSource; existing tabs can focus now.
        if (source != null && pendingRevealLine < 1) {
            source.focus()
        }
    }

}

// Center a source line after a newly opened tab has been mapped. The first
// open of a runtime file has no size yet, so this retries once.
//
// Parameters: none.
// Returns: Nothing.
void Cdbg.revealPendingSource() {
    int64 line = pendingRevealLine
    if (closed || source == null || line < 1) {
        pendingRevealLine = 0
        pendingRevealTries = 0
        return
    }
    source.centerCursor(line, 1)
    source.focus()
    if (source.line() != line && pendingRevealTries < 1) {
        pendingRevealTries = pendingRevealTries + 1
        Gtk.Application().post(_self().revealPendingSource)
        return
    }
    pendingRevealLine = 0
    pendingRevealTries = 0
}

// Read a source file for display. On failure, show the parented error dialog
// and leave every tab unchanged.
//
// path: File to read.
// Returns: True when the text was read into sourceText.
bool Cdbg.readText(String path) {
    sourceText = ""
    if (path.equals("") || !System.FileSystem().isFile(path)) {
        loadFailure(format("Source unavailable: {}", path))
        return(false)
    }
    System.File file = null
    try {
        file = System.File(path, "r")
        String text = file.readAll()
        String readError = System.System().lastError()
        file.close()
        if (!readError.equals("")) {
            loadFailure(format(
                    "Could not read source {}: {}",
                    path,
                    readError))
            return(false)
        }
        if (!GtkSource.Content().isText(text)) {
            loadFailure(format("Source is not a text file: {}", path))
            return(false)
        }
        sourceText = text
        return(true)
    }
    except(Exception) as err {
        if (file != null && file.isOpen()) {
            file.close()
        }
        loadFailure(
                format("Could not display source {}: {}", path, err.message))
    }
    return(false)
}

// Read a file the way showSource does, without opening a tab.
//
// path: File to test.
// Returns: True when the file is readable text.
bool Cdbg.readableText(String path) {
    bool readable = readText(path)
    sourceText = ""
    return(readable)
}

// Show a text file in a read-only tab, reusing a tab that is already open for
// that path.
//
// path: File to show.
// line: 1-based line to reveal, or empty to leave the cursor.
// Returns: True when the tab is showing the file.
bool Cdbg.showSource(String path, String line) {
    String absolute = System.FileSystem().absolutePath(path)
    if (!absolute.equals("")) {
        path = absolute
    }

    int64 i = 0
    while (i < sourceFiles.length) {

        DebugSource file = sourceFiles[i] as DebugSource
        if (file.path.equals(path)) {
            bool switched = sourceTabs.currentPage() != i
            source = file.view
            sourceTabs.setCurrentPage(i)
            if (identifier(line) && line.toInt64() > 0 &&
                    (switched
                            || source.line() != line.toInt64()
                            || file.centeredStop != stopCount)) {
                source.centerCursor(line.toInt64(), 1)
                file.centeredStop = stopCount
            }
            removeMessagePage()
            return(true)
        }

        i = i + 1
    }

    if (!readText(path)) {
        return(false)
    }
    source = pane()
    source.setText(sourceText)
    sourceText = ""
    source.setLanguage(GtkSource.Content().languageFor(path))
    source.setLineSelection(true)
    source.onLineActivated(_self().sourceLineClicked)
    Gtk.ScrolledWindow container = scroll(source)
    DebugSource document = DebugSource(path, source, container)
    document.closeAction = _self().closeSource
    source.setMarkStyle("breakpoint", "media-record-symbolic", "#f4b4b4")
    source.setMarkStyle(
            "disabled-breakpoint",
            "media-record-symbolic",
            "#cccccc")
    sourceFiles.append(document)
    syncBreakpointMarks()
    sourceTabs.appendClosablePage(
            container,
            System.FileSystem().basename(path),
            document.close)
    removeMessagePage()
    sourceTabs.setCurrentPage(sourceFiles.length - 1)
    if (identifier(line) && line.toInt64() > 0) {
        document.centeredStop = stopCount
        pendingRevealLine = line.toInt64()
        pendingRevealTries = 0
        Gtk.Application().post(_self().revealPendingSource)
    }
    return(true)
}
