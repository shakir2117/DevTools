import SwiftUI
import DevKitCore

struct FileSizeTool: Tool {
    let id = "file-size"
    let name = "File Size"
    let summary = "Bytes through petabytes, SI and IEC side by side"
    let symbol = "externaldrive"
    let category = ToolCategory.converters
    func makeView() -> AnyView { AnyView(FileSizeToolView()) }
}

struct FileSizeToolView: View {
    @EnvironmentObject private var model: AppModel
    @State private var unit = "MiB"
    @State private var restored = false

    var body: some View {
        let chosen = unit
        TextToolView(
            toolID: "file-size",
            sample: "1.5",
            runToken: chosen,
            canSwap: false,
            transform: { FileSizeCalc.convert(text: $0, unit: chosen) }
        ) {
            Picker("Unit", selection: $unit) {
                ForEach(FileSizeCalc.units, id: \.self) { Text($0).tag($0) }
            }
            .frame(maxWidth: 160)
        }
        .onAppear {
            guard !restored else { return }
            restored = true
            unit = model.loadOptionsObject(for: "file-size")["unit"] as? String ?? "MiB"
        }
        .onChange(of: unit) { _, _ in
            model.saveOptionsObject(["unit": unit], for: "file-size")
        }
    }
}
