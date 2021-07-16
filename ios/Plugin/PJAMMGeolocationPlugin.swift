import Foundation
import Capacitor
import CoreLocation

/**
 * Please read the Capacitor iOS Plugin Development Guide
 * here: https://capacitorjs.com/docs/plugins/ios
 */

@objc enum PauseLevel : Int {
    case none
    case initial
    case secondary
    case final
}


@objc(PJAMMGeolocationPlugin)
public class PJAMMGeolocationPlugin: CAPPlugin {
    private let implementation = PJAMMGeolocation()

    @objc private var locationManager:CLLocationManager?
    @objc private var notificationCenter:UNUserNotificationCenter?
    
    @objc private var locationCalls:[CAPPluginCall] = []
    @objc private var backgroundMode:Bool           = false
    @objc private var locationPaused:PauseLevel     = .none
    @objc private var locationStarted:Bool          = false
    
    @objc private var activityType:CLActivityType   = .automotiveNavigation
    
    @objc private var resumeDate:Date               = Date()
    @objc private var resumeWatchOk:Bool            = false
    @objc private var movementLocation:CLLocation?  = nil
    @objc private var lastWatchSend:Date            = Date()
    
    @objc private var geoRegionRelaunch:CLRegion?   = nil
    @objc private var geoRegionResume:CLRegion?     = nil
    @objc private var geoRelaunchID:String          = "pjamm-geofence-relaunch"
    @objc private var geoResumeID:String            = "pjamm-geofence-resume"
    
