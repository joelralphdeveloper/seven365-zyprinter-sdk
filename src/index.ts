import { registerPlugin } from '@capacitor/core';

import type { ZyprintPlugin } from './definitions';

const Zyprint = registerPlugin<ZyprintPlugin>('Zyprint', {
  web: () => import('./web').then((m) => new m.ZyprintWeb()),
});

export * from './definitions';
export { Zyprint };
