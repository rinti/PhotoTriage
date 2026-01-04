# PhotoTriage - macOS Photo Cleanup App

## Overview
A native macOS SwiftUI app to quickly cycle through your iCloud Photos library, marking photos to keep or delete. Deletions sync across all Apple devices via iCloud.

## Technical Requirements
- **Language**: Swift
- **UI Framework**: SwiftUI
- **Photos Access**: PhotoKit (Photos.framework)
- **Minimum macOS**: 26.0 (Tahoe)
- **Appearance**: Follow system (light/dark mode)

---

## Core Workflow

### Main Menu
- **Continue** button (only visible if a saved session exists)
- **Start New Session** with filter options:
  - Sort order: Newest first / Oldest first
  - Album: Dropdown of user's albums (or "All Photos")
  - Date range: From/To date pickers
  - Location: Text field with fuzzy search (matches city, region, or country)
- Filter settings persist through the "Continue" button (saved with session)
- If filters return 0 photos: Show error "No photos match your filters", stay on menu

### Photo Viewer (Session)
**Keyboard Controls:**
| Key | Action |
|-----|--------|
| `s` | Keep photo, advance to next |
| `d` | Mark photo for deletion (add to bucket), advance to next |
| `z` | Go back to previous photo (unlimited history), auto-restore if it was marked for delete |
| `b` | Open delete bucket view |
| `c` | Commit all deletions (if bucket not empty; silent if empty) |
| `q` | Quit session (prompts if bucket has items) |
| `?` | Show keyboard shortcuts help overlay |
| `Space` | Play/pause video |

**Display:**
- Photos/videos display full-screen in resizable window
- Window size and position remembered between launches
- Progress counter always visible (e.g., "47/523")
- Bucket counter visible when not empty (e.g., "Bucket: 12")
- Red border/overlay on photos marked for deletion
- Metadata overlay (optional, toggle in Settings):
  - Position: Bottom-left corner
  - Shows: Date, location, dimensions, file size
- Slide animation: Forward slides left, backward (z) slides right

**Media Handling:**
- Photos: Load low-to-medium resolution (no need for full quality)
- Videos: Show first frame, press Space to play/pause, can delete while playing
- Live Photos: Display as still images only
- Screenshots/screen recordings: Included like any other media
- Failed loads: Auto-skip, log error
- Preloading: Preload next 3 photos/videos for smooth experience

**Duplicates:**
- Same photo in multiple albums: Show each instance (not deduplicated)

**Session State:**
- Session uses snapshot from when started (ignores library changes during session)
- Audio: No sounds

### Delete Bucket View
- Accessed by pressing `b`
- Grid of thumbnails (responsive columns based on window width)
- Red overlay on all thumbnails (since all are marked for delete)
- Shows total at top: "X photos/videos, Y.Z GB will be freed"
- Click thumbnail to remove from bucket (restore photo)
- Press `b` again or Escape to return to photo viewer

### Quit Session (Q)
- If bucket is empty: Save session position, return to main menu
- If bucket has items: Prompt "You have X items marked for deletion. Commit, Discard, or Cancel?"
  - Commit: Execute deletions, show summary, return to menu
  - Discard: Clear bucket, save position, return to menu
  - Cancel: Stay in session

### Commit Deletions (C)
- Always shows confirmation: "Delete X photos/videos permanently?"
- On confirm: Execute via `PHAssetChangeRequest.deleteAssets()`
- Photos move to "Recently Deleted" (recoverable for 30 days, syncs via iCloud)
- Confirmation cannot be disabled in settings

### End of Session
- When reaching last photo: Show detailed summary
- Summary includes:
  - Photos kept
  - Photos deleted
  - Total photos reviewed
  - Storage space freed
  - Time spent
  - Photos per minute
- "Done" button returns to main menu

### Settings (Cmd+,)
- Toggle: Show photo metadata
- (Appearance follows system automatically)

---

