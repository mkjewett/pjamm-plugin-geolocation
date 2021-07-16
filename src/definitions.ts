import { WebPlugin } from "@capacitor/core";

export interface PJAMMGeolocationPlugin extends WebPlugin {
  getLocation(options?:any):Promise<any>;
  startLocation(options?:any):void;
  stopLocation():void;

  enableBackgroundTracking():void;
  disableBackgroundTracking():void;
}
