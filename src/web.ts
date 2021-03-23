import { WebPlugin } from '@capacitor/core';
import { PJAMMGeolocationPlugin } from './definitions';

export class PJAMMGeolocationWeb extends WebPlugin implements PJAMMGeolocationPlugin {
  
  private watchID:number|null = null;

  constructor() {
    super({
      name: 'PJAMMGeolocation',
      platforms: ['web'],
    });
  }

  async getLocation(options?:any):Promise<any>{
    
    let posOptions:any = {
      enableHighAccuracy: true,
      maximumAge: 0,
      timeout: 10000
    };

    if(options && options.enableHighAccuracy != null) posOptions.enableHighAccuracy = options.enableHighAccuracy;
    if(options && options.timeout != null)            posOptions.timeout            = options.timeout;
    if(options && options.maximumAge != null)         posOptions.maximumAge         = options.maximumAge;
    
    return new Promise((resolve, reject) => {
      return this.requestPermissions().then((_result) => {
        window.navigator.geolocation.getCurrentPosition((pos) => {
          resolve(pos);
        }, (err) => {
          reject(err);
        }, posOptions);
      });
    });

  }

  startLocation(options?:any) {

    let posOptions:any = {
      enableHighAccuracy: true,
      maximumAge: 0,
      timeout: 10000
    };

    if(options && options.enableHighAccuracy != null) posOptions.enableHighAccuracy = options.enableHighAccuracy;
    if(options && options.timeout != null)            posOptions.timeout            = options.timeout;
    if(options && options.maximumAge != null)         posOptions.maximumAge         = options.maximumAge;

    if(this.watchID != null){
      this.stopLocation();
    }

    let id:number = window.navigator.geolocation.watchPosition((pos) => {
      this.notifyListeners('pjammLocation', pos);
    }, (err) => {
      this.notifyListeners('pjammLocationError', err);
    }, posOptions);

    this.watchID = id;
  }

  stopLocation() {
    if(this.watchID != null){
      window.navigator.geolocation.clearWatch(this.watchID);
      this.watchID = null;
    }
  }

  enableBackgroundTracking() {
    //Do Nothing
    return;
  }

  disableBackgroundTracking() {
    //Do Nothing
    return;
  }
}

const PJAMMGeolocation = new PJAMMGeolocationWeb();

export { PJAMMGeolocation };

import { registerWebPlugin } from '@capacitor/core';
registerWebPlugin(PJAMMGeolocation);