## File Structure
```
PhotoTriage/
├── PhotoTriageApp.swift           # App entry point, window management
├── Views/
│   ├── MainMenuView.swift       # Main menu with filters
│   ├── PhotoViewerView.swift    # Photo display with keyboard handling
│   ├── BucketView.swift         # Delete bucket grid view
│   ├── SummaryView.swift        # End-of-session summary
│   ├── SettingsView.swift       # Settings panel
│   ├── MetadataOverlay.swift    # Photo info overlay
│   └── HelpOverlay.swift        # Keyboard shortcuts help (?)
├── Managers/
│   ├── PhotoLibraryManager.swift    # PhotoKit integration
│   ├── SessionManager.swift         # Session state persistence
│   ├── ImageLoader.swift            # Async image/video loading with preload
│   └── DeleteBucket.swift           # In-memory bucket management
├── Models/
│   ├── SortOrder.swift              # Sort order enum
│   ├── SessionData.swift            # Session state model
│   └── SessionStats.swift           # Statistics tracking
├── Info.plist                   # Permissions
└── PhotoTriage.entitlements       # Sandbox config
```

---

## Implementation Notes

### PhotoKit Integration
```swift
// Fetch photos with filters
let options = PHFetchOptions()
options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: sortOrder == .oldestFirst)]

// Date range predicate
if let from = dateFrom, let to = dateTo {
    options.predicate = NSPredicate(format: "creationDate >= %@ AND creationDate <= %@", from as NSDate, to as NSDate)
}

// Fetch from album or all photos
let assets: PHFetchResult<PHAsset>
if let album = selectedAlbum {
    assets = PHAsset.fetchAssets(in: album, options: options)
} else {
    assets = PHAsset.fetchAssets(with: options)  // .image and .video
}
```

### Location Filtering
- Fetch all matching assets first
- For each asset with `location` property, reverse geocode to get place name
- Filter by fuzzy string match on city/region/country
- Use `CLGeocoder` for reverse geocoding (may need caching for performance)

### Session Persistence
```swift
// Save via @AppStorage (UserDefaults)
- currentAssetIdentifier: String
- currentIndex: Int
- sortOrder: SortOrder
- albumIdentifier: String?
- dateFrom: Date?
- dateTo: Date?
- locationFilter: String?
- hasActiveSession: Bool
```

### Delete Bucket
- In-memory array of `PHAsset.localIdentifier` strings
- Calculate storage: Sum of `PHAsset` estimated file sizes
- Batch deletion: `PHAssetChangeRequest.deleteAssets()` with all bucket items

### Preloading Strategy
- Keep next 3 images in memory
- When advancing, drop oldest preloaded, add new one
- Cancel any pending loads for images no longer in preload window

### Window State
- Use SwiftUI's `WindowGroup` with `defaultSize` and state restoration
- Store frame in UserDefaults via `@SceneStorage` or manual `NSWindow` frame saving

---

## Permissions Required

**Info.plist:**
```xml
<key>NSPhotoLibraryUsageDescription</key>
<string>PhotoTriage needs access to display and manage your photos</string>
```

**Entitlements:**
- `com.apple.security.app-sandbox` = YES
- `com.apple.security.personal-information.photos-library` = read-write

---

## Important Behaviors

1. **Deletion is soft**: Photos move to "Recently Deleted", recoverable for 30 days
2. **iCloud sync**: Deletions sync to all devices automatically
3. **System confirmation**: macOS shows one confirmation dialog when committing (via PhotoKit)
4. **No permanent delete API**: Cannot bypass "Recently Deleted" programmatically
5. **Session snapshot**: Library changes during session are ignored until restart

---

# Sprint Plan

This project is divided into sprints that can each be completed within a single Claude Code context window. After each sprint, update the "Sprint Log" section with what was completed, any deviations from plan, and context needed for the next sprint.

---

## Sprint 1: Project Setup & Core Infrastructure
**Goal:** Create Xcode project, set up permissions, and build basic PhotoKit integration.

**Tasks:**
1. Create new macOS SwiftUI project "PhotoTriage" in Xcode
2. Configure Info.plist with `NSPhotoLibraryUsageDescription`
3. Configure entitlements for Photos library access (read-write)
4. Create `SortOrder.swift` enum
5. Create `PhotoLibraryManager.swift`:
   - Authorization request and status handling
   - Fetch all albums method
   - Fetch photos method with sort order parameter (no filters yet)
