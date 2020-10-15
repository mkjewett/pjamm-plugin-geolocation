import Foundation
import Capacitor
import CoreLocation

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitorjs.com/docs/plugins/ios
 */
@objc(PJAMMGeolocation)
public class PJAMMGeolocation: CAPPlugin, CLLocationManagerDelegate {

    private var locationManager:CLLocationManager?

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {

        if let location = locations.last {

            let timestamp:Int64 = Int64(1000 * location.timestamp.timeIntervalSince1970)

            let position:[String:Any] = [
                "timestamp": timestamp,
                "coords": [
                    "accuracy": location.horizontalAccuracy,
                    "altitude": location.altitude,
                    "altitudeAccuracy": location.verticalAccuracy,
                    "heading":location.course,
                    "latitude":location.coordinate.latitude,
                    "longitude":location.coordinate.longitude,
                    "speed":location.speed
                ]
            ]

            self.notifyListeners("pjammLocation",data: position)

        }

    }

    @objc func startLocation(_ call: CAPPluginCall) {

        DispatchQueue.main.async {
            self.locationManager = CLLocationManager()
            self.locationManager?.requestAlwaysAuthorization()
            self.locationManager?.startUpdatingLocation()
            self.locationManager?.delegate = self
        }

        call.resolve()
    }

    @objc func stopLocation(_ call: CAPPluginCall) {
        locationManager?.stopUpdatingLocation();
        call.resolve()
    }

    @objc func enableBackgroundTracking(_ call: CAPPluginCall) {
        locationManager?.allowsBackgroundLocationUpdates = true
    }

    @objc func disableBackgroundTracking(_ call: CAPPluginCall) {
        locationManager?.allowsBackgroundLocationUpdates = false
    }

}
