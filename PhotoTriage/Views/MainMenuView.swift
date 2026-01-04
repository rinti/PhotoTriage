//
//  MainMenuView.swift
//  PhotoTriage
//

import SwiftUI
import Photos

struct MainMenuView: View {
    @StateObject private var photoManager = PhotoLibraryManager()
    @StateObject private var sessionManager = SessionManager()
    @State private var selectedSortOrder: SortOrder = .newestFirst
    @State private var isShowingViewer = false
    @State private var assets: PHFetchResult<PHAsset>?

    // Session restoration state
    @State private var resumeIndex: Int = 0
    @State private var resumeVisitedIndices: [Int] = []
    @State private var resumeMarkedAssets: [String] = []
    @State private var resumeSortOrder: SortOrder = .newestFirst

    var body: some View {
        ZStack {
            if isShowingViewer, let assets = assets {
                PhotoViewerView(
                    assets: assets,
                    sortOrder: resumeSortOrder,
                    sessionManager: sessionManager,
                    initialIndex: resumeIndex,
                    initialVisitedIndices: resumeVisitedIndices,
                    initialMarkedAssets: resumeMarkedAssets
                ) {
                    // On dismiss, return to main menu
                    isShowingViewer = false
                    self.assets = nil
                    // Reset resume state
                    resumeIndex = 0
                    resumeVisitedIndices = []
                    resumeMarkedAssets = []
                }
            } else {
                mainMenuContent
            }
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
                        continueSession(session)
                    } label: {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Continue (\(session.currentIndex + 1)/\(session.totalAssetCount))")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    if !session.markedAssets.isEmpty {
                        Text("\(session.markedAssets.count) items in delete bucket")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()
                    .frame(maxWidth: 300)
            }

            // Sort Order Picker
            Picker("Sort Order", selection: $selectedSortOrder) {
                ForEach(SortOrder.allCases, id: \.self) { order in
                    Text(order.rawValue).tag(order)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 300)

            Button("Start New Session") {
                startNewSession()
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
            .disabled(photoManager.photoCount == 0)
        }
    }

    private func startNewSession() {
        // Clear any existing saved session
        sessionManager.clearSession()

        let fetchedAssets = photoManager.fetchAssets(sortOrder: selectedSortOrder)
        guard fetchedAssets.count > 0 else { return }

        // Reset resume state for fresh start
        resumeIndex = 0
        resumeVisitedIndices = []
        resumeMarkedAssets = []
        resumeSortOrder = selectedSortOrder

        assets = fetchedAssets
        isShowingViewer = true
    }

    private func continueSession(_ session: SessionData) {
        // Fetch assets with saved sort order
        let fetchedAssets = photoManager.fetchAssets(sortOrder: session.sortOrder)
        guard fetchedAssets.count > 0 else { return }

        // Set resume state from saved session
        resumeIndex = session.currentIndex
        resumeVisitedIndices = session.visitedIndices
        resumeMarkedAssets = session.markedAssets
        resumeSortOrder = session.sortOrder

        assets = fetchedAssets
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

#Preview {
    MainMenuView()
}
