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
public class PJAMMGeolocationPlugin: CAPPlugin, CLLocationManagerDelegate, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    private let implementation = PJAMMGeolocation()

    private var locationManager:CLLocationManager?
    private var notificationCenter:UNUserNotificationCenter?
    
//    @objc private var locationCalls:[CAPPluginCall] = []
    private var callQueue:[String]            = []
    private var backgroundMode:Bool           = false
    private var locationPaused:PauseLevel     = .none
    private var locationStarted:Bool          = false
    
    private var activityType:CLActivityType   = .automotiveNavigation
    
    private var resumeDate:Date               = Date()
    private var resumeWatchOk:Bool            = false
    private var movementLocation:CLLocation?  = nil
    private var lastWatchSend:Date            = Date()
    
    private var geoRegionRelaunch:CLRegion?   = nil
    private var geoRegionResume:CLRegion?     = nil
    private var geoRelaunchID:String          = "pjamm-geofence-relaunch"
    private var geoResumeID:String            = "pjamm-geofence-resume"
    
    @objc public override func load() {
        
        DispatchQueue.main.async { [weak self] in
            
            guard let self = self else { return }
            
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
        
        DispatchQueue.main.async { [weak self] in
            
            guard let self = self else { return }
            
            if self.locationManager == nil {
                self.launchLocationManager()
            }

            if self.notificationCenter == nil {
                self.launchNotificationCenter()
            }
        }
    }
    
    @objc public func didBecomeActive(notification:Notification) {
    
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

        if let location = locations.last {
            
            let position = convertLocationToPosition(location: location)

            if locationPaused == .none {
                
                if !resumeWatchOk && location.horizontalAccuracy < 20 {
                    self.resumeWatchOk = true
                }
                
                if !resumeWatchOk && self.resumeDate.timeIntervalSinceNow < -5 {
                    self.resumeWatchOk = true
                }
                
                self.callQueue.forEach({callId in
                    if let call = bridge?.savedCall(withID: callId) {
                        call.resolve(position)
                        bridge?.releaseCall(withID: callId)
                    }
                })
                
                self.updateGeofenceRegion(location: location, id: self.geoRelaunchID)
                
            } else if self.movementLocation != nil {
                let lastPos = self.convertLocationToPosition(location: self.movementLocation!)
                
                self.callQueue.forEach({callId in
                    if let call = bridge?.savedCall(withID: callId) {
                        call.resolve(lastPos)
                        bridge?.releaseCall(withID: callId)
                    }
                })
                
            } else {

                self.callQueue.forEach({callId in
                    if let call = bridge?.savedCall(withID: callId) {
                        call.resolve(position)
                        bridge?.releaseCall(withID: callId)
                    }
                })
            }
            
            if self.resumeWatchOk || (self.lastWatchSend.timeIntervalSinceNow < -60 && location.horizontalAccuracy < 40){
                
                self.notifyListeners("pjammLocation", data: position)
                self.lastWatchSend = Date()
                
            }
            
            self.callQueue.removeAll()
            self.checkUserMovement(location: location)
        }
    }
    
    @objc public func locationManagerDidPauseLocationUpdates(_ manager: CLLocationManager) {
        
        self.pauseLocationUpdates(location: manager.location, level: .final)
        self.locationManager?.startUpdatingLocation()
        
        self.sendNotification(title: "Location Alert", body: "Location accuracy reduced to save power", identifier: "location-accuracy-reduced")
        
    }
    
    @objc public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("PJAMMGeo - location error: " + error.localizedDescription)
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
        
        guard let movementLocation = self.movementLocation else { return }
        
        let dist = round(location.distance(from: movementLocation))
        let time = round(location.timestamp.timeIntervalSince1970 - movementLocation.timestamp.timeIntervalSince1970)
        let speed = location.speed
        
        switch self.locationPaused {
        
        case .final:
            
            //Logic to resume location events
            if speed > 0.5 || dist > 50 {
                self.resumeLocationUpdates(location: location)
            }
            
            break
            
        case .secondary:
            
            //Logic to resume location events
            if dist < 50 && speed < 0.5 {
                //Do Nothing
            } else if speed > 0.5 || dist > 100 {
                self.resumeLocationUpdates(location: location)
            }
            
            break
            
        case .initial:
            
            if dist > 50 || speed > 0.5 {
                //Logic to resume location events
                self.resumeLocationUpdates(location: location)
            } else if time > 120 && speed < 0.5 {
                //Logic to increase pause
                self.pauseLocationUpdates(location: location, level: .secondary)
            }
            
            break
            
        case .none:
            
            //Logic to pause location events
            if dist > 50 {
                self.movementLocation = location
            } else if time > 60 && speed < 0.5 {
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
            // self.sendNotification(title: "Location Alert", body: "Location Updates Resumed", identifier: "location-resume")
        }
    }
    
    @objc private func pauseLocationUpdates(location:CLLocation?, level:PauseLevel = .initial){
        
        let location = location ?? self.locationManager?.location
        
        self.movementLocation   = location
        self.locationPaused     = level
        self.resumeWatchOk      = false
        
        self.setDesiredLocationAccuracy()
        
        if self.backgroundMode && self.locationPaused == .none {
            // self.sendNotification(title: "Location Alert", body: "Location Updates Paused", identifier: "location-paused")
        }
        
        guard let locationIn = location else { return }
        
        self.updateGeofenceRegion(location: locationIn, id: self.geoResumeID)
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
        
                
                if self.geoRegionRelaunch != nil {
                    self.locationManager?.startMonitoring(for: self.geoRegionRelaunch!)
                }
            }
            
            break
            
        case self.geoResumeID:
            
            if self.geoRegionResume != nil {
                self.locationManager?.stopMonitoring(for: self.geoRegionResume!)
                self.geoRegionResume = nil
            }
            
            self.geoRegionResume = CLCircularRegion(center: location.coordinate, radius: 50, identifier: self.geoResumeID)
            self.geoRegionResume?.notifyOnExit = true;
            
            if(self.geoRegionResume != nil){
                self.locationManager?.startMonitoring(for: self.geoRegionResume!)
            }
            
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
        
        call.keepAlive = true;
        self.callQueue.append(call.callbackId)
        
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            
            self.locationManager?.requestWhenInUseAuthorization()
            self.locationManager?.requestAlwaysAuthorization()
            self.locationManager?.requestLocation()
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) { [weak self] in
            
            guard let self = self else { return }
            
            if self.callQueue.contains(call.callbackId) {
                if let call = self.bridge?.savedCall(withID: call.callbackId) {
                    self.bridge?.releaseCall(withID: call.callbackId)
                    self.callQueue.removeAll(where: {$0 == call.callbackId})
                }
            }

        }
    }

    @objc func startLocation(_ call: CAPPluginCall) {
        
        DispatchQueue.main.async { [weak self] in
            
            guard let self = self else { return }
            
            if self.locationManager == nil {
                self.launchLocationManager()
            }
            
            self.locationManager?.requestWhenInUseAuthorization()
            self.locationManager?.requestAlwaysAuthorization()
            self.resumeLocationUpdates()
            self.locationManager?.stopUpdatingLocation()
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
