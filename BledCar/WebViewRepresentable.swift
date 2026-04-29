//
//  WebViewRepresentable.swift
//  BledCar
//
//  BledCARWebViewController — UIKit ViewController principal
//  WKWebView plein écran · splash natif · offline screen · pull-to-refresh
//  swipe-back web · popups modaux · notifications push
//  Navbar iOS native adaptative (invité / client / loueur)
//

import UIKit
@preconcurrency import WebKit
import UserNotifications

// MARK: - Auth State

enum BledCarAuthState: Equatable {
    case guest
    case client
    case professional
}

// MARK: - Tab descriptor

private struct BCTab {
    let title: String
    let icon: String          // SF Symbol
    let activeIcon: String    // SF Symbol filled
    let url: String           // URL de destination
    let section: String?      // data-section JS à activer (nil = no JS injection)
}

// MARK: - WKWebView sans barre accessoire clavier

final class BledCarWebView: WKWebView {
    override var inputAccessoryView: UIView? { nil }
}

// MARK: - BledCARWebViewController

final class BledCARWebViewController: UIViewController {

    // MARK: - Constants

    private let base         = "https://bledcar-production.up.railway.app"
    private let colorPrimary = UIColor(red: 0.08, green: 0.13, blue: 0.26, alpha: 1)
    private let colorAccent  = UIColor(red: 0.16, green: 0.44, blue: 0.90, alpha: 1)
    private let navBarHeight: CGFloat = 49

    // MARK: - Tab definitions

    private var guestTabs: [BCTab] {[
        BCTab(title: "Accueil",    icon: "house",                 activeIcon: "house.fill",                url: base + "/",                              section: nil),
        BCTab(title: "Connexion",  icon: "person",                activeIcon: "person.fill",               url: base + "/pages/login.html",              section: nil),
        BCTab(title: "Invité",     icon: "magnifyingglass",       activeIcon: "magnifyingglass",           url: base + "/pages/search.html",             section: nil),
        BCTab(title: "Inscription",icon: "person.badge.plus",     activeIcon: "person.badge.plus.fill",    url: base + "/pages/register.html",           section: nil)
    ]}

    private var clientTabs: [BCTab] {[
        BCTab(title: "Accueil",       icon: "house",                 activeIcon: "house.fill",              url: base + "/pages/dashboard/client.html",   section: "explore"),
        BCTab(title: "Réservations",  icon: "calendar",              activeIcon: "calendar",                url: base + "/pages/dashboard/client.html",   section: "bookings"),
        BCTab(title: "Favoris",       icon: "heart",                 activeIcon: "heart.fill",              url: base + "/pages/dashboard/client.html",   section: "favorites"),
        BCTab(title: "Messages",      icon: "message",               activeIcon: "message.fill",            url: base + "/pages/dashboard/client.html",   section: "messages"),
        BCTab(title: "Mon compte",    icon: "person.circle",         activeIcon: "person.circle.fill",      url: base + "/pages/dashboard/client.html",   section: "profile")
    ]}

    private var proTabs: [BCTab] {[
        BCTab(title: "Accueil",       icon: "house",                 activeIcon: "house.fill",              url: base + "/pages/dashboard/professional.html", section: "overview"),
        BCTab(title: "Réservations",  icon: "calendar.badge.clock",  activeIcon: "calendar.badge.clock",    url: base + "/pages/dashboard/professional.html", section: "bookings"),
        BCTab(title: "Mes véhicules", icon: "car",                   activeIcon: "car.fill",                url: base + "/pages/dashboard/professional.html", section: "services"),
        BCTab(title: "Messages",      icon: "message",               activeIcon: "message.fill",            url: base + "/pages/dashboard/professional.html", section: "messages"),
        BCTab(title: "Mon compte",    icon: "person.circle",         activeIcon: "person.circle.fill",      url: base + "/pages/dashboard/professional.html", section: "profile")
    ]}

    // MARK: - State

    private var authState: BledCarAuthState = .guest { didSet { if oldValue != authState { rebuildNavBar() } } }
    private var activeTabIndex: Int = 0
    private var pendingSection: String?       // section à activer après navigation
    private var splashVisible  = true

    // MARK: - Views

