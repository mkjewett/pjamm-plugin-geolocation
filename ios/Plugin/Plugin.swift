import Foundation
import Capacitor
import CoreLocation

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitorjs.com/docs/plugins/ios
 */
@objc(PJAMMGeolocation)
public class PJAMMGeolocation: CAPPlugin {

    private var locationManager:CLLocationManager?

    @objc func startLocation(_ call: CAPPluginCall) {
        
        locationManager = CLLocationManager()
        locationManager?.requestAlwaysAuthorization()
        locationManager?.startUpdatingLocation()
        locationManager?.delegate = self
        
        call.resolve()
    }
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        if let location = locations.last {
            self.notifyListeners("pjammLocation",data: ["location":location])
        }
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
