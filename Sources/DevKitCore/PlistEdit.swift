import Foundation

public enum PlistEdit {
    public enum Direction: String {
        case toJSON
        case toXML
    }

    public static func convert(_ text: String, direction: Direction) -> ToolResult {
        if text.utf8.count > 2_000_000 { return .failure("Input is larger than 2 MB.") }
        if text.utf8.contains(0) { return .failure("Input looks like binary data. Open the plist file instead.") }
        switch direction {
        case .toJSON:
            return dataToJSON(Data(text.utf8))
        case .toXML:
            return jsonToXML(text)
        }
    }

    public static func dataToJSON(_ data: Data) -> ToolResult {
        if data.count > 2_000_000 { return .failure("File is larger than 2 MB.") }
        var format = PropertyListSerialization.PropertyListFormat.xml
        guard let object = try? PropertyListSerialization.propertyList(from: data, options: [], format: &format) else {
            return .failure("That is not an XML or binary property list.")
        }
        guard JSONSerialization.isValidJSONObject(object),
              let json = try? JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys]),
              let text = String(data: json, encoding: .utf8) else {
            return .failure("This property list cannot be shown as JSON.")
        }
        return .success(text)
    }

    public static func jsonToXML(_ text: String) -> ToolResult {
        guard let data = text.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) else {
            return .failure("Enter JSON to turn into a property list.")
        }
        guard let plist = try? PropertyListSerialization.data(fromPropertyList: object, format: .xml, options: 0),
              let xml = String(data: plist, encoding: .utf8) else {
            return .failure("That JSON cannot be stored as a property list.")
        }
        return .success(xml)
    }

    public static func runChecks(_ expect: (String, Bool) -> Void) {
        let xml = jsonToXML(#"{"name":"DevKit"}"#)
        expect("plist xml", xml.output.contains("<key>name</key>") && xml.output.contains("DevKit"))
        let back = convert(xml.output, direction: .toJSON)
        expect("plist json", back.output.contains("\"name\" : \"DevKit\"") || back.output.contains("\"name\": \"DevKit\""))
        expect("plist junk", convert("not a plist", direction: .toJSON).issue != nil)
    }
}