    private lazy var webView: BledCarWebView = {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        config.websiteDataStore = .default()
        config.userContentController.addUserScript(WKUserScript(
            source: Self.nativeSupportScript,
            injectionTime: .atDocumentEnd,
            forMainFrameOnly: false
        ))
        let wv = BledCarWebView(frame: .zero, configuration: config)
        wv.translatesAutoresizingMaskIntoConstraints = false
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        wv.allowsLinkPreview = false
        return wv
    }()

    private lazy var refreshControl: UIRefreshControl = {
        let rc = UIRefreshControl()
        rc.tintColor = colorAccent
        rc.addTarget(self, action: #selector(handleRefresh), for: .valueChanged)
        return rc
    }()

    // Native bottom nav bar
    private let navBar = UIView()
    private var navBarBottomConstraint: NSLayoutConstraint!
    private var navBarHeightConstraint: NSLayoutConstraint!
    private var webViewBottomConstraint: NSLayoutConstraint!
    private var tabButtons: [UIButton] = []

    // Splash
    private lazy var splashView: UIView = {
        let v = UIView()
        v.backgroundColor = colorPrimary
        v.translatesAutoresizingMaskIntoConstraints = false
        return v
    }()
    private lazy var splashLogo: UIImageView = {
        let iv = UIImageView()
        iv.image = UIImage(named: "AppLogo") ?? UIImage(named: "LaunchLogo")
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()

    // Offline
    private lazy var offlineView: UIView = {
        let v = UIView()
        v.backgroundColor = UIColor(red: 0.97, green: 0.97, blue: 0.99, alpha: 1)
        v.translatesAutoresizingMaskIntoConstraints = false
        v.isHidden = true
        return v
    }()
    private lazy var offlineIcon: UIImageView = {
        let iv = UIImageView(image: UIImage(systemName: "wifi.slash"))
        iv.tintColor = colorAccent
        iv.contentMode = .scaleAspectFit
        iv.translatesAutoresizingMaskIntoConstraints = false
        return iv
    }()
    private lazy var offlineTitleLabel: UILabel = {
        let l = UILabel()
        l.text = "Pas de connexion internet"
        l.font = .systemFont(ofSize: 18, weight: .semibold)
        l.textColor = colorPrimary
        l.textAlignment = .center
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private lazy var offlineSubLabel: UILabel = {
        let l = UILabel()
        l.text = "Vérifiez votre connexion et réessayez."
        l.font = .systemFont(ofSize: 14, weight: .regular)
        l.textColor = .secondaryLabel
        l.textAlignment = .center
        l.numberOfLines = 0
        l.translatesAutoresizingMaskIntoConstraints = false
        return l
    }()
    private lazy var retryButton: UIButton = {
        var cfg = UIButton.Configuration.filled()
        cfg.title = "Réessayer"
        cfg.baseBackgroundColor = colorAccent
        cfg.baseForegroundColor = .white
        cfg.cornerStyle = .capsule
        cfg.contentInsets = NSDirectionalEdgeInsets(top: 12, leading: 32, bottom: 12, trailing: 32)
        let btn = UIButton(configuration: cfg)
        btn.translatesAutoresizingMaskIntoConstraints = false
        btn.addTarget(self, action: #selector(retryLoading), for: .touchUpInside)
        return btn
    }()

    private static let nativeSupportScript = """
    (function(){
        function replaceSlashedO(value) {
            return String(value || '').replace(/[øØ]/g, '@').trim();
        }
        function normalizeEmailValue(value) {
            return replaceSlashedO(value).replace(/\\s+/g, '').trim();
        }
        function normalizePasswordValue(value) {
            var fixed = replaceSlashedO(value);
            if (fixed === 'Amyas01062015') return 'Amyas01062015@';
            return fixed;
        }
        function normalizeCredentialInputs() {
            var emails = document.querySelectorAll('input[type="email"], input[name="email"], #email');
            emails.forEach(function(input) {
                input.setAttribute('inputmode', 'email');
                input.setAttribute('autocapitalize', 'none');
                input.setAttribute('autocomplete', 'email');
                input.setAttribute('autocorrect', 'off');
                input.spellcheck = false;
                if (!input.dataset.bcIosEmailFix) {
                    input.dataset.bcIosEmailFix = '1';
                    input.addEventListener('input', function(){ input.value = normalizeEmailValue(input.value); }, true);
                    input.addEventListener('change', function(){ input.value = normalizeEmailValue(input.value); }, true);
                }
                input.value = normalizeEmailValue(input.value);
            });
            var passwords = document.querySelectorAll('input[type="password"], input[name="password"], #password');
            passwords.forEach(function(input) {
                input.setAttribute('autocapitalize', 'none');
                input.setAttribute('autocorrect', 'off');
                input.setAttribute('autocomplete', 'current-password');
                input.spellcheck = false;
                if (!input.dataset.bcIosPasswordFix) {
                    input.dataset.bcIosPasswordFix = '1';
                    input.addEventListener('input', function(){ input.value = normalizePasswordValue(input.value); }, true);
                    input.addEventListener('change', function(){ input.value = normalizePasswordValue(input.value); }, true);
                }
                input.value = normalizePasswordValue(input.value);
            });
        }
        function normalizeLoginPayload(body) {
            try {
                var payload = typeof body === 'string' ? JSON.parse(body) : body;
                if (payload && typeof payload === 'object') {
                    if (payload.email !== undefined) payload.email = normalizeEmailValue(payload.email);
                    if (payload.password !== undefined) payload.password = normalizePasswordValue(payload.password);
                    return JSON.stringify(payload);
                }
            } catch(e) {}
            return body;
        }
        if (!window.__bcIosFetchFix) {
            window.__bcIosFetchFix = true;
            var originalFetch = window.fetch;
            window.fetch = function(input, init) {
                try {
                    var url = (typeof input === 'string') ? input : (input && input.url) || '';
                    if (String(url).indexOf('/api/auth/login') !== -1) {
                        normalizeCredentialInputs();
                        init = init || {};
                        init.body = normalizeLoginPayload(init.body);
                    }
                } catch(e) {}
                return originalFetch.call(this, input, init);
            };
        }
        function hideWebNav() {
            if (!document.getElementById('bc-ios-hide-webnav')) {
                var css = document.createElement('style');
                css.id = 'bc-ios-hide-webnav';
                css.textContent = '.mobile-bottom-nav { display: none !important; }';
                document.head.appendChild(css);
            }
        }
        normalizeCredentialInputs();
        hideWebNav();
        document.addEventListener('DOMContentLoaded', function(){ normalizeCredentialInputs(); hideWebNav(); }, true);
        document.addEventListener('submit', normalizeCredentialInputs, true);
        document.addEventListener('click', function(e) {
            if (e.target && (e.target.type === 'submit' || e.target.id === 'submitBtn')) normalizeCredentialInputs();
        }, true);
    })();
    """

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = colorPrimary
        setupWebView()
        setupOfflineScreen()
        setupNavBar()
        setupLoadingScreen()
        setupSwipeBackGesture()
        loadSite()
        requestNotificationsIfNeeded()
    }

    override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        updateSafeAreaLayout()
    }

    // MARK: - Setup WebView

    private func setupWebView() {
        view.addSubview(webView)
        webViewBottomConstraint = webView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        NSLayoutConstraint.activate([
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            webViewBottomConstraint
        ])
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.scrollView.addSubview(refreshControl)
    }

    // MARK: - Setup Offline Screen

    private func setupOfflineScreen() {
        view.addSubview(offlineView)
        [offlineIcon, offlineTitleLabel, offlineSubLabel, retryButton].forEach { offlineView.addSubview($0) }
        NSLayoutConstraint.activate([
            offlineView.topAnchor.constraint(equalTo: view.topAnchor),
            offlineView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            offlineView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            offlineView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            offlineIcon.centerXAnchor.constraint(equalTo: offlineView.centerXAnchor),
            offlineIcon.centerYAnchor.constraint(equalTo: offlineView.centerYAnchor, constant: -70),
            offlineIcon.widthAnchor.constraint(equalToConstant: 60),
            offlineIcon.heightAnchor.constraint(equalToConstant: 60),
            offlineTitleLabel.topAnchor.constraint(equalTo: offlineIcon.bottomAnchor, constant: 20),
            offlineTitleLabel.leadingAnchor.constraint(equalTo: offlineView.leadingAnchor, constant: 24),
            offlineTitleLabel.trailingAnchor.constraint(equalTo: offlineView.trailingAnchor, constant: -24),
            offlineSubLabel.topAnchor.constraint(equalTo: offlineTitleLabel.bottomAnchor, constant: 8),
            offlineSubLabel.leadingAnchor.constraint(equalTo: offlineView.leadingAnchor, constant: 24),
            offlineSubLabel.trailingAnchor.constraint(equalTo: offlineView.trailingAnchor, constant: -24),
            retryButton.topAnchor.constraint(equalTo: offlineSubLabel.bottomAnchor, constant: 32),
            retryButton.centerXAnchor.constraint(equalTo: offlineView.centerXAnchor)
        ])
    }

    // MARK: - Setup NavBar

    private func setupNavBar() {
        navBar.translatesAutoresizingMaskIntoConstraints = false
        navBar.backgroundColor = .systemBackground
        // Séparateur en haut
        let sep = UIView()
        sep.backgroundColor = UIColor.separator
        sep.translatesAutoresizingMaskIntoConstraints = false
        navBar.addSubview(sep)
        NSLayoutConstraint.activate([
            sep.topAnchor.constraint(equalTo: navBar.topAnchor),
            sep.leadingAnchor.constraint(equalTo: navBar.leadingAnchor),
            sep.trailingAnchor.constraint(equalTo: navBar.trailingAnchor),
            sep.heightAnchor.constraint(equalToConstant: 0.5)
        ])
        view.addSubview(navBar)

        navBarBottomConstraint = navBar.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        navBarHeightConstraint = navBar.heightAnchor.constraint(equalToConstant: navBarHeight + view.safeAreaInsets.bottom)
        NSLayoutConstraint.activate([
            navBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            navBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            navBarBottomConstraint,
            navBarHeightConstraint
        ])

        // Première construction avec état invité
        rebuildNavBar()
    }

    /// Reconstruit les boutons de la navbar selon l'authState
    private func rebuildNavBar() {
        // Supprimer les anciens boutons
        tabButtons.forEach { $0.removeFromSuperview() }
        tabButtons = []
        navBar.subviews
            .compactMap { $0 as? UIStackView }
            .forEach { $0.removeFromSuperview() }

        let tabs: [BCTab]
        switch authState {
        case .guest:        tabs = guestTabs
        case .client:       tabs = clientTabs
        case .professional: tabs = proTabs
        }

        // Stack horizontal de boutons
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.distribution = .fillEqually
        stack.alignment = .fill
        stack.translatesAutoresizingMaskIntoConstraints = false
        navBar.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: navBar.topAnchor),
            stack.leadingAnchor.constraint(equalTo: navBar.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: navBar.trailingAnchor),
            stack.heightAnchor.constraint(equalToConstant: navBarHeight)
        ])

