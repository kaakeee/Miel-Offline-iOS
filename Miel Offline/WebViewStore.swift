//
//  WebViewStore.swift
//  Miel Offline
//
//  Created by Ramiro Nehuen Sanabria
//

import Foundation
import WebKit
import SwiftUI

// MARK: - WebViewStore

/// Holds the single WKWebView instance for the app lifetime.
/// Acts as its own WKNavigationDelegate and WKUIDelegate to detect login/logout
/// and intercept file downloads.
class WebViewStore: NSObject, ObservableObject {

    // MARK: Published state
    @Published var estimatedProgress: Double = 0
    @Published var canGoBack: Bool = false
    @Published var canGoForward: Bool = false
    @Published var isLoading: Bool = false
    @Published var descargaEnCurso: String? = nil
    
    var ultimaMateriaSolicitada: String? = nil

    struct DuplicadoInfo {
        let url: URL
        let nombre: String
        let materia: String
    }
    @Published var archivoDuplicado: DuplicadoInfo? = nil
    @Published var quickLookURLParaAbrir: URL? = nil

    // MARK: WebView
    let webView: WKWebView

    // MARK: Weak references to other managers
    weak var sessionManager: SessionManager?
    weak var gestorArchivos: GestionArchivos?

    // KVO observers
    private var progressObserver: NSKeyValueObservation?
    private var backObserver: NSKeyValueObservation?
    private var forwardObserver: NSKeyValueObservation?
    private var loadingObserver: NSKeyValueObservation?

    private let tiposDescargables: Set<String> = [
        "pdf", "doc", "docx", "ppt", "pptx", "xls", "xlsx",
        "txt", "mp4", "mov", "avi", "zip", "rar", "png", "jpg", "jpeg"
    ]

    static let urlInicial = URL(string: "https://miel.unlam.edu.ar/principal/home/")!

    override init() {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = WKWebsiteDataStore.default() // Persistent cookies
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        // Inyecta un script que busca etiquetas <video> y agrega un botón de "Descargar Offline"
        let js = """
        function addMielDownloadButtons() {
            let materia = "General";
            let btnDropdown = document.getElementById('botonDropdownCurso');
            if (btnDropdown && btnDropdown.getAttribute('aria-label')) {
                let aria = btnDropdown.getAttribute('aria-label');
                if (aria.includes('(')) {
                    materia = aria.split('(')[0].trim();
                } else {
                    materia = aria.trim();
                }
            } else {
                let title = document.title;
                if (title && title.includes('(')) {
                    materia = title.split('(')[0].trim();
                } else {
                    let h1 = document.querySelector('h1.w3-hide-small') || document.querySelector('h1');
                    if (h1 && h1.innerText && h1.innerText.trim().length > 2) {
                        materia = h1.innerText.trim();
                    }
                }
            }

            document.querySelectorAll('a.btnDescargar').forEach(a => {
                if (!a.classList.contains('popup-mp4')) {
                    if (a.href && !a.href.includes('miel_materia')) {
                        let sep = a.href.includes('?') ? '&' : '?';
                        a.href = a.href + sep + 'miel_materia=' + encodeURIComponent(materia);
                    }
                }
            });

            let videos = document.querySelectorAll('video');
            videos.forEach(v => {
                if (!v.hasAttribute('data-miel-download-added')) {
                    v.setAttribute('data-miel-download-added', 'true');
                    let url = v.src || (v.querySelector('source') ? v.querySelector('source').src : null);
                    if (url && !url.includes('youtube') && !url.includes('vimeo') && !url.startsWith('blob:')) {
                        let vTitle = document.title.replace(/[^a-zA-Z0-9 ]/g, '').trim();
                        let h = document.querySelector('h1, h2, h3, h4');
                        if (h && h.innerText) {
                             let cleanH = h.innerText.replace(/[^a-zA-Z0-9 ]/g, '').trim();
                             if (cleanH.length > 3) vTitle = cleanH;
                        }
                        
                        let aTag = document.querySelector(`a[data-link="${url}"]`);
                        if (aTag) {
                            let tr = aTag.closest('tr');
                            if (tr) {
                                let titleTd = tr.querySelectorAll('td')[1];
                                if (titleTd) {
                                    let cleanRowTitle = titleTd.innerText.replace(/\\n/g, '').trim();
                                    if (cleanRowTitle.length > 0) {
                                        vTitle = cleanRowTitle;
                                    }
                                }
                            }
                        }

                        if (!vTitle || vTitle.toLowerCase().includes('miel') || vTitle.toLowerCase() === 'contenidos') {
                             vTitle = 'Video_Clase';
                        }
                        
                        let separator = url.includes('?') ? '&' : '?';
                        let finalUrl = url + separator + 'miel_title=' + encodeURIComponent(vTitle) + '&miel_materia=' + encodeURIComponent(materia);
                        
                        let a = document.createElement('a');
                        a.href = finalUrl;
                        a.download = vTitle + '.mp4';
                        document.body.appendChild(a);
                        a.click();
                        document.body.removeChild(a);
                    }
                }
            });
        }
        setInterval(addMielDownloadButtons, 1500);
        """
        let script = WKUserScript(source: js, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        config.userContentController.addUserScript(script)

        webView = WKWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        // Use a desktop user-agent for better MIEL compatibility
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) " +
            "AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

        super.init()

        webView.navigationDelegate = self
        webView.uiDelegate = self

        // KVO for UI state
        progressObserver = webView.observe(\.estimatedProgress, options: .new) { [weak self] wv, _ in
            DispatchQueue.main.async { self?.estimatedProgress = wv.estimatedProgress }
        }
        backObserver = webView.observe(\.canGoBack, options: .new) { [weak self] wv, _ in
            DispatchQueue.main.async { self?.canGoBack = wv.canGoBack }
        }
        forwardObserver = webView.observe(\.canGoForward, options: .new) { [weak self] wv, _ in
            DispatchQueue.main.async { self?.canGoForward = wv.canGoForward }
        }
        loadingObserver = webView.observe(\.isLoading, options: .new) { [weak self] wv, _ in
            DispatchQueue.main.async { self?.isLoading = wv.isLoading }
        }

        webView.load(URLRequest(url: WebViewStore.urlInicial))
    }

