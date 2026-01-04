//
//  MainMenuView.swift
//  PhotoTriage
//

import SwiftUI
import Photos

struct MainMenuView: View {
    @StateObject private var photoManager = PhotoLibraryManager()
    @StateObject private var sessionManager = SessionManager()
    @StateObject private var locationCache = LocationCache()

    // Filter state
    @State private var selectedSortOrder: SortOrder = .newestFirst
    @State private var selectedAlbum: PHAssetCollection?
    @State private var selectedDateFrom: Date?
    @State private var selectedDateTo: Date?
    @State private var selectedLocation: String = ""

    // UI state
    @State private var isShowingViewer = false
    @State private var filteredAssets: [PHAsset]?
    @State private var showNoPhotosAlert = false
    @State private var isFiltering = false
    @State private var filterProgress: (current: Int, total: Int)?

    // Session restoration state
    @State private var resumeIndex: Int = 0
    @State private var resumeVisitedIndices: [Int] = []
    @State private var resumeMarkedAssets: [String] = []
    @State private var resumeSortOrder: SortOrder = .newestFirst
    @State private var resumeAlbum: PHAssetCollection?
    @State private var resumeDateFrom: Date?
    @State private var resumeDateTo: Date?
    @State private var resumeLocation: String = ""

    var body: some View {
        ZStack {
            if isShowingViewer, let assets = filteredAssets, !assets.isEmpty {
                PhotoViewerView(
                    assets: assets,
                    sortOrder: resumeSortOrder,
                    sessionManager: sessionManager,
                    initialIndex: resumeIndex,
                    initialVisitedIndices: resumeVisitedIndices,
                    initialMarkedAssets: resumeMarkedAssets,
                    albumIdentifier: resumeAlbum?.localIdentifier,
                    dateFrom: resumeDateFrom,
                    dateTo: resumeDateTo,
                    location: resumeLocation.isEmpty ? nil : resumeLocation
                ) {
                    // On dismiss, return to main menu
                    isShowingViewer = false
                    filteredAssets = nil
                    // Reset resume state
                    resumeIndex = 0
                    resumeVisitedIndices = []
                    resumeMarkedAssets = []
                    resumeAlbum = nil
                    resumeDateFrom = nil
                    resumeDateTo = nil
                    resumeLocation = ""
                }
            } else {
                mainMenuContent
            }
        }
        .alert("No Photos Match", isPresented: $showNoPhotosAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("No photos match your filter criteria. Try adjusting your filters.")
        }
    }

    private var mainMenuContent: some View {
        VStack(spacing: 24) {
            // App Title
            Text("PhotoTriage")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Quickly sort through your photo library")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            // Authorization Status
            authorizationSection

            Spacer()

            // Start Session Button
            if photoManager.isAuthorized {
                sessionSection
            }
        }
        .padding(40)
        .frame(minWidth: 400, minHeight: 300)
        .task {
            if photoManager.authorizationStatus == .notDetermined {
                await photoManager.requestAuthorization()
            } else if photoManager.isAuthorized {
                photoManager.fetchPhotoCount()
                photoManager.fetchAlbums()
            }
        }
    }

