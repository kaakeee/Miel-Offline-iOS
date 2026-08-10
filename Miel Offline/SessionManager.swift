//
//  SessionManager.swift
//  Miel Offline
//
//  Created by Ramiro Nehuen Sanabria
//

import Foundation
import WebKit
import SwiftUI

/// Manages the user's login session state for MIEL.
/// Uses UserDefaults as a quick indicator of prior session, and WKWebsiteDataStore
/// to handle actual cookie-based authentication.
class SessionManager: ObservableObject {

    @Published var isLoggedIn: Bool
    @Published var nombreUsuario: String

    init() {
        let wasLoggedIn = UserDefaults.standard.bool(forKey: "miel_session_active")
        self.isLoggedIn = wasLoggedIn
        self.nombreUsuario = UserDefaults.standard.string(forKey: "miel_usuario") ?? ""
    }

    // MARK: - State Updates

    func setLoggedIn(nombre: String) {
        withAnimation(.easeInOut(duration: 0.3)) {
            isLoggedIn = true
        }
        UserDefaults.standard.set(true, forKey: "miel_session_active")
        guard !nombre.isEmpty else { return }
        nombreUsuario = nombre
        UserDefaults.standard.set(nombre, forKey: "miel_usuario")
    }

    func setLoggedOut() {
        withAnimation(.easeInOut(duration: 0.3)) {
            isLoggedIn = false
        }
        UserDefaults.standard.set(false, forKey: "miel_session_active")
    }

    // MARK: - Logout

    /// Clears all MIEL website data (cookies, cache) and resets session state.
    func logout(webViewStore: WebViewStore, completion: @escaping () -> Void) {
        let dataStore = WKWebsiteDataStore.default()
        let allTypes = WKWebsiteDataStore.allWebsiteDataTypes()

        dataStore.fetchDataRecords(ofTypes: allTypes) { records in
            // Only remove records related to MIEL/UNLaM
            let toRemove = records.filter {
                $0.displayName.contains("unlam") || $0.displayName.contains("miel")
            }
            let itemsToRemove = toRemove.isEmpty ? records : toRemove

            dataStore.removeData(ofTypes: allTypes, for: itemsToRemove) {
                DispatchQueue.main.async {
                    self.nombreUsuario = ""
                    UserDefaults.standard.removeObject(forKey: "miel_usuario")
                    UserDefaults.standard.set(false, forKey: "miel_session_active")
                    webViewStore.navigateToHome()
                    withAnimation(.easeInOut(duration: 0.3)) {
                        self.isLoggedIn = false
                    }
                    completion()
                }
            }
        }
    }

    // MARK: - Storage Info

    /// Returns the count and total size of downloaded files.
    var storageInfo: (archivos: Int, espacio: String) {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            return (0, "0 KB")
        }
        let carpeta = docs.appendingPathComponent("ArchivosOffline")
        let urls = (try? fm.contentsOfDirectory(
            at: carpeta,
            includingPropertiesForKeys: [.fileSizeKey],
            options: .skipsHiddenFiles
        )) ?? []

        let count = urls.count
        let bytes = urls
            .compactMap { try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize }
            .reduce(0, +)

        let espacioStr: String
        if bytes >= 1_048_576 {
            espacioStr = String(format: "%.1f MB", Double(bytes) / 1_048_576)
        } else if bytes >= 1024 {
            espacioStr = String(format: "%.0f KB", Double(bytes) / 1024)
        } else {
            espacioStr = "\(bytes) bytes"
        }
        return (count, espacioStr)
    }
}
