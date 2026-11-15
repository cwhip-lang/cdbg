/*
 * src/cdbgSettings.cw — Appearance and keyboard settings file.
 *
 * Created: 2026-10-30
 * Author: Charles Tilbury
 *
 * Changelog:
 *   2026-10-30  Add the multi-pane layout and Preferences.
 *   2026-11-15  Apply the Cwhip coding standard.
 */

// Appearance, default break-at-start, and keyboard bindings stored in the user
// config file ~/.config/cwhip/cdbg.toml. The debugger owns one settings object
// for the life of the window.
class CdbgSettings {
    public:
    String fontFamily
    int64 fontSize
    int64 tabWidth
    bool lineNumbers
    bool defaultBreakAtStart
    list commands
    String path
    String original
    String errors
    bool writable
    int64 shortcutRevision

    // Load appearance, the default break-at-start flag, and the command list
    // from the user config file, creating built-in defaults first.
    //
    // Parameters: none.
    // Returns: Nothing.
    CdbgSettings() {
        resetAppearance()
        defaultBreakAtStart = true
        commands = [
                CommandBinding("quit", "Quit", "<Control>q"),
                CommandBinding("load", "Load Executable", ""),
                CommandBinding("open-source", "Open Source Code", ""),
                CommandBinding("find", "Find", "<Control>f"),
                CommandBinding("preferences", "Preferences", "<Control>comma"),
                CommandBinding("resume", "Run / Continue", "F5"),
                CommandBinding("restart", "Restart", ""),
                CommandBinding("interrupt", "Pause", ""),
                CommandBinding("step-into", "Step Into", "F11"),
                CommandBinding("step-over", "Step Over", "F10"),
                CommandBinding("step-out", "Step Out", "<Shift>F11"),
                CommandBinding(
                        "toggle-breakpoint",
                        "Set/Clear Breakpoint",
                        "F9"),
                CommandBinding(
                    "toggle-enable",
                    "Enable/Disable Breakpoint",
                    "<Control>F9"),
                CommandBinding("view-locals", "Show Locals", ""),
                CommandBinding("view-watches", "Show Watches", ""),
                CommandBinding("view-stack", "Show Stack", ""),
                CommandBinding("view-breaks", "Show Breakpoints", ""),
                CommandBinding("view-output", "Show Program Output", ""),
                CommandBinding("view-console", "Show Debugger Console", ""),
                CommandBinding("view-runtime", "Show Runtime Values", ""),
                CommandBinding("view-threads", "Show Threads", "")
                ]
        original = ""
        errors = ""
        writable = true
        shortcutRevision = 1
        String configHome = System.Process().getEnv("XDG_CONFIG_HOME")
        if (configHome.equals("")) {
            configHome = System.FileSystem().join(
                    System.Process().getEnv("HOME"),
                    ".config")
        }
        path = System.FileSystem().join(configHome, "cwhip/cdbg.toml")
        if (!configHome.startsWith("/")) {
            error("XDG_CONFIG_HOME (or HOME fallback) must be an absolute path")
        }
        load()
    }

    void resetAppearance()

    void error(String message)

    CommandBinding command(String id)

    String bindingError(CommandBinding binding, String trigger)

    String value(String section, String key)

    int64 integer(
            String section,
            String key,
            int64 fallback,
            int64 minimum,
            int64 maximum)

    bool boolean(String section, String key, bool fallback)

    String fontError(String font)

    void load()

    void resetKeyboard()

    String serialize()

    int64 byteSpanBound(int64 value, int64 length)
    String byteSpan(String text, int64 first, int64 last)
}

// Restore the built-in font, size, tab width, and line-number defaults.
//
// Parameters: none.
// Returns: Nothing.
void CdbgSettings.resetAppearance() {
    fontFamily = "monospace"
    fontSize = 11
    tabWidth = 4
    lineNumbers = true
}

// Record a settings error and mark the file not writable so a later save will
// not overwrite it.
//
// message: Error text appended to the settings report.
// Returns: Nothing.
void CdbgSettings.error(String message) {
    if (!errors.equals("")) {
        errors.append("\n")
    }
    errors.append(message)
    writable = false
}

