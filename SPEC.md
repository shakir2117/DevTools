# DevKit spec

Native macOS SwiftUI app for Apple Silicon. Personal use: no sandbox, no App Store. Offline except the network tools.

## Platform
- Swift Package, executable target `DevKit`, library target `DevKitCore`, macOS 14+.
- Build: `swift build -c release --arch arm64`. Package via `build.sh` (ad-hoc codesign).
- No Xcode: no previews, no asset catalogs, no XCUITest.
- Dependencies (SwiftPM only if needed): Yams, swift-markdown, SwiftSoup.

## Shell and UX
- NavigationSplitView sidebar with collapsible groups, "All Tools" card grid (icon, name, one-line description), search field.
- ⌘K command palette: fuzzy search, Enter opens, Esc closes. Favorites and Recent sections.
- Shared TextToolView: Input | Output panes with Paste, Copy, Clear, Swap, Sample, Open/Save file.
- Live debounced conversion, inline errors with line/column.
- Dark/light mode, SF Symbols, monospaced code font, drag and drop onto inputs.
- Persist last tool, favorites, window size, per-tool state.
- Large inputs (several MB) must not freeze UI: background work, progress and cancel.

## Tools

### Formatters
1. JSON Formatter: beautify, minify, validate, sort keys, indent 2/4/tab, error location.
2. XML Formatter: prettify, minify, validate.
3. YAML Formatter: prettify, validate.
4. HTML Formatter: beautify, minify.
5. JS Beautifier, CSS, SCSS, LESS formatters (Prettier via JavaScriptCore, local bundle).
6. Code Minifier: JSON, XML, JS, CSS.
7. URL Parser: scheme, host, port, path, editable query table, fragment, user info.

### Converters
8. JSON <-> YAML.
9. CSV <-> JSON: quoted fields, embedded commas/newlines, custom delimiter, header toggle, type inference.
10. XML -> JSON: attributes, text nodes, arrays; document the mapping in README.
11. JSON -> CSV: flatten nested objects with dot notation.
12. Timestamp: Unix s/ms <-> human, timezone picker, ISO 8601, relative time, "now".
13. Date Converter: many input formats, ISO 8601 / RFC 2822 / custom output, timezones, date difference.
14. Number Base: base 2 to 36, arbitrary precision.
15. Color Converter: HEX/RGB/HSL/HSB/CMYK, alpha, picker, CSS/Swift/SwiftUI output.
16. Unit Converter: length, mass, temperature, volume, area, speed, time, data, energy, pressure.
17. File Size Calc: B to PB, SI (1000) and IEC (1024) side by side.

### Encoders / decoders
18. Base64: text and file, standard and URL-safe.
19. URL Encoder/Decoder: component vs full URL.
20. HTML Entity Encoder/Decoder: named and numeric.
21. JWT: decode header/payload/signature, exp/iat/nbf as dates with valid/expired badge, verify and sign HS256/384/512, verify RS256 with PEM public key.

### Inspection
22. Regex Playground: NSRegularExpression, flags, live highlight, capture groups table, replace preview, pattern library.
23. Text Diff: line and word/char diff, side-by-side and unified, ignore whitespace/case.
24. JSON Path: dot notation, indexes, wildcards, filters.
25. CSV Viewer: sortable table, search/filter, delimiter detection, lazy large files.
26. Markdown Preview: GFM (tables, task lists, code blocks), export HTML/PDF.
27. HTML Preview: WKWebView, JS toggle, responsive width presets.

### Generators
28. Hash: MD5, SHA-1/256/384/512, HMAC, text and file input. bcrypt with cost and verify mode.
29. ID Generator: UUID v4/v7, ULID, NanoID, bulk 1 to 1000, case/hyphen options.
30. Password Generator: length, character sets, exclude ambiguous, passphrase mode, entropy meter. SecRandomCopyBytes only.
31. Crontab Generator: builder, plain-English explanation, parse, next 10 runs, 5-field cron.
32. QR Generator: text/URL/Wi-Fi/vCard, error correction, size, colors, export PNG/SVG/PDF.
33. QR Reader: image file, drag-drop, clipboard (Vision).
34. PDF Generator: from text/Markdown/HTML/images, page size, margins, merge, reorder (PDFKit).
35. User Agent: generate realistic UA strings and parse a pasted UA.

### Networking and API
36. HTTP Client: all methods, params/headers tables, bodies (raw, form, multipart), Basic/Bearer/API key auth, redirects toggle, timeout, response viewer (body, headers, status, time, size, cookies), history, collections, {{env}} variables.
37. cURL -> Code: parse curl, output Swift (URLSession), Python (requests), JS (fetch), Go, Node.
38. HTTP Status: searchable reference of all codes.
39. WebSocket: ws/wss, headers, send text/binary, timestamped log, auto-reconnect.
40. DNS Lookup: A, AAAA, MX, TXT, CNAME, NS, SOA, PTR, SRV, CAA; system or DoH resolver; TTL. (Shelling out to `dig` is allowed since there is no sandbox.)
41. WHOIS: TCP port 43, follow referrals, parsed fields plus raw output.
42. IP Lookup: geolocation/ASN for an IP or "my IP" via configurable HTTPS provider, MapKit map.
43. TLS Certificate: full chain, subject/issuer/SAN/validity/serial/fingerprints, SecTrust result, days to expiry, export PEM.
44. Network Diagnostics: DNS time, TCP connect time, HTTP timing breakdown, NWPathMonitor status, local IPs, multi-sample latency (real `ping` allowed).

## Quality bar
- No crashes on empty, huge, binary, or malformed input.
- Round-trip checks for every converter; known-answer checks for hashes, JWT, base conversion, cron (`swift test` if XCTest is available, otherwise a small `--selftest` CLI flag).
- Zero compiler warnings.
