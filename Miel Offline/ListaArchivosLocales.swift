//
//  ArchivosOfflineView.swift  (was: ListaArchivosLocales.swift)
//  Miel Offline
//
//  Created by Ramiro Nehuen Sanabria
//

import SwiftUI
import AVKit

// MARK: - ArchivosOfflineView

struct ArchivosOfflineView: View {
    @EnvironmentObject var gestorArchivos: GestionArchivos

    @State private var archivoSeleccionado: ArchivoLocal? = nil
    @State private var quickLookURL: URL? = nil
    @State private var mostrandoVideo   = false
    @State private var showAlert        = false
    @State private var alertMsg         = ""
    @State private var confirmarLimpiar = false

    var body: some View {
        NavigationStack {
            Group {
                if gestorArchivos.archivos.isEmpty {
                    emptyState
                } else {
                    listaArchivos
                }
            }
            .navigationTitle("Archivos Offline")
            .toolbar {
                if !gestorArchivos.archivos.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button(role: .destructive) { confirmarLimpiar = true } label: {
                            Image(systemName: "trash").foregroundStyle(.red)
                        }
                    }
                }
            }
            .refreshable { gestorArchivos.sincronizarConDisco() }
            .confirmationDialog(
                "¿Eliminar todos los archivos offline?",
                isPresented: $confirmarLimpiar,
                titleVisibility: .visible
            ) {
                Button("Eliminar todos", role: .destructive) { gestorArchivos.eliminarTodos() }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Se eliminan los archivos del dispositivo. No se puede deshacer.")
            }
            // QuickLook preview (PDF, Word, PowerPoint, Excel, TXT, etc.)
            .quickLookPreview($quickLookURL)
            // Video player sheet
            .sheet(isPresented: $mostrandoVideo) {
                if let archivo = archivoSeleccionado, let url = archivo.url {
                    VideoPlayerView(url: url, titulo: archivo.nombreOriginal)
                }
            }
            .alert("Error", isPresented: $showAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(alertMsg)
            }
        }
    }

    // MARK: - Empty State

    var emptyState: some View {
        VStack(spacing: 24) {
            Spacer()
            Image(systemName: "arrow.down.circle.dotted")
                .font(.system(size: 72))
                .foregroundStyle(.secondary)
            Text("Sin archivos descargados")
                .font(.title2.weight(.semibold))
            Text("Al tocar cualquier archivo en el Campus (PDF, Word, PowerPoint, Excel, video, etc.) se descargará aquí automáticamente.\n\nEstarán disponibles aunque no haya internet.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            Spacer()
        }
    }

    // MARK: - File List

    var listaArchivos: some View {
        List {
            // Files grouped by Materia
            ForEach(gestorArchivos.archivosPorMateria, id: \.materia) { grupo in
                Section(grupo.materia) {
                    ForEach(grupo.archivos) { archivo in
                        ArchivoFilaView(archivo: archivo) {
                            abrirArchivo(archivo)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                            Button(role: .destructive) {
                                gestorArchivos.eliminarArchivo(archivo)
                            } label: {
                                Label("Eliminar", systemImage: "trash")
                            }
                            if let url = archivo.url {
                                ShareLink(item: url) {
                                    Label("Compartir", systemImage: "square.and.arrow.up")
                                }
                                .tint(.blue)
                            }
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Actions

    func abrirArchivo(_ archivo: ArchivoLocal) {
        guard let url = archivo.url else {
            alertMsg = "El archivo no se encuentra en el dispositivo."
            showAlert = true
            return
        }
        archivoSeleccionado = archivo
        if ["mp4", "mov", "avi", "mkv"].contains(archivo.extension_) {
            mostrandoVideo = true
        } else {
            quickLookURL = url
        }
    }
}

// MARK: - File Row

struct ArchivoFilaView: View {
    let archivo: ArchivoLocal
    let onTap:   () -> Void

    var body: some View {
        HStack(spacing: 14) {
            // Icon badge
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(archivo.colorIcono.opacity(0.15))
                    .frame(width: 46, height: 46)
                Image(systemName: archivo.iconoSistema)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(archivo.colorIcono)
            }

            // File info
            VStack(alignment: .leading, spacing: 4) {
                Text(archivo.nombreOriginal.isEmpty ? archivo.nombre : archivo.nombreOriginal)
                    .font(.subheadline.weight(.medium))
                    .lineLimit(2)
                HStack(spacing: 6) {
                    Text(archivo.tamanoString)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Text(archivo.fechaDescarga, style: .relative)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            // Share button
            if let url = archivo.url {
                ShareLink(item: url) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(.blue)
                        .padding(8)
                }
                .buttonStyle(.plain)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .padding(.vertical, 2)
    }
}



// MARK: - Video Player

struct VideoPlayerView: View {
    let url: URL
    let titulo: String
    @State private var player: AVPlayer

    init(url: URL, titulo: String) {
        self.url    = url
        self.titulo = titulo
        _player = State(initialValue: AVPlayer(url: url))
    }

    var body: some View {
        NavigationStack {
            VideoPlayer(player: player)
                .ignoresSafeArea(edges: .bottom)
                .navigationTitle(titulo)
                .navigationBarTitleDisplayMode(.inline)
                .onAppear  { player.play() }
                .onDisappear { player.pause() }
        }
    }
}