6. Create basic `MainMenuView.swift`:
   - Request authorization on appear
   - Show authorization status
   - Simple "Start Session" button (no filters yet)
7. Create `PhotoTriageApp.swift` with basic window setup

**Deliverables:**
- App compiles and runs
- Requests Photos permission
- Can fetch and count photos from library

**Files to create:**
- `PhotoTriage/PhotoTriageApp.swift`
- `PhotoTriage/Views/MainMenuView.swift`
- `PhotoTriage/Managers/PhotoLibraryManager.swift`
- `PhotoTriage/Models/SortOrder.swift`

---

## Sprint 2: Basic Photo Viewer
**Goal:** Display photos one at a time with basic navigation.

**Tasks:**
1. Create `ImageLoader.swift`:
   - Load single image from PHAsset
   - Low-to-medium resolution (not full quality)
   - Handle loading states
2. Create basic `PhotoViewerView.swift`:
   - Display current photo full-screen
   - Show progress counter ("1/523")
   - Basic `s` key to advance (no delete yet)
3. Wire up navigation from MainMenuView to PhotoViewerView
4. Handle empty photo library case

**Deliverables:**
- Can start a session and see photos
- Press `s` to advance through photos
- Progress counter works

**Files to create/modify:**
- `PhotoTriage/Managers/ImageLoader.swift`
- `PhotoTriage/Views/PhotoViewerView.swift`
- Modify `MainMenuView.swift` for navigation

---

## Sprint 3: Delete Bucket & Basic Workflow
**Goal:** Implement soft-delete bucket and core s/d/z workflow.

**Tasks:**
1. Create `DeleteBucket.swift`:
   - In-memory storage of marked assets
   - Add/remove methods
   - Calculate total storage size
2. Implement `d` key to mark for deletion + advance
3. Implement `z` key to go back:
   - Unlimited history
   - Auto-restore if going back to deleted item
4. Add red border/overlay for marked photos
5. Add bucket counter display (when not empty)

**Deliverables:**
- Full s/d/z workflow working
- Visual feedback for marked photos
- Bucket counter visible

**Files to create/modify:**
- `PhotoTriage/Managers/DeleteBucket.swift`
- Modify `PhotoViewerView.swift`

---

## Sprint 4: Bucket View & Commit
**Goal:** Implement bucket view and commit functionality.

**Tasks:**
1. Create `BucketView.swift`:
   - Grid of thumbnails (responsive columns)
   - Red overlay on all thumbnails
   - Storage total at top
   - Click to remove from bucket
2. Implement `b` key to toggle bucket view
3. Implement `c` key to commit:
   - Confirmation dialog
   - Execute `PHAssetChangeRequest.deleteAssets()`
   - Handle errors
4. Implement `q` key to quit:
   - Prompt if bucket has items
   - Commit/Discard/Cancel options

**Deliverables:**
- Bucket view fully functional
- Can commit deletions
- Quit workflow complete

**Files to create/modify:**
- `PhotoTriage/Views/BucketView.swift`
- Modify `PhotoViewerView.swift`
- Modify `DeleteBucket.swift`

---

## Sprint 5: Session Persistence & Continue
**Goal:** Save and restore session state.

**Tasks:**
1. Create `SessionData.swift` model
2. Create `SessionManager.swift`:
   - Save current position and filters
   - Load saved session
   - Clear session
3. Update `MainMenuView.swift`:
   - Show "Continue" button when session exists
   - Load session on continue
4. Update `PhotoViewerView.swift`:
   - Save position on quit
   - Resume from saved position

**Deliverables:**
- Can quit and continue session
- Session state persists across app launches

**Files to create/modify:**
- `PhotoTriage/Models/SessionData.swift`
- `PhotoTriage/Managers/SessionManager.swift`
- Modify `MainMenuView.swift`
- Modify `PhotoViewerView.swift`

---

## Sprint 6: Filters (Album, Date, Location)
**Goal:** Implement all filter options on main menu.

**Tasks:**
1. Update `MainMenuView.swift` with filter UI:
   - Album picker dropdown
   - Date range pickers
   - Location text field
2. Update `PhotoLibraryManager.swift`:
   - Fetch albums for picker
   - Apply album filter
   - Apply date range predicate
   - Location filtering with reverse geocoding
