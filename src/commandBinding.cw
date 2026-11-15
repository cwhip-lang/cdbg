/*
 * src/commandBinding.cw — One keyboard command and its shortcut.
 *
 * Created: 2026-10-30
 * Author: Charles Tilbury
 *
 * Changelog:
 *   2026-10-30  Add the multi-pane layout and Preferences.
 *   2026-11-15  Apply the Cwhip coding standard.
 */

// One debugger command: its id, the label shown in menus, the built-in
// shortcut, and the shortcut the user has set.
class CommandBinding {
    public:
    String id
    String name
    String defaultTrigger
    String trigger
    String normalized
    bool valid
    void<> action
    // Store one command's id, label, and initial shortcut.
    //
    // command: Stable command id.
    // label: Name shown in the Keyboard page and menus.
    // shortcut: Built-in trigger. Empty means unbound.
    // Returns: Nothing.
    CommandBinding(String command, String label, String shortcut) {
        id = command
        name = label
        defaultTrigger = shortcut
        setTrigger(shortcut)
    }
    void setTrigger(String shortcut)
}

// Replace the shortcut and remember whether it normalizes to a real key
// sequence.
//
// shortcut: New trigger. Empty clears the binding and is valid.
// Returns: Nothing.
void CommandBinding.setTrigger(String shortcut) {
    trigger = shortcut
    normalized = ""
    if (!shortcut.equals("")) {
        normalized = Gtk.Keyboard().normalize(shortcut)
    }
    valid = shortcut.equals("") || normalized.length > 0
}

