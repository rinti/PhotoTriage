import SwiftUI

struct HelpOverlay: View {
    @Binding var isPresented: Bool

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented = false
                }

            // Help content
            VStack(spacing: 20) {
                Text("Keyboard Shortcuts")
                    .font(.title2)
                    .fontWeight(.semibold)

                VStack(alignment: .leading, spacing: 12) {
                    ShortcutRow(key: "S", description: "Keep photo, advance to next")
                    ShortcutRow(key: "D", description: "Mark for deletion, advance")
                    ShortcutRow(key: "Z", description: "Go back to previous photo")
                    ShortcutRow(key: "B", description: "Open delete bucket")
                    ShortcutRow(key: "C", description: "Commit all deletions")
                    ShortcutRow(key: "Q", description: "Quit session")
                    ShortcutRow(key: "?", description: "Show/hide this help")
                    ShortcutRow(key: "Space", description: "Play/pause video")
                }

                Text("Press ? or Escape to close")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(30)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(radius: 20)
        }
        .focusable()
        .onKeyPress { keyPress in
            if keyPress.characters == "?" || keyPress.key == .escape {
                isPresented = false
                return .handled
            }
            return .ignored
        }
    }
}

private struct ShortcutRow: View {
    let key: String
    let description: String

    var body: some View {
        HStack(spacing: 16) {
            Text(key)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
                .frame(width: 60)
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(.quaternary)
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text(description)
                .foregroundStyle(.secondary)

            Spacer()
        }
    }
}

#Preview {
    HelpOverlay(isPresented: .constant(true))
}
