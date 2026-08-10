//
//  CuentaView.swift  (was: MateriasStore.swift)
//  Miel Offline
//
//  Created by Ramiro Nehuen Sanabria
//

import SwiftUI

// MARK: - CuentaView

struct CuentaView: View {
    @EnvironmentObject var sessionManager: SessionManager
    @EnvironmentObject var webViewStore:   WebViewStore
    @EnvironmentObject var gestorArchivos: GestionArchivos

    @AppStorage("aperturaAutomatica") private var aperturaAutomatica = true
    
    @State private var confirmarLogout = false
    @State private var cerrandoSesion  = false

    var body: some View {
        NavigationStack {
            List {

                // ─── Profile ───────────────────────────────────────────
                Section {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.yellow.opacity(0.2))
                                .frame(width: 66, height: 66)
                            Image(systemName: "person.fill")
                                .font(.system(size: 32))
                                .foregroundStyle(Color.yellow)
                        }
                        VStack(alignment: .leading, spacing: 5) {
                            Text(sessionManager.nombreUsuario.isEmpty
                                 ? "Usuario MIEL"
                                 : sessionManager.nombreUsuario)
                                .font(.headline)
                                .lineLimit(2)
                            Text("UNLaM · MIEL")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 6)
                }

                // ─── Storage ───────────────────────────────────────────
                Section("Almacenamiento Offline") {
                    let info = sessionManager.storageInfo

                    LabeledContent {
                        Text("\(info.archivos)")
                    } label: {
                        Label("Archivos guardados", systemImage: "doc.fill")
                    }

                    LabeledContent {
                        Text(info.espacio)
                    } label: {
                        Label("Espacio utilizado", systemImage: "internaldrive.fill")
                    }

                    Toggle(isOn: $aperturaAutomatica) {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Apertura automática", systemImage: "arrow.up.forward.app.fill")
                            Text("Abre los archivos si ya fueron descargados")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)

                    NavigationLink {
                        ArchivosOfflineView()
                    } label: {
                        Label("Ver todos los archivos", systemImage: "folder.fill")
                    }
                }

                // ─── App Info ──────────────────────────────────────────
                Section("Información") {
                    LabeledContent("Versión") {
                        Text(
                            Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                        )
                        .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Label("Archivos disponibles offline", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                            .font(.subheadline.weight(.medium))

                        Text("Los archivos descargados también aparecen en la app Archivos de iOS bajo \"En mi iPhone → Miel Offline\".")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // ─── Logout ────────────────────────────────────────────
                Section {
                    Button(role: .destructive) {
                        confirmarLogout = true
                    } label: {
                        HStack(spacing: 10) {
                            if cerrandoSesion {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .red))
                                    .scaleEffect(0.85)
                            } else {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                            }
                            Text(cerrandoSesion ? "Cerrando sesión..." : "Cerrar Sesión")
                        }
                    }
                    .disabled(cerrandoSesion)
                }
            }
            .navigationTitle("Mi Cuenta")
            .confirmationDialog(
                "¿Cerrar sesión?",
                isPresented: $confirmarLogout,
                titleVisibility: .visible
            ) {
                Button("Cerrar Sesión", role: .destructive) { cerrarSesion() }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Se cerrará tu sesión en MIEL. Los archivos descargados se mantienen en tu dispositivo.")
            }
        }
    }

    private func cerrarSesion() {
        cerrandoSesion = true
        sessionManager.logout(webViewStore: webViewStore) {
            cerrandoSesion = false
        }
    }
}
