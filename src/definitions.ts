declare module '@capacitor/core' {
  interface PluginRegistry {
    PJAMMGeolocation: PJAMMGeolocationPlugin;
  }
}

export interface PJAMMGeolocationPlugin {
  getLocation(options?:any):Promise<Position>;
  startLocation(options?:any):void;
  stopLocation():void;
  enableBackgroundTracking():void;
  disableBackgroundTracking():void;
}