// Find a command binding by its id.
//
// id: Command id, such as step-over.
// Returns: The binding, or null when the id is unknown.
CommandBinding CdbgSettings.command(String id) {
    int64 i = 0
    while (i < commands.length) {
        CommandBinding binding = commands[i] as CommandBinding
        if (binding.id.equals(id)) {
            return(binding)
        }
        i = i + 1
    }
    return(null)
}

// Validate a shortcut trigger against the keyboard grammar and the other
// commands.
//
// binding: Command being changed.
// trigger: Candidate shortcut text. Empty clears the binding.
// Returns: An error message, or an empty string when the trigger is
// acceptable.
String CdbgSettings.bindingError(CommandBinding binding, String trigger) {
    if (trigger.equals("")) {
        return("")
    }
    String normalized = binding.normalized
    if (!trigger.equals(binding.trigger)) {
        normalized = Gtk.Keyboard().normalize(trigger)
    }
    if (normalized.equals("")) {
        return(format("Invalid shortcut trigger: {}", trigger))
    }

    int64 i = 0
    while (i < commands.length) {
        CommandBinding other = commands[i] as CommandBinding
        if (other != binding && !other.trigger.equals("") &&
                other.normalized.equals(
                normalized)) {
            return(format(
                    "Shortcut conflicts with {}: {}",
                    other.name,
                    trigger))
        }
        i = i + 1
    }

    return("")
}

// Read one string from the loaded settings file.
//
// section: TOML table name.
// key: Key inside that table.
// Returns: The raw value, or an empty string when the key is absent.
String CdbgSettings.value(String section, String key) {
    return(Gtk.Config().value(original, section, key))
}

// Read an integer setting, checking the inclusive range.
//
// section: TOML table name.
// key: Key inside that table.
// fallback: Value used when the key is missing or invalid.
// minimum: Smallest accepted value.
// maximum: Largest accepted value.
// Returns: The parsed value, or fallback when the key is missing or out of
// range.
int64 CdbgSettings.integer(
        String section,
        String key,
        int64 fallback,
        int64 minimum,
        int64 maximum) {
    String raw = value(section, key)
    if (raw.equals("")) {
        return(fallback)
    }
    if (raw.startsWith("i")) {
        int64 number = byteSpan(raw, 1, raw.length).toInt64()
        if (number >= minimum && number <= maximum) {
            return(number)
        }
    }
    error(format(
            "{}.{} must be an integer from {} to {}",
            section,
            key,
            minimum,
            maximum))
    return(fallback)
}

// Read a boolean setting stored as btrue or bfalse.
//
// section: TOML table name.
// key: Key inside that table.
// fallback: Value used when the key is missing or invalid.
// Returns: The parsed value, or fallback when the key is missing or invalid.
bool CdbgSettings.boolean(String section, String key, bool fallback) {
    String raw = value(section, key)
    if (raw.equals("")) {
        return(fallback)
    }
    if (raw.equals("btrue")) {
        return(true)
    }
    if (raw.equals("bfalse")) {
        return(false)
    }
    error(format("{}.{} must be a boolean", section, key))
    return(fallback)
}

// Validate a font family name.
//
// font: Family name from the settings file or the Appearance page.
// Returns: An error message, or an empty string when the name is acceptable.
String CdbgSettings.fontError(String font) {
    if (font.trim().equals("") || font.length > 128 || font.contains("\n") ||
            font.contains(
            "\r") || font.contains(
            "\t")) {
        return(
                "Font family must be 1-128 characters, without control characters")
    }
    if (!Gtk.Font().isMonospace(font)) {
        return("Choose an installed monospace font family (or monospace)")
    }
    return("")
}

