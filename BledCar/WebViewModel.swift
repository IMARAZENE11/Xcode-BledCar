//
//  WebViewModel.swift
//  BledCar
//
//  Gestion de l'état de la WebView (chargement, navigation, erreurs, pont JS natif).
//

import SwiftUI
@preconcurrency import WebKit
import Combine

// MARK: - URL du site BledCar

enum BledCarURL {
    static let base         = "https://bledcar-production.up.railway.app"
    static let home         = base + "/"
    static let search       = base + "/pages/search.html"
    static let login        = base + "/pages/login.html"
    static let reservations = base + "/pages/login.html?type=client"
    static let profil       = base + "/pages/login.html"
}

// MARK: - Message reçu depuis JS

struct JSBridgeMessage {
    enum Action: String {
        case share              = "share"
        case addFavorite        = "addFavorite"
        case removeFavorite     = "removeFavorite"
        case bookingConfirmed   = "bookingConfirmed"
        case requestLocation    = "requestLocation"
        case openPhone          = "openPhone"
    }
    let action: Action
    let payload: [String: Any]
}

// MARK: - Données Calendrier

struct CalendarBooking: Equatable {
    let vehicleName: String
    let category: String
    let startDate: Date
    let endDate: Date
    let location: String
    let notes: String
}

// MARK: - Erreur de chargement

struct WebLoadingError: Identifiable {
    let id = UUID()
    let message: String
}

// MARK: - WebViewModel

@MainActor
final class WebViewModel: NSObject, ObservableObject {

    // MARK: Published properties

    @Published var isLoading: Bool         = false
    @Published var loadingProgress: Double = 0
    @Published var loadingError: WebLoadingError? = nil
    @Published var canGoBack: Bool         = false
    @Published var canGoForward: Bool      = false
    /// Déclenche la share sheet native
    @Published var shareItem: URL?         = nil
    /// Véhicule à ajouter en favori (reçu depuis JS)
    @Published var pendingFavorite: FavoriteVehicle? = nil
    /// Réservation à ajouter au Calendrier iOS
    @Published var pendingCalendar: CalendarBooking? = nil
    /// Déclenche la proposition d'activer Face ID
    @Published var didLogin: Bool = false
    @Published var currentURL: String      = ""

    // MARK: Internal web view

    let webView: BledCarWebView

    // MARK: - Init

