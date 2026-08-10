//
//  MainTabView.swift
//  Miel Offline
//
//  Created by Ramiro Nehuen Sanabria
//

import SwiftUI

// MARK: - MainTabView

struct MainTabView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var webViewStore: WebViewStore
    @EnvironmentObject var gestorArchivos: GestionArchivos
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {

            // Tab 1: Campus browser
            CampusView()
                .tabItem { Label("Campus", systemImage: "globe") }
                .tag(0)

            // Tab 2: Downloaded files
            ArchivosOfflineView()
                .tabItem { Label("Archivos", systemImage: "folder.fill") }
                .tag(1)
                .badge(webViewStore.descargaEnCurso != nil ? 1 : 0)

            // Tab 3: Account & logout
            CuentaView()
                .tabItem { Label("Cuenta", systemImage: "person.fill") }
                .tag(2)
        }
        .accentColor(.yellow)
        .quickLookPreview($webViewStore.quickLookURLParaAbrir)
    }
}

// MARK: - Campus Browser View

struct CampusView: View {
    @EnvironmentObject var webViewStore: WebViewStore

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                VStack(spacing: 0) {
                    // Loading progress bar
                    if webViewStore.isLoading {
                        GeometryReader { geo in
                            Rectangle()
                                .fill(Color.yellow)
                                .frame(
                                    width: geo.size.width * webViewStore.estimatedProgress,
                                    height: 3
                                )
                                .animation(
                                    .linear(duration: 0.15),
                                    value: webViewStore.estimatedProgress
                                )
                        }
                        .frame(height: 3)
                        .transition(.opacity)
                    }

                    // The WebView fills remaining space
                    WebViewRepresentable(store: webViewStore)
                }

                // Download notification banner (overlays bottom)
                if let nombre = webViewStore.descargaEnCurso {
                    DescargaBanner(nombre: nombre)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: webViewStore.descargaEnCurso)
            .navigationTitle("Campus MIEL")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { campusToolbar }
        }
    }

    @ToolbarContentBuilder
    var campusToolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarLeading) {
            Button { webViewStore.goBack() } label: {
                Image(systemName: "chevron.left").fontWeight(.semibold)
            }
            .disabled(!webViewStore.canGoBack)

            Button { webViewStore.goForward() } label: {
                Image(systemName: "chevron.right").fontWeight(.semibold)
            }
            .disabled(!webViewStore.canGoForward)
        }

        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                webViewStore.isLoading ? webViewStore.stopLoading() : webViewStore.reload()
            } label: {
                Image(systemName: webViewStore.isLoading ? "xmark" : "arrow.clockwise")
                    .fontWeight(.semibold)
            }
        }
    }
}

// MARK: - Download Banner

struct DescargaBanner: View {
    let nombre: String

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                .scaleEffect(0.85)

            VStack(alignment: .leading, spacing: 2) {
                Text("Descargando archivo")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.85))
                Text(nombre)
                    .font(.footnote.weight(.medium))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            Spacer()

            Image(systemName: "arrow.down.circle.fill")
                .font(.title3)
                .foregroundStyle(.white.opacity(0.75))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            LinearGradient(
                colors: [Color(red: 0.1, green: 0.7, blue: 0.3), Color(red: 0.05, green: 0.55, blue: 0.25)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .shadow(color: .black.opacity(0.18), radius: 10, y: 4)
    }
}
