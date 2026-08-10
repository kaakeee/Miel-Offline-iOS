//
//  ContentView.swift
//  Miel Offline
//
//  Created by Ramiro Nehuen Sanabria on 08/09/2025.
//

import SwiftUI
import WebKit

// MARK: - ContentView (Router)

/// Routes between LoginView and MainTabView based on session state.
/// The underlying WKWebView (in WebViewStore) always stays alive regardless
/// of which view is shown, so navigation history and cookies are preserved.
struct ContentView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var webViewStore: WebViewStore
    @EnvironmentObject var gestorArchivos: GestionArchivos

    var body: some View {
        Group {
            if sessionManager.isLoggedIn {
                MainTabView()
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
            } else {
                LoginView()
                    .transition(.asymmetric(
                        insertion: .opacity,
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            }
        }
        .animation(.easeInOut(duration: 0.35), value: sessionManager.isLoggedIn)
        .onAppear {
            // Ensure WebViewStore always has updated references
            webViewStore.sessionManager = sessionManager
            webViewStore.gestorArchivos = gestorArchivos
        }
    }
}

// MARK: - LoginView

/// Full-screen WebView shown when the user is not authenticated.
/// The user logs in normally through MIEL's login page;
/// the WebView delegate detects the successful login automatically.
struct LoginView: View {
    @EnvironmentObject var webViewStore: WebViewStore

    var body: some View {
        ZStack(alignment: .top) {
            WebViewRepresentable(store: webViewStore)
                .ignoresSafeArea()

            // Thin yellow progress bar during loading
            if webViewStore.isLoading {
                GeometryReader { geo in
                    Rectangle()
                        .fill(Color.yellow)
                        .frame(
                            width: geo.size.width * webViewStore.estimatedProgress,
                            height: 3
                        )
                        .animation(.linear(duration: 0.15), value: webViewStore.estimatedProgress)
                }
                .frame(height: 3)
                .ignoresSafeArea(edges: .top)
            }
        }
    }
}

// MARK: - Color Hex Initializer

extension Color {
    init(hex: String) {
        let scanner = Scanner(string: hex)
        var rgb: UInt64 = 0
        scanner.scanHexInt64(&rgb)
        let r = Double((rgb >> 16) & 0xFF) / 255
        let g = Double((rgb >>  8) & 0xFF) / 255
        let b = Double( rgb        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
