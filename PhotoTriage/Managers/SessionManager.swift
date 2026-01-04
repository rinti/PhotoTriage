//
//  SessionManager.swift
//  PhotoTriage
//

import Foundation
import Combine
import SwiftUI

/// Manages session state persistence using UserDefaults
@MainActor
final class SessionManager: ObservableObject {
    private static let sessionKey = "com.phototriage.savedSession"

    /// Whether there is a saved session available
    @Published private(set) var hasActiveSession: Bool = false

    /// The currently loaded session data (if any)
    @Published private(set) var sessionData: SessionData?

    init() {
        // Load session on init to set initial state
        loadSessionIfExists()
    }

    /// Save session state to UserDefaults
    func saveSession(_ data: SessionData) {
        do {
            let encoded = try JSONEncoder().encode(data)
            UserDefaults.standard.set(encoded, forKey: Self.sessionKey)
            // Update published properties safely
            // Use withAnimation(nil) to avoid potential SwiftUI update conflicts
            withAnimation(nil) {
                self.sessionData = data
                self.hasActiveSession = true
            }
        } catch {
            print("Failed to save session: \(error)")
        }
    }

    /// Load saved session from UserDefaults
    func loadSession() -> SessionData? {
        guard let data = UserDefaults.standard.data(forKey: Self.sessionKey) else {
            return nil
        }
        do {
            let session = try JSONDecoder().decode(SessionData.self, from: data)
            return session
        } catch {
            print("Failed to load session: \(error)")
            // Clear corrupted data
            clearSession()
            return nil
        }
    }

    /// Clear saved session from UserDefaults
    func clearSession() {
        UserDefaults.standard.removeObject(forKey: Self.sessionKey)
        sessionData = nil
        hasActiveSession = false
    }

    /// Load session on init and update published properties
    private func loadSessionIfExists() {
        if let session = loadSession() {
            sessionData = session
            hasActiveSession = true
        }
    }

    /// Validate saved session against current library state
    /// - Parameter currentAssetCount: The current number of assets in the library
    /// - Returns: true if counts match, false if library has changed
    func validateSession(currentAssetCount: Int) -> Bool {
        guard let session = sessionData else { return false }
        return session.totalAssetCount == currentAssetCount
    }
}