3. Handle "No photos match" error
4. Save filters with session

**Deliverables:**
- All filters working
- Filters saved with session for Continue

**Files to modify:**
- `PhotoTriage/Views/MainMenuView.swift`
- `PhotoTriage/Managers/PhotoLibraryManager.swift`
- `PhotoTriage/Managers/SessionManager.swift`

---

## Sprint 7: Video Support
**Goal:** Add video playback support.

**Tasks:**
1. Update `ImageLoader.swift` to detect video assets
2. Create video player component in `PhotoViewerView.swift`:
   - Show first frame initially
   - Space to play/pause
   - Can delete while playing
3. Handle Live Photos as still images
4. Update bucket to show video thumbnails

**Deliverables:**
- Videos display and play correctly
- Space to play/pause works
- Can delete videos

**Files to modify:**
- `PhotoTriage/Managers/ImageLoader.swift`
- `PhotoTriage/Views/PhotoViewerView.swift`
- `PhotoTriage/Views/BucketView.swift`

---

## Sprint 8: Animations & Preloading
**Goal:** Add slide animations and preloading for smooth UX.

**Tasks:**
1. Implement slide animation:
   - Forward (s/d) slides left
   - Backward (z) slides right
2. Update `ImageLoader.swift` for preloading:
   - Preload next 3 images
   - Cancel loads for images no longer needed
   - Memory management
3. Add loading indicator for slow loads
4. Auto-skip failed loads

**Deliverables:**
- Smooth slide animations
- Fast navigation with preloading
- Graceful error handling

**Files to modify:**
- `PhotoTriage/Views/PhotoViewerView.swift`
- `PhotoTriage/Managers/ImageLoader.swift`

---

## Sprint 9: Summary & Stats
**Goal:** End-of-session summary with detailed statistics.

**Tasks:**
1. Create `SessionStats.swift` model:
   - Track kept, deleted, total
   - Track storage freed
   - Track time spent
   - Calculate photos per minute
2. Create `SummaryView.swift`:
   - Display all stats
   - "Done" button to return to menu
3. Show summary at end of session
4. Show summary after commit from quit dialog

**Deliverables:**
- Detailed end-of-session summary
- All stats tracked correctly

**Files to create/modify:**
- `PhotoTriage/Models/SessionStats.swift`
- `PhotoTriage/Views/SummaryView.swift`
- Modify `PhotoViewerView.swift`

---

## Sprint 10: Settings, Help & Polish
**Goal:** Settings view, help overlay, and final polish.

**Tasks:**
1. Create `SettingsView.swift`:
   - Toggle for metadata overlay
   - Wire up to Cmd+,
2. Create `MetadataOverlay.swift`:
   - Bottom-left corner position
   - Date, location, dimensions, file size
3. Create `HelpOverlay.swift`:
   - Show on `?` key
   - List all keyboard shortcuts
4. Window state persistence:
   - Remember size and position
5. Follow system appearance (light/dark)
6. Final testing and bug fixes

**Deliverables:**
- Complete, polished app
- All features working
- Ready for use

**Files to create/modify:**
- `PhotoTriage/Views/SettingsView.swift`
- `PhotoTriage/Views/MetadataOverlay.swift`
- `PhotoTriage/Views/HelpOverlay.swift`
- `PhotoTriage/PhotoTriageApp.swift`

---

# Sprint Log

## Instructions for Sprint Execution
After completing each sprint, update this section with:
1. **Completed:** What was actually built
2. **Deviations:** Any changes from the plan
3. **Issues:** Problems encountered and how they were resolved
4. **Context for Next Sprint:** Important details the next session needs to know

---

### Sprint 1 Log
**Status:** Complete
**Completed:**
- Created directory structure (Views/, Managers/, Models/)
- Created `SortOrder.swift` enum with newestFirst/oldestFirst cases
- Created `PhotoLibraryManager.swift` with:
  - Authorization status tracking and request
  - Album fetching (user albums + smart albums)
  - Photo/video count fetching with sort order
  - Asset fetching method for sessions
