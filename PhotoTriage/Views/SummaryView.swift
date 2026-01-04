import SwiftUI

/// End-of-session summary view displaying statistics
struct SummaryView: View {
    let stats: SessionStats
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 32) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(.green)
                Text("Session Complete")
                    .font(.largeTitle)
                    .fontWeight(.bold)
            }

            // Stats grid
            VStack(spacing: 20) {
                // Photos stats
                HStack(spacing: 40) {
                    StatItem(
                        icon: "checkmark.circle",
                        iconColor: .green,
                        value: "\(stats.photosKept)",
                        label: "kept"
                    )
                    StatItem(
                        icon: "trash",
                        iconColor: .red,
                        value: "\(stats.photosDeleted)",
                        label: "deleted"
                    )
                    StatItem(
                        icon: "photo.stack",
                        iconColor: .blue,
                        value: "\(stats.totalPhotosReviewed)",
                        label: "reviewed"
                    )
                }

                Divider()
                    .frame(width: 300)

                // Time and storage stats
                HStack(spacing: 40) {
                    StatItem(
                        icon: "externaldrive",
                        iconColor: .purple,
                        value: stats.formattedStorageFreed,
                        label: "freed"
                    )
                    StatItem(
                        icon: "clock",
                        iconColor: .orange,
                        value: stats.formattedDuration,
                        label: "spent"
                    )
                    StatItem(
                        icon: "bolt",
                        iconColor: .yellow,
                        value: String(format: "%.1f", stats.photosPerMinute),
                        label: "photos/min"
                    )
                }
            }
            .padding(.vertical, 20)

            // Done button
            Button(action: onDismiss) {
                Text("Done")
                    .font(.headline)
                    .frame(width: 120)
            }
            .keyboardShortcut(.return, modifiers: [])
            .buttonStyle(.borderedProminent)
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

/// Individual stat item with icon, value, and label
private struct StatItem: View {
    let icon: String
    let iconColor: Color
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(iconColor)
            Text(value)
                .font(.title)
                .fontWeight(.semibold)
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(minWidth: 80)
    }
}

#Preview {
    var stats = SessionStats(sessionStartTime: Date().addingTimeInterval(-754)) // ~12.5 min ago
    stats.photosKept = 127
    stats.photosDeleted = 43
    stats.storageFreed = 2_500_000_000 // 2.5 GB

    return SummaryView(stats: stats, onDismiss: {})
        .frame(width: 600, height: 500)
}
