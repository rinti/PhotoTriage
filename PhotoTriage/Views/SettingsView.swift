import SwiftUI

struct SettingsView: View {
    @AppStorage("showMetadataOverlay") private var showMetadataOverlay: Bool = false

    var body: some View {
        Form {
            Section {
                Toggle("Show photo metadata", isOn: $showMetadataOverlay)
            } header: {
                Text("Display")
            } footer: {
                Text("Shows date, location, dimensions, and file size in the bottom-left corner during photo review.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 150)
    }
}

#Preview {
    SettingsView()
}