- Created `MainMenuView.swift` with:
  - Authorization status display with icon/color indicators
  - Request authorization button (when not determined)
  - Open System Settings button (when denied)
  - Photo count display
  - Sort order picker (segmented control)
  - Start Session button (placeholder for Sprint 2)
- Updated `PhotoTriageApp.swift` - removed SwiftData, uses MainMenuView with default window size
- Created `PhotoTriage.entitlements` with sandbox and photos-library access
- Deleted unused template files (ContentView.swift, Item.swift)

**Deviations:**
- None significant. Followed sprint plan as specified.

**Issues:**
- New files need to be manually added to Xcode project
- Entitlements file needs to be linked in build settings
- Info.plist key needs to be added via Xcode UI

**Context for Next Sprint:**
- `PhotoLibraryManager.fetchAssets(sortOrder:album:)` returns `PHFetchResult<PHAsset>` ready for use
- `MainMenuView` has `selectedSortOrder` state ready to pass to PhotoViewerView
- Navigation to PhotoViewerView needs to be wired up
- Sprint 2 will create ImageLoader and PhotoViewerView for displaying photos

---

### Sprint 2 Log
**Status:** Complete
**Completed:**
- Created `ImageLoader.swift` with:
  - PHImageManager-based image loading
  - Medium resolution (1600x1600) for performance
  - iCloud network access support
  - Loading state and error handling
  - Request cancellation support
- Created `PhotoViewerView.swift` with:
  - Full-window photo display on black background
  - Progress counter overlay ("47/523")
  - `s` key to advance to next photo
  - `q` key to quit and return to menu
  - Loading indicator and error states
  - End of photos message
- Updated `MainMenuView.swift`:
  - Added navigation state management
  - "Start Session" fetches assets and shows PhotoViewerView
  - Dismiss callback returns to main menu

**Deviations:**
- None significant. Followed sprint plan as specified.

**Issues:**
- None encountered.

**Context for Next Sprint:**
- PhotoViewerView has `currentIndex` state ready for history tracking
- Need to add `d` key for marking deletion and `z` key for going back
- ImageLoader is ready to be extended for preloading
- Sprint 3 will add DeleteBucket and s/d/z workflow

---

### Sprint 3 Log
**Status:** Complete
**Completed:**
- Created `DeleteBucket.swift` with:
  - In-memory storage using `Set<String>` of asset localIdentifiers
  - O(1) lookup for checking if asset is marked
  - `markForDeletion()`, `restore()`, `isMarked()`, `clear()` methods
  - `calculateTotalSize()` method using PHAssetResource
  - `@MainActor` + `@Published` for reactive UI updates
- Updated `PhotoViewerView.swift` with:
  - `@StateObject` for DeleteBucket
  - `visitedIndices` array (stack) for unlimited back navigation history
  - `currentAsset` computed property for cleaner code
  - `isCurrentMarked` computed property for checking deletion status
  - `d` key handler: marks current photo for deletion and advances
  - `z` key handler: goes back to previous photo, auto-restores if marked
  - Red border overlay (8px stroke) on marked photos
  - "Marked for deletion" indicator badge in bottom-left corner
  - Bucket counter with trash icon in top-right (only shows when not empty)
  - Updated `advanceToNext()` to push to history before advancing

**Deviations:**
- Added `restoreByIdentifier()` and `isMarkedByIdentifier()` helper methods to DeleteBucket for flexibility
- Added "Marked for deletion" text badge in addition to red border for clearer visual feedback

**Issues:**
- Initial build failed due to missing `import Combine` in DeleteBucket.swift - fixed by adding the import

**Context for Next Sprint:**
- DeleteBucket is in-memory only, does not persist across app restarts (expected)
- Sprint 4 will add BucketView grid, commit functionality (`c` key), and quit workflow improvements (`q` key with prompt)
- `deleteBucket.calculateTotalSize()` is ready for use in BucketView header
- `deleteBucket.markedAssets` provides access to all marked identifiers for BucketView grid

---

### Sprint 4 Log
**Status:** Complete
**Completed:**
- Updated `DeleteBucket.swift` with:
  - `getMarkedAssets(from:)` method to retrieve marked assets as array
  - `commitDeletions()` async method using `PHAssetChangeRequest.deleteAssets()`
