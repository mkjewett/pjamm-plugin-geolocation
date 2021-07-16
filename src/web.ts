import { WebPlugin } from '@capacitor/core';

import type { PJAMMGeolocationPlugin } from './definitions';

export class PJAMMGeolocationWeb extends WebPlugin implements PJAMMGeolocationPlugin {
  private watchID:number|null = null;

  async getLocation(options?:any):Promise<any>{

    if(typeof navigator === 'undefined' || !navigator.geolocation) {
      throw this.unavailable('Geolocation API not available in this browser.');
    }
    
    let posOptions:any = {
      enableHighAccuracy: true,
      maximumAge: 0,
      timeout: 10000
    };

    if(options && options.enableHighAccuracy != null) posOptions.enableHighAccuracy = options.enableHighAccuracy;
    if(options && options.timeout != null)            posOptions.timeout            = options.timeout;
    if(options && options.maximumAge != null)         posOptions.maximumAge         = options.maximumAge;
    
    return new Promise((resolve, reject) => {
      navigator.geolocation.getCurrentPosition((pos) => {
        resolve(pos);
      }, (err) => {
        reject(err);
      }, posOptions);
    });

  }
  startLocation(options?:any) {

    if(typeof navigator === 'undefined' || !navigator.geolocation) {
      throw this.unavailable('Geolocation API not available in this browser.');
    }

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

    let id:number = navigator.geolocation.watchPosition((pos) => {
      this.notifyListeners('pjammLocation', pos);
    }, (err) => {
      this.notifyListeners('pjammLocationError', err);
    }, posOptions);

    this.watchID = id;
  }
  stopLocation() {
    if(typeof navigator === 'undefined' || !navigator.geolocation) {
      throw this.unavailable('Geolocation API not available in this browser.');
    }
    
    if(this.watchID != null){
      window.navigator.geolocation.clearWatch(this.watchID);
      this.watchID = null;
    }
  }

  enableBackgroundTracking() {
    throw this.unimplemented('Not implemented on web.');
  }
  disableBackgroundTracking() {
    throw this.unimplemented('Not implemented on web.');
  }
}
