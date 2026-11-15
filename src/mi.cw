/*
 * src/mi.cw — GDB/MI parser and argument and environment lists.
 *
 * Created: 2026-10-13
 * Author: Charles Tilbury
 *
 * Changelog:
 *   2026-10-13  Initial debugger prototype.
 *   2026-11-15  Apply the Cwhip coding standard.
 */

import process

// One GDB/MI value: either c-string text or a tuple of named fields.
class MiValue {
    public:
    String text
    list keys
    list values

    // Create an empty MI value, with no text and no fields.
    //
    // Parameters: none.
    // Returns: Nothing.
    MiValue() {
        text = ""
        keys = []
        values = []
    }
    MiValue field(String key)
}

// Look up one field of a tuple result.
//
// key: Field name.
// Returns: The field value, or an empty value when the key is absent.
MiValue MiValue.field(String key) {
    int64 i = 0
    while (i < keys.length) {
        if ((keys[i] as String).equals(key)) {
            return(values[i] as MiValue)
        }
        i = i + 1
    }
    return(MiValue())
}


// Parser for one GDB/MI line, plus the quoter used when cdbg sends commands.
class MiParser {
    public:
    String input
    int64 offset
    bool valid
    String token
    String kind
    String result
    MiValue data

    String character()
    bool take(String expected)
    bool digit(String value)
    String word()
    String quoted()
    MiValue value(int64 depth)
    void parse(String line)
    String quote(String text)

    int64 byteSpanBound(int64 value, int64 length)
    String byteSpan(String text, int64 first, int64 last)
}

// Return the next input byte as a one-character string.
//
// Parameters: none.
// Returns: The character, or an empty string at the end of the input.
String MiParser.character() {
    if (offset >= input.length) {
        return("")
    }
    return(byteSpan(input, offset, offset + 1))
}

// Consume the next character when it matches.
//
// expected: Character that must come next.
// Returns: True when the character was consumed. A mismatch marks the parse
// invalid.
bool MiParser.take(String expected) {
    if (!character().equals(expected)) {
        valid = false
        return(false)
    }
    offset = offset + 1
    return(true)
}

// Report whether a one-character string is a decimal digit.
//
// value: One-character string to test.
// Returns: True for characters 0 through 9.
bool MiParser.digit(String value) {
    return(
            value.length == 1
            && int64(value[0]) >= 48
            && int64(value[0]) <= 57)
}

// Read an unquoted MI token up to the next separator.
//
// Parameters: none.
// Returns: The token. An empty token marks the parse invalid.
String MiParser.word() {
    int64 first = offset
    while (offset < input.length && !character().equals("=") &&
            !character().equals(",") && !character().equals("}") &&
            !character().equals(
            "]")) {
        offset = offset + 1
    }
    if (first == offset) {
        valid = false
    }
    return(byteSpan(input, first, offset))
}

// Read a C-style quoted string, including the escapes GDB uses.
//
// Parameters: none.
// Returns: The decoded text. A bad escape marks the parse invalid.
String MiParser.quoted() {
    buffer bytes = buffer[]
    if (!take("\"")) {
        return("")
    }

    while (offset < input.length && !character().equals("\"") && valid) {
        int64 byte = int64(input[offset])
        offset = offset + 1

        if (byte == 92) {
            if (offset >= input.length) {
                valid = false
                return("")
            }
            byte = int64(input[offset])
            offset = offset + 1

            if (byte >= 48 && byte <= 55) {
                int64 number = byte - 48
                int64 count = 1
                while (count < 3 && offset < input.length &&
                        int64(input[
                        offset]) >= 48 && int64(input[
                        offset]) <= 55) {
                    number = number * 8 + int64(input[offset]) - 48
                    offset = offset + 1
                    count = count + 1
                }
                if (number > 255) {
                    valid = false
                    return("")
                }
                byte = number
            }
            else {
                String escapes = "nrtbfv\\\"'"
                list replacements = [10, 13, 9, 8, 12, 11, 92, 34, 39]
                int64 index = escapes.find(byteSpan(input, offset - 1, offset))
                if (index < 0) {
                    valid = false
                    return("")
                }
                byte = int64(replacements[index] as int8)
            }

        }

        bytes.append(uint64(byte))
    }

    take("\"")
    Process.OutputDecoder decoder = Process.OutputDecoder()
    String text = decoder.decode(bytes)
    text.append(decoder.finish())
    return(text)
}