    // MARK: - Navigation Controls
    func goBack()       { webView.goBack() }
    func goForward()    { webView.goForward() }
    func reload()       { webView.reload() }
    func stopLoading()  { webView.stopLoading() }

    func navigateToHome() {
        webView.load(URLRequest(url: WebViewStore.urlInicial))
    }

    func forzarDescarga(_ dup: DuplicadoInfo) {
        let fm = FileManager.default
        let destino = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ArchivosOffline")
            .appendingPathComponent(dup.materia)
            .appendingPathComponent(dup.nombre)
        try? fm.removeItem(at: destino)
        
        let js = "let a = document.createElement('a'); a.href = '\(dup.url.absoluteString)'; a.download = '\(dup.nombre)'; document.body.appendChild(a); a.click(); document.body.removeChild(a);"
        webView.evaluateJavaScript(js)
    }

    func mostrarAlertaGlobal(titulo: String, mensaje: String, dup: DuplicadoInfo) {
        DispatchQueue.main.async {
            let alert = UIAlertController(title: titulo, message: mensaje, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "Abrir archivo", style: .default, handler: { _ in
                let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("ArchivosOffline")
                    .appendingPathComponent(dup.materia)
                    .appendingPathComponent(dup.nombre)
                self.quickLookURLParaAbrir = url
            }))
            alert.addAction(UIAlertAction(title: "Reescribir", style: .destructive, handler: { _ in
                self.forzarDescarga(dup)
            }))
            alert.addAction(UIAlertAction(title: "Cancelar", style: .cancel, handler: nil))
            
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController {
                var topVC = rootVC
                while let presented = topVC.presentedViewController {
                    topVC = presented
                }
                topVC.present(alert, animated: true)
            }
        }
    }
}

// MARK: - WKNavigationDelegate

extension WebViewStore: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url else { return }
        let urlStr = url.absoluteString

        DispatchQueue.main.async {
            self.canGoBack = webView.canGoBack
            self.canGoForward = webView.canGoForward
        }

        // — Detect authenticated/internal pages —
        let isInternal = urlStr.contains("/principal/interno")
                      || urlStr.contains("/principal/alumno")
                      || urlStr.contains("/materia/")
                      || urlStr.contains("/foro/")
                      || urlStr.contains("/contenido/")

        if isInternal, let sm = sessionManager, !sm.isLoggedIn {
            // Try to extract the username from the page
            let js = """
            (function() {
                var sels = ['.nombre', '.usuario', '[class*="nombre"]',
                            '.w3-bar-item b', 'header b', '.alumno', 'b.nombre'];
                for (var s of sels) {
                    var el = document.querySelector(s);
                    if (el && el.innerText.trim().length > 0)
                        return el.innerText.trim().split('\\n')[0].trim();
                }
                return '';
            })()
            """
            webView.evaluateJavaScript(js) { result, _ in
                let nombre = (result as? String)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                DispatchQueue.main.async { sm.setLoggedIn(nombre: nombre) }
            }
        }

        // — Detect login/logout page —
        let isHomePage = urlStr.hasSuffix("/principal/home/") || urlStr.hasSuffix("/principal/home")
        if isHomePage {
            webView.evaluateJavaScript(
                "document.querySelector('input[type=\"password\"]') !== null"
            ) { result, _ in
                if let hasForm = result as? Bool, hasForm {
                    DispatchQueue.main.async { self.sessionManager?.setLoggedOut() }
                }
            }
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        guard (error as NSError).code != NSURLErrorCancelled else { return }
    }

    /// Intercepts file downloads via URL extension
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        if let url = navigationAction.request.url,
           let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let materia = components.queryItems?.first(where: { $0.name == "miel_materia" })?.value {
            self.ultimaMateriaSolicitada = materia
        }

        if navigationAction.shouldPerformDownload {
            decisionHandler(.download)
            return
        }

        guard let url = navigationAction.request.url else {
            decisionHandler(.allow); return
        }

        let ext = url.pathExtension.lowercased()
        if tiposDescargables.contains(ext) {
            decisionHandler(.download)
            return
        }

        decisionHandler(.allow)
    }

    /// Intercepts file downloads via MIME type when viewing inline
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationResponse: WKNavigationResponse,
        decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void
    ) {
        guard let mimeType = navigationResponse.response.mimeType?.lowercased() else {
            decisionHandler(.allow)
            return
        }

        let isDownloadable = mimeType.contains("pdf") ||
                             mimeType.contains("word") ||
                             mimeType.contains("excel") ||
                             mimeType.contains("powerpoint") ||
                             mimeType.contains("zip") ||
                             mimeType.contains("rar") ||
                             mimeType.starts(with: "video/") ||
                             mimeType.starts(with: "audio/") ||
                             mimeType == "application/octet-stream"

        if isDownloadable {
            decisionHandler(.download)
        } else {
            decisionHandler(.allow)
        }
    }

    // Connect WKDownload to our delegate
    func webView(_ webView: WKWebView, navigationAction: WKNavigationAction, didBecome download: WKDownload) {
        download.delegate = self
    }

    func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
        download.delegate = self
    }
}