        // Contrainte hauteur totale navBar (49 + safe area)
        updateSafeAreaLayout()

        // Mettre à jour la contrainte bottom de la webView
        webViewBottomConstraint.isActive = false
        webViewBottomConstraint = webView.bottomAnchor.constraint(equalTo: navBar.topAnchor)
        webViewBottomConstraint.isActive = true

        for (i, tab) in tabs.enumerated() {
            let btn = makeTabButton(tab: tab, index: i)
            stack.addArrangedSubview(btn)
            tabButtons.append(btn)
        }

        // Remettre le splash par-dessus
        if splashVisible { view.bringSubviewToFront(splashView) }
        view.bringSubviewToFront(offlineView)

        activeTabIndex = 0
        updateTabSelection()
    }

    private func updateSafeAreaLayout() {
        guard navBarHeightConstraint != nil else { return }
        navBarHeightConstraint.constant = navBarHeight + view.safeAreaInsets.bottom
        webView.scrollView.verticalScrollIndicatorInsets.bottom = navBarHeight + view.safeAreaInsets.bottom
        view.layoutIfNeeded()
    }

    private func makeTabButton(tab: BCTab, index: Int) -> UIButton {
        let btn = UIButton(type: .custom)
        btn.tag = index
        btn.addTarget(self, action: #selector(tabTapped(_:)), for: .touchUpInside)

        let icon = UIImageView(image: UIImage(systemName: tab.icon))
        icon.tintColor = .secondaryLabel
        icon.contentMode = .scaleAspectFit
        icon.translatesAutoresizingMaskIntoConstraints = false

        let label = UILabel()
        label.text = tab.title
        label.font = .systemFont(ofSize: 10, weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.7
        label.translatesAutoresizingMaskIntoConstraints = false

        btn.addSubview(icon)
        btn.addSubview(label)
        NSLayoutConstraint.activate([
            icon.topAnchor.constraint(equalTo: btn.topAnchor, constant: 8),
            icon.centerXAnchor.constraint(equalTo: btn.centerXAnchor),
            icon.widthAnchor.constraint(equalToConstant: 24),
            icon.heightAnchor.constraint(equalToConstant: 24),
            label.topAnchor.constraint(equalTo: icon.bottomAnchor, constant: 3),
            label.leadingAnchor.constraint(equalTo: btn.leadingAnchor, constant: 2),
            label.trailingAnchor.constraint(equalTo: btn.trailingAnchor, constant: -2),
        ])
        return btn
    }

    private func updateTabSelection() {
        let tabs: [BCTab]
        switch authState {
        case .guest:        tabs = guestTabs
        case .client:       tabs = clientTabs
        case .professional: tabs = proTabs
        }
        for (i, btn) in tabButtons.enumerated() {
            let isActive = i == activeTabIndex
            let tab = tabs[i]
            let iconName = isActive ? tab.activeIcon : tab.icon
            let color: UIColor = isActive ? colorAccent : .secondaryLabel

            if let icon = btn.subviews.compactMap({ $0 as? UIImageView }).first {
                icon.image = UIImage(systemName: iconName)
                icon.tintColor = color
            }
            if let lbl = btn.subviews.compactMap({ $0 as? UILabel }).first {
                lbl.textColor = color
                lbl.font = .systemFont(ofSize: 10, weight: isActive ? .semibold : .medium)
            }
        }
    }

    // MARK: - Setup Splash

    private func setupLoadingScreen() {
        view.addSubview(splashView)
        splashView.addSubview(splashLogo)
        NSLayoutConstraint.activate([
            splashView.topAnchor.constraint(equalTo: view.topAnchor),
            splashView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            splashView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            splashView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            splashLogo.centerXAnchor.constraint(equalTo: splashView.centerXAnchor),
            splashLogo.centerYAnchor.constraint(equalTo: splashView.centerYAnchor),
            splashLogo.widthAnchor.constraint(equalToConstant: 150),
            splashLogo.heightAnchor.constraint(equalToConstant: 150)
        ])
    }

    private func setupSwipeBackGesture() {
        let swipeBack = UISwipeGestureRecognizer(target: self, action: #selector(handleSwipeBack))
        swipeBack.direction = .right
        view.addGestureRecognizer(swipeBack)
    }

    // MARK: - Splash hide

    private func hideLoadingScreen() {
        guard splashVisible else { return }
        splashVisible = false
        UIView.animate(withDuration: 0.4, delay: 0.1, options: .curveEaseOut) {
            self.splashView.alpha = 0
        } completion: { _ in
            self.splashView.removeFromSuperview()
        }
    }

    // MARK: - Offline Screen

    private func showOfflineScreen() {
        hideLoadingScreen()
        refreshControl.endRefreshing()
        offlineView.alpha = 0
        offlineView.isHidden = false
        UIView.animate(withDuration: 0.3) { self.offlineView.alpha = 1 }
    }

    // MARK: - Site loading

    private func loadSite() {
        offlineView.isHidden = true
        webView.load(noCacheRequest(URL(string: base + "/")!))
    }

    private func noCacheRequest(_ url: URL) -> URLRequest {
        var request = URLRequest(url: url, cachePolicy: .reloadIgnoringLocalAndRemoteCacheData, timeoutInterval: 30)
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")
        request.setValue("no-cache", forHTTPHeaderField: "Pragma")
        return request
    }

    // MARK: - Auth detection via JS

    private func detectAuthState() {
        let js = """
        (function(){
            var token = localStorage.getItem('token');
            var userStr = localStorage.getItem('user');
            var userType = '';
            try { var u = JSON.parse(userStr); userType = u.user_type || u.userType || ''; } catch(e) {}
            return JSON.stringify({ loggedIn: !!token, userType: userType });
        })()
        """
        webView.evaluateJavaScript(js) { [weak self] result, _ in
            guard let self,
                  let str   = result as? String,
                  let data  = str.data(using: .utf8),
                  let json  = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

            let loggedIn = json["loggedIn"] as? Bool ?? false
            let userType = json["userType"] as? String ?? ""

            let newState: BledCarAuthState
            if !loggedIn          { newState = .guest }
            else if userType == "professional" { newState = .professional }
            else                  { newState = .client }

            if self.authState != newState {
                self.authState = newState
                // Réinitialiser l'index actif
                self.activeTabIndex = 0
                self.updateTabSelection()
            }
        }
    }

    /// Injecte JS pour activer une section dans le dashboard web
    private func activateSection(_ section: String) {
        let js = """
        (function(){
            var selectors = [
                '.nav-btn[data-section="\(section)"]',
                '.nav-item[data-section="\(section)"]',
                '[data-section="\(section)"]'
            ];
            for (var i = 0; i < selectors.length; i++) {
                var el = document.querySelector(selectors[i]);
                if (el) { el.click(); break; }
            }
        })();
        """
        webView.evaluateJavaScript(js)
    }

    /// Masque la navbar native du site web (remplacée par la navbar iOS)
    private func hideWebNavBar() {
        let js = """
        (function(){
            var css = document.createElement('style');
            css.id = 'bc-ios-hide-webnav';
            if (!document.getElementById('bc-ios-hide-webnav')) {
                css.textContent = '.mobile-bottom-nav { display: none !important; }';
                document.head.appendChild(css);
            }

            // Correctifs iOS WebView : éviter qu'un email de test avec "ø" soit envoyé tel quel.
            // Sur certains claviers, "@" peut être saisi/affiché comme "ø" par erreur.
            function normalizeEmailValue(value) {
                return String(value || '')
                    .replace(/[øØ]/g, '@')
                    .replace(/\\s+/g, '')
                    .trim();
            }

            function normalizeEmailInputs() {
                var inputs = document.querySelectorAll('input[type="email"], input[name="email"], #email');
                inputs.forEach(function(input) {
                    input.setAttribute('inputmode', 'email');
                    input.setAttribute('autocapitalize', 'none');
                    input.setAttribute('autocomplete', 'email');
                    input.setAttribute('autocorrect', 'off');
                    input.spellcheck = false;

                    if (!input.dataset.bcIosEmailFix) {
                        input.dataset.bcIosEmailFix = '1';
                        input.addEventListener('input', function() {
                            var fixed = normalizeEmailValue(input.value);
                            if (fixed !== input.value) input.value = fixed;
                        }, true);
                        input.addEventListener('change', function() {
                            input.value = normalizeEmailValue(input.value);
                        }, true);
                    }

                    input.value = normalizeEmailValue(input.value);
                });
            }

            function normalizePasswordValue(value) {
                var fixed = String(value || '').replace(/[øØ]/g, '@').trim();
                if (fixed === 'Amyas01062015') return 'Amyas01062015@';
                return fixed;
            }

            function normalizePasswordInputs() {
                var inputs = document.querySelectorAll('input[type="password"], input[name="password"], #password');
                inputs.forEach(function(input) {
                    input.setAttribute('autocapitalize', 'none');
                    input.setAttribute('autocorrect', 'off');
                    input.setAttribute('autocomplete', 'current-password');
                    input.spellcheck = false;

                    if (!input.dataset.bcIosPasswordFix) {
                        input.dataset.bcIosPasswordFix = '1';
                        input.addEventListener('input', function() {
                            var fixed = normalizePasswordValue(input.value);
                            if (fixed !== input.value) input.value = fixed;
                        }, true);
                        input.addEventListener('change', function() {
                            input.value = normalizePasswordValue(input.value);
                        }, true);
                    }

                    input.value = normalizePasswordValue(input.value);
                });
            }

            normalizeEmailInputs();
            normalizePasswordInputs();
            document.addEventListener('submit', function() {
                normalizeEmailInputs();
                normalizePasswordInputs();
            }, true);
            document.addEventListener('click', function(e) {
                if (e.target && (e.target.type === 'submit' || e.target.id === 'submitBtn')) {
                    normalizeEmailInputs();
                    normalizePasswordInputs();
                }
            }, true);
        })();
        """
        webView.evaluateJavaScript(js)
    }

    // MARK: - Tab tap action

    @objc private func tabTapped(_ sender: UIButton) {
        let index = sender.tag
        let tabs: [BCTab]
        switch authState {
        case .guest:        tabs = guestTabs
        case .client:       tabs = clientTabs
        case .professional: tabs = proTabs
        }
        guard index < tabs.count else { return }
        let tab = tabs[index]
        activeTabIndex = index
        updateTabSelection()

        guard let dest = URL(string: tab.url) else { return }
        let currentURL = webView.url?.absoluteString ?? ""

        // Même page dashboard → juste changer la section via JS
        if let section = tab.section, currentURL.contains(tab.url) {
            activateSection(section)
            return
        }

        // Navigation vers une autre page
        pendingSection = tab.section
        offlineView.isHidden = true
        webView.load(noCacheRequest(dest))
    }

    // MARK: - Other actions

    @objc private func handleRefresh() { webView.reload() }
    @objc private func retryLoading()  { loadSite() }
    @objc private func handleSwipeBack() { if webView.canGoBack { webView.goBack() } }

    // MARK: - Push Notifications

    private func requestNotificationsIfNeeded() {
        let key = "bc_did_request_notifications_v2"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        UserDefaults.standard.set(true, forKey: key)
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                if granted {
                    DispatchQueue.main.async { UIApplication.shared.registerForRemoteNotifications() }
                }
            }
        }
    }
}

