import Foundation
import AVFoundation
import CoreLocation
import UIKit

// MARK: - Permissions Manager
/// Centralized permissions management for the app
class PermissionsManager: NSObject, ObservableObject {
    static let shared = PermissionsManager()
    
    // Published permission states
    @Published var microphonePermission: AVAudioSession.RecordPermission = .undetermined
    @Published var locationPermission: CLAuthorizationStatus = .notDetermined
    
    private let locationManager = CLLocationManager()
    
    override init() {
        super.init()
        locationManager.delegate = self
        updatePermissionStates()
    }
    
    // MARK: - Update Permission States
    func updatePermissionStates() {
        microphonePermission = AVAudioSession.sharedInstance().recordPermission
        locationPermission = locationManager.authorizationStatus
    }
    
    // MARK: - Microphone Permissions
    /// Checks current microphone permission status
    func checkMicrophonePermission() -> AVAudioSession.RecordPermission {
        let status = AVAudioSession.sharedInstance().recordPermission
        microphonePermission = status
        return status
    }
    
    /// Requests microphone permission
    func requestMicrophonePermission() async -> Bool {
        let currentStatus = checkMicrophonePermission()
        
        switch currentStatus {
        case .granted:
            return true
        case .denied:
            // Permission was denied - user needs to go to Settings
            await MainActor.run {
                showMicrophoneSettingsAlert()
            }
            return false
        case .undetermined:
            // Request permission
            return await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    Task { @MainActor in
                        self.microphonePermission = granted ? .granted : .denied
                    }
                    continuation.resume(returning: granted)
                }
            }
        @unknown default:
            return false
        }
    }
    
    /// Opens Settings app to microphone permissions
    func openMicrophoneSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
    
    private func showMicrophoneSettingsAlert() {
        // This will be handled by the view that calls requestMicrophonePermission
        // Views should check the returned value and show appropriate alerts
    }
    
    // MARK: - Location Permissions
    /// Checks current location permission status
    func checkLocationPermission() -> CLAuthorizationStatus {
        let status = locationManager.authorizationStatus
        locationPermission = status
        return status
    }
    
    /// Requests location permission (when in use)
    func requestLocationPermission() async -> Bool {
        let currentStatus = checkLocationPermission()
        
        switch currentStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            return true
        case .denied, .restricted:
            // Permission was denied - user needs to go to Settings
            await MainActor.run {
                showLocationSettingsAlert()
            }
            return false
        case .notDetermined:
            // Request permission
            return await withCheckedContinuation { continuation in
                locationManager.requestWhenInUseAuthorization()
                // The delegate will handle the response
                // We'll use a timer to check status after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    let newStatus = self.locationManager.authorizationStatus
                    self.locationPermission = newStatus
                    continuation.resume(returning: newStatus == .authorizedWhenInUse || newStatus == .authorizedAlways)
                }
            }
        @unknown default:
            return false
        }
    }
    
    /// Opens Settings app to location permissions
    func openLocationSettings() {
        if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
            UIApplication.shared.open(settingsURL)
        }
    }
    
    private func showLocationSettingsAlert() {
        // This will be handled by the view that calls requestLocationPermission
        // Views should check the returned value and show appropriate alerts
    }
    
    // MARK: - Permission Status Helpers
    /// Returns true if microphone permission is granted
    var hasMicrophonePermission: Bool {
        return checkMicrophonePermission() == .granted
    }
    
    /// Returns true if location permission is granted
    var hasLocationPermission: Bool {
        let status = checkLocationPermission()
        return status == .authorizedWhenInUse || status == .authorizedAlways
    }
    
    /// Returns a user-friendly message for microphone permission status
    func microphonePermissionMessage() -> String {
        switch checkMicrophonePermission() {
        case .granted:
            return "Microphone access is enabled"
        case .denied:
            return "Microphone access is denied. Please enable it in Settings to record sounds."
        case .undetermined:
            return "Microphone permission is required to record sounds."
        @unknown default:
            return "Microphone permission status is unknown."
        }
    }
    
    /// Returns a user-friendly message for location permission status
    func locationPermissionMessage() -> String {
        switch checkLocationPermission() {
        case .authorizedWhenInUse, .authorizedAlways:
            return "Location access is enabled"
        case .denied:
            return "Location access is denied. You can enable it in Settings to tag your recordings with location."
        case .restricted:
            return "Location access is restricted on this device."
        case .notDetermined:
            return "Location permission is optional. It helps tag your recordings with location."
        @unknown default:
            return "Location permission status is unknown."
        }
    }
}

// MARK: - CLLocationManagerDelegate
extension PermissionsManager: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        locationPermission = manager.authorizationStatus
    }
}

