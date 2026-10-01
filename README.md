# DevKit

Native macOS toolbox for Apple Silicon. Personal use, ad-hoc signed, no sandbox.

## Build

```bash
chmod +x build.sh
./build.sh
```

The script builds an arm64 release binary, wraps it in `DevKit.app`, and codesigns it ad-hoc. If Gatekeeper blocks the first launch, right-click the app and choose Open, or run `xattr -cr DevKit.app`.

## XML → JSON

DevKit maps an XML document to one JSON object:

- The root element name is the top-level key.
- Attributes become string fields prefixed with `@`. `<book id="1">` contributes `"@id": "1"`.
- An element whose only content is text becomes a JSON string. `<name>Ada</name>` becomes `"name": "Ada"`.
- Child elements become nested objects under their tag name.
- When the same child tag appears more than once, the value is a JSON array in document order. `<tag>a</tag><tag>b</tag>` becomes `"tag": ["a", "b"]`.
- Mixed content, text together with child elements, keeps the text in `"#text"`.
- Whitespace-only text between elements is ignored. Comments are not copied.

Example:

```xml
<book id="1"><title>Hi</title><tag>a</tag><tag>b</tag></book>
```

```json
{ "book": { "@id": "1", "tag": ["a", "b"], "title": "Hi" } }
```

Run logic checks without opening the window:

```bash
swift run -c release --arch arm64 DevKit --selftest
```