// Read the user settings file and apply appearance, session, and keyboard
// keys.
//
// Parameters: none.
// Returns: Nothing.
void CdbgSettings.load() {
    String presence = Gtk.Config().fileStatus(path)
    if (presence.equals("missing")) {
        return
    }
    if (presence.length > 0) {
        error(format("Could not read settings: {}", presence))
        return
    }
    if (!System.FileSystem().isFile(path) || System.FileSystem().fileSize(
            path) > 65536) {
        error("Settings must be a regular TOML file no larger than 64 KiB")
        return
    }
    System.File file = null
    try {
        file = System.File(path, "r")
    }
    except(Exception) {
        error(format(
                "Could not read settings: {}",
                System.System().lastError()))
        return
    }
    try {
        original = file.readAll()
    }
    except(Exception) as failure {
        error(failure.message)
    }
    String readError = System.System().lastError()
    file.close()
    if (!readError.equals("")) {
        error(readError)
    }
    if (!GtkSource.Content().isText(original)) {
        error("Malformed settings TOML: embedded NUL bytes")
        return
    }
    String malformed = Gtk.Config().validate(original)
    if (!malformed.equals("")) {
        error(format("Malformed settings TOML: {}", malformed))
        return
    }
    String version = value("", "version")
    if (!version.equals("") && !version.equals("i1")) {
        error("Unsupported settings version: expected version = 1")
        return
    }
    if (!value("", "appearance").equals("") && !value("", "appearance").equals(
            "t")) {
        error("appearance must be a table")
    }
    if (!value("", "keyboard").equals("") && !value("", "keyboard").equals(
            "t")) {
        error("keyboard must be a table")
    }
    if (!value("", "session").equals("") && !value("", "session").equals(
            "t")) {
        error("session must be a table")
    }

    String font = value("appearance", "font_family")
    if (!font.equals("")) {

        if (!font.startsWith("s")) {
            error("appearance.font_family must be a string")
        }
        else {
            String name = byteSpan(font, 1, font.length)
            String problem = fontError(name)
            if (problem.equals("")) {
                fontFamily = name
            }
            else {
                error(problem)
            }
        }

    }

    fontSize = integer("appearance", "font_size", fontSize, 6, 72)
    tabWidth = integer("appearance", "tab_width", tabWidth, 1, 16)
    lineNumbers = boolean("appearance", "line_numbers", lineNumbers)
    defaultBreakAtStart = boolean(
            "session",
            "break_at_start",
            defaultBreakAtStart)

    int64 i = 0
    while (i < commands.length) {
        CommandBinding binding = commands[i] as CommandBinding
        String raw = value("keyboard", binding.id)
        if (!raw.equals("")) {
            if (!raw.startsWith("s")) {
                error(format("keyboard.{} must be a string", binding.id))
            }
            else {
                binding.setTrigger(byteSpan(raw, 1, raw.length))
            }
        }
        i = i + 1
    }

    i = 0
    while (i < commands.length) {
        CommandBinding binding = commands[i] as CommandBinding
        String problem = bindingError(binding, binding.trigger)
        if (!problem.equals("")) {
            binding.valid = false
            error(problem)
        }
        i = i + 1
    }
    String key = Gtk.Config().key(original, "keyboard", 0)
    i = 0
    while (!key.equals("")) {
        if (command(key) == null) {
            error(format("Unknown keyboard command: {}", key))
        }
        i = i + 1
        key = Gtk.Config().key(original, "keyboard", i)
    }
}

// Restore every command to its built-in shortcut.
//
// Parameters: none.
// Returns: Nothing.
void CdbgSettings.resetKeyboard() {
    int64 i = 0
    while (i < commands.length) {
        CommandBinding binding = commands[i] as CommandBinding
        binding.setTrigger(binding.defaultTrigger)
        i = i + 1
    }
}

// Render appearance, the default break-at-start flag, and keyboard bindings as
// TOML.
//
// Parameters: none.
// Returns: The file text to write.
String CdbgSettings.serialize() {
    String text = format("version = 1\n[appearance]\nfont_family = {}\nfont_size = {}\ntab_width = {}\nline_numbers = {}\n[session]\nbreak_at_start = {}\n[keyboard]\n",
            Gtk.Config().quote(fontFamily),
            fontSize,
            tabWidth,
            lineNumbers,
            defaultBreakAtStart)
    int64 i = 0
    while (i < commands.length) {
        CommandBinding binding = commands[i] as CommandBinding
        text.append(format("{} = {}\n", binding.id, Gtk.Config().quote(
                binding.trigger)))
        i = i + 1
    }
    return(Gtk.Config().merge(original, text))
}

// Clamp a half-open index into a string.
//
// value: Requested index.
// length: String length.
// Returns: An index in range, from 0 through length.
int64 CdbgSettings.byteSpanBound(int64 value, int64 length) {
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
String CdbgSettings.byteSpan(String text, int64 first, int64 last) {
    int64 lower = byteSpanBound(first, text.length)
    int64 end = byteSpanBound(last, text.length)
    if (end <= lower) {
        return("")
    }
    return(text[lower..(end - 1)])
}

