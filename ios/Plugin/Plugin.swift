import Foundation
import Capacitor
import CoreLocation

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitorjs.com/docs/plugins/ios
 */

@objc(PJAMMGeolocation)
public class PJAMMGeolocation: CAPPlugin, CLLocationManagerDelegate {

    @objc private var locationManager:CLLocationManager?
    @objc private var taskKey:NSInteger             = 0
    @objc private var locationCalls:[CAPPluginCall] = []
    @objc private var backgroundMode:Bool           = false
    @objc private var geoRegion:CLRegion            = nil
    @objc private var regionID:String               = "pjamm-geofence"
    
    @objc public override init!(bridge: CAPBridge!, pluginId: String!, pluginName: String!) {
        super.init(bridge: bridge, pluginId: pluginId, pluginName: pluginName);
        
        DispatchQueue.main.async {
            self.locationManager = CLLocationManager()
            self.locationManager?.delegate = self
            self.locationManager?.desiredAccuracy = kCLLocationAccuracyBest
            self.locationManager?.activityType = CLActivityType.fitness
            self.locationManager?.showsBackgroundLocationIndicator = true
            self.locationManager?.pausesLocationUpdatesAutomatically = false
            self.locationManager?.allowsBackgroundLocationUpdates = self.backgroundMode
        }
    }
    
    @objc public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {

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
            
            self.locationCalls.forEach( { call in
                call.resolve(position)
            })
            
            self.locationCalls.removeAll()
            
            self.updateGeofenceRegion(location: location)
        }
    }
    
    @objc public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("location error: " + error.localizedDescription)
    }
    
    @objc private func updateGeofenceRegion (location:CLLocation){
        let state = UIApplication.shared.applicationState
        
        if self.geoRegion != nil {
            self.locationManager?.stopMonitoring(for: self.geoRegion)
            self.geoRegion = nil
        }
        
        if self.backgroundMode == true && state != .active {
            
            self.geoRegion = CLCircularRegion(center: location.coordinate, radius: 50, identifier: self.regionID)
            self.locationManager?.startMonitoring(for: self.geoRegion)
        
        }
    }
    
    @objc private func clearAllPJAMMGeofenceReions(){
        for region:CLRegion in self.locationManager?.monitoredRegion {
            if region.identifier == self.regionID {
                self.locationManager?.stopMonitoring(for: region)
            }
        }
        
        self.geoRegion = nil
    }
    
/**
 * Capacitor Plugin Methods
 */
    
    @objc func getLocation(_ call: CAPPluginCall) {
        self.locationCalls.append(call)
        self.locationManager?.requestWhenInUseAuthorization()
        self.locationManager?.requestAlwaysAuthorization()
        self.locationManager?.requestLocation()

        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            
            if(self.locationCalls.contains(call)){
                call.reject("Error: Timeout has occured")
                self.locationCalls.removeAll(where: { $0 == call })
            }

        }
    }

    @objc func startLocation(_ call: CAPPluginCall) {
        self.locationManager?.requestWhenInUseAuthorization()
        self.locationManager?.requestAlwaysAuthorization()
        self.locationManager?.startUpdatingLocation()
    }

    @objc func stopLocation(_ call: CAPPluginCall) {
        self.locationManager?.stopUpdatingLocation()
        self.clearAllPJAMMGeofenceReions()
    }

    @objc func enableBackgroundTracking(_ call: CAPPluginCall) {
        self.backgroundMode = true
        self.locationManager?.allowsBackgroundLocationUpdates = true
    }

    @objc func disableBackgroundTracking(_ call: CAPPluginCall) {
        self.backgroundMode = false
        self.locationManager?.allowsBackgroundLocationUpdates = false
        self.clearAllPJAMMGeofenceReions()
    }

}