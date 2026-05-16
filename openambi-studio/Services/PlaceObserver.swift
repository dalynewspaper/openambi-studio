import Foundation
import CoreLocation
import Combine
import SwiftUI
import WeatherKit

/// Snapshot of "where you are right now" for the openambi 2.0 place chip.
///
/// The chip wants to read like a postcard caption — short, evocative,
/// always present. It combines three pieces of context:
///
/// 1. **Locality** (`Lisbon`, `Brooklyn`, `Tofino`) — reverse-geocoded
///    from the user's coarse location.
/// 2. **Local time** — derived from the device clock at render time,
///    not stored on the snapshot (it would go stale instantly).
/// 3. **Weather descriptor** — a short editorial phrase derived from
///    WeatherKit (`"sea breeze 12 km/h"`, `"light rain 9°C"`,
///    `"clear 18°C"`).
///
/// Any of the three may be missing: the chip degrades gracefully. If
/// location is denied, the chip shows only the time. If WeatherKit
/// fails (network, missing entitlement, server hiccup), the chip shows
/// place + time. Nothing is ever a hard error.
struct Place: Equatable {
    let locality: String?
    let coordinate: CLLocationCoordinate2D
    let weather: WeatherSnapshot?
    let capturedAt: Date

    static func == (lhs: Place, rhs: Place) -> Bool {
        lhs.locality == rhs.locality &&
        lhs.weather == rhs.weather &&
        abs(lhs.coordinate.latitude - rhs.coordinate.latitude) < 0.0001 &&
        abs(lhs.coordinate.longitude - rhs.coordinate.longitude) < 0.0001
    }
}

struct WeatherSnapshot: Equatable {
    let temperatureCelsius: Double
    let condition: String
    let windKmh: Double
    /// Editorial one-line descriptor, e.g. `"sea breeze 12 km/h"`.
    let descriptor: String
}

/// Observable place + weather source for the place chip.
///
/// Designed to be cheap to keep alive: location is requested once on
/// start and only refreshed if the user moves more than ~250m, weather
/// is refetched at most every 15 minutes. Holds no audio resources so
/// it's safe to instantiate as a `@StateObject` per-screen.
@MainActor
final class PlaceObserver: NSObject, ObservableObject {

    static let shared = PlaceObserver()

    @Published private(set) var place: Place?
    @Published private(set) var authorizationStatus: CLAuthorizationStatus = .notDetermined

    /// The most recent error message, suitable for log-only display.
    @Published private(set) var lastError: String?

    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    private var lastWeatherFetch: Date = .distantPast
    private var lastWeatherCoordinate: CLLocationCoordinate2D?

    override init() {
        super.init()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        locationManager.distanceFilter = 250
        authorizationStatus = locationManager.authorizationStatus
    }

    /// Kick off location + weather. Idempotent — safe to call from a view's
    /// `onAppear` every time it appears.
    func start() {
        switch authorizationStatus {
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.requestLocation()
        case .denied, .restricted:
            // Permission denied — chip will degrade to time-only.
            break
        @unknown default:
            break
        }
    }

    // MARK: - Internals

    private func handleLocation(_ location: CLLocation) {
        Task { @MainActor in
            let locality = await reverseGeocode(location)
            let weather = await refreshedWeather(for: location)

            let snapshot = Place(
                locality: locality,
                coordinate: location.coordinate,
                weather: weather,
                capturedAt: Date()
            )

            // Only publish if the snapshot actually changed — avoids
            // pointless redraws of the chip.
            if snapshot != self.place {
                self.place = snapshot
            }
        }
    }

    private func reverseGeocode(_ location: CLLocation) async -> String? {
        do {
            let placemarks = try await geocoder.reverseGeocodeLocation(location)
            guard let placemark = placemarks.first else { return nil }
            return placemark.locality
                ?? placemark.subLocality
                ?? placemark.administrativeArea
                ?? placemark.name
        } catch {
            lastError = "Geocoding: \(error.localizedDescription)"
            return nil
        }
    }

    /// Throttled WeatherKit fetch. Re-uses the last result if we asked
    /// fewer than 15 minutes ago at roughly the same coordinate.
    private func refreshedWeather(for location: CLLocation) async -> WeatherSnapshot? {
        if shouldReuseCachedWeather(for: location),
           let cached = place?.weather {
            return cached
        }

        do {
            let weather = try await WeatherService.shared.weather(for: location)
            let current = weather.currentWeather
            let descriptor = Self.descriptor(for: current)
            let snap = WeatherSnapshot(
                temperatureCelsius: current.temperature.converted(to: .celsius).value,
                condition: current.condition.description,
                windKmh: current.wind.speed.converted(to: .kilometersPerHour).value,
                descriptor: descriptor
            )
            lastWeatherFetch = Date()
            lastWeatherCoordinate = location.coordinate
            return snap
        } catch {
            lastError = "WeatherKit: \(error.localizedDescription)"
            return nil
        }
    }

    private func shouldReuseCachedWeather(for location: CLLocation) -> Bool {
        let age = Date().timeIntervalSince(lastWeatherFetch)
        guard age < 15 * 60, let prev = lastWeatherCoordinate else { return false }
        let dx = abs(prev.latitude - location.coordinate.latitude)
        let dy = abs(prev.longitude - location.coordinate.longitude)
        return dx < 0.005 && dy < 0.005
    }

    /// Editorial one-liner. Prefers an evocative phrase over a literal
    /// "Mostly Cloudy 18°C, Wind 12 km/h" weather report.
    private static func descriptor(for current: CurrentWeather) -> String {
        let tempC = Int(current.temperature.converted(to: .celsius).value.rounded())
        let windKmh = current.wind.speed.converted(to: .kilometersPerHour).value
        let condition = current.condition

        let evocative: String?
        switch condition {
        case .clear, .mostlyClear:
            evocative = windKmh > 18 ? "breeze" : "still air"
        case .partlyCloudy, .mostlyCloudy:
            evocative = "shifting light"
        case .cloudy:
            evocative = "overcast"
        case .drizzle, .rain, .freezingRain:
            evocative = "soft rain"
        case .heavyRain, .thunderstorms, .strongStorms:
            evocative = "heavy rain"
        case .snow, .heavySnow, .blowingSnow, .flurries:
            evocative = "snowfall"
        case .windy, .blowingDust:
            evocative = "strong wind"
        case .foggy, .haze:
            evocative = "fog"
        default:
            evocative = nil
        }

        let windPart = windKmh >= 8 ? " · \(Int(windKmh.rounded())) km/h" : ""
        if let evocative = evocative {
            return "\(evocative) · \(tempC)°C\(windPart)"
        }
        return "\(tempC)°C\(windPart)"
    }
}

// MARK: - CLLocationManagerDelegate

extension PlaceObserver: CLLocationManagerDelegate {

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        Task { @MainActor in handleLocation(loc) }
    }

    nonisolated func locationManager(_ manager: CLLocationManager,
                                     didFailWithError error: Error) {
        Task { @MainActor in lastError = "Location: \(error.localizedDescription)" }
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in
            self.authorizationStatus = status
            if status == .authorizedWhenInUse || status == .authorizedAlways {
                manager.requestLocation()
            }
        }
    }
}
