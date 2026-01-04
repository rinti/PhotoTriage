import SwiftUI
import Photos

struct MetadataOverlay: View {
    let asset: PHAsset
    let locationCache: LocationCache

    @State private var locationString: String?
    @State private var isLoadingLocation = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            // Date
            if let date = asset.creationDate {
                MetadataRow(icon: "calendar", text: formatDate(date))
            }

            // Location
            if let location = locationString {
                MetadataRow(icon: "location.fill", text: location)
            } else if isLoadingLocation {
                MetadataRow(icon: "location.fill", text: "Loading...")
            }

            // Dimensions
            MetadataRow(
                icon: "aspectratio",
                text: "\(asset.pixelWidth) x \(asset.pixelHeight)"
            )

            // File size
            MetadataRow(icon: "doc.fill", text: formatFileSize(for: asset))
        }
        .font(.caption)
        .padding(10)
        .background(.black.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .foregroundStyle(.white)
        .task(id: asset.localIdentifier) {
            await loadLocation()
        }
    }

    private func loadLocation() async {
        // Check cache first
        if let cached = locationCache.getLocation(for: asset.localIdentifier) {
            locationString = cached
            return
        }

        // Only try to geocode if asset has location data
        guard asset.location != nil else {
            locationString = nil
            return
        }

        isLoadingLocation = true
        locationString = await locationCache.geocodeAsset(asset)
        isLoadingLocation = false
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatFileSize(for asset: PHAsset) -> String {
        let resources = PHAssetResource.assetResources(for: asset)
        var totalSize: Int64 = 0

        for resource in resources {
            if let fileSize = resource.value(forKey: "fileSize") as? Int64 {
                totalSize += fileSize
            }
        }

        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: totalSize)
    }
}

private struct MetadataRow: View {
    let icon: String
    let text: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .frame(width: 14)
            Text(text)
        }
    }
}