// MARK: - WKDownloadDelegate

extension WebViewStore: WKDownloadDelegate {
    
    func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
        let fm = FileManager.default
        guard let docs = fm.urls(for: .documentDirectory, in: .userDomainMask).first else {
            completionHandler(nil)
            return
        }
        
        var materia = self.ultimaMateriaSolicitada ?? "General"
        var finalName = suggestedFilename
        if let responseURL = response.url,
           let components = URLComponents(url: responseURL, resolvingAgainstBaseURL: false) {
            
            if let queryTitle = components.queryItems?.first(where: { $0.name == "miel_title" })?.value {
                finalName = queryTitle + ".mp4"
            }
            if let queryMateria = components.queryItems?.first(where: { $0.name == "miel_materia" })?.value {
                materia = queryMateria
            }
        }
        if finalName.isEmpty { finalName = "archivo_descargado" }
        
        let carpeta = docs.appendingPathComponent("ArchivosOffline").appendingPathComponent(materia)
        try? fm.createDirectory(at: carpeta, withIntermediateDirectories: true, attributes: nil)
        
        let destino = carpeta.appendingPathComponent(finalName)
        
        if fm.fileExists(atPath: destino.path) {
            completionHandler(nil) // Cancel the download to prevent duplicates
            
            DispatchQueue.main.async {
                let autoOpenObj = UserDefaults.standard.object(forKey: "aperturaAutomatica")
                let autoOpen = autoOpenObj != nil ? UserDefaults.standard.bool(forKey: "aperturaAutomatica") : true
                
                if autoOpen {
                    self.quickLookURLParaAbrir = destino
                } else {
                    let dupInfo = DuplicadoInfo(url: response.url ?? URL(string: "about:blank")!, nombre: finalName, materia: materia)
                    self.archivoDuplicado = dupInfo
                    self.mostrarAlertaGlobal(
                        titulo: "Archivo Duplicado",
                        mensaje: "El archivo ya fue descargado previamente. ¿Qué deseas hacer?",
                        dup: dupInfo
                    )
                }
            }
            return
        }
        
        DispatchQueue.main.async {
            withAnimation(.spring(response: 0.4)) {
                self.descargaEnCurso = finalName
            }
        }
        
        completionHandler(destino)
    }
    
    func downloadDidFinish(_ download: WKDownload) {
        DispatchQueue.main.async {
            self.gestorArchivos?.sincronizarConDisco()
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation { self.descargaEnCurso = nil }
            }
        }
    }
    
    func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
        DispatchQueue.main.async {
            withAnimation { self.descargaEnCurso = nil }
        }
        if (error as NSError).code != NSURLErrorCancelled {
            print("❌ Download failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - WKUIDelegate

extension WebViewStore: WKUIDelegate {

    /// Open target="_blank" links in the same WebView.
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if navigationAction.targetFrame == nil || !navigationAction.targetFrame!.isMainFrame {
            webView.load(navigationAction.request)
        }
        return nil
    }
}

// MARK: - SwiftUI UIViewRepresentable

/// Wraps the shared WKWebView for use in SwiftUI.
/// Always returns the same webView instance from the store.
struct WebViewRepresentable: UIViewRepresentable {
    let store: WebViewStore

    func makeUIView(context: Context) -> WKWebView {
        store.webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        // No updates needed — store manages the webView directly
    }
}
