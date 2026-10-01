import SwiftUI
import MapKit
import DevKitCore

struct IPLookupTool: Tool {
    let id = "ip-lookup"
    let name = "IP Lookup"
    let summary = "Geolocation and ASN for an IP address or your public IP"
    let symbol = "mappin.and.ellipse"
    let category = ToolCategory.networking
    func makeView() -> AnyView { AnyView(IPLookupToolView()) }
}

struct IPLookupToolView: View {
    @State private var ip = ""
    @State private var provider = "https://ipwho.is/{ip}"
    @State private var report = "Leave the address empty, or type my ip, to look up this machine."
    @State private var position = MapCameraPosition.automatic
    @State private var coordinate: CLLocationCoordinate2D?
    @State private var busy = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                TextField("IP or empty for my IP", text: $ip)
                TextField("Provider URL with {ip}", text: $provider)
                Button(busy ? "Looking…" : "Lookup") { lookup() }.disabled(busy)
            }
            Map(position: $position) {
                if let coordinate {
                    Marker("IP", coordinate: coordinate)
                }
            }
            .frame(height: 220)
            Text(report)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(12)
    }

    private func lookup() {
        busy = true
        let ip = ip
        let provider = provider
        Task {
            let result = await IPLookup.lookup(ip: ip, provider: provider)
            await MainActor.run {
                report = result.report
                if let latitude = result.latitude, let longitude = result.longitude {
                    let coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
                    self.coordinate = coordinate
                    position = .region(MKCoordinateRegion(center: coordinate, span: MKCoordinateSpan(latitudeDelta: 4, longitudeDelta: 4)))
                }
                busy = false
            }
        }
    }
}