    override init() {
        let config = WKWebViewConfiguration()
        #if os(iOS)
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        #endif

        // Cookies persistants partagés
        config.websiteDataStore = .default()

        // ── Script injecté sur chaque page ──────────────────────────────
        let nativeScript = """
        (function() {
            // 1. Viewport – bloquer zoom
            var meta = document.querySelector('meta[name="viewport"]');
            if (!meta) { meta = document.createElement('meta'); meta.name = 'viewport'; document.head.appendChild(meta); }
            meta.content = 'width=device-width, initial-scale=1.0, maximum-scale=1.0, user-scalable=no';

            // 2. Désactiver la sélection de texte
            var style = document.createElement('style');
            style.textContent = '* { -webkit-user-select: none !important; user-select: none !important; -webkit-touch-callout: none !important; }';
            document.head.appendChild(style);

            // 3. Bloquer le menu contextuel (long press)
            document.addEventListener('contextmenu', function(e) { e.preventDefault(); }, true);

            // 4. Forcer target="_blank" → même fenêtre
            document.addEventListener('click', function(e) {
                var el = e.target.closest('a');
                if (el && el.target === '_blank') { el.target = '_self'; }
            }, true);

            // 5. Safe area iOS – colle le header sous le Dynamic Island / notch
            (function() {
                var css = document.createElement('style');
                css.textContent = [
                    ':root {',
                    '  --bc-safe-top: env(safe-area-inset-top);',
                    '  --bc-header-extra-top: clamp(18px, 3.2vh, 30px);',
                    '  --bc-panel-extra-top: clamp(14px, 2.6vh, 24px);',
                    '  --bc-header-base-height: clamp(74px, 8.5vh, 86px);',
                    '  --bc-header-top-padding: calc(var(--bc-safe-top) + var(--bc-header-extra-top));',
                    '  --bc-header-total-height: calc(var(--bc-header-base-height) + var(--bc-header-top-padding));',
                    '  --bc-modern-navbar-base-height: clamp(60px, 7.2vh, 70px);',
                    '  --bc-modern-navbar-total-height: calc(var(--bc-modern-navbar-base-height) + var(--bc-header-top-padding));',
                    '  --bc-modern-panel-header-height: calc(60px + var(--bc-safe-top) + var(--bc-panel-extra-top));',
                    '}',
                    '.header-v2 {',
                    '  padding-top: var(--bc-header-top-padding) !important;',
                    '  height: var(--bc-header-total-height) !important;',
                    '}',
                    '.mobile-menu-btn, .mobile-menu-btn i, .mobile-menu-btn .fas, .mobile-menu-btn .fa-bars {',
                    '  color: #FFFFFF !important;',
                    '  opacity: 1 !important;',
                    '}',
                    '.header-v2 + .hero-v2 {',
                    '  margin-top: var(--bc-header-total-height) !important;',
                    '}',
                    'body.page-search {',
                    '  padding-top: calc(84px + var(--bc-header-top-padding)) !important;',
                    '}',
                    '.profile-hero {',
                    '  margin-top: var(--bc-header-total-height) !important;',
                    '}',
                    '.modern-navbar {',
                    '  padding-top: var(--bc-header-top-padding) !important;',
                    '  height: var(--bc-modern-navbar-total-height) !important;',
                    '}',
                    '.modern-navbar ~ .dashboard-container {',
                    '  margin-top: var(--bc-modern-navbar-total-height) !important;',
                    '}',
                    '.modern-panel-header {',
                    '  padding-top: calc(var(--bc-safe-top) + var(--bc-panel-extra-top)) !important;',
                    '  height: var(--bc-modern-panel-header-height) !important;',
                    '}'
                ].join('');
                document.head.appendChild(css);
            })();

            // 6. Pont natif – exposé au site web
            window.BledCarNative = {
                share: function(url, title) {
                    window.webkit.messageHandlers.nativeBridge.postMessage(
                        JSON.stringify({ action: 'share', url: url || location.href, title: title || document.title })
                    );
                },
                addFavorite: function(id, name, category, url) {
                    window.webkit.messageHandlers.nativeBridge.postMessage(
                        JSON.stringify({ action: 'addFavorite', id: id, name: name, category: category || '', url: url || location.href })
                    );
                },
                removeFavorite: function(id) {
                    window.webkit.messageHandlers.nativeBridge.postMessage(
                        JSON.stringify({ action: 'removeFavorite', id: id })
                    );
                },
                bookingConfirmed: function(vehicle, startDate, endDate, location, category, notes) {
                    window.webkit.messageHandlers.nativeBridge.postMessage(
                        JSON.stringify({ action: 'bookingConfirmed', vehicle: vehicle,
                            startDate: startDate, endDate: endDate,
                            location: location || '', category: category || '', notes: notes || '' })
                    );
                },
                userLoggedIn: function(email, token) {
                    window.webkit.messageHandlers.nativeBridge.postMessage(
                        JSON.stringify({ action: 'userLoggedIn', email: email || '', token: token || '' })
                    );
                },
                requestLocation: function() {
                    window.webkit.messageHandlers.nativeBridge.postMessage(
                        JSON.stringify({ action: 'requestLocation' })
                    );
                }
            };
        })();
        """
        let userScript = WKUserScript(source: nativeScript, injectionTime: .atDocumentEnd, forMainFrameOnly: false)
        config.userContentController.addUserScript(userScript)

        // ── Enregistrer le handler du pont JS ───────────────────────────
        // (le delegate sera défini après super.init)
        let controller = config.userContentController

        webView = BledCarWebView(frame: .zero, configuration: config)
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = false
        #if os(iOS)
        webView.scrollView.contentInsetAdjustmentBehavior = .never
        webView.scrollView.contentInset = .zero
        webView.scrollView.scrollIndicatorInsets = .zero
        // Désactiver le zoom pinch
        webView.scrollView.pinchGestureRecognizer?.isEnabled = false
        webView.scrollView.bouncesZoom = false
        #endif

        super.init()

        // Ajouter le message handler après super.init (self disponible)
        controller.add(WeakScriptHandler(target: self), name: "nativeBridge")

        webView.navigationDelegate = self
        webView.addObserver(self, forKeyPath: "estimatedProgress",
                            options: .new, context: nil)
        webView.addObserver(self, forKeyPath: "canGoBack",
                            options: .new, context: nil)
        webView.addObserver(self, forKeyPath: "canGoForward",
                            options: .new, context: nil)
    }