// Parse one MI value: a quoted string, a tuple, or a list.
//
// depth: Current nesting depth. Deeper than 32 is rejected.
// Returns: The value. Past the nesting limit, the parse is marked invalid.
MiValue MiParser.value(int64 depth) {
    MiValue node = MiValue()
    if (depth > 32) {
        valid = false
        return(node)
    }
    if (character().equals("\"")) {
        node.text = quoted()
        return(node)
    }
    String open = character()
    if (!open.equals("{") && !open.equals("[")) {
        valid = false
        return(node)
    }
    offset = offset + 1
    String close = "}"
    if (open.equals("[")) {
        close = "]"
    }

    while (valid && offset < input.length && !character().equals(close)) {
        String key = ""
        if (!character().equals("\"") && !character().equals("{") &&
                !character().equals(
                "[")) {
            key = word()
            take("=")
        }
        else {
            if (open.equals("{")) {
                valid = false
            }
        }
        node.keys.append(key)
        node.values.append(value(depth + 1))
        if (!character().equals(close)) {
            take(",")
            if (character().equals(close)) {
                valid = false
            }
        }
    }

    take(close)
    return(node)
}

// Parse one MI line into a token, a record kind, a result class, and a value.
//
// line: One raw MI line, without the trailing newline.
// Returns: Nothing.
void MiParser.parse(String line) {
    input = line
    offset = 0
    valid = true
    token = ""
    kind = ""
    result = ""
    data = MiValue()
    while (digit(character())) {
        token.append(character())
        offset = offset + 1
    }
    kind = character()
    offset = offset + 1

    if (kind.equals("~") || kind.equals("@") || kind.equals("&")) {
        data.text = quoted()
    }
    else {
        if (kind.equals("^") || kind.equals("*") || kind.equals("=") ||
                kind.equals(
                "+")) {
            result = word()

            while (valid && offset < input.length) {
                take(",")
                // Older GDB versions append unlabelled child locations
                // after a multi-location bkpt result/notification.
                if (character().equals("{") && data.keys.length > 0 &&
                        (data.keys[
                        data.keys.length - 1] as String).equals(
                        "bkpt")) {
                    MiValue parent = data.values[
                            data.values.length - 1] as MiValue
                    MiValue child = value(0)
                    if (!child.field("number").text.startsWith(
                            format("{}.", parent.field(
                            "number").text))) {
                        valid = false
                    }
                    MiValue locations = parent.field("locations")
                    if (locations.values.length == 0) {
                        parent.keys.append("locations")
                        parent.values.append(locations)
                    }
                    locations.keys.append("")
                    locations.values.append(child)
                }
                else {
                    String key = word()
                    take("=")
                    data.keys.append(key)
                    data.values.append(value(0))
                }
            }

        }
        else {
            valid = false
        }
    }

    if (offset != input.length) {
        valid = false
    }
}

// Quote text for an MI command argument.
//
// text: Raw argument text.
// Returns: A double-quoted string with backslashes and quotes escaped.
String MiParser.quote(String text) {
    return(format("\"{}\"", text.replace("\\", "\\\\").replace("\"", "\\\"")
            .replace(
            "\n",
            "\\n").replace(
            "\r",
            "\\r").replace(
            "\t",
            "\\t")))
}

