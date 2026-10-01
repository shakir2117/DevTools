import SwiftUI
import DevKitCore

struct DateTool: Tool {
    let id = "date"
    let name = "Date Converter"
    let summary = "Parse dates, format them, and measure the difference"
    let symbol = "calendar"
    let category = ToolCategory.converters
    func makeView() -> AnyView { AnyView(DateToolView()) }
}

struct DateToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var style: DateConvert.OutputStyle = .iso8601
    @State private var custom = "yyyy-MM-dd HH:mm:ss"
    @State private var zone = "UTC"
    @State private var other = ""
    @State private var restored = false

    var body: some View {
        let style = style
        let custom = custom
        let zone = zone
        let other = other
        TextToolView(
            toolID: "date",
            sample: "2020-01-02T03:04:05Z",
            runToken: "\(style.rawValue)|\(custom)|\(zone)|\(other)",
            canSwap: false,
            transform: { DateConvert.convert(text: $0, other: other, style: style, customFormat: custom, timeZoneID: zone) }
        ) {
            HStack(spacing: 12) {
                Picker("Output", selection: $style) {
                    ForEach(DateConvert.OutputStyle.allCases, id: \.self) { item in
                        Text(item.title).tag(item)
                    }
                }
                .frame(maxWidth: 200)
                TextField("Custom format", text: $custom)
                    .frame(maxWidth: 180)
                    .disabled(style != .custom)
                Picker("Zone", selection: $zone) {
                    ForEach(TimestampConvert.commonZones, id: \.self) { item in
                        Text(item == "local" ? "Local" : item).tag(item)
                    }
                }
                .frame(maxWidth: 180)
                TextField("Second date", text: $other)
                    .frame(maxWidth: 180)
                Spacer()
            }
        }
        .onAppear(perform: restore)
        .onChange(of: style) { _, _ in persist() }
        .onChange(of: custom) { _, _ in persist() }
        .onChange(of: zone) { _, _ in persist() }
        .onChange(of: other) { _, _ in persist() }
    }

    private func restore() {
        guard !restored else { return }
        restored = true
        let object = model.loadOptionsObject(for: "date")
        if let value = object["style"] as? String, let parsed = DateConvert.OutputStyle(rawValue: value) { style = parsed }
        custom = object["custom"] as? String ?? custom
        zone = object["zone"] as? String ?? "UTC"
        other = object["other"] as? String ?? ""
    }

    private func persist() {
        model.saveOptionsObject([
            "style": style.rawValue,
            "custom": custom,
            "zone": zone,
            "other": other,
        ], for: "date")
    }
}
