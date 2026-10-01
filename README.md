# DevKit

Native macOS toolbox for day-to-day developer work: format and convert data, encode and inspect text, generate ids and files, and check DNS, HTTP, and TLS. It is a SwiftUI app for Apple Silicon on macOS 14 or later, built as a Swift package and ad-hoc signed for personal use.

Formatters, converters, and generators run on the machine. The networking tools are the ones that leave it.

## Requirements

- macOS 14 or later
- Apple Silicon
- Swift 5.9 or later (`swift` on your PATH)

## Build

```bash
chmod +x build.sh
./build.sh
open DevKit.app
```

`build.sh` compiles an arm64 release binary, wraps it in `DevKit.app`, copies bundled resources, and codesigns the app ad-hoc. If Gatekeeper blocks the first launch, right-click the app and choose Open, or run `xattr -cr DevKit.app`.

## Using it

The sidebar groups every tool. **All Tools** is a card grid you can search. **⌘K** opens the command palette (fuzzy match, Return opens a tool, Escape closes it) with Favorites and Recent at the top. **⌘D** toggles a favorite for the open tool, **⌘[** returns to the grid, and **⇧⌘C** copies the output.

Most text tools share one layout: input and output, with Paste, Copy, Clear, Swap, Sample, and Open/Save. Conversion runs as you type. Drop a file on an input. The last tool, favorites, window size, and per-tool state are restored on the next launch. A menu-bar window opens the same tools without bringing the main window forward.

## Tools

### Formatters

| Tool | What it does |
| --- | --- |
| JSON Formatter | Beautify, minify, validate, and sort keys |
| XML Formatter | Prettify, minify, and validate XML |
| YAML Formatter | Prettify and validate YAML |
| HTML Formatter | Beautify and minify HTML |
| SQL Formatter | Pretty-print a query and list the tables it names |
| Code Beautifier | Format JavaScript, CSS, SCSS, and LESS with Prettier |
| Code Minifier | Minify JSON, XML, JavaScript, and CSS |
| URL Parser | Split a URL and edit its query string |

### Converters

| Tool | What it does |
| --- | --- |
| JSON ↔ YAML | Convert between JSON and YAML |
| CSV ↔ JSON | Convert CSV and JSON, including quoted fields |
| XML → JSON | Map elements, attributes, text, and repeated tags |
| JSON → CSV | Flatten nested JSON into a CSV with dot keys |
| Plist Editor | XML or binary property lists to JSON, and JSON back to XML |
| .env Editor | `KEY=value`, quotes, and comments to JSON, dotenv, or shell export |
| Semantic Version | Compare, bump, and test `^`, `~`, and inequality ranges |
| Number Base | Convert integers between bases 2 and 36 |
| Timestamp | Unix time, ISO 8601, time zones, and relative time |
| Date Converter | Parse dates, format them, and measure the difference |
| Color | Convert HEX, RGB, HSL, HSB, and CMYK |
| Unit Converter | Length, mass, temperature, volume, area, speed, time, data, energy, pressure |
| File Size | Bytes through petabytes, SI and IEC side by side |

### Encoders

| Tool | What it does |
| --- | --- |
| Base64 | Encode and decode text or files, standard or URL-safe |
| URL Encoder | Percent-encode or decode a component or a full URL |
| HTML Entity | Encode and decode named and numeric HTML entities |
| Unicode Escapes | JSON `\u`, HTML numeric, and URL percent encoding |
| JWT | Decode claims, sign and verify HMAC, verify RS256 |
| Snowflake ID | Decode Twitter and Discord snowflake ids |

### Inspection

| Tool | What it does |
| --- | --- |
| Regex | Test `NSRegularExpression` with matches, groups, and replace |
| Text Diff | Line, word, and character diffs, side by side or unified |
| JSON Path | Dot paths, indexes, wildcards, and simple filters |
| JSON Schema | Check a document against type, required, enum, and length rules |
| CSV Viewer | Sort, search, and detect the delimiter of a CSV |
| Markdown Preview | GitHub-flavored Markdown with HTML and PDF export |
| HTML Preview | Preview HTML in a web view, with JavaScript and width presets |
| Unicode Inspector | Code points, names, categories, and UTF-8 bytes |
| Hex Viewer | Hex and ASCII dump, with a highlighted range |
| chmod Calculator | `755`, setuid, setgid, and sticky bits as octal or `rwx` |
| Certificate Viewer | PEM certificate or CSR: subject, SANs, and expiry |
| Image EXIF | Dimensions, color, and location, with location removal |
| QR Reader | Read a QR code from a file, a drop, or the clipboard |

### Generators

| Tool | What it does |
| --- | --- |
| Hash | MD5, SHA, HMAC, and bcrypt for text or a file |
| ID Generator | UUID v4, UUID v7, ULID, and NanoID |
| Password | Random passwords and passphrases with an entropy meter |
| User Agent | Generate a realistic user agent or parse one |
| Crontab | Build, explain, and preview the next runs of a 5-field cron |
| QR Generator | QR codes for text, URLs, Wi-Fi, and vCards |
| PDF Generator | Build PDFs from text, Markdown, HTML, or images, then merge and reorder |
| .gitignore Builder | Swift, Node, Python, and macOS ignore rules |
| launchd Plist | Write a LaunchAgent plist. It is not loaded. |

### Networking

| Tool | What it does |
| --- | --- |
| HTTP Client | Methods, headers, bodies, auth, history, and environment variables |
| Request Builder | Split a curl command into URL, headers, and body, then send it |
| cURL → Code | Turn a curl command into Swift, Python, JavaScript, Go, or Node |
| HTTP Status | Search the HTTP status code reference |
| WebSocket | Connect, send text or binary, and log frames |
| DNS Lookup | Query A through CAA with `dig` or DNS over HTTPS |
| WHOIS | Query port 43, follow referrals, and show parsed fields |
| IP Lookup | Geolocation and ASN for an IP address or your public IP |
| TLS Certificate | Inspect the chain, trust result, fingerprints, and PEM |
| Network Diagnostics | DNS, TCP, HTTP timing, path status, local IPs, and ping |

## XML → JSON

DevKit maps an XML document to one JSON object:

- The root element name is the top-level key.
- Attributes become string fields prefixed with `@`. `<book id="1">` contributes `"@id": "1"`.
- An element whose only content is text becomes a JSON string. `<name>Ada</name>` becomes `"name": "Ada"`.
- Child elements become nested objects under their tag name.
- When the same child tag appears more than once, the value is a JSON array in document order. `<tag>a</tag><tag>b</tag>` becomes `"tag": ["a", "b"]`.
- Mixed content, text together with child elements, keeps the text in `"#text"`.
- Whitespace-only text between elements is ignored. Comments are not copied.

```xml
<book id="1"><title>Hi</title><tag>a</tag><tag>b</tag></book>
```

```json
{ "book": { "@id": "1", "tag": ["a", "b"], "title": "Hi" } }
```

## Checks

Logic checks run without opening the window:

```bash
swift run -c release --arch arm64 DevKit --selftest
```

## Layout

`Sources/DevKit` is the SwiftUI app. `Sources/DevKitCore` is the pure logic behind each tool, with no SwiftUI import, so `--selftest` can call it directly. Third-party packages are Yams, swift-markdown, and SwiftSoup. JavaScript, CSS, SCSS, and LESS formatting uses a local Prettier bundle through JavaScriptCore.