    deinit {
        MainActor.assumeIsolated {
            webView.configuration.userContentController.removeScriptMessageHandler(forName: "nativeBridge")
            webView.removeObserver(self, forKeyPath: "estimatedProgress")
            webView.removeObserver(self, forKeyPath: "canGoBack")
            webView.removeObserver(self, forKeyPath: "canGoForward")
        }
    }

    // MARK: - KVO

    nonisolated override func observeValue(forKeyPath keyPath: String?,
                                           of object: Any?,
                                           change: [NSKeyValueChangeKey: Any]?,
                                           context: UnsafeMutableRawPointer?) {
        Task { @MainActor in
            switch keyPath {
            case "estimatedProgress":
                loadingProgress = webView.estimatedProgress
            case "canGoBack":
                canGoBack = webView.canGoBack
            case "canGoForward":
                canGoForward = webView.canGoForward
            default:
                break
            }
        }
    }

    // MARK: - Navigation publique

    func loadHomeIfNeeded() {
        guard webView.url == nil else { return }
        loadHome()
    }

    func loadHome() {
        load(BledCarURL.home)
    }

    func loadSearch() {
        load(BledCarURL.search)
    }

    func loadReservations() {
        load(BledCarURL.reservations)
    }

    func loadProfil() {
        load(BledCarURL.profil)
    }

    func openLogin() {
        load(BledCarURL.login)
    }

    func reload() {
        loadingError = nil
        webView.reload()
    }

    func goBack() {
        webView.goBack()
    }

    func goForward() {
        webView.goForward()
    }

    // MARK: - Private

    private func load(_ urlString: String) {
        loadingError = nil
        guard let url = URL(string: urlString) else { return }
        let request = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad,
                                 timeoutInterval: 30)
        webView.load(request)
    }
}

// MARK: - WKNavigationDelegate

extension WebViewModel: WKNavigationDelegate {

    // Intercepte toutes les navigations – jamais Safari
    func webView(_ webView: WKWebView,
                 decidePolicyFor navigationAction: WKNavigationAction,
                 decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        let url = navigationAction.request.url
        let scheme = url?.scheme?.lowercased() ?? ""
        // Tél, mail, sms → app native correspondante
        if scheme == "tel" || scheme == "mailto" || scheme == "sms" {
            if let url {
                #if os(iOS)
                Task { @MainActor in UIApplication.shared.open(url) }
                #endif
            }
            decisionHandler(.cancel)
            return
        }
        // Tout http/https reste dans la WebView
        decisionHandler(.allow)
    }

