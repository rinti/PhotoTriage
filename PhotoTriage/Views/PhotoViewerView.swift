//
//  PhotoViewerView.swift
//  PhotoTriage
//

import SwiftUI
import Photos

struct PhotoViewerView: View {
    let assets: [PHAsset]
    let sortOrder: SortOrder
    let sessionManager: SessionManager
    let onDismiss: () -> Void

    // Initial state for session restoration
    let initialIndex: Int
    let initialVisitedIndices: [Int]
    let initialMarkedAssets: [String]

    // Filter parameters (for session persistence)
    let albumIdentifier: String?
    let dateFrom: Date?
    let dateTo: Date?
    let location: String?

    @StateObject private var imageLoader = ImageLoader()
    @StateObject private var deleteBucket = DeleteBucket()
    @State private var currentIndex: Int = 0
    @State private var visitedIndices: [Int] = []  // Stack for back navigation history

    init(
        assets: [PHAsset],
        sortOrder: SortOrder,
        sessionManager: SessionManager,
        initialIndex: Int = 0,
        initialVisitedIndices: [Int] = [],
        initialMarkedAssets: [String] = [],
        albumIdentifier: String? = nil,
        dateFrom: Date? = nil,
        dateTo: Date? = nil,
        location: String? = nil,
        onDismiss: @escaping () -> Void
    ) {
        self.assets = assets
        self.sortOrder = sortOrder
        self.sessionManager = sessionManager
        self.initialIndex = initialIndex
        self.initialVisitedIndices = initialVisitedIndices
        self.initialMarkedAssets = initialMarkedAssets
        self.albumIdentifier = albumIdentifier
        self.dateFrom = dateFrom
        self.dateTo = dateTo
        self.location = location
        self.onDismiss = onDismiss
    }
    @State private var showBucketView = false
    @State private var showCommitConfirmation = false
    @State private var showQuitConfirmation = false
    @FocusState private var isFocused: Bool

    /// Current asset being viewed (nil if at end or empty)
    private var currentAsset: PHAsset? {
        guard currentIndex < assets.count else { return nil }
        return assets[currentIndex]
    }

    /// Whether current photo is marked for deletion
    private var isCurrentMarked: Bool {
        guard let asset = currentAsset else { return false }
        return deleteBucket.isMarked(asset)
    }