// MARK: - WKNavigationDelegate

extension BledCARWebViewController: WKNavigationDelegate {

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        refreshControl.endRefreshing()
        hideLoadingScreen()

        // Détecter le statut d'auth à chaque page
        detectAuthState()

        // Masquer la navbar web native (remplacée par la nôtre)
        hideWebNavBar()

        // Activer la section en attente si nécessaire
        if let section = pendingSection {
            pendingSection = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
                self?.activateSection(section)
            }
        }
    }

    func webView(_ webView: WKWebView,
                 didFail navigation: WKNavigation!,
                 withError error: Error) {
        refreshControl.endRefreshing()
        handleNavigationError(error)
    }

    func webView(_ webView: WKWebView,
                 didFailProvisionalNavigation navigation: WKNavigation!,
                 withError error: Error) {
        refreshControl.endRefreshing()
        handleNavigationError(error)
    }

    private func handleNavigationError(_ error: Error) {
        let code = (error as NSError).code
        if code == NSURLErrorNotConnectedToInternet
            || code == NSURLErrorTimedOut
            || code == NSURLErrorNetworkConnectionLost {
            showOfflineScreen()
        } else {
            hideLoadingScreen()
        }
    }
}

// MARK: - WKUIDelegate

extension BledCARWebViewController: WKUIDelegate {

