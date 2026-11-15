/*
 * src/cdbgLayout.cw — Inspection panes and the View menu.
 *
 * Created: 2026-10-30
 * Author: Charles Tilbury
 *
 * Changelog:
 *   2026-10-30  Add the multi-pane layout and Preferences.
 *   2026-11-15  Apply the Cwhip coding standard.
 */

// Build the right-hand locals, stack, breakpoint, output, and console panes.
//
// host: Horizontal paned that receives the right column.
// Returns: Nothing.
void Cdbg.buildInspectionLayout(Gtk.Paned host) {
    rightColumn = Gtk.Paned(Gtk.Paned.VERTICAL)
    rightColumn.setHExpand(true)
    rightColumn.setVExpand(true)
    rightColumn.setPosition(420)
    host.append(rightColumn)
    topMid = Gtk.Paned(Gtk.Paned.VERTICAL)
    topMid.setHExpand(true)
    topMid.setVExpand(true)
    topMid.setPosition(220)
    topInspection = Gtk.Notebook()
    topInspection.setBorderedTabs()
    topInspection.setScrollable(true)
    topInspection.setHExpand(true)
    topInspection.setVExpand(true)
    midInspection = Gtk.Notebook()
    midInspection.setBorderedTabs()
    midInspection.setScrollable(true)
    midInspection.setHExpand(true)
    midInspection.setVExpand(true)
    bottomRow = Gtk.Paned()
    bottomRow.setHExpand(true)
    bottomRow.setVExpand(true)
    bottomRow.setPosition(400)
    topMid.append(topInspection)
    topMid.append(midInspection)
    rightColumn.append(topMid)
    rightColumn.append(bottomRow)
    locals = pane()
    watches = pane()
    runtimeValues = pane()
    stack = pane()
    breaks = pane()
    threads = pane()
    console = pane()
    programOutput = pane()
    locals.setLineSelection(true)
    locals.onLineActivated(_self().localsClicked)
    localsScroll = scroll(locals)
    watchesScroll = scroll(watches)
    runtimeScroll = scroll(runtimeValues)
    stackScroll = scroll(stack)
    breaksScroll = scroll(breaks)
    threadsScroll = scroll(threads)
    outputNotebook = Gtk.Notebook()
    outputNotebook.setBorderedTabs()
    outputNotebook.setScrollable(true)
    outputNotebook.setHExpand(true)
    outputNotebook.setVExpand(true)
    consoleNotebook = Gtk.Notebook()
    consoleNotebook.setBorderedTabs()
    consoleNotebook.setScrollable(true)
    consoleNotebook.setHExpand(true)
    consoleNotebook.setVExpand(true)
    outputScroll = scroll(programOutput)
    consoleScroll = scroll(console)
    bottomRow.append(outputNotebook)
    bottomRow.append(consoleNotebook)
    stack.setLineSelection(true)
    stack.onLineActivated(_self().stackClicked)
    breaks.setLineSelection(true)
    breaks.onLineActivated(_self().breakpointClicked)
    threads.setLineSelection(true)
    threads.onLineActivated(_self().threadClicked)
    threadIds = []
    breakMenu = Gtk.ContextMenu(breaks.widget())
    disableBreakItem = breakMenu.addItem(
            "Disable Breakpoint",
            _self().disableSelectedBreakpoint)
    enableBreakItem = breakMenu.addItem(
            "Enable Breakpoint",
            _self().enableSelectedBreakpoint)
    breakMenu.addItem("Edit Condition...", _self().showBreakpointCondition)
    breakMenu.addItem("Hit Count...", _self().showBreakpointHitCount)
    deleteBreakItem = breakMenu.addItem(
            "Delete Breakpoint",
            _self().deleteSelectedBreakpoint)
    watches.setLineSelection(true)
    watches.onLineActivated(_self().watchClicked)
    watchMenu = Gtk.ContextMenu(watches.widget())
    watchMenu.addItem("Add Watch...", _self().showWatch)
    watchMenu.addItem("Add Watch for Symbol", _self().watchSymbolFromWatches)
    watchMenu.addItem("Copy Friendly Value", _self().copyWatchFriendly)
    deleteWatchItem = watchMenu.addItem(
            "Delete Watch",
            _self().deleteSelectedWatch)
    Gtk.ContextMenu localsMenu = Gtk.ContextMenu(locals.widget())
    localsMenu.addItem("Add Watch for Symbol", _self().watchSymbolFromLocals)
    localsMenu.addItem("Copy Friendly Value", _self().copyLocalsFriendly)
    outputMenu = Gtk.ContextMenu(programOutput.widget())
    outputMenu.addItem("Clear", _self().clearOutput)
    outputMenu.addItem("Copy", _self().copyOutput)
    outputMenu.addItem("Copy All", _self().copyAllOutput)
    showLocals = true
    showWatches = true
    showStack = true
    showBreaks = true
    showOutput = true
    showConsole = true
    showRuntime = false
    showThreads = false
    localsAttached = false
    watchesAttached = false
    runtimeAttached = false
    stackAttached = false
    breaksAttached = false
    threadsAttached = false
    outputAttached = false
    consoleAttached = false
    syncInspectionPages()
}