    nonisolated func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        Task { @MainActor in
            isLoading    = true
            loadingError = nil
        }
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        Task { @MainActor in
            isLoading       = false
            loadingProgress = 1.0
            currentURL      = webView.url?.absoluteString ?? ""
        }
    }

    nonisolated func webView(_ webView: WKWebView,
                              didFail navigation: WKNavigation!,
                              withError error: Error) {
        Task { @MainActor in
            isLoading    = false
            let nsError  = error as NSError
            if nsError.code != NSURLErrorCancelled {
                loadingError = WebLoadingError(message: error.localizedDescription)
            }
        }
    }

    nonisolated func webView(_ webView: WKWebView,
                              didFailProvisionalNavigation navigation: WKNavigation!,
                              withError error: Error) {
        Task { @MainActor in
            isLoading    = false
            let nsError  = error as NSError
            if nsError.code != NSURLErrorCancelled {
                loadingError = WebLoadingError(message: "Impossible de charger la page. Vérifiez votre connexion.")
            }
        }
    }
}

// MARK: - Pont JS → Natif (WKScriptMessageHandler)

extension WebViewModel: WKScriptMessageHandler {

    func userContentController(_ userContentController: WKUserContentController,
                                            didReceive message: WKScriptMessage) {
        guard message.name == "nativeBridge",
              let body = message.body as? String,
              let data = body.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let actionStr = json["action"] as? String else { return }

        Task { @MainActor in
            switch actionStr {

            case "share":
                let urlStr = json["url"] as? String ?? BledCarURL.home
                shareItem = URL(string: urlStr)

            case "addFavorite":
                let id       = json["id"] as? String ?? (json["url"] as? String ?? BledCarURL.home)
                let name     = json["name"] as? String ?? "Véhicule"
                let category = json["category"] as? String ?? ""
                let url      = json["url"] as? String ?? BledCarURL.home
                let vehicle  = FavoriteVehicle(id: id, name: name, category: category, url: url)
                FavoritesManager.shared.add(vehicle)

            case "removeFavorite":
                if let id = json["id"] as? String {
                    FavoritesManager.shared.remove(id: id)
                }

            case "bookingConfirmed":
                let vehicleName = json["vehicle"] as? String ?? "votre véhicule"
                let category    = json["category"] as? String ?? ""
                let location    = json["location"] as? String ?? ""
                let notes       = json["notes"] as? String ?? ""
                let now         = Date()
                // Dates depuis le JS (timestamps ISO ou secondes)
                let startDate: Date
                let endDate: Date
                if let sStr = json["startDate"] as? String,
                   let d = ISO8601DateFormatter().date(from: sStr) { startDate = d }
                else { startDate = now.addingTimeInterval(86_400) }
                if let eStr = json["endDate"] as? String,
                   let d = ISO8601DateFormatter().date(from: eStr) { endDate = d }
                else { endDate = startDate.addingTimeInterval(86_400) }
                // Proposer d'ajouter au Calendrier
                pendingCalendar = CalendarBooking(
                    vehicleName: vehicleName, category: category,
                    startDate: startDate, endDate: endDate,
                    location: location, notes: notes)
                // Rappel natif
                NotificationManager.shared.scheduleBookingReminder(
                    vehicleName: vehicleName,
                    date: startDate,
                    isDelivery: false
                )

            case "userLoggedIn":
                // Stocker token dans Keychain + proposer Face ID
                if let token = json["token"] as? String, !token.isEmpty {
                    BiometricManager.shared.saveToken(token)
                }
                if let email = json["email"] as? String, !email.isEmpty {
                    BiometricManager.shared.saveEmail(email)
                }
                didLogin = true

            case "requestLocation":
                LocationManager().requestPermission()

            default:
                break
            }
        }
    }
}

// MARK: - WeakScriptHandler (évite retain cycle)

/// Wrapper léger pour éviter que WKUserContentController retienne WebViewModel
final class WeakScriptHandler: NSObject, WKScriptMessageHandler {
    weak var target: (NSObject & WKScriptMessageHandler)?
    init(target: NSObject & WKScriptMessageHandler) { self.target = target }

    func userContentController(_ userContentController: WKUserContentController,
                                didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
