import SwiftUI
import DevKitCore

struct UnitTool: Tool {
    let id = "unit"
    let name = "Unit Converter"
    let summary = "Length, mass, temperature, volume, area, speed, time, data, energy, pressure"
    let symbol = "ruler"
    let category = ToolCategory.converters
    func makeView() -> AnyView { AnyView(UnitToolView()) }
}

struct UnitToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var family = "length"
    @State private var fromUnit = "km"
    @State private var toUnit = "m"
    @State private var restored = false

    private var units: [String] {
        UnitConvert.families.first { $0.id == family }?.units ?? []
    }

    var body: some View {
        let chosenFamily = family
        let chosenFrom = fromUnit
        let chosenTo = toUnit
        TextToolView(
            toolID: "unit",
            sample: "1",
            runToken: "\(chosenFamily)|\(chosenFrom)|\(chosenTo)",
            canSwap: false,
            transform: { UnitConvert.convert(text: $0, family: chosenFamily, from: chosenFrom, to: chosenTo) }
        ) {
            HStack(spacing: 12) {
                Picker("Family", selection: $family) {
                    ForEach(UnitConvert.families) { item in
                        Text(item.title).tag(item.id)
                    }
                }
                .frame(maxWidth: 160)
                Picker("From", selection: $fromUnit) {
                    ForEach(units, id: \.self) { Text($0).tag($0) }
                }
                .frame(maxWidth: 120)
                Picker("To", selection: $toUnit) {
                    ForEach(units, id: \.self) { Text($0).tag($0) }
                }
                .frame(maxWidth: 120)
                Button("Swap") {
                    let current = self.fromUnit
                    self.fromUnit = self.toUnit
                    self.toUnit = current
                }
                Spacer()
            }
        }
        .onAppear(perform: restore)
        .onChange(of: family) { _, newValue in
            if let units = UnitConvert.families.first(where: { $0.id == newValue })?.units {
                if !units.contains(fromUnit) { fromUnit = units[0] }
                if !units.contains(toUnit) { toUnit = units.count > 1 ? units[1] : units[0] }
            }
            persist()
        }
        .onChange(of: fromUnit) { _, _ in persist() }
        .onChange(of: toUnit) { _, _ in persist() }
    }

    private func restore() {
        guard !restored else { return }
        restored = true
        let object = model.loadOptionsObject(for: "unit")
        family = object["family"] as? String ?? "length"
        fromUnit = object["from"] as? String ?? "km"
        toUnit = object["to"] as? String ?? "m"
    }

    private func persist() {
        model.saveOptionsObject(["family": family, "from": fromUnit, "to": toUnit], for: "unit")
    }
}