// Clamp a half-open index into a string.
//
// value: Requested index.
// length: String length.
// Returns: An index in range, from 0 through length.
int64 MiParser.byteSpanBound(int64 value, int64 length) {
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
String MiParser.byteSpan(String text, int64 first, int64 last) {
    int64 lower = byteSpanBound(first, text.length)
    int64 end = byteSpanBound(last, text.length)
    if (end <= lower) {
        return("")
    }
    return(text[lower..(end - 1)])
}


// Shell-like inferior argument parsing without invoking a shell. Blanks
// separate words. Single quotes are literal. Double quotes honor backslash
// escapes. An unquoted backslash escapes the next character. Empty quotes give
// an empty word.
class ArgumentList {
    public:
    list values
    String error

    // Create an empty argument list.
    //
    // Parameters: none.
    // Returns: Nothing.
    ArgumentList() {
        values = []
        error = ""
    }
    String word(buffer bytes)
    bool parse(String text)
    String display(list items)
}

// Decode the bytes of one argument word into a string.
//
// bytes: Bytes collected for the word, without a trailing NUL.
// Returns: The word.
String ArgumentList.word(buffer bytes) {
    Process.OutputDecoder decoder = Process.OutputDecoder()
    String text = decoder.decode(bytes)
    text.append(decoder.finish())
    return(text)
}

// Split inferior arguments without invoking a shell. Blanks separate words.
// Single quotes are literal. Double quotes honor backslash escapes. An
// unquoted backslash escapes the next character. Empty quotes give an empty
// word.
//
// text: Argument text from the Session page or a saved setting.
// Returns: True when the text was a valid argument string.
bool ArgumentList.parse(String text) {
    values = []
    error = ""

    buffer current = buffer[]
    bool started = false
    int64 quote = 0
    int64 i = 0
    while (i < text.length) {
        int64 c = int64(text[i])
        i = i + 1

        if (quote == 39) {
            if (c == 39) {
                quote = 0
            }
            else {
                current.append(uint64(c))
            }
        }
        else {

            if (quote == 34) {

                if (c == 34) {
                    quote = 0
                }
                else {
                    if (c == 92 && i < text.length && (int64(text[i]) == 34 ||
                            int64(text[
                            i]) == 92 || int64(text[
                            i]) == 36 ||
                            int64(text[
                            i]) == 96)) {
                        current.append(text[i])
                        i = i + 1
                    }
                    else {
                        current.append(uint64(c))
                    }
                }

            }
            else {

                if (c == 32 || c == 9 || c == 10 || c == 13) {
                    if (started) {
                        values.append(word(current))
                        current = buffer[]
                        started = false
                    }
                }
                else {
                    started = true

                    if (c == 39 || c == 34) {
                        quote = c
                    }
                    else {

                        if (c == 92) {
                            if (i >= text.length) {
                                error = "trailing backslash"
                                values = []
                                return(false)
                            }
                            current.append(text[i])
                            i = i + 1
                        }
                        else {
                            current.append(uint64(c))
                        }

                    }

                }

            }

        }

    }

    if (quote != 0) {
        error = "unterminated quote"
        values = []
        return(false)
    }
    if (started) {
        values.append(word(current))
    }
    return(true)
}

// Join argument words the way the Session entry shows them, quoting words that
// need it.
//
// items: Words to display.
// Returns: One line of argument text.
String ArgumentList.display(list items) {

    String text = ""
    int64 i = 0
    while (i < items.length) {
        String item = items[i] as String
        if (i > 0) {
            text.append(" ")
        }

        if (item.equals("") || item.contains(" ") || item.contains("\t")
                || item.contains(
                "\n") ||
                item.contains(
                "\r") || item.contains(
                "'") || item.contains(
                "\"") || item.contains(
                "\\")) {
            text.append(format("'{}'", item.replace("'", "'\\''")))
        }
        else {
            text.append(item)
        }

        i = i + 1
    }

    return(text)
}


// One KEY=VALUE pair from the Session environment list.
class EnvironmentPair {
    public:
    String name
    String value
    // Store one environment variable assignment.
    //
    // key: Variable name.
    // text: Variable value.
    // Returns: Nothing.
    EnvironmentPair(String key, String text) {
        name = key
        value = text
    }
}

// Session environment text: one KEY=VALUE per line. Blank lines and # comments
// are ignored.
class EnvironmentList {
    public:
    list pairs
    String error

    // Create an empty environment list.
    //
    // Parameters: none.
    // Returns: Nothing.
    EnvironmentList() {
        pairs = []
        error = ""
    }

    bool nameOk(String name)

    bool parse(String text)

    String display(list items)
}

// Report whether a name is a legal environment variable name.
//
// name: Name to test.
// Returns: True when the name is non-empty and made of letters, digits, and
// underscores.
bool EnvironmentList.nameOk(String name) {
    if (name.equals("") || name.length > 256) {
        return(false)
    }

    int64 i = 0
    while (i < name.length) {
        int64 c = int64(name[i])
        bool letter = (c >= 65 && c <= 90) || (c >= 97 && c <= 122) || c == 95
        bool digit = c >= 48 && c <= 57
        if (i == 0) {
            if (!letter) {
                return(false)
            }
        }
        else {
            if (!letter && !digit) {
                return(false)
            }
        }
        i = i + 1
    }

    return(true)
}

// Parse session environment text: one KEY=VALUE per line. Blank lines and #
// comments are ignored.
//
// text: Environment text from the Session page.
// Returns: True when every line is valid.
bool EnvironmentList.parse(String text) {
    pairs = []
    error = ""
    if (text.length > 16384) {
        error = "environment text exceeds 16 KiB"
        return(false)
    }

    list lines = text.split("\n")
    int64 i = 0
    while (i < lines.length) {
        String line = (lines[i] as String).trim()
        i = i + 1
        if (line.equals("") || line.startsWith("#")) {
            continue
        }
        int64 eq = line.find("=")
        if (eq < 1) {
            error = format("expected KEY=VALUE on line {}", i)
            pairs = []
            return(false)
        }
        String name = ""
        String value = ""
        if (eq > 0) {
            name = line[0..(eq - 1)]
        }
        if (eq + 1 <= line.length - 1) {
            value = line[(eq + 1)..(line.length - 1)]
        }
        else {
            if (eq + 1 == line.length) {
                value = ""
            }
        }
        if (!nameOk(name)) {
            error = format("invalid environment name '{}'", name)
            pairs = []
            return(false)
        }
        if (value.length > 4096) {
            error = format("value for {} exceeds 4096 bytes", name)
            pairs = []
            return(false)
        }
        pairs.append(EnvironmentPair(name, value))
        if (pairs.length > 64) {
            error = "at most 64 environment variables"
            pairs = []
            return(false)
        }
    }

    return(true)
}

// Join environment pairs as KEY=VALUE lines.
//
// items: Pairs to display.
// Returns: The text the Session page shows.
String EnvironmentList.display(list items) {
    String text = ""
    int64 i = 0
    while (i < items.length) {
        EnvironmentPair item = items[i] as EnvironmentPair
        if (i > 0) {
            text.append("\n")
        }
        text.append(format("{}={}", item.name, item.value))
        i = i + 1
    }
    return(text)
}

