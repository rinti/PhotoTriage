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
    let locationCache: LocationCache
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

    @AppStorage("showMetadataOverlay") private var showMetadataOverlay: Bool = false
    @StateObject private var imageLoader = ImageLoader()
    @StateObject private var deleteBucket = DeleteBucket()
    @State private var currentIndex: Int = 0
    @State private var visitedIndices: [Int] = []  // Stack for back navigation history
    @State private var showHelp = false

    init(
        assets: [PHAsset],
        sortOrder: SortOrder,
        sessionManager: SessionManager,
        locationCache: LocationCache,
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
        self.locationCache = locationCache
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
    @State private var isVideoPlaying = false
    @State private var slideDirection: Edge = .trailing  // Animation direction
    @State private var showLoadingIndicator = false  // Delayed loading indicator
    @State private var sessionStats = SessionStats()  // Session statistics tracking
    @State private var showSummary = false  // Show end-of-session summary
    @State private var summaryStorageFreed: Int64 = 0  // Storage freed (calculated before commit)
    @State private var hasInitialized = false  // Track if session state has been restored
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

    /// Final stats for summary view (includes storage freed)
    private var finalStats: SessionStats {
        var stats = sessionStats
        stats.storageFreed = summaryStorageFreed
        return stats
    }

    var body: some View {
        Group {
            if showSummary {
                SummaryView(stats: finalStats, onDismiss: onDismiss)
            } else if showBucketView {
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

            // Photo/Video display with slide animation
            Group {
                if imageLoader.mediaType == .video, let videoAsset = imageLoader.videoAsset {
                    // Video player
                    VideoPlayerView(videoAsset: videoAsset, isPlaying: $isVideoPlaying)
                        .overlay {
                            // Play/pause button - click to toggle
                            ZStack {
                                // Clickable area covers entire video
                                Color.clear
                                    .contentShape(Rectangle())
                                    .onTapGesture {
                                        isVideoPlaying.toggle()
                                    }

                                // Play button indicator when paused
                                if !isVideoPlaying {
                                    ZStack {
                                        Circle()
                                            .fill(.black.opacity(0.5))
                                            .frame(width: 80, height: 80)
                                        Image(systemName: "play.fill")
                                            .font(.system(size: 32))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                        }
                        .overlay {
                            // Red border for marked videos
                            if isCurrentMarked {
                                RoundedRectangle(cornerRadius: 0)
                                    .stroke(.red, lineWidth: 8)
                            }
                        }
                } else if let image = imageLoader.image {
                    // Image (photo or video first frame while loading)
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
                } else if imageLoader.isLoading && showLoadingIndicator {
                    // Delayed loading indicator (only shows after 200ms)
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
            }
            .id(currentIndex)
            .transition(.asymmetric(
                insertion: .move(edge: slideDirection),
                removal: .move(edge: slideDirection == .trailing ? .leading : .trailing)
            ))

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

            // Bottom-left overlays (metadata and/or deletion indicator)
            VStack {
                Spacer()
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        // Metadata overlay (if enabled)
                        if showMetadataOverlay, let asset = currentAsset {
                            MetadataOverlay(asset: asset, locationCache: locationCache)
                        }

                        // Marked for deletion indicator
                        if isCurrentMarked {
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
                        }
                    }
                    .padding()
                    Spacer()
                }
            }

            // Help overlay
            if showHelp {
                HelpOverlay(isPresented: $showHelp)
            }

            // End of photos - show summary
            if currentIndex >= assets.count {
                Color.clear
                    .onAppear {
                        // Calculate storage freed from bucket
                        Task {
                            summaryStorageFreed = await deleteBucket.calculateTotalSizeFromArray(assets)
                            showSummary = true
                        }
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
            // Only restore session state once (not when returning from bucket view)
            guard !hasInitialized else {
                isFocused = true
                return
            }
            hasInitialized = true
            currentIndex = initialIndex
            visitedIndices = initialVisitedIndices
            deleteBucket.restoreFromSession(initialMarkedAssets)
            loadCurrentPhoto()
            isFocused = true
        }
        .onChange(of: imageLoader.isLoading) { _, isLoading in
            // Delayed loading indicator - only show after 200ms to avoid flashing
            if isLoading {
                Task {
                    try? await Task.sleep(for: .milliseconds(200))
                    if imageLoader.isLoading {
                        showLoadingIndicator = true
                    }
                }
            } else {
                showLoadingIndicator = false
            }
        }
        .onChange(of: imageLoader.error) { _, error in
            // Auto-skip failed loads
            if error != nil {
                print("Failed to load asset at index \(currentIndex): \(error ?? "unknown")")
                Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    if currentIndex < assets.count - 1 {
                        advanceToNext()
                    }
                }
            }
        }
        .onDisappear {
            imageLoader.clearPreloadCache()
        }
    }

    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        switch keyPress.characters.lowercased() {
        case "s":
            // Keep photo, advance to next
            Task { @MainActor in
                if currentIndex < assets.count {
                    sessionStats.photosKept += 1
                }
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
        case " ":
            // Space: Play/pause video
            if imageLoader.mediaType == .video {
                isVideoPlaying.toggle()
            }
            return .handled
        case "?":
            // Toggle help overlay
            Task { @MainActor in
                showHelp.toggle()
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
        // Set slide direction (new content comes from right)
        slideDirection = .trailing
        // Push current index to history before advancing
        withAnimation(.easeInOut(duration: 0.25)) {
            visitedIndices.append(currentIndex)
            currentIndex += 1
        }
        loadCurrentPhoto()
    }

    private func markForDeletionAndAdvance() {
        guard currentIndex < assets.count else { return }
        let asset = assets[currentIndex]
        deleteBucket.markForDeletion(asset)
        sessionStats.photosDeleted += 1
        advanceToNext()
    }

    private func goBack() {
        guard let previousIndex = visitedIndices.popLast() else {
            // No history, can't go back
            return
        }
        // Set slide direction (new content comes from left)
        slideDirection = .leading
        withAnimation(.easeInOut(duration: 0.25)) {
            currentIndex = previousIndex
        }
        loadCurrentPhoto()
        sessionStats.backNavigations += 1

        // Auto-restore if the photo was marked for deletion
        if let asset = currentAsset, deleteBucket.isMarked(asset) {
            deleteBucket.restore(asset)
            // Adjust stats: no longer deleting this photo
            sessionStats.photosDeleted -= 1
        }
    }

    private func loadCurrentPhoto() {
        // Stop video playback when navigating
        isVideoPlaying = false

        guard currentIndex < assets.count else { return }
        let asset = assets[currentIndex]
        imageLoader.loadImage(from: asset)
        preloadNextPhotos()
    }

    private func preloadNextPhotos() {
        let startIndex = currentIndex + 1
        let endIndex = min(currentIndex + 4, assets.count)  // Next 3
        guard startIndex < endIndex else { return }
        let assetsToPreload = Array(assets[startIndex..<endIndex])
        imageLoader.preloadAssets(assetsToPreload)
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
            // Calculate storage before committing (bucket will be cleared after)
            let storageFreed = await deleteBucket.calculateTotalSizeFromArray(assets)

            do {
                _ = try await deleteBucket.commitDeletions()
                await MainActor.run {
                    // Clear session - photos deleted, position unreliable
                    sessionManager.clearSession()
                    // Show summary instead of immediately dismissing
                    summaryStorageFreed = storageFreed
                    showSummary = true
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