// Add the View menu items that show or hide each inspection pane.
//
// Parameters: none.
// Returns: Nothing.
void Cdbg.addViewMenu() {
    int64 viewMenu = menu.addMenu("View")
    viewLocalsItem = menu.addCheckItem(
            viewMenu,
            "Locals / Arguments",
            showLocals,
            _self().viewLocalsChecked)
    viewWatchesItem = menu.addCheckItem(
            viewMenu,
            "Watches",
            showWatches,
            _self().viewWatchesChecked)
    viewStackItem = menu.addCheckItem(
            viewMenu,
            "Stack",
            showStack,
            _self().viewStackChecked)
    viewBreaksItem = menu.addCheckItem(
            viewMenu,
            "Breakpoints",
            showBreaks,
            _self().viewBreaksChecked)
    viewThreadsItem = menu.addCheckItem(
            viewMenu,
            "Threads",
            showThreads,
            _self().viewThreadsChecked)
    viewOutputItem = menu.addCheckItem(
            viewMenu,
            "Program Output",
            showOutput,
            _self().viewOutputChecked)
    viewConsoleItem = menu.addCheckItem(
            viewMenu,
            "Debugger Console",
            showConsole,
            _self().viewConsoleChecked)
    viewRuntimeItem = menu.addCheckItem(
            viewMenu,
            "Runtime Values",
            showRuntime,
            _self().viewRuntimeChecked)
}

// Show or hide the Locals pane when its View menu check changes.
//
// active: True when the Locals menu item is checked.
// Returns: Nothing.
void Cdbg.viewLocalsChecked(bool active) {
    setPanelVisible("locals", active)
}
// Show or hide the Watches pane when its View menu check changes.
//
// active: True when the Watches menu item is checked.
// Returns: Nothing.
void Cdbg.viewWatchesChecked(bool active) {
    setPanelVisible("watches", active)
}
// Show or hide the Stack pane when its View menu check changes.
//
// active: True when the Stack menu item is checked.
// Returns: Nothing.
void Cdbg.viewStackChecked(bool active) {
    setPanelVisible("stack", active)
}
// Show or hide the Breakpoints pane when its View menu check changes.
//
// active: True when the Breakpoints menu item is checked.
// Returns: Nothing.
void Cdbg.viewBreaksChecked(bool active) {
    setPanelVisible("breaks", active)
}
// Show or hide the Threads pane when its View menu check changes.
//
// active: True when the Threads menu item is checked.
// Returns: Nothing.
void Cdbg.viewThreadsChecked(bool active) {
    setPanelVisible("threads", active)
}
// Show or hide the Program Output pane when its View menu check changes.
//
// active: True when the Program Output menu item is checked.
// Returns: Nothing.
void Cdbg.viewOutputChecked(bool active) {
    setPanelVisible("output", active)
}
// Show or hide the Debugger Console pane when its View menu check changes.
//
// active: True when the Debugger Console menu item is checked.
// Returns: Nothing.
void Cdbg.viewConsoleChecked(bool active) {
    setPanelVisible("console", active)
}
// Show or hide the Runtime Values pane when its View menu check changes.
//
// active: True when the Runtime Values menu item is checked.
// Returns: Nothing.
void Cdbg.viewRuntimeChecked(bool active) {
    setPanelVisible("runtime", active)
}

// Show or hide one inspection pane and remember the choice.
//
// name: Pane id: locals, watches, stack, breaks, output, console, runtime, or
// threads.
// active: True to show the pane.
// Returns: Nothing.
void Cdbg.setPanelVisible(String name, bool active) {
    if (name.equals("locals")) {
        showLocals = active
    }
    if (name.equals("watches")) {
        showWatches = active
    }
    if (name.equals("stack")) {
        showStack = active
    }
    if (name.equals("breaks")) {
        showBreaks = active
    }
    if (name.equals("threads")) {
        showThreads = active
    }
    if (name.equals("output")) {
        showOutput = active
    }
    if (name.equals("console")) {
        showConsole = active
    }
    if (name.equals("runtime")) {
        showRuntime = active
    }
    syncInspectionPages()
    syncViewMenuChecks()
}

