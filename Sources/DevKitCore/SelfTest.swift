import Foundation

public enum SelfTest {
    public static func run() -> Int32 {
        var failures: [String] = []
        var checks = 0
        func expect(_ name: String, _ condition: Bool) {
            checks += 1
            if !condition { failures.append(name) }
        }

        let pretty = JSONFormatter.format("{\"b\":1,\"a\":2}", mode: .beautify, indent: .two, sortKeys: true)
        expect("json beautify sort", pretty.output == "{\n  \"a\": 2,\n  \"b\": 1\n}" && pretty.issue == nil)

        let mini = JSONFormatter.format("{\"b\":1,\"a\":2}", mode: .minify, indent: .two, sortKeys: true)
        expect("json minify sort", mini.output == "{\"a\":2,\"b\":1}" && mini.issue == nil)

        let valid = JSONFormatter.format("[]", mode: .validate, indent: .two, sortKeys: false)
        expect("json validate", valid.issue == nil && valid.output.contains("Valid JSON"))

        let broken = JSONFormatter.format("{\n\"a\":", mode: .beautify, indent: .two, sortKeys: false)
        expect("json error located", broken.issue != nil)

        let empty = JSONFormatter.format("   ", mode: .beautify, indent: .two, sortKeys: false)
        expect("json empty", empty.issue != nil && empty.output.isEmpty)

        let binary = JSONFormatter.format(String(repeating: "\u{0}", count: 8), mode: .minify, indent: .two, sortKeys: false)
        expect("json binary", binary.issue != nil)

        let huge = JSONFormatter.format(String(repeating: " ", count: 5_000_000) + "[]", mode: .minify, indent: .two, sortKeys: false)
        expect("json huge", huge.output == "[]" && huge.issue == nil)

        let encoded = Base64Codec.convert("Hello, DevKit", direction: .encode, alphabet: .standard)
        expect("base64 encode", encoded.output == "SGVsbG8sIERldktpdA==" && encoded.issue == nil)
        let decoded = Base64Codec.convert(encoded.output, direction: .decode, alphabet: .standard)
        expect("base64 roundtrip", decoded.output == "Hello, DevKit")

        let urlSafe = Base64Codec.encode(Data([0xfb, 0xff, 0xbf]), alphabet: .urlSafe)
        expect("base64 url safe", urlSafe.contains("-") || urlSafe.contains("_"))
        expect("base64 url safe no pad", !urlSafe.contains("="))
        let urlBack = Base64Codec.decode(urlSafe, alphabet: .urlSafe)
        expect("base64 url roundtrip", urlBack == Data([0xfb, 0xff, 0xbf]))

        let component = URLTextEncoder.convert("a b/c", direction: .encode, scope: .component)
        expect("url component", component.output == "a%20b%2Fc")
        let componentBack = URLTextEncoder.convert(component.output, direction: .decode, scope: .component)
        expect("url component roundtrip", componentBack.output == "a b/c")

        let full = URLTextEncoder.convert("https://example.com/a b", direction: .encode, scope: .fullURL)
        expect("url full keeps scheme", full.output.hasPrefix("https://example.com/a%20b") && full.issue == nil)

        let malformed64 = Base64Codec.convert("!!!!", direction: .decode, alphabet: .standard)
        expect("base64 malformed", malformed64.issue != nil)

        HTMLEntities.runChecks(expect)
        Hashing.runChecks(expect)
        IDGenerator.runChecks(expect)
        NumberBase.runChecks(expect)
        PasswordGenerator.runChecks(expect)
        TimestampConvert.runChecks(expect)
        UserAgentToolCore.runChecks(expect)
        JWTCodec.runChecks(expect)
        XMLFormatter.runChecks(expect)
        YAMLFormatter.runChecks(expect)
        YAMLJSON.runChecks(expect)
        CSVJSON.runChecks(expect)
        XMLToJSON.runChecks(expect)
        JSONToCSV.runChecks(expect)
        ColorConvert.runChecks(expect)
        UnitConvert.runChecks(expect)
        FileSizeCalc.runChecks(expect)
        DateConvert.runChecks(expect)
        RegexPlayground.runChecks(expect)
        TextDiff.runChecks(expect)
        JSONPath.runChecks(expect)
        URLParserChecks.runChecks(expect)
        Cron.runChecks(expect)
        MarkdownRender.runChecks(expect)

        if failures.isEmpty {
            print("selftest ok (\(checks) checks)")
            return 0
        }
        for failure in failures {
            print("FAIL \(failure)")
        }
        print("selftest failed \(failures.count) of \(checks)")
        return 1
    }
}
