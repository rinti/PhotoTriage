import SwiftUI

struct SettingsView: View {
    @AppStorage("showMetadataOverlay") private var showMetadataOverlay: Bool = false
    @ObservedObject private var skippedPhotosManager = SkippedPhotosManager.shared

    var body: some View {
        Form {
            Section {
                Toggle("Show photo metadata", isOn: $showMetadataOverlay)
            } header: {
                Text("Display")
            } footer: {
                Text("Shows date, location, dimensions, and file size in the bottom-left corner during photo review.")
            }

            Section {
                HStack {
                    Text("\(skippedPhotosManager.count) photos permanently skipped")
                    Spacer()
                    Button("Clear All") {
                        skippedPhotosManager.clearAll()
                    }
                    .disabled(skippedPhotosManager.count == 0)
                }
            } header: {
                Text("Skipped Photos")
            } footer: {
                Text("Photos you keep (S) are permanently skipped and won't appear in future sessions.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 220)
    }
}

#Preview {
    SettingsView()
}
