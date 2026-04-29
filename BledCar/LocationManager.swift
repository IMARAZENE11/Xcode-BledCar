//
//  LocationManager.swift
//  BledCar
//
//  Localisation native – injecte les coordonnées dans la WebView
//  et propose un bouton "Agences proches" natif.
//

import Foundation
import CoreLocation
import Combine

@MainActor
final class LocationManager: NSObject, ObservableObject {

    // MARK: - Published

    @Published var authStatus: CLAuthorizationStatus = .notDetermined
    @Published var currentLocation: CLLocation?
    @Published var cityName: String = ""
    @Published var permissionDenied: Bool = false

    // MARK: - Private

    private let manager = CLLocationManager()
    private let geocoder = CLGeocoder()

    // MARK: - Init

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        authStatus = manager.authorizationStatus
    }

    // MARK: - Public

    func requestPermission() {
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .denied, .restricted:
            permissionDenied = true
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        @unknown default:
            break
        }
    }

    func startUpdating() {
        guard manager.authorizationStatus == .authorizedWhenInUse ||
              manager.authorizationStatus == .authorizedAlways else { return }
        manager.requestLocation()
    }

    /// Script JS à injecter dans la WebView pour fournir la localisation au site
    func locationInjectionScript() -> String? {
        guard let loc = currentLocation else { return nil }
        return """
        (function() {
            window.__nativeLocation = {
                lat: \(loc.coordinate.latitude),
                lng: \(loc.coordinate.longitude),
                city: '\(cityName.replacingOccurrences(of: "'", with: "\\'"))',
                accuracy: \(loc.horizontalAccuracy)
            };
            var ev = new CustomEvent('nativeLocationReady', { detail: window.__nativeLocation });
            document.dispatchEvent(ev);
        })();
        """
    }

    // MARK: - Private

    private func reverseGeocode(_ location: CLLocation) {
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            Task { @MainActor in
                self?.cityName = placemarks?.first?.locality ?? ""
            }
        }
    }
}

// MARK: - CLLocationManagerDelegate

extension LocationManager: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didChangeAuthorization status: CLAuthorizationStatus) {
        Task { @MainActor in
            authStatus = status
            permissionDenied = (status == .denied || status == .restricted)
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.requestLocation()
            }
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in
            currentLocation = loc
            reverseGeocode(loc)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        // Échec silencieux – la localisation est optionnelle
    }
}
