import { registerPlugin } from '@capacitor/core';

import type { PJAMMGeolocationPlugin } from './definitions';

const PJAMMGeolocation = registerPlugin<PJAMMGeolocationPlugin>('PJAMMGeolocation', {
  web: () => import('./web').then(m => new m.PJAMMGeolocationWeb()),
});

export * from './definitions';
export { PJAMMGeolocation };
