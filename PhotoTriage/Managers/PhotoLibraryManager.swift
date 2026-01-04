//
//  PhotoLibraryManager.swift
//  PhotoTriage
//

import Foundation
import Photos
import Combine

@MainActor
class PhotoLibraryManager: ObservableObject {
    @Published var authorizationStatus: PHAuthorizationStatus = .notDetermined
    @Published var photoCount: Int = 0
    @Published var albums: [PHAssetCollection] = []

    init() {
        authorizationStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    func requestAuthorization() async {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        authorizationStatus = status

        if status == .authorized || status == .limited {
            fetchPhotoCount()
            fetchAlbums()
        }
    }

    func fetchPhotoCount(sortOrder: SortOrder = .newestFirst) {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: sortOrder == .oldestFirst)]

        let imageAssets = PHAsset.fetchAssets(with: .image, options: options)
        let videoAssets = PHAsset.fetchAssets(with: .video, options: options)

        photoCount = imageAssets.count + videoAssets.count
    }

    func fetchAlbums() {
        var fetchedAlbums: [PHAssetCollection] = []

        // Fetch user-created albums
        let userAlbums = PHAssetCollection.fetchAssetCollections(
            with: .album,
            subtype: .any,
            options: nil
        )
        userAlbums.enumerateObjects { collection, _, _ in
            fetchedAlbums.append(collection)
        }

        // Fetch smart albums (e.g., Favorites, Recently Added)
        let smartAlbums = PHAssetCollection.fetchAssetCollections(
            with: .smartAlbum,
            subtype: .any,
            options: nil
        )
        smartAlbums.enumerateObjects { collection, _, _ in
            // Skip some system albums that aren't useful for triaging
            let skipSubtypes: [PHAssetCollectionSubtype] = [
                .smartAlbumAllHidden,
                .smartAlbumRecentlyAdded
            ]
            if !skipSubtypes.contains(collection.assetCollectionSubtype) {
                fetchedAlbums.append(collection)
            }
        }

        albums = fetchedAlbums.sorted { ($0.localizedTitle ?? "") < ($1.localizedTitle ?? "") }
    }

    func fetchAssets(sortOrder: SortOrder, album: PHAssetCollection? = nil) -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: sortOrder == .oldestFirst)]

        if let album = album {
            return PHAsset.fetchAssets(in: album, options: options)
        } else {
            // Fetch both images and videos
            options.predicate = NSPredicate(format: "mediaType == %d OR mediaType == %d",
                                           PHAssetMediaType.image.rawValue,
                                           PHAssetMediaType.video.rawValue)
            return PHAsset.fetchAssets(with: options)
        }
    }

    var isAuthorized: Bool {
        authorizationStatus == .authorized || authorizationStatus == .limited
    }

    var authorizationStatusDescription: String {
        switch authorizationStatus {
        case .notDetermined:
            return "Photos access not yet requested"
        case .restricted:
            return "Photos access is restricted"
        case .denied:
            return "Photos access denied. Please enable in System Settings > Privacy > Photos"
        case .authorized:
            return "Full access to Photos library"
        case .limited:
            return "Limited access to Photos library"
        @unknown default:
            return "Unknown authorization status"
        }
    }
}
