# DevKit

Native macOS toolbox for Apple Silicon. Personal use, ad-hoc signed, no sandbox.

## Build

```bash
chmod +x build.sh
./build.sh
```

The script builds an arm64 release binary, wraps it in `DevKit.app`, and codesigns it ad-hoc. If Gatekeeper blocks the first launch, right-click the app and choose Open, or run `xattr -cr DevKit.app`.

Run logic checks without opening the window:

```bash
swift run -c release --arch arm64 DevKit --selftest
```
