import SwiftUI

public struct RemoteView: View {
    private let devices: [String]
    private let connect: (String) -> Void

    public init(devices: [String], connect: @escaping (String) -> Void) {
        self.devices = devices
        self.connect = connect
    }

    public var body: some View {
        NavigationStack {
            List(devices, id: \.self) { device in
                Button(device) { connect(device) }
            }
            .navigationTitle("Nearby TVs")
            .overlay {
                if devices.isEmpty { ContentUnavailableView("No TVs found", systemImage: "tv") }
            }
        }
    }
}
