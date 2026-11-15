/*
 * src/cdbgFind.cw — Find dialog for the source pane.
 *
 * Created: 2026-10-30
 * Author: Charles Tilbury
 *
 * Changelog:
 *   2026-10-30  Split debugger methods into modules.
 *   2026-11-15  Apply the Cwhip coding standard.
 */

// Show the Find dialog and, when the selection is a single line, place that
// text in the entry.
//
// Parameters: none.
// Returns: Nothing.
void Cdbg.showFind() {
    if (findWindow == null || findWindow.disposed()) {
        return
    }
    findStatus.setText("")
    if (source != null && source.hasSelection()) {
        String selected = source.selectedText()
        if (!selected.contains("\n")) {
            findEntry.setText(selected)
        }
    }
    findWindow.setVisible(true)
    findWindow.present()
    findEntry.focus()
}

// Hide the Find dialog.
//
// Parameters: none.
// Returns: Nothing.
void Cdbg.closeFind() {
    if (findWindow != null && !findWindow.disposed()) {
        findWindow.setVisible(false)
    }
}

// Hide the Find dialog when its window is closed.
//
// Parameters: none.
// Returns: True so the window is allowed to close.
bool Cdbg.findCloseRequested() {
    findWindow.setVisible(false)
    return(true)
}
// Search forward for the Find dialog's text.
//
// Parameters: none.
// Returns: Nothing.
void Cdbg.findNext() {
    find(false)
}
// Search backward for the Find dialog's text.
//
// Parameters: none.
// Returns: Nothing.
void Cdbg.findPrevious() {
    find(true)
}

// Search the active source for the Find dialog's text, wrapping at the ends.
//
// backward: True to search toward the start of the file.
// Returns: Nothing.
void Cdbg.find(bool backward) {
    String query = findEntry.text()
    if (query.equals("")) {
        findStatus.setText("Enter text to find")
        return
    }
    if (source == null || currentSource() == null) {
        findStatus.setText("No source file is open")
        return
    }
    int64 before = source.line()
    int64 options = 0
    if (backward) {
        options = GtkSource.View.BACKWARD
    }
    if (!source.findWith(query, options)) {
        findStatus.setText(format("Not found: {}", query))
        return
    }
    int64 after = source.line()
    if ((!backward && after < before) || (backward && after > before)) {
        findStatus.setText(format("Wrapped: {} at line {}", query, after))
    }
    else {
        findStatus.setText(format("Found: {} at line {}", query, after))
    }
}
