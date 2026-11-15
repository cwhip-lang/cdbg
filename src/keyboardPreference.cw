/*
 * src/keyboardPreference.cw — One row of the Keyboard preferences page.
 *
 * Created: 2026-10-30
 * Author: Charles Tilbury
 *
 * Changelog:
 *   2026-10-30  Add the multi-pane layout and Preferences.
 *   2026-11-15  Apply the Cwhip coding standard.
 */

// One row of the Keyboard preferences page. It edits a single command binding.
class KeyboardPreference {
    public:
    KeyboardPreference _self()
    CommandBinding binding
    CdbgSettings settings
    Gtk.Label name
    Gtk.Entry entry
    Gtk.Button recordButton
    Gtk.Button resetButton
    Gtk.Button disableButton
    Gtk.Label errorLabel
    void<> applied
    void<> prepareRecord
    int64 recording
    bool refreshing

    // Build one keyboard-page row and connect its record, reset, and disable
    // buttons.
    //
    // model: Settings object that validates triggers.
    // command: Command this row edits.
    // changed: Callback run after a trigger is accepted.
    // prepare: Callback run before this row starts recording, so other rows
    // cancel.
    // grid: Keyboard grid that receives the row.
    // index: Row index. Each command uses two grid rows.
    // Returns: Nothing.
    KeyboardPreference(
            CdbgSettings model,
            CommandBinding command,
            void<> changed,
            void<> prepare,
            Gtk.Grid grid,
            int64 index) {
        settings = model
        binding = command
        applied = changed
        prepareRecord = prepare
        name = Gtk.Label(binding.name)
        entry = Gtk.Entry(binding.trigger)
        entry.setEditable(false)
        entry.setHExpand(true)
        recordButton = Gtk.Button("Record")
        resetButton = Gtk.Button("Reset")
        disableButton = Gtk.Button("Disable")
        errorLabel = Gtk.Label("")
        grid.attach(name, 0, index * 2, 1, 1)
        grid.attach(entry, 1, index * 2, 1, 1)
        grid.attach(recordButton, 2, index * 2, 1, 1)
        grid.attach(resetButton, 3, index * 2, 1, 1)
        grid.attach(disableButton, 4, index * 2, 1, 1)
        grid.attach(errorLabel, 0, index * 2 + 1, 5, 1)
        entry.onChanged(_self().changedTrigger)
        recordButton.onClicked(_self().record)
        resetButton.onClicked(_self().reset)
        disableButton.onClicked(_self().disable)
    }

    void changedTrigger(String text)
    void record()
    void recorded(String trigger)
    void cancelRecording()
    void reset()
    void disable()
    void setTrigger(String trigger)
    void refresh()
    void setVisible(bool visible)
}

// Validate the entry text and store it when it is a legal trigger.
//
// text: Current entry text.
// Returns: Nothing.
void KeyboardPreference.changedTrigger(String text) {
    if (refreshing) {
        return
    }
    if (text.equals("")) {
        errorLabel.setText("Use Disable to remove this binding")
        return
    }
    String problem = settings.bindingError(binding, text)
    errorLabel.setText(problem)
    if (!problem.equals("")) {
        return
    }
    binding.setTrigger(text)
    applied()
}

// Start recording the next key sequence into this row.
//
// Parameters: none.
// Returns: Nothing.
void KeyboardPreference.record() {
    prepareRecord()
    errorLabel.setText("Press shortcut; Escape cancels")
    recording = Gtk.Keyboard().record(entry, _self().recorded)
}

// Store a recorded trigger, or leave the binding unchanged when recording was
// cancelled.
//
// trigger: Recorded shortcut. Empty means Escape cancelled.
// Returns: Nothing.
void KeyboardPreference.recorded(String trigger) {
    cancelRecording()
    if (!trigger.equals("")) {
        setTrigger(trigger)
    }
}

// Stop key recording on this row and clear its prompt.
//
// Parameters: none.
// Returns: Nothing.
void KeyboardPreference.cancelRecording() {
    if (recording != 0) {
        Gtk.Keyboard().cancel(recording)
        recording = 0
        errorLabel.setText("")
    }
}

// Restore this command's built-in shortcut.
//
// Parameters: none.
// Returns: Nothing.
void KeyboardPreference.reset() {
    cancelRecording()
    setTrigger(binding.defaultTrigger)
}

// Clear this command's shortcut.
//
// Parameters: none.
// Returns: Nothing.
void KeyboardPreference.disable() {
    cancelRecording()
    refreshing = true
    entry.setText("")
    refreshing = false
    binding.setTrigger("")
    errorLabel.setText("")
    applied()
}

// Show a trigger in the entry and validate it.
//
// trigger: Shortcut text to display.
// Returns: Nothing.
void KeyboardPreference.setTrigger(String trigger) {
    refreshing = true
    entry.setText(trigger)
    refreshing = false
    changedTrigger(trigger)
}

// Show the binding's current trigger and cancel any recording.
//
// Parameters: none.
// Returns: Nothing.
void KeyboardPreference.refresh() {
    refreshing = true
    cancelRecording()
    entry.setText(binding.trigger)
    errorLabel.setText("")
    refreshing = false
}

// Show or hide this command's row while the keyboard list is filtered.
//
// visible: True to show the row.
// Returns: Nothing.
void KeyboardPreference.setVisible(bool visible) {
    name.setVisible(visible)
    entry.setVisible(visible)
    recordButton.setVisible(visible)
    resetButton.setVisible(visible)
    disableButton.setVisible(visible)
    errorLabel.setVisible(visible)
}


// Return this row as the callback receiver the GTK bindings require.
//
// Parameters: none.
// Returns: This KeyboardPreference instance.
KeyboardPreference KeyboardPreference._self() from "cwhip_gtk_self"
