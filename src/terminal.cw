/*
 * src/terminal.cw — Program-output terminal owned by the debugger.
 *
 * Created: 2026-10-13
 * Author: Charles Tilbury
 *
 * Changelog:
 *   2026-10-13  Add the program-output terminal.
 *   2026-11-15  Apply the Cwhip coding standard.
 */

import process as TerminalProcess

// Program-output terminal owned by the debugger. The native handle is private
// because the terminal allocates and releases it.
class DebugTerminal {
    private:
    handle _native
    TerminalProcess.OutputDecoder _decoder
    bool _closed
    bool _finished

    handle _nativeOpen()
    String _nativePath(handle terminal)
    buffer _nativeRead(handle terminal)
    void _nativeClose(handle terminal)
    String _nativeError(handle terminal)
    void _nativeDestroy(handle terminal)

    public:
    String valuesScript()
    // Open the program-output terminal and its decoder. The terminal owns the
    // native handle.
    //
    // Parameters: none.
    // Returns: Nothing.
    DebugTerminal() {
        _native = _nativeOpen()
        _decoder = TerminalProcess.OutputDecoder()
        _closed = false
        _finished = false
    }

    String path()

    String read()

    void close()

    String error()

    // Release the native terminal when this object is destroyed.
    //
    // Parameters: none.
    // Returns: Nothing.
    destroy {
        if (_native != null) {
            _nativeDestroy(_native)
            _native = null
        }
    }
}

// Return the inferior-side path of the program terminal.
//
// Parameters: none.
// Returns: The path passed to GDB as the inferior tty.
String DebugTerminal.path() {
    return(_nativePath(_native))
}

// Read program output that is waiting, and finish the decoder after the
// terminal closes.
//
// Parameters: none.
// Returns: Decoded text, or an empty string when nothing new is available.
String DebugTerminal.read() {
    if (_native != null && !_closed) {
        return(_decoder.decode(_nativeRead(_native)))
    }
    if (!_finished) {
        _finished = true
        return(_decoder.finish())
    }
    return("")
}

// Close the program terminal so the inferior receives end of file.
//
// Parameters: none.
// Returns: Nothing.
void DebugTerminal.close() {
    if (!_closed) {
        _closed = true
        if (_native != null) {
            _nativeClose(_native)
        }
    }
}

// Return the last native terminal error.
//
// Parameters: none.
// Returns: The error text, or an empty string when the terminal is healthy.
String DebugTerminal.error() {
    return(_nativeError(_native))
}


// Return the GDB Python script that prints Cwhip values.
//
// Parameters: none.
// Returns: The script source embedded in the debugger.
String DebugTerminal.valuesScript() from "cwhip_cdbg_values_script"
// Open a native pseudo-terminal for program output.
//
// Parameters: none.
// Returns: The terminal handle, or null when allocation fails.
handle DebugTerminal._nativeOpen() from "cwhip_cdbg_terminal_open"
// Return the path of an open native terminal.
//
// terminal: Handle from _nativeOpen.
// Returns: The slave path.
String DebugTerminal._nativePath(
        handle terminal) from "cwhip_cdbg_terminal_path"
// Read bytes waiting on a native terminal.
//
// terminal: Handle from _nativeOpen.
// Returns: The bytes, which may be empty.
buffer DebugTerminal._nativeRead(
        handle terminal) from "cwhip_cdbg_terminal_read"
// Close a native terminal.
//
// terminal: Handle from _nativeOpen.
// Returns: Nothing.
void DebugTerminal._nativeClose(
        handle terminal) from "cwhip_cdbg_terminal_close"
// Return the last error from a native terminal.
//
// terminal: Handle from _nativeOpen.
// Returns: The error text.
String DebugTerminal._nativeError(
        handle terminal) from "cwhip_cdbg_terminal_error"
// Free a native terminal.
//
// terminal: Handle from _nativeOpen.
// Returns: Nothing.
void DebugTerminal._nativeDestroy(
        handle terminal) from "cwhip_cdbg_terminal_destroy"