// Invert one inspection pane's visibility.
//
// name: Pane id, as in setPanelVisible.
// Returns: Nothing.
void Cdbg.togglePanel(String name) {
    if (name.equals("locals")) {
        setPanelVisible(name, !showLocals)
    }
    if (name.equals("watches")) {
        setPanelVisible(name, !showWatches)
    }
    if (name.equals("stack")) {
        setPanelVisible(name, !showStack)
    }
    if (name.equals("breaks")) {
        setPanelVisible(name, !showBreaks)
    }
    if (name.equals("threads")) {
        setPanelVisible(name, !showThreads)
    }
    if (name.equals("output")) {
        setPanelVisible(name, !showOutput)
    }
    if (name.equals("console")) {
        setPanelVisible(name, !showConsole)
    }
    if (name.equals("runtime")) {
        setPanelVisible(name, !showRuntime)
    }
}

// Make each View menu check match the pane it controls.
//
// Parameters: none.
// Returns: Nothing.
void Cdbg.syncViewMenuChecks() {
    if (menu == null) {
        return
    }
    menu.setItemChecked(viewLocalsItem, showLocals)
    menu.setItemChecked(viewWatchesItem, showWatches)
    menu.setItemChecked(viewStackItem, showStack)
    menu.setItemChecked(viewBreaksItem, showBreaks)
    menu.setItemChecked(viewThreadsItem, showThreads)
    menu.setItemChecked(viewOutputItem, showOutput)
    menu.setItemChecked(viewConsoleItem, showConsole)
    menu.setItemChecked(viewRuntimeItem, showRuntime)
}

// Add or remove one notebook page so the notebook matches the pane's
// visibility. The caller updates the attached flag after this returns.
//
// notebook: Inspection notebook that owns the page.
// item: Scrolled page to add or remove.
// title: Tab title.
// want: True when the page should be present.
// attached: True when the page is already in the notebook.
// Returns: Nothing.
void Cdbg.syncPage(
        Gtk.Notebook notebook,
        Gtk.ScrolledWindow item,
        String title,
        bool want,
        bool attached) {
    // Caller updates the attached flag after this returns via
    // syncInspectionPages.
    if (want && !attached) {
        notebook.appendPage(item, title)
    }
    if (!want && attached) {
        notebook.remove(item)
    }
}

// Add or remove every inspection page to match the current visibility flags.
//
// Parameters: none.
// Returns: Nothing.
void Cdbg.syncInspectionPages() {
    if (showLocals != localsAttached) {
        syncPage(
                topInspection,
                localsScroll,
                "Locals / Arguments (Cwhip / Native)",
                showLocals,
                localsAttached)
        localsAttached = showLocals
    }
    if (showWatches != watchesAttached) {
        syncPage(
                topInspection,
                watchesScroll,
                "Watches (Cwhip / Native)",
                showWatches,
                watchesAttached)
        watchesAttached = showWatches
    }
    if (showRuntime != runtimeAttached) {
        syncPage(
                topInspection,
                runtimeScroll,
                "Runtime Values",
                showRuntime,
                runtimeAttached)
        runtimeAttached = showRuntime
    }
    if (showStack != stackAttached) {
        syncPage(midInspection, stackScroll, "Stack", showStack, stackAttached)
        stackAttached = showStack
    }
    if (showBreaks != breaksAttached) {
        syncPage(
                midInspection,
                breaksScroll,
                "Breakpoints",
                showBreaks,
                breaksAttached)
        breaksAttached = showBreaks
    }
    if (showThreads != threadsAttached) {
        syncPage(
                midInspection,
                threadsScroll,
                "Threads",
                showThreads,
                threadsAttached)
        threadsAttached = showThreads
    }
    if (showOutput != outputAttached) {
        syncPage(
                outputNotebook,
                outputScroll,
                "Program Output",
                showOutput,
                outputAttached)
        outputAttached = showOutput
    }
    if (showConsole != consoleAttached) {
        syncPage(
                consoleNotebook,
                consoleScroll,
                "Debugger Console",
                showConsole,
                consoleAttached)
        consoleAttached = showConsole
    }
    topInspection.setVisible(topInspection.pageCount() > 0)
    midInspection.setVisible(midInspection.pageCount() > 0)
    topMid.setVisible(topInspection.visible() || midInspection.visible())
    outputNotebook.setVisible(showOutput)
    consoleNotebook.setVisible(showConsole)
    bottomRow.setVisible(showOutput || showConsole)
    rightColumn.setVisible(topMid.visible() || bottomRow.visible())
}
