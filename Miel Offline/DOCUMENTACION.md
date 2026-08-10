//
//  GestionArchivos.swift
//  MielOffline
//
//  Created by Ramiro Nehuen Sanabria on 08/09/2025.
//

import Foundation
import SwiftUI
import QuickLook
import PDFKit

class GestionArchivos: ObservableObject {
    static let shared = GestionArchivos()
    
    @Published var archivosLocales: [URL] = []
    @Published var paginasLocales: [URL] = []
    
    let documentosURL: URL
    let carpetaArchivos: URL
    let carpetaPaginas: URL
    
    private init() {
        let fileManager = FileManager.default
        self.documentosURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        self.carpetaArchivos = documentosURL.appendingPathComponent("ArchivosOffline")
        self.carpetaPaginas = documentosURL.appendingPathComponent("PaginasOffline")
        crearCarpetasSiNoExisten()
        cargarArchivosLocales()
        cargarPaginasLocales()
    }
    
    func crearCarpetasSiNoExisten() {
        let fileManager = FileManager.default
        if !fileManager.fileExists(atPath: carpetaArchivos.path) {
            do {
                try fileManager.createDirectory(at: carpetaArchivos, withIntermediateDirectories: true, attributes: nil)
                print("Carpeta ArchivosOffline creada.")
            } catch {
                print("Error creando carpeta ArchivosOffline: \(error.localizedDescription)")
            }
        }
        if !fileManager.fileExists(atPath: carpetaPaginas.path) {
            do {
                try fileManager.createDirectory(at: carpetaPaginas, withIntermediateDirectories: true, attributes: nil)
                print("Carpeta PaginasOffline creada.")
            } catch {
                print("Error creando carpeta PaginasOffline: \(error.localizedDescription)")
            }
        }
    }
    
    func cargarArchivosLocales() {
        let fileManager = FileManager.default
        do {
            let archivos = try fileManager.contentsOfDirectory(at: carpetaArchivos, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            self.archivosLocales = archivos.filter { $0.pathExtension.lowercased() == "pdf" || $0.pathExtension.lowercased() == "docx" || $0.pathExtension.lowercased() == "doc" }
            print("Archivos locales cargados: \(archivosLocales.count)")
        } catch {
            print("Error cargando archivos locales: \(error.localizedDescription)")
        }
    }
    
    func cargarPaginasLocales() {
        let fileManager = FileManager.default
        do {
            let paginas = try fileManager.contentsOfDirectory(at: carpetaPaginas, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            self.paginasLocales = paginas.filter { $0.pathExtension.lowercased() == "html" || $0.pathExtension.lowercased() == "htm" }
            print("Páginas locales cargadas: \(paginasLocales.count)")
        } catch {
            print("Error cargando páginas locales: \(error.localizedDescription)")
        }
    }
    
    func descargarArchivo(desde link: String) {
        guard let url = URL(string: link) else {
            print("URL inválida para descargar archivo: \(link)")
            return
        }
        let nombreArchivo = url.lastPathComponent
        let destino = carpetaArchivos.appendingPathComponent(nombreArchivo)
        
        if FileManager.default.fileExists(atPath: destino.path) {
            print("El archivo ya existe localmente: \(nombreArchivo)")
            return
        }
        
        let tarea = URLSession.shared.downloadTask(with: url) { localURL, _, error in
            if let error = error {
                print("Error descargando archivo: \(error.localizedDescription)")
                return
            }
            guard let localURL = localURL else {
                print("URL local de descarga es nil")
                return
            }
            do {
                try FileManager.default.moveItem(at: localURL, to: destino)
                DispatchQueue.main.async {
                    self.archivosLocales.append(destino)
                }
                print("Archivo descargado y guardado en: \(destino.path)")
            } catch {
                print("Error moviendo archivo descargado: \(error.localizedDescription)")
            }
        }
        tarea.resume()
    }
    
    func descargarPagina(desde link: String) {
        guard let url = URL(string: link) else {
            print("URL inválida para descargar página: \(link)")
            return
        }
        let nombreArchivo = url.lastPathComponent.isEmpty ? "index.html" : url.lastPathComponent
        let nombreConHtml = nombreArchivo.hasSuffix(".html") || nombreArchivo.hasSuffix(".htm") ? nombreArchivo : nombreArchivo + ".html"
        let destino = carpetaPaginas.appendingPathComponent(nombreConHtml)
        
        if FileManager.default.fileExists(atPath: destino.path) {
            print("La página ya existe localmente: \(nombreConHtml)")
            return
        }
        
        let tarea = URLSession.shared.dataTask(with: url) { data, _, error in
            if let error = error {
                print("Error descargando página: \(error.localizedDescription)")
                return
            }
            guard let data = data else {
                print("Datos nulos al descargar página")
                return
            }
            do {
                try data.write(to: destino)
                DispatchQueue.main.async {
                    self.paginasLocales.append(destino)
                }
                print("Página descargada y guardada en: \(destino.path)")
            } catch {
                print("Error guardando página descargada: \(error.localizedDescription)")
            }
        }
        tarea.resume()
    }
}

struct VisorArchivos: UIViewControllerRepresentable {
    let url: URL
    
    func makeCoordinator() -> Coordinator {
        Coordinator(url)
    }
    
    func makeUIViewController(context: Context) -> QLPreviewController {
        let controlador = QLPreviewController()
        controlador.dataSource = context.coordinator
        return controlador
    }
    
    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {}
    
    class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL
        
        init(_ url: URL) {
            self.url = url
        }
        
        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }
        
        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as QLPreviewItem
        }
    }
}

/// SwiftUI view to display local PDF files using PDFKit.
/// Use PDFLocalView(url:) directly if QuickLook does not work properly.
struct PDFLocalView: UIViewRepresentable {
    let url: URL
    
    init(url: URL) {
        self.url = url
    }
    
    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.autoScales = true
        if let document = PDFDocument(url: url) {
            pdfView.document = document
        }
        return pdfView
    }
    
    func updateUIView(_ uiView: PDFView, context: Context) {}
}