- Created `BucketView.swift` with:
  - LazyVGrid with adaptive columns (150-200px thumbnails)
  - Header showing count and storage size (ByteCountFormatter)
  - Red overlay and trash icon on each thumbnail
  - Click to remove from bucket (restore)
  - `b` and Escape keys to return to photo viewer
  - Empty state with "Bucket is empty" message
  - ThumbnailView subview with async thumbnail loading (300x300)
- Updated `PhotoViewerView.swift` with:
  - `showBucketView`, `showCommitConfirmation`, `showQuitConfirmation` state
  - `b` key handler to show bucket view
  - `c` key handler to show commit confirmation (only when bucket not empty)
  - Updated `q` key handler with conditional quit confirmation
  - Two confirmation dialogs (commit and quit)
  - `commitDeletions()`, `commitAndQuit()`, `discardAndQuit()` helper functions
  - Extracted photo viewer content to `photoViewerContent` computed property

**Deviations:**
- ThumbnailView uses 300x300 size instead of 200x200 for better quality on Retina displays
- Added empty state UI for bucket view when no items marked

**Issues:**
- None encountered. Build succeeded on first attempt.

**Context for Next Sprint:**
- Bucket view and commit functionality fully working
- Sprint 5 will add session persistence (SessionData, SessionManager)
- `deleteBucket` is still in-memory only, clears on app restart
- MainMenuView will need "Continue" button for saved sessions

---

### Sprint 5 Log
**Status:** Complete
**Completed:**
- Created `SessionData.swift` model with Codable support:
  - Stores sortOrder, currentIndex, visitedIndices, markedAssets, totalAssetCount, savedAt
  - Added `Codable` conformance to `SortOrder` enum
- Created `SessionManager.swift` with:
  - UserDefaults persistence using JSON encoding
  - `saveSession()`, `loadSession()`, `clearSession()` methods
  - `hasActiveSession` and `sessionData` published properties
  - `validateSession()` method for checking if library changed
- Updated `DeleteBucket.swift`:
  - Added `restoreFromSession()` method to restore bucket from saved identifiers
- Updated `PhotoViewerView.swift`:
  - Added `sortOrder`, `sessionManager`, `initialIndex`, `initialVisitedIndices`, `initialMarkedAssets` parameters
  - Restores state (including bucket) from initial values in `.task`
  - Quit dialog now has 3 options: "Save & Quit", "Commit & Quit", "Discard & Quit"
  - "Save & Quit" preserves bucket contents for next session
  - "Discard & Quit" clears bucket but saves position
  - Clears session after commit (photos deleted, position unreliable)
- Updated `MainMenuView.swift`:
  - Added SessionManager StateObject
  - Added Continue button with progress display (e.g., "Continue (42/150)")
  - Shows bucket count below Continue button if items exist
  - `continueSession()` restores saved state including bucket contents
  - `startNewSession()` clears any existing session first

**Deviations:**
- Bucket state IS now persisted (changed from original plan based on user feedback)
- Validation behavior deferred to Sprint 6 (library change warning not yet implemented)

**Issues:**
- None. Build succeeded.

**Context for Next Sprint:**
- Session persistence is fully functional including bucket contents
- Sprint 6 will add filters (album, date, location) which should also be saved with session
- Session validation (warning when library changed) could be enhanced in future sprint
- MainMenuView now has sessionManager available for use with filters

---

### Sprint 6 Log
**Status:** Complete
**Completed:**
- Updated `SessionData.swift` with filter fields:
  - `albumIdentifier: String?` for album filter
  - `dateFrom: Date?` and `dateTo: Date?` for date range
  - `location: String?` for location filter
- Created `LocationCache.swift` with:
  - Geocoding cache persisted to UserDefaults
  - Uses `MKReverseGeocodingRequest` (macOS 26+ API)
  - `filterAssetsByLocation()` async method with progress callback
  - Rate limiting (0.1s delay every 10 assets) to avoid API limits
- Updated `PhotoLibraryManager.swift`:
  - Extended `fetchAssets()` with `dateFrom` and `dateTo` parameters
  - Added date predicate building with NSCompoundPredicate
  - Added `getAlbum(byIdentifier:)` helper method
  - Added `assetsToArray()` and `filterAssetsByLocation()` helpers
