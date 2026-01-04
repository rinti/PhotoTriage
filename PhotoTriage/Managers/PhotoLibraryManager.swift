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

    func fetchAssets(
        sortOrder: SortOrder,
        album: PHAssetCollection? = nil,
        dateFrom: Date? = nil,
        dateTo: Date? = nil
    ) -> PHFetchResult<PHAsset> {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: sortOrder == .oldestFirst)]

        // Build predicates
        var predicates: [NSPredicate] = []

        // Media type predicate (images and videos)
        let mediaTypePredicate = NSPredicate(
            format: "mediaType == %d OR mediaType == %d",
            PHAssetMediaType.image.rawValue,
            PHAssetMediaType.video.rawValue
        )
        predicates.append(mediaTypePredicate)

        // Date range predicates
        if let from = dateFrom {
            predicates.append(NSPredicate(format: "creationDate >= %@", from as NSDate))
        }
        if let to = dateTo {
            // Add one day to include the entire "to" date
            let endOfDay = Calendar.current.date(byAdding: .day, value: 1, to: to) ?? to
            predicates.append(NSPredicate(format: "creationDate < %@", endOfDay as NSDate))
        }

        if let album = album {
            // When fetching from album, we can't use mediaType predicate with fetchAssets(in:)
            // Instead, apply date predicates only
            if predicates.count > 1 {
                let datePredicates = Array(predicates.dropFirst())
                options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: datePredicates)
            }
            return PHAsset.fetchAssets(in: album, options: options)
        } else {
            // Combine all predicates
            options.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
            return PHAsset.fetchAssets(with: options)
        }
    }

    /// Get an album by its localIdentifier
    func getAlbum(byIdentifier identifier: String) -> PHAssetCollection? {
        let result = PHAssetCollection.fetchAssetCollections(
            withLocalIdentifiers: [identifier],
            options: nil
        )
        return result.firstObject
    }

    /// Convert PHFetchResult to array for location filtering
    func assetsToArray(_ fetchResult: PHFetchResult<PHAsset>) -> [PHAsset] {
        var assets: [PHAsset] = []
        fetchResult.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }

    /// Filter assets by location using the location cache
    func filterAssetsByLocation(
        assets: [PHAsset],
        matchingIds: Set<String>
    ) -> [PHAsset] {
        assets.filter { matchingIds.contains($0.localIdentifier) }
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
