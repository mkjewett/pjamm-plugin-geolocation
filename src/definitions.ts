declare module '@capacitor/core' {
  interface PluginRegistry {
    PJAMMGeolocation: PJAMMGeolocationPlugin;
  }
}

export interface PJAMMGeolocationPlugin {
  startLocation(options:any):Promise<void>;
  stopLocation():Promise<void>;
  enableBackgroundTracking():void;
  disableBackgroundTracking():void;
}
