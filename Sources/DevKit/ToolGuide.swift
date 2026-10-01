import Foundation

enum ToolGuide {
    struct Note {
        var how: String
        var input: String
        var output: String
    }

    static func note(for id: String) -> Note {
        notes[id] ?? Note(
            how: "Use Sample for a starting value, then edit the input.",
            input: "Paste or type the source. Sample fills an example.",
            output: "The result updates as you edit."
        )
    }

    private static let notes: [String: Note] = [
        "json-formatter": Note(how: "Pretty-prints JSON. Sample: {\"b\":1,\"a\":[true,null,\"hi\"]}.", input: "A JSON value. Sample loads a small object.", output: "Indented JSON. Invalid input shows the error line."),
        "url-parser": Note(how: "Splits a URL into scheme, host, path, and query. Try https://example.com/a?x=1.", input: "One absolute URL.", output: "Each URL part on its own line."),
        "xml-formatter": Note(how: "Indents XML. Sample starts with <root><item>.", input: "An XML document.", output: "Indented XML, or a parse error."),
        "yaml-formatter": Note(how: "Checks and formats YAML. Sample is a title with a list.", input: "A YAML document.", output: "Formatted YAML."),
        "html-formatter": Note(how: "Formats HTML tags. Sample is a <div> with a paragraph.", input: "An HTML fragment.", output: "Indented HTML."),
        "code-beautifier": Note(how: "Formats JavaScript, CSS, or JSON. Sample: const answer={value:1+2}.", input: "Source in the language selected above.", output: "The formatted source."),
        "code-minifier": Note(how: "Removes extra whitespace. Sample: const value = 1 + 2.", input: "JS, CSS, or HTML.", output: "A shorter version of the same source."),
        "sql-format": Note(how: "Puts SQL keywords on their own lines and lists tables. Sample selects from users and orders.", input: "One SQL statement. It is not executed.", output: "The formatted query, then the table names."),
        "base64": Note(how: "Encodes text or a file, or decodes Base64. Sample: Hello, DevKit.", input: "Plain text to encode, or Base64 to decode.", output: "The encoded or decoded text. Encode File reads a binary file."),
        "url-encoder": Note(how: "Percent-encodes or decodes a URL piece. Sample: a b/c?x=1&y=hello world.", input: "Text or an already encoded string.", output: "The encoded or decoded text."),
        "html-entity": Note(how: "Turns <, &, and quotes into HTML entities. Sample: Tom & Jerry <3.", input: "Plain text or text that already contains entities.", output: "Encoded or decoded text."),
        "jwt": Note(how: "Decodes a JWT header and payload. Checking the signature needs the secret.", input: "A token with three base64 parts.", output: "Header, payload, and whether the signature matches."),
        "unicode-escape": Note(how: "Turns é into JSON \\u00E9, HTML &#xE9;, or URL %C3%A9. Sample: A é.", input: "Text to escape, or an escaped string to decode.", output: "The converted text."),
        "snowflake": Note(how: "Reads a Twitter or Discord id into a time, worker, and sequence.", input: "A positive snowflake number. Pick the layout above.", output: "Time and the bit fields."),
        "json-yaml": Note(how: "Converts JSON to YAML and back. Sample: {\"name\":\"Ada\",\"ok\":true}.", input: "JSON or YAML, matching the direction.", output: "The other format."),
        "plist": Note(how: "JSON becomes an XML plist. To JSON reads XML or a binary plist file.", input: "JSON, or XML plist text. Open Plist reads a file.", output: "JSON or an XML property list."),
        "dotenv": Note(how: "Reads KEY=value lines, including quotes and # comments. Sample exports FOO=\"a b\".", input: "A .env file.", output: "JSON, a cleaned .env, or shell export lines."),
        "semver": Note(how: "Compare 1.2.3 with 1.2.4, bump a part, or test a range such as ^1.2.0.", input: "Version, the other version, and a range.", output: "Order, the bumped version, or whether the range matches."),
        "csv-json": Note(how: "Turns a CSV table into JSON rows, and JSON back into CSV.", input: "CSV with a header, or a JSON array.", output: "The other format."),
        "xml-json": Note(how: "Turns an XML element into JSON. Sample is a <book> with a title.", input: "An XML element.", output: "A JSON object."),
        "json-csv": Note(how: "Flattens a JSON array of objects into CSV columns.", input: "A JSON array. Nested fields become dotted names.", output: "A CSV table."),
        "number-base": Note(how: "Converts 255 between decimal, hex, binary, and octal.", input: "A number in the base you select.", output: "The same number in the other base."),
        "timestamp": Note(how: "Turns a unix time such as 1700000000 into a calendar date.", input: "Seconds or milliseconds since 1970.", output: "The UTC date, and the time in other units."),
        "date": Note(how: "Parses a date such as 2020-01-02T03:04:05Z.", input: "An ISO date or a date in the selected format.", output: "The date in the other formats."),
        "color": Note(how: "Converts #336699 between hex, RGB, HSL, HSB, and CMYK.", input: "A color value, or use the picker.", output: "The same color in every form."),
        "unit": Note(how: "Converts a number inside the unit family you pick. Sample starts at 1.", input: "A number in the From unit.", output: "That amount in the To unit."),
        "file-size": Note(how: "Turns 1.5 into bytes, KB, MB, and GB.", input: "A number. Choose the unit it is already in.", output: "The size in the other units."),
        "hash": Note(how: "Hashes text. Sample abc is the standard SHA-256 test.", input: "The text to hash.", output: "The digest for each selected algorithm."),
        "id-generator": Note(how: "Makes a UUID, ULID, or Nano ID. The input can stay empty.", input: "Optional. Generation uses the options above.", output: "A new id each time the options change."),
        "password": Note(how: "Builds a random password from the length and character sets.", input: "Optional. The options choose the alphabet.", output: "A new password."),
        "user-agent": Note(how: "Explains a browser user-agent. Sample is a Chrome string on macOS.", input: "One User-Agent header value.", output: "Browser, OS, and device fields."),
        "regex": Note(how: "Tests a pattern such as (\\w+)@(\\w+) against a@b and c@d, and can replace matches.", input: "The pattern is the first field. The text to search is below it.", output: "Each match, its groups, and the replacement."),
        "unicode": Note(how: "Lists code points and UTF-8 bytes. Sample: A é €.", input: "Any text, up to 20,000 characters.", output: "One line per character: code point, name, category, bytes."),
        "hex": Note(how: "Text mode dumps what you type. Hex mode reads bytes such as 48 65 6C. Open File reads a binary file.", input: "Text, hex pairs, or a file. Highlight start and length mark a range.", output: "Offset, hex bytes, and an ASCII column."),
        "diff": Note(how: "Compares two texts. The sample is a, b, c against a, x, c.", input: "Left and right texts. Choose line, word, or character.", output: "Added, removed, and unchanged parts."),
        "json-path": Note(how: "Runs a path such as $.user.name against a JSON document.", input: "A JSON document. Set the path in the options.", output: "The values the path selects."),
        "json-schema": Note(how: "Checks a document against type, required, and length rules. Sample name is too short.", input: "The JSON document. The box above is the schema.", output: "Valid, or the failing path such as $.name."),
        "csv-viewer": Note(how: "Opens a CSV and lets you sort and filter the rows.", input: "Paste a table or use Open. Large files skip the text editor.", output: "A table. Sort by a column and filter from the field above."),
        "markdown": Note(how: "Renders Markdown on a light page. Scripts and outside links stay off.", input: "Markdown source.", output: "The rendered page."),
        "html-preview": Note(how: "Shows HTML. JavaScript cannot open windows, and file links are blocked.", input: "An HTML document.", output: "The page preview."),
        "chmod": Note(how: "Type 755 or rwxr-xr-x. 4755 shows the setuid bit.", input: "One octal mode or a 9-character symbolic mode.", output: "Octal, symbolic form, and who can read, write, or execute."),
        "certificate": Note(how: "Reads a PEM certificate or CSR for subject, names, and expiry. It does not contact a server.", input: "PEM text, or Open PEM or DER for a file.", output: "Subject, validity, and subject alternative names."),
        "exif": Note(how: "Open a local image for size, color, and location. Save Without Location removes GPS.", input: "Use Open Image. Nothing is fetched from the network.", output: "Width, height, color, and location if the file has one."),
        "cron": Note(how: "Five fields, minute through weekday. 0 0 * * * means every day at midnight.", input: "Edit the fields or the expression line.", output: "What the expression means and the next run times."),
        "qr-generator": Note(how: "Turns text into a QR image you can copy or save.", input: "The text to encode.", output: "The QR image."),
        "qr-reader": Note(how: "Reads a QR code from an image file on this Mac.", input: "Open an image that contains a QR code.", output: "The text stored in the code."),
        "pdf": Note(how: "Builds a simple PDF from the text you type.", input: "The page text.", output: "Use Save to write the PDF."),
        "gitignore": Note(how: "Turns on Swift, Node, Python, or macOS and copies the rules.", input: "The toggles choose which rule sets to include.", output: "A .gitignore with duplicate lines removed."),
        "launchd": Note(how: "Writes a LaunchAgent plist. DevKit does not load it or run the program.", input: "Label, program path, arguments, and an optional interval.", output: "XML property list you can save yourself."),
        "http-client": Note(how: "Sends an HTTP request. Methods are GET, POST, PUT, PATCH, DELETE, HEAD, and OPTIONS.", input: "URL, headers, and body. Only http and https are allowed.", output: "Status, headers, and body. History keeps this request."),
        "request-builder": Note(how: "Paste a curl command, edit the URL, headers, query, and body, then send it.", input: "Import splits the command. Change any part before Send.", output: "Status, response headers, and body are shown apart."),
        "curl": Note(how: "Turns a curl command into code. Sample posts JSON to https://example.com/api.", input: "One curl command.", output: "The request in the language you pick."),
        "http-status": Note(how: "Search a code or phrase. Try 404 or Not Found.", input: "A status code or words from its name.", output: "The matching codes and what they mean."),
        "websocket": Note(how: "Connects to a ws:// or wss:// URL and sends a text message.", input: "The socket URL and the message to send.", output: "Messages received from the server."),
        "dns": Note(how: "Looks up a host name. Try example.com and type A. A name cannot start with -.", input: "A host name and a record type from the list.", output: "The dig or DNS-over-HTTPS answer."),
        "whois": Note(how: "Shows the public registration record for a domain.", input: "A domain name, not a command.", output: "The WHOIS text."),
        "ip-lookup": Note(how: "Looks up an IP address over HTTPS, or your own address if you leave it blank.", input: "An IP address. The provider must be an https URL.", output: "The provider's JSON response."),
        "tls": Note(how: "Shows the certificate chain presented by a host. The default port is 443.", input: "A host name.", output: "Subject, expiry, and whether the system trusts the chain."),
        "diagnostics": Note(how: "Pings a host and reports the timing. The host cannot start with -.", input: "A host name and how many samples to take.", output: "The ping summary."),
    ]
}