- Updated `MainMenuView.swift` with filter UI:
  - Album picker dropdown using existing `photoManager.albums`
  - Date range pickers with `OptionalDatePicker` helper view
  - Location text field for fuzzy search
  - "Clear Filters" button when filters active
  - Progress indicator during location geocoding
  - "No Photos Match" alert when filters return 0 results
  - Filters persist when continuing session
- Updated `PhotoViewerView.swift`:
  - Changed from `PHFetchResult<PHAsset>` to `[PHAsset]` array
  - Added filter parameters for session persistence
  - Session save includes all filter fields
- Updated `BucketView.swift` and `DeleteBucket.swift`:
  - Added array-based methods (`getMarkedAssetsFromArray`, `calculateTotalSizeFromArray`)

**Deviations:**
- Used `MKReverseGeocodingRequest` instead of deprecated `CLGeocoder` (macOS 26+)
- Used `MKAddress.fullAddress` for location string (simpler than individual components)
- Location filter uses full geocoded address for fuzzy matching

**Issues:**
- `CLGeocoder` is deprecated in macOS 26.0 - migrated to `MKReverseGeocodingRequest`
- `MKMapItem.placemark` is deprecated - using `MKMapItem.address.fullAddress` instead

**Context for Next Sprint:**
- All filters fully functional (album, date range, location)
- Session persistence includes all filter parameters
- Sprint 7 will add video support (space to play/pause, Live Photos as stills)

---

### Sprint 7 Log
**Status:** Complete
**Completed:**
- Updated `ImageLoader.swift` with video support:
  - Added `mediaType: PHAssetMediaType?` published property
  - Added `videoURL: URL?` published property for AVPlayer
  - Detect asset type in `loadImage(from:)` and branch to video or photo loading
  - Video loading uses `PHImageManager.requestAVAsset()` to get URL
  - First frame extraction via `AVAssetImageGenerator`
  - Added `VideoLoadError` enum for error handling
- Created `VideoPlayerView.swift`:
  - NSViewRepresentable wrapper for AVPlayerView
  - Muted by default (`player.isMuted = true`)
  - Loops continuously via `AVPlayerItemDidPlayToEndTime` notification
  - Hidden controls (`controlsStyle = .none`)
  - Play/pause controlled via `isPlaying` binding
  - Proper cleanup in `dismantleNSView`
- Updated `PhotoViewerView.swift`:
  - Added `@State private var isVideoPlaying = false`
  - Conditional rendering: VideoPlayerView for videos, Image for photos
  - Space key handler toggles `isVideoPlaying` for videos
  - `loadCurrentPhoto()` resets `isVideoPlaying = false` when navigating
- Updated `BucketView.swift`:
  - ThumbnailView now detects video assets via `asset.mediaType == .video`
  - Video indicator overlay (top-right): play icon + formatted duration
  - Duration formatted as "M:SS" from `asset.duration`

**Deviations:**
- Used `PHImageManager.requestAVAsset()` instead of `PHAssetResource` for video URL (simpler, returns AVURLAsset directly)
- Videos muted by default (per user preference)
- Videos loop continuously (per user preference)

**Issues:**
- None. Build succeeded on first attempt.

