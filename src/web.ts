import { WebPlugin } from '@capacitor/core';
import { PJAMMGeolocationPlugin } from './definitions';

export class PJAMMGeolocationWeb extends WebPlugin implements PJAMMGeolocationPlugin {
  constructor() {
    super({
      name: 'PJAMMGeolocation',
      platforms: ['web'],
    });
  }

  async echo(options: { value: string }): Promise<{ value: string }> {
    console.log('ECHO', options);
    return options;
  }
}

const PJAMMGeolocation = new PJAMMGeolocationWeb();

export { PJAMMGeolocation };

import { registerWebPlugin } from '@capacitor/core';
registerWebPlugin(PJAMMGeolocation);