    @objc public override func load() {
    
        print("PJAMMGeo - Plugin Load")
        
        DispatchQueue.main.async {
            if self.locationManager == nil {
                self.launchLocationManager()
            }
            
            if self.notificationCenter == nil {
                self.launchNotificationCenter()
            }
        }
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.didFinishLaunching(notification:)), name: UIApplication.didFinishLaunchingNotification, object: nil)
        
        NotificationCenter.default.addObserver(self, selector: #selector(self.didBecomeActive(notification:)), name: UIApplication.didBecomeActiveNotification, object: nil)
        
    }
    
    @objc public func didFinishLaunching(notification:Notification){
        
        if let userInfo = notification.userInfo {
            
            if userInfo.keys.contains(UIApplication.LaunchOptionsKey.location) {
                // App Launched due to Location Event
            }
        }
        
        DispatchQueue.main.async {
            if self.locationManager == nil {
                self.launchLocationManager()
            }

            if self.notificationCenter == nil {
                self.launchNotificationCenter()
            }
        }
    }
    
    @objc public func didBecomeActive(notification:Notification){
        if self.locationPaused != .none && self.locationStarted {
            self.resumeLocationUpdates()
        }
    }
    
    @objc private func launchLocationManager() {
        self.locationManager = CLLocationManager()
        self.locationManager?.delegate = self
        self.locationManager?.activityType = self.activityType
        self.locationManager?.showsBackgroundLocationIndicator = true
        self.locationManager?.pausesLocationUpdatesAutomatically = true
        self.locationManager?.allowsBackgroundLocationUpdates = self.backgroundMode
        
        self.setDesiredLocationAccuracy()
    }
    
    @objc private func launchNotificationCenter() {
        self.notificationCenter = UNUserNotificationCenter.current()
        self.notificationCenter?.delegate = self
        
        let options:UNAuthorizationOptions = [.alert, .sound]
        
        self.notificationCenter?.requestAuthorization(options: options) { (granted, error) in
            
            if !granted {
                print("PJAMMGeo - Notification Permission not granted")
            }
            
        }
    }
    
    @objc public func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        completionHandler(.alert)
    }
    
    @objc private func sendNotification(title:String, body:String, identifier:String, delay:TimeInterval = 1){
        
        let content = UNMutableNotificationContent()
        content.title   = title
        content.body    = body
        content.sound   = UNNotificationSound.default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        
        self.notificationCenter?.add(request, withCompletionHandler: {(error) in
            if error != nil {
                print("PJAMMGeo - Error adding notification with identifier: \(identifier)")
            }
        })
    }
    
    @objc public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        
        if self.lastWatchSend.timeIntervalSinceNow > -0.5 {
            return
        }

        if let location = locations.last {
            
            let position = self.convertLocationToPosition(location: location)

            if locationPaused == .none {
                
                if !self.resumeWatchOk && location.horizontalAccuracy < 20 {
                    self.resumeWatchOk = true
                }
                
                if !self.resumeWatchOk && self.resumeDate.timeIntervalSinceNow < -5 {
                    self.resumeWatchOk = true
                }
                
                self.locationCalls.forEach( { call in
                    call.resolve(position)
                })
                
                self.updateGeofenceRegion(location: location, id: self.geoRelaunchID)
                
            } else if self.movementLocation != nil {
                let lastPos = self.convertLocationToPosition(location: self.movementLocation!)
                
                self.locationCalls.forEach( { call in
                    call.resolve(lastPos)
                })
                
            } else {
                self.locationCalls.forEach( { call in
                    call.resolve(position)
                })
            }
            
            if self.resumeWatchOk || (self.lastWatchSend.timeIntervalSinceNow < -60 && location.horizontalAccuracy < 40){
                
                self.notifyListeners("pjammLocation", data: position)
                self.lastWatchSend = Date()
            }
            
            self.locationCalls.removeAll()
            self.checkUserMovement(location: location)
        }
    }
    
    @objc public func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        
        self.pauseLocationUpdates(location: manager.location!, level: .final)
        self.locationManager?.startUpdatingLocation()
        
        self.sendNotification(title: "Location Alert", body: "Location accuracy reduced to save power", identifier: "location-accuracy-reduced")
        
    }
    
    @objc public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("PJAMM - location error: " + error.localizedDescription)
    }
    
    @objc public func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        // print("PJAMMGeo - Success monitoring region")
    }
    
    @objc public func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print("PJAMMGeo - Error monitoring region")
    }
    
    @objc public func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        
        self.locationManager?.stopMonitoring(for: region)
        
        if self.locationPaused != .none {
            self.resumeLocationUpdates()
        }
        
        if !self.locationStarted && region.identifier == self.geoRelaunchID {
            self.sendNotification(title: "Tracking Stopped", body: "The app was terminated while tracking was active. Reopen the app to resume tracking.", identifier: region.identifier)
        }
        
    }
    
    @objc private func setDesiredLocationAccuracy(){
        
        if self.locationPaused == .final {
            
            self.locationManager?.desiredAccuracy = kCLLocationAccuracyKilometer
            
        } else if self.locationPaused == .secondary {
            
            self.locationManager?.desiredAccuracy = kCLLocationAccuracyHundredMeters
            
        } else if self.locationPaused == .initial {
            
            self.locationManager?.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            
        } else {
            
            self.locationManager?.desiredAccuracy = kCLLocationAccuracyBest
            
        }
        
    }
    
    @objc private func convertLocationToPosition(location:CLLocation) -> [String:Any] {
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
        
        return position
    }
    
    @objc private func checkUserMovement (location:CLLocation){
        
        if self.movementLocation == nil {
            self.movementLocation = location
            return
        }
        
        let dist = round(location.distance(from: self.movementLocation!))
        let time = round(location.timestamp.timeIntervalSince1970 - (self.movementLocation?.timestamp.timeIntervalSince1970)!)
        let speed = location.speed
        
        switch self.locationPaused {
        
        case .final:
            
            //Logic to resume location events
            if speed > 1 || dist > 50 {
                self.resumeLocationUpdates(location: location)
            }
            
            break
            
        case .secondary:
            
            //Logic to resume location events
            if dist < 50 && speed < 2 {
                //Do Nothing
            } else if speed > 1 || dist > 100 {
                self.resumeLocationUpdates(location: location)
            }
            
            break
            
        case .initial:
            
            if dist > 50 || speed > 2 {
                //Logic to resume location events
                self.resumeLocationUpdates(location: location)
            } else if time > 120 && speed < 1 {
                //Logic to increase pause
                self.pauseLocationUpdates(location: location, level: .secondary)
            }
            
            break
            
        case .none:
            
            //Logic to pause location events
            if dist > 50 {
                self.movementLocation = location
            } else if time > 60 && speed < 1 {
                self.pauseLocationUpdates(location: location, level: .initial)
            }
            
            break
            
        default:
            break
        }
            
    }
    
    @objc private func resumeLocationUpdates(location:CLLocation? = nil){
        
        self.movementLocation = location
        
        if locationPaused == .none {
            return
        }

        self.locationPaused     = .none
        self.resumeDate         = Date()
        self.resumeWatchOk      = false
        self.setDesiredLocationAccuracy()
        self.clearGeofenceReion(id: self.geoResumeID)
        
        if self.backgroundMode {
            self.sendNotification(title: "Location Alert", body: "Location Updates Resumed", identifier: "location-resume")
        }
    }
    
    @objc private func pauseLocationUpdates(location:CLLocation, level:PauseLevel = .initial){
        self.movementLocation   = location
        self.locationPaused     = level
        self.resumeWatchOk      = false
        
        self.setDesiredLocationAccuracy()
        
        if self.backgroundMode && self.locationPaused == .none {
            self.sendNotification(title: "Location Alert", body: "Location Updates Paused", identifier: "location-paused")
        }
        self.updateGeofenceRegion(location: location, id: self.geoResumeID)
        
    }
    
    @objc private func updateGeofenceRegion(location:CLLocation, id:String){
        
        switch id {
        case self.geoRelaunchID:
            
            let state = UIApplication.shared.applicationState
            
            if self.geoRegionRelaunch != nil {
                self.locationManager?.stopMonitoring(for: self.geoRegionRelaunch!)
                self.geoRegionRelaunch = nil
            }
            
            if self.backgroundMode == true && state != .active {
                self.geoRegionRelaunch = CLCircularRegion(center: location.coordinate, radius: 50, identifier: self.geoRelaunchID)
                self.geoRegionRelaunch?.notifyOnExit = true;
        
                self.locationManager?.startMonitoring(for: self.geoRegionRelaunch!)
            }
            
            break
            
        case self.geoResumeID:
            
            if self.geoRegionResume != nil {
                self.locationManager?.stopMonitoring(for: self.geoRegionResume!)
                self.geoRegionResume = nil
            }
            
            self.geoRegionResume = CLCircularRegion(center: location.coordinate, radius: 50, identifier: self.geoResumeID)
            self.geoRegionResume?.notifyOnExit = true;
    
            self.locationManager?.startMonitoring(for: self.geoRegionResume!)
            
            break
            
        default:
            break
        }
    }
    
    @objc private func clearGeofenceReion(id:String? = nil){
        
        if (id == nil || id == self.geoRelaunchID) && self.geoRegionRelaunch != nil {
            self.locationManager?.stopMonitoring(for: self.geoRegionRelaunch!)
            self.geoRegionRelaunch = nil
        }
        
        if (id == nil || id == self.geoResumeID) && self.geoRegionResume != nil {
            self.locationManager?.stopMonitoring(for: self.geoRegionResume!)
            self.geoRegionResume = nil
        }
        
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
        
        DispatchQueue.main.async {
            
            if self.locationManager == nil {
                self.launchLocationManager()
            }
            
            self.locationManager?.requestWhenInUseAuthorization()
            self.locationManager?.requestAlwaysAuthorization()
            self.resumeLocationUpdates()
            self.locationManager?.startUpdatingLocation()
            self.locationStarted = true;
        }

    }

    @objc func stopLocation(_ call: CAPPluginCall) {
        self.locationManager?.stopUpdatingLocation()
        self.clearGeofenceReion()
        self.locationStarted = false
    }

    @objc func enableBackgroundTracking(_ call: CAPPluginCall) {
        self.backgroundMode = true
        self.locationManager?.allowsBackgroundLocationUpdates = true
        self.resumeLocationUpdates()
    }

    @objc func disableBackgroundTracking(_ call: CAPPluginCall) {
        self.backgroundMode = false
        self.locationManager?.allowsBackgroundLocationUpdates = false
        self.clearGeofenceReion()
    }
}