    var body: some View {
        Group {
            if showBucketView {
                BucketView(
                    deleteBucket: deleteBucket,
                    assets: assets,
                    onDismiss: { showBucketView = false }
                )
            } else {
                photoViewerContent
            }
        }
        .confirmationDialog(
            "Delete \(deleteBucket.count) photos permanently?",
            isPresented: $showCommitConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                commitDeletions()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Photos will be moved to Recently Deleted and removed from all your devices.")
        }
        .confirmationDialog(
            "You have \(deleteBucket.count) items marked for deletion",
            isPresented: $showQuitConfirmation,
            titleVisibility: .visible
        ) {
            Button("Save & Quit") {
                saveSessionAndQuit()
            }
            Button("Commit & Quit", role: .destructive) {
                commitAndQuit()
            }
            Button("Discard & Quit") {
                discardAndQuit()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Save & Quit will remember your marked items for next time.")
        }
    }

    private var photoViewerContent: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()

            // Photo display
            if let image = imageLoader.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .overlay {
                        // Red border for marked photos
                        if isCurrentMarked {
                            RoundedRectangle(cornerRadius: 0)
                                .stroke(.red, lineWidth: 8)
                        }
                    }
            } else if imageLoader.isLoading {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)
            } else if let error = imageLoader.error {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.largeTitle)
                        .foregroundStyle(.yellow)
                    Text(error)
                        .foregroundStyle(.secondary)
                }
            }

            // Overlays (progress counter, bucket counter)
            VStack {
                HStack {
                    Spacer()

                    // Bucket counter (only show when not empty)
                    if !deleteBucket.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.caption)
                            Text("Bucket: \(deleteBucket.count)")
                        }
                        .font(.headline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.red.opacity(0.8))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.white)
                    }

                    // Progress counter
                    Text("\(currentIndex + 1)/\(assets.count)")
                        .font(.headline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(.black.opacity(0.6))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.white)
                        .padding()
                }
                Spacer()
            }

            // Red overlay indicator for marked photos
            if isCurrentMarked {
                VStack {
                    Spacer()
                    HStack {
                        HStack(spacing: 6) {
                            Image(systemName: "trash.fill")
                            Text("Marked for deletion")
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.red.opacity(0.9))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .foregroundStyle(.white)
                        .padding()
                        Spacer()
                    }
                }
            }

            // End of photos message
            if currentIndex >= assets.count {
                VStack(spacing: 16) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.green)
                    Text("You've reached the end!")
                        .font(.title2)
                        .foregroundStyle(.white)
                    Text("Press Q to quit")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .focusable()
        .focused($isFocused)
        .onKeyPress { keyPress in
            handleKeyPress(keyPress)
        }
        .task {
            // Restore session state if resuming
            currentIndex = initialIndex
            visitedIndices = initialVisitedIndices
            deleteBucket.restoreFromSession(initialMarkedAssets)
            loadCurrentPhoto()
            isFocused = true
        }
    }

    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        switch keyPress.characters.lowercased() {
        case "s":
            // Keep photo, advance to next
            Task { @MainActor in
                advanceToNext()
            }
            return .handled
        case "d":
            // Mark for deletion, advance to next
            Task { @MainActor in
                markForDeletionAndAdvance()
            }
            return .handled
        case "z":
            // Go back to previous photo
            Task { @MainActor in
                goBack()
            }
            return .handled
        case "b":
            // Toggle bucket view
            Task { @MainActor in
                showBucketView = true
            }
            return .handled
        case "c":
            // Commit deletions (if bucket not empty)
            Task { @MainActor in
                if !deleteBucket.isEmpty {
                    showCommitConfirmation = true
                }
            }
            return .handled
        case "q":
            // Quit session (prompt if bucket has items)
            Task { @MainActor in
                if deleteBucket.isEmpty {
                    saveSessionAndQuit()
                } else {
                    showQuitConfirmation = true
                }
            }
            return .handled
        default:
            return .ignored
        }
    }

    private func advanceToNext() {
        guard currentIndex < assets.count - 1 else {
            // Already at the last photo
            currentIndex = assets.count // Trigger "end" state
            return
        }
        // Push current index to history before advancing
        visitedIndices.append(currentIndex)
        currentIndex += 1
        loadCurrentPhoto()
    }

    private func markForDeletionAndAdvance() {
        guard currentIndex < assets.count else { return }
        let asset = assets[currentIndex]
        deleteBucket.markForDeletion(asset)
        advanceToNext()
    }

    private func goBack() {
        guard let previousIndex = visitedIndices.popLast() else {
            // No history, can't go back
            return
        }
        currentIndex = previousIndex
        loadCurrentPhoto()

        // Auto-restore if the photo was marked for deletion
        if let asset = currentAsset, deleteBucket.isMarked(asset) {
            deleteBucket.restore(asset)
        }
    }

    private func loadCurrentPhoto() {
        guard currentIndex < assets.count else { return }
        let asset = assets[currentIndex]
        imageLoader.loadImage(from: asset)
    }

    private func commitDeletions() {
        Task {
            do {
                _ = try await deleteBucket.commitDeletions()
                // Clear session after commit - position is unreliable after photos deleted
                await MainActor.run {
                    sessionManager.clearSession()
                }
            } catch {
                print("Failed to delete photos: \(error)")
            }
        }
    }

    private func commitAndQuit() {
        Task {
            do {
                _ = try await deleteBucket.commitDeletions()
                await MainActor.run {
                    // Clear session - photos deleted, position unreliable
                    sessionManager.clearSession()
                    onDismiss()
                }
            } catch {
                print("Failed to delete photos: \(error)")
            }
        }
    }

    private func discardAndQuit() {
        // Capture values before any potential view changes
        let count = assets.count
        let currentIdx = currentIndex
        let visited = visitedIndices

        // Clear bucket but save position
        let sessionData = SessionData(
            sortOrder: sortOrder,
            currentIndex: currentIdx,
            visitedIndices: visited,
            markedAssets: [],  // Discarded
            totalAssetCount: count,
            savedAt: Date(),
            albumIdentifier: albumIdentifier,
            dateFrom: dateFrom,
            dateTo: dateTo,
            location: location
        )
        sessionManager.saveSession(sessionData)

        // Small delay to let the save complete before dismissing
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            onDismiss()
        }
    }

    private func saveSessionAndQuit() {
        // Capture values before any potential view changes
        let count = assets.count
        let currentIdx = currentIndex
        let visited = visitedIndices
        let marked = Array(deleteBucket.markedAssets)

        let sessionData = SessionData(
            sortOrder: sortOrder,
            currentIndex: currentIdx,
            visitedIndices: visited,
            markedAssets: marked,
            totalAssetCount: count,
            savedAt: Date(),
            albumIdentifier: albumIdentifier,
            dateFrom: dateFrom,
            dateTo: dateTo,
            location: location
        )
        sessionManager.saveSession(sessionData)

        // Small delay to let the save complete before dismissing
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
            onDismiss()
        }
    }
}