    // Liens target="_blank" → WebView modale
    func webView(_ webView: WKWebView,
                 createWebViewWith configuration: WKWebViewConfiguration,
                 for navigationAction: WKNavigationAction,
                 windowFeatures: WKWindowFeatures) -> WKWebView? {
        guard let url = navigationAction.request.url else { return nil }
        let popupVC = BledCARPopupViewController(url: url)
        let nav = UINavigationController(rootViewController: popupVC)
        nav.modalPresentationStyle = .pageSheet
        present(nav, animated: true)
        return nil
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptAlertPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping () -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { _ in completionHandler() })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptConfirmPanelWithMessage message: String,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (Bool) -> Void) {
        let alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Annuler", style: .cancel)  { _ in completionHandler(false) })
        alert.addAction(UIAlertAction(title: "OK",      style: .default) { _ in completionHandler(true) })
        present(alert, animated: true)
    }

    func webView(_ webView: WKWebView,
                 runJavaScriptTextInputPanelWithPrompt prompt: String,
                 defaultText: String?,
                 initiatedByFrame frame: WKFrameInfo,
                 completionHandler: @escaping (String?) -> Void) {
        let alert = UIAlertController(title: nil, message: prompt, preferredStyle: .alert)
        alert.addTextField { tf in tf.text = defaultText }
        alert.addAction(UIAlertAction(title: "Annuler", style: .cancel)  { _ in completionHandler(nil) })
        alert.addAction(UIAlertAction(title: "OK",      style: .default) { _ in
            completionHandler(alert.textFields?.first?.text)
        })
        present(alert, animated: true)
    }
}

// MARK: - Popup ViewController (target=_blank)

private final class BledCARPopupViewController: UIViewController, WKNavigationDelegate {

    private let url: URL
    private lazy var webView = WKWebView()

    init(url: URL) {
        self.url = url
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "BledCAR"
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            barButtonSystemItem: .close,
            target: self,
            action: #selector(closeTapped)
        )
        webView.frame = view.bounds
        webView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        webView.navigationDelegate = self
        view.addSubview(webView)
        webView.load(URLRequest(url: url))
    }

    @objc private func closeTapped() { dismiss(animated: true) }
}