**Context for Next Sprint:**
- Video playback fully functional with Space to play/pause
- Live Photos display as still images (no special handling needed - they're `.image` type)
- Sprint 8 will add slide animations and preloading for smoother navigation

---

### Sprint 8 Log
**Status:** Complete
**Completed:**
- Updated `ImageLoader.swift` with preloading support:
  - Added `preloadCache: [String: NSImage]` for storing preloaded images by localIdentifier
  - Added `preloadRequests: [String: PHImageRequestID]` for tracking pending preload requests
  - Modified `loadImage(from:)` to check preload cache first before loading
  - Added `preloadAssets(_:)` method that preloads next N images (photos only, not videos)
  - Added `clearPreloadCache()` method to cancel pending requests and clear cache
  - Preloading respects PHImageManager cancellation and only caches high-quality (non-degraded) images
- Updated `PhotoViewerView.swift` with slide animations:
  - Added `slideDirection: Edge` state to track animation direction
  - Added `showLoadingIndicator: Bool` state for delayed loading indicator
  - Wrapped photo/video content in `Group` with `.id(currentIndex)` and `.transition()` modifiers
  - Forward navigation (s/d) uses `.trailing` direction (content slides left)
  - Backward navigation (z) uses `.leading` direction (content slides right)
  - Animation duration: 0.25 seconds with `.easeInOut` curve
  - Updated `advanceToNext()` and `goBack()` to use `withAnimation()`
- Integrated preloading in `PhotoViewerView.swift`:
  - Added `preloadNextPhotos()` helper that preloads next 3 images
  - Called from `loadCurrentPhoto()` after each navigation
  - Added `.onDisappear` modifier to clear preload cache when leaving view
- Added delayed loading indicator:
  - Loading spinner only shows after 200ms delay via `.onChange(of: imageLoader.isLoading)`
  - Prevents flashing on fast loads from preloaded cache
- Added auto-skip for failed loads:
  - `.onChange(of: imageLoader.error)` detects load failures
  - Logs error and auto-advances after 500ms delay
  - Only skips if not at last photo

**Deviations:**
- Preloading only applies to photos, not videos (videos are heavier and have different loading path)
- Used 250ms animation duration instead of 300ms for snappier feel

**Issues:**
- **Crash with video + slide animation**: "An AVPlayerItem cannot be associated with more than one instance of AVPlayer". During slide animations, SwiftUI creates two view instances simultaneously (old and new), and both tried to use the same AVPlayerItem.
  - **Fix**: Changed `ImageLoader.playerItem: AVPlayerItem` to `ImageLoader.videoAsset: AVAsset`, and updated `VideoPlayerView` to accept `AVAsset` and create its own `AVPlayerItem`. This allows each view instance to have its own player item from the shared asset.

**Context for Next Sprint:**
- Sprint 9 will add SessionStats model and SummaryView for end-of-session statistics
- Current session already tracks kept/deleted counts implicitly via bucket and position
- Need to add explicit time tracking and photos-per-minute calculation

---

### Sprint 9 Log
**Status:** Complete
**Completed:**
- Created `SessionStats.swift` model with:
  - `sessionStartTime`, `photosKept`, `photosDeleted`, `storageFreed`, `backNavigations` properties
  - Computed `totalPhotosReviewed` (kept + deleted)
  - Computed `duration` and `formattedDuration` (e.g., "12 min 34 sec")
  - Computed `photosPerMinute` rate
  - Computed `formattedStorageFreed` using ByteCountFormatter
- Created `SummaryView.swift` with:
  - Large "Session Complete" header with checkmark icon
  - StatItem component for consistent stat display
  - Stats shown: photos kept (green), photos deleted (red), total reviewed (blue)
  - Additional stats: storage freed (purple), time spent (orange), photos/min rate (yellow)
  - "Done" button with Return key shortcut to dismiss
  - Follows system appearance (light/dark mode)
- Updated `PhotoViewerView.swift`:
  - Added `sessionStats`, `showSummary`, `summaryStorageFreed` state variables
  - Added `finalStats` computed property combining stats with storage freed
  - Track `photosKept` on 's' key press
  - Track `photosDeleted` in `markForDeletionAndAdvance()`
  - Track `backNavigations` in `goBack()` and adjust `photosDeleted` when auto-restoring
  - Replaced end-of-photos message with SummaryView (triggered when `currentIndex >= assets.count`)
  - `commitAndQuit()` now shows SummaryView after committing instead of immediately dismissing

**Deviations:**
- Added `backNavigations` tracking (not in original spec but useful metric)
- Stats adjust when going back: `photosDeleted` decrements when auto-restoring a marked photo

**Issues:**
- None. Build succeeded on first attempt.

**Context for Next Sprint:**
- Sprint 10 will add Settings view (metadata toggle), MetadataOverlay, HelpOverlay, and window state persistence
- SessionStats currently resets when session is saved/resumed (stats don't persist across sessions - could enhance in future)
- SummaryView uses SF Symbols for icons which work well with system appearance

---

### Sprint 10 Log
**Status:** Not started
**Completed:**
**Deviations:**
**Issues:**
**Context for Next Sprint:**
