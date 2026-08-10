//
//  GestionArchivos.swift
//  Miel Offline
//
//  Created by Ramiro Nehuen Sanabria on 08/09/2025.
//

import Foundation
import SwiftUI
import QuickLook
import PDFKit
import AVKit


// MARK: - ArchivoLocal Model

struct ArchivoLocal: Identifiable, Codable {
    var id: UUID = UUID()
    var nombre: String               // Actual filename on disk
    var nombreOriginal: String       // Original filename from server
    var extension_: String           // File extension (lowercase)
    var fechaDescarga: Date
    var tamano: Int64                // Bytes

    enum CodingKeys: String, CodingKey {
        case id, nombre, nombreOriginal, extension_, fechaDescarga, tamano
    }

    // MARK: Computed URL

    var url: URL? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileURL = docs
            .appendingPathComponent("ArchivosOffline")
            .appendingPathComponent(nombre)
        return FileManager.default.fileExists(atPath: fileURL.path) ? fileURL : nil
    }

    // MARK: Display helpers

    var iconoSistema: String {
        switch extension_ {
        case "pdf":                         return "doc.richtext.fill"
        case "doc", "docx":                return "doc.fill"
        case "ppt", "pptx":               return "chart.bar.doc.horizontal.fill"
        case "xls", "xlsx":               return "tablecells.fill"
        case "txt":                         return "doc.plaintext.fill"
        case "mp4", "mov", "avi", "mkv":  return "film.fill"
        case "zip", "rar", "7z":          return "archivebox.fill"
        case "png", "jpg", "jpeg", "gif": return "photo.fill"
        default:                            return "doc.fill"
        }
    }

    var colorIcono: Color {
        switch extension_ {
        case "pdf":              return .red
        case "doc", "docx":    return .blue
        case "ppt", "pptx":   return .orange
        case "xls", "xlsx":   return .green
        case "txt":             return Color(uiColor: .systemGray)
        case "mp4", "mov":    return .purple
        case "zip", "rar":    return Color(uiColor: .systemBrown)
        case "png", "jpg", "jpeg": return .teal
        default:                return .secondary
        }
    }

    var tamanoString: String {
        if tamano >= 1_048_576 {
            return String(format: "%.1f MB", Double(tamano) / 1_048_576)
        } else if tamano >= 1024 {
            return String(format: "%.0f KB", Double(tamano) / 1024)
        } else {
            return "\(tamano) bytes"
        }
    }

    var tipoLegible: String {
        switch extension_ {
        case "pdf":              return "PDF"
        case "doc", "docx":    return "Word"
        case "ppt", "pptx":   return "PowerPoint"
        case "xls", "xlsx":   return "Excel"
        case "txt":             return "Texto"
        case "mp4", "mov":    return "Video"
        case "zip", "rar":    return "Comprimido"
        case "png", "jpg", "jpeg", "gif": return "Imagen"
        default:               return extension_.uppercased()
        }
    }
}

// MARK: - GestionArchivos

class GestionArchivos: ObservableObject {

    @Published var archivos: [ArchivoLocal] = []

    let carpetaArchivos: URL
    private let metadataURL: URL

    private let tiposPermitidos: Set<String> = [
        "pdf", "doc", "docx", "ppt", "pptx", "xls", "xlsx",
        "txt", "mp4", "mov", "avi", "mkv", "zip", "rar",
        "png", "jpg", "jpeg", "gif"
    ]

    init() {
        let fm = FileManager.default
        let docs = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.carpetaArchivos = docs.appendingPathComponent("ArchivosOffline")
        self.metadataURL    = docs.appendingPathComponent("archivos_metadata.json")
        crearCarpetaSiNoExiste()
        cargarMetadata()
        sincronizarConDisco()
    }

    // MARK: - Setup

    private func crearCarpetaSiNoExiste() {
        guard !FileManager.default.fileExists(atPath: carpetaArchivos.path) else { return }
        try? FileManager.default.createDirectory(at: carpetaArchivos, withIntermediateDirectories: true)
    }

    func cargarMetadata() {
        guard let data    = try? Data(contentsOf: metadataURL),
              let decoded = try? JSONDecoder().decode([ArchivoLocal].self, from: data)
        else { return }
        archivos = decoded
    }

    func guardarMetadata() {
        guard let data = try? JSONEncoder().encode(archivos) else { return }
        try? data.write(to: metadataURL)
    }

    /// Syncs in-memory metadata with actual files on disk (handles files added externally or metadata mismatches).
    func sincronizarConDisco() {
        let fm = FileManager.default
        let keys: [URLResourceKey] = [.fileSizeKey, .creationDateKey]
        guard let urls = try? fm.contentsOfDirectory(
            at: carpetaArchivos,
            includingPropertiesForKeys: keys,
            options: .skipsHiddenFiles
        ) else { return }

        let nombresEnDisco    = Set(urls.map { $0.lastPathComponent })
        let nombresEnMetadata = Set(archivos.map { $0.nombre })

        // Remove metadata for files no longer on disk
        archivos.removeAll { !nombresEnDisco.contains($0.nombre) }

        // Add metadata for files on disk that have no metadata entry
        for url in urls {
            let nombre = url.lastPathComponent
            let ext    = url.pathExtension.lowercased()
            guard tiposPermitidos.contains(ext), !nombresEnMetadata.contains(nombre) else { continue }
            let res    = try? url.resourceValues(forKeys: Set(keys))
            let archivo = ArchivoLocal(
                nombre:          nombre,
                nombreOriginal:  nombre,
                extension_:      ext,
                fechaDescarga:   res?.creationDate ?? Date(),
                tamano:          Int64(res?.fileSize ?? 0)
            )
            archivos.append(archivo)
        }

        archivos.sort { $0.fechaDescarga > $1.fechaDescarga }
        guardarMetadata()
    }



    // MARK: - Delete

    func eliminarArchivo(_ archivo: ArchivoLocal) {
        if let url = archivo.url { try? FileManager.default.removeItem(at: url) }
        archivos.removeAll { $0.id == archivo.id }
        guardarMetadata()
    }

    func eliminarTodos() {
        archivos.forEach { if let url = $0.url { try? FileManager.default.removeItem(at: url) } }
        archivos.removeAll()
        guardarMetadata()
    }

    // MARK: - Grouping

    /// Files grouped by human-readable type, alphabetically.
    var archivosPorTipo: [(tipo: String, archivos: [ArchivoLocal])] {
        let tipos = Array(Set(archivos.map { $0.tipoLegible })).sorted()
        return tipos.compactMap { tipo in
            let lista = archivos.filter { $0.tipoLegible == tipo }
            return lista.isEmpty ? nil : (tipo: tipo, archivos: lista)
        }
    }
}

