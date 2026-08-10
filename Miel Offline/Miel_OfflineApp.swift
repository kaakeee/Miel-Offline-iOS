//
//  Miel_OfflineApp.swift
//  Miel Offline
//
//  Created by Ramiro Nehuen Sanabria on 08/09/2025.
//

import SwiftUI

@main
struct Miel_OfflineApp: App {
    @StateObject private var sessionManager = SessionManager()
    @StateObject private var gestorArchivos = GestionArchivos()
    @StateObject private var webViewStore = WebViewStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionManager)
                .environmentObject(gestorArchivos)
                .environmentObject(webViewStore)
                .onAppear {
                    // Link the WebViewStore to the other managers so it can
                    // notify them of login/logout events and trigger downloads.
                    webViewStore.sessionManager = sessionManager
                    webViewStore.gestorArchivos = gestorArchivos
                }
        }
    }
}
