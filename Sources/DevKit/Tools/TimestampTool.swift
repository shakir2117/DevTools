import SwiftUI
import DevKitCore

struct TimestampTool: Tool {
    let id = "timestamp"
    let name = "Timestamp"
    let summary = "Unix time, ISO 8601, time zones, and relative time"
    let symbol = "clock"
    let category = ToolCategory.converters
    func makeView() -> AnyView { AnyView(TimestampToolView()) }
}

struct TimestampToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var unit: TimestampConvert.UnitMode = .auto
    @State private var zone = "UTC"
    @State private var customZone = ""
    @State private var pushed = ""
    @State private var restored = false

    private var activeZone: String {
        let trimmed = customZone.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? zone : trimmed
    }

    var body: some View {
        let unit = unit
        let activeZone = activeZone
        TextToolView(
            toolID: "timestamp",
            sample: "1700000000",
            runToken: "\(unit.rawValue)|\(activeZone)",
            pushedInput: pushed,
            transform: { TimestampConvert.convert($0, unit: unit, timeZoneID: activeZone) }
        ) {
            HStack(spacing: 12) {
                Picker("Unit", selection: $unit) {
                    ForEach(TimestampConvert.UnitMode.allCases, id: \.self) { item in
                        Text(item.title).tag(item)
                    }
                }
                .frame(maxWidth: 220)
                Picker("Zone", selection: $zone) {
                    ForEach(TimestampConvert.commonZones, id: \.self) { item in
                        Text(item == "local" ? "Local" : item).tag(item)
                    }
                }
                .frame(maxWidth: 220)
                TextField("IANA zone", text: $customZone)
                    .frame(maxWidth: 180)
                Button("Now") {
                    pushed = String(Int(Date().timeIntervalSince1970))
                }
                Spacer()
            }
        }
        .onAppear(perform: restore)
        .onChange(of: unit) { _, _ in persist() }
        .onChange(of: zone) { _, _ in persist() }
        .onChange(of: customZone) { _, _ in persist() }
    }

    private func restore() {
        guard !restored else { return }
        restored = true
        let object = model.loadOptionsObject(for: "timestamp")
        if let value = object["unit"] as? String, let parsed = TimestampConvert.UnitMode(rawValue: value) { unit = parsed }
        zone = object["zone"] as? String ?? "UTC"
        customZone = object["customZone"] as? String ?? ""
    }

    private func persist() {
        model.saveOptionsObject([
            "unit": unit.rawValue,
            "zone": zone,
            "customZone": customZone,
        ], for: "timestamp")
    }
}
