#import <Foundation/Foundation.h>
#import <Capacitor/Capacitor.h>

// Define the plugin using the CAP_PLUGIN Macro, and
// each method the plugin supports using the CAP_PLUGIN_METHOD macro.
CAP_PLUGIN(PJAMMGeolocation, "PJAMMGeolocation",
           CAP_PLUGIN_METHOD(startLocation, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(stopLocation, CAPPluginReturnPromise);
           CAP_PLUGIN_METHOD(enableBackgroundTracking, CAPPluginReturnNone);
           CAP_PLUGIN_METHOD(disableBackgroundTracking, CAPPluginReturnNone);
)