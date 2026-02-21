# PhotoTriage

PhotoTriage is a native macOS SwiftUI app for quickly triaging your Photos library with keyboard-first controls.

You can review photos/videos one-by-one, keep items you want, mark unwanted items for deletion in a bucket, and commit deletions in batches through PhotoKit.

## What It Does

- Reviews both photos and videos from your Photos library.
- Supports filtered sessions by:
  - sort order (`Newest First` / `Oldest First`)
  - album
  - date range
  - location text search (fuzzy match against reverse-geocoded locations)
- Uses fast keyboard controls for triage (`s`, `d`, `z`, `b`, `c`, `q`, `?`, `Space`).
- Saves in-progress sessions so you can continue later.
- Shows an end-of-session summary (kept/deleted/reviewed/time/rate/storage freed).
- Lets you optionally show metadata overlay (date, location, dimensions, file size).

## Platform and Requirements

- macOS app (SwiftUI + AppKit interop), not iOS.
- Minimum deployment target: `macOS 26.0` (per `PhotoTriage.xcodeproj`).
- Xcode with a macOS SDK that supports this deployment target.
- Photos permission granted at runtime.

## Getting Started

### 1. Open in Xcode

Open `PhotoTriage.xcodeproj`, select the `PhotoTriage` scheme, then Run.

### 2. Grant Photos Access

On first launch, grant Photos access when prompted.

If previously denied, use the app button to open System Settings and re-enable access.

### 3. Start a Session

From the main menu:

- choose optional filters
- click `Start New Session`
- or click `Continue` if a saved session exists

## Usage

### Triage Controls

In the viewer:

- `S`: Keep current item, advance
- `D`: Mark for deletion, advance
- `Z`: Go back to previous item (history stack)
- `B`: Open bucket view
- `C`: Commit all marked deletions (with confirmation)
- `Q`: Quit session (`Save & Quit` / `Commit & Quit` / `Cancel`)
- `?`: Toggle keyboard help overlay
- `Space`: Play/pause current video

### Bucket View

- Shows all currently marked items in a thumbnail grid.
- Click a thumbnail to restore (remove from bucket).
- Press `B` or `Esc` to return to the viewer.

### Filters

- Album + date filters are applied with PhotoKit fetch options.
- Location filter geocodes assets and performs case-insensitive fuzzy text matching.
- Location filtering can be slow on first run because reverse geocoding is rate-limited and cached.

### Settings

Use macOS app settings (`Settings...`) to:

- toggle metadata overlay in the viewer
- clear all permanently skipped items

## Data and Privacy Behavior

- Photos are deleted through `PHAssetChangeRequest.deleteAssets`, which moves them to **Recently Deleted**.
- Session state and caches are stored in `UserDefaults` (session, skipped IDs, location cache).
- `S` (keep) permanently skips that asset from future sessions until skipped items are cleared in Settings.
- The app never uploads your photo data itself; it operates through system Photos APIs.

## Project Structure

```text
PhotoTriage/
├── PhotoTriageApp.swift
├── Managers/
│   ├── DeleteBucket.swift
│   ├── ImageLoader.swift
│   ├── LocationCache.swift
│   ├── PhotoLibraryManager.swift
│   ├── SessionManager.swift
│   └── SkippedPhotosManager.swift
├── Models/
│   ├── SessionData.swift
│   ├── SessionStats.swift
│   └── SortOrder.swift
└── Views/
    ├── BucketView.swift
    ├── HelpOverlay.swift
    ├── MainMenuView.swift
    ├── MetadataOverlay.swift
    ├── PhotoViewerView.swift
    ├── SettingsView.swift
    ├── SummaryView.swift
    └── VideoPlayerView.swift
```

## Development

### Build (CLI)

```bash
xcodebuild -project PhotoTriage.xcodeproj -scheme PhotoTriage -destination 'platform=macOS' build
```

### Test (CLI)

```bash
xcodebuild -project PhotoTriage.xcodeproj -scheme PhotoTriage -destination 'platform=macOS' test
```

Note: the current test targets are Xcode template placeholders and do not yet cover app behavior.

## Known Limitations

- This project currently depends on modern platform APIs (for example, reverse geocoding APIs available in newer macOS SDKs).
- Session validation against library changes exists in `SessionManager` but is not currently enforced in the main flow.