    @ViewBuilder
    private var authorizationSection: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: authorizationIcon)
                    .foregroundStyle(authorizationColor)
                Text(photoManager.authorizationStatusDescription)
                    .foregroundStyle(.secondary)
            }

            if photoManager.authorizationStatus == .notDetermined {
                Button("Grant Photos Access") {
                    Task {
                        await photoManager.requestAuthorization()
                    }
                }
                .buttonStyle(.borderedProminent)
            } else if photoManager.authorizationStatus == .denied {
                Button("Open System Settings") {
                    if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Photos") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
            }
        }
    }

    @ViewBuilder
    private var sessionSection: some View {
        VStack(spacing: 16) {
            Text("\(photoManager.photoCount) photos and videos in library")
                .font(.headline)

            // Continue button (only visible if session exists)
            if sessionManager.hasActiveSession, let session = sessionManager.sessionData {
                VStack(spacing: 8) {
                    Button {
                        Task {
                            await continueSession(session)
                        }
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Continue (\(session.currentIndex + 1)/\(session.totalAssetCount))")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(isFiltering)

                    if !session.markedAssets.isEmpty {
                        Text("\(session.markedAssets.count) items in delete bucket")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()
                    .frame(maxWidth: 300)
            }

            // Filters section
            VStack(alignment: .leading, spacing: 12) {
                Text("Filters")
                    .font(.headline)

                // Sort Order Picker
                HStack {
                    Text("Sort:")
                        .frame(width: 80, alignment: .trailing)
                    Picker("Sort Order", selection: $selectedSortOrder) {
                        ForEach(SortOrder.allCases, id: \.self) { order in
                            Text(order.rawValue).tag(order)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Album Picker
                HStack {
                    Text("Album:")
                        .frame(width: 80, alignment: .trailing)
                    Picker("Album", selection: $selectedAlbum) {
                        Text("All Photos").tag(nil as PHAssetCollection?)
                        ForEach(photoManager.albums, id: \.localIdentifier) { album in
                            Text(album.localizedTitle ?? "Untitled").tag(album as PHAssetCollection?)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Date From Picker
                HStack {
                    Text("From:")
                        .frame(width: 80, alignment: .trailing)
                    OptionalDatePicker(date: $selectedDateFrom, placeholder: "Any date")
                }

                // Date To Picker
                HStack {
                    Text("To:")
                        .frame(width: 80, alignment: .trailing)
                    OptionalDatePicker(date: $selectedDateTo, placeholder: "Any date")
                }

                // Location Filter
                HStack {
                    Text("Location:")
                        .frame(width: 80, alignment: .trailing)
                    TextField("City, region, or country", text: $selectedLocation)
                        .textFieldStyle(.roundedBorder)
                }

                // Clear Filters Button
                if hasActiveFilters {
                    HStack {
                        Spacer()
                        Button("Clear Filters") {
                            clearFilters()
                        }
                        .buttonStyle(.link)
                    }
                }
            }
            .frame(maxWidth: 400)

            // Progress indicator during location filtering
            if isFiltering, let progress = filterProgress {
                VStack(spacing: 4) {
                    ProgressView(value: Double(progress.current), total: Double(progress.total))
                    Text("Filtering by location... \(progress.current)/\(progress.total)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: 300)
            }

            Button("Start New Session") {
                Task {
                    await startNewSession()
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(photoManager.photoCount == 0 || isFiltering)
        }
    }

    private var hasActiveFilters: Bool {
        selectedAlbum != nil || selectedDateFrom != nil || selectedDateTo != nil || !selectedLocation.isEmpty
    }

    private func clearFilters() {
        selectedAlbum = nil
        selectedDateFrom = nil
        selectedDateTo = nil
        selectedLocation = ""
    }

    private func startNewSession() async {
        // Clear any existing saved session
        sessionManager.clearSession()

        // Fetch assets with album and date filters
        let fetchedAssets = photoManager.fetchAssets(
            sortOrder: selectedSortOrder,
            album: selectedAlbum,
            dateFrom: selectedDateFrom,
            dateTo: selectedDateTo
        )

        var assetsArray = photoManager.assetsToArray(fetchedAssets)

        // Apply location filter if specified
        if !selectedLocation.isEmpty {
            isFiltering = true
            filterProgress = (0, assetsArray.count)

            let matchingIds = await locationCache.filterAssetsByLocation(
                assets: assetsArray,
                query: selectedLocation
            ) { current, total in
                filterProgress = (current, total)
            }

            assetsArray = assetsArray.filter { matchingIds.contains($0.localIdentifier) }
            isFiltering = false
            filterProgress = nil
        }

        // Check if any photos match
        guard !assetsArray.isEmpty else {
            showNoPhotosAlert = true
            return
        }

        // Reset resume state for fresh start
        resumeIndex = 0
        resumeVisitedIndices = []
        resumeMarkedAssets = []
        resumeSortOrder = selectedSortOrder
        resumeAlbum = selectedAlbum
        resumeDateFrom = selectedDateFrom
        resumeDateTo = selectedDateTo
        resumeLocation = selectedLocation

        filteredAssets = assetsArray
        isShowingViewer = true
    }

    private func continueSession(_ session: SessionData) async {
        // Restore album from identifier
        let album: PHAssetCollection?
        if let albumId = session.albumIdentifier {
            album = photoManager.getAlbum(byIdentifier: albumId)
        } else {
            album = nil
        }

        // Fetch assets with saved filters
        let fetchedAssets = photoManager.fetchAssets(
            sortOrder: session.sortOrder,
            album: album,
            dateFrom: session.dateFrom,
            dateTo: session.dateTo
        )

        var assetsArray = photoManager.assetsToArray(fetchedAssets)

        // Apply location filter if it was saved
        if let location = session.location, !location.isEmpty {
            isFiltering = true
            filterProgress = (0, assetsArray.count)

            let matchingIds = await locationCache.filterAssetsByLocation(
                assets: assetsArray,
                query: location
            ) { current, total in
                filterProgress = (current, total)
            }

            assetsArray = assetsArray.filter { matchingIds.contains($0.localIdentifier) }
            isFiltering = false
            filterProgress = nil
        }

        guard !assetsArray.isEmpty else {
            showNoPhotosAlert = true
            return
        }

        // Set resume state from saved session
        resumeIndex = min(session.currentIndex, assetsArray.count - 1)
        resumeVisitedIndices = session.visitedIndices
        resumeMarkedAssets = session.markedAssets
        resumeSortOrder = session.sortOrder
        resumeAlbum = album
        resumeDateFrom = session.dateFrom
        resumeDateTo = session.dateTo
        resumeLocation = session.location ?? ""

        filteredAssets = assetsArray
        isShowingViewer = true
    }

    private var authorizationIcon: String {
        switch photoManager.authorizationStatus {
        case .authorized, .limited:
            return "checkmark.circle.fill"
        case .denied, .restricted:
            return "xmark.circle.fill"
        case .notDetermined:
            return "questionmark.circle.fill"
        @unknown default:
            return "questionmark.circle.fill"
        }
    }

    private var authorizationColor: Color {
        switch photoManager.authorizationStatus {
        case .authorized, .limited:
            return .green
        case .denied, .restricted:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .gray
        }
    }
}

// MARK: - Helper Views

/// A date picker that supports optional dates with a clear button
struct OptionalDatePicker: View {
    @Binding var date: Date?
    let placeholder: String

    @State private var isShowingPicker = false
    @State private var tempDate = Date()

    var body: some View {
        HStack {
            if let selectedDate = date {
                Text(selectedDate, style: .date)
                    .foregroundStyle(.primary)

                Button {
                    date = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            } else {
                Button(placeholder) {
                    tempDate = Date()
                    isShowingPicker = true
                }
                .foregroundStyle(.secondary)
            }

            Spacer()

            if date == nil {
                DatePicker("", selection: $tempDate, displayedComponents: .date)
                    .labelsHidden()
                    .onChange(of: tempDate) { _, newValue in
                        date = newValue
                    }
            } else {
                DatePicker("", selection: Binding(
                    get: { date ?? Date() },
                    set: { date = $0 }
                ), displayedComponents: .date)
                    .labelsHidden()
            }
        }
    }
}

#Preview {
    MainMenuView()
}
