import { WebPlugin } from '@capacitor/core';
import {CapacitorMicrosoftAuthPlugin , OAuth2AuthenticateBaseOptions} from "./definitions";

export class CapacitorMicrosoftAuthWeb extends WebPlugin implements CapacitorMicrosoftAuthPlugin {
  constructor() {
    super({
      name: 'CapacitorMicrosoftAuth',
      platforms: ['web']
    });
  }

  async echo(options: { value: string }): Promise<{value: string}> {
    console.log('ECHO', options);
    return options;
  }

  authenticate(options: OAuth2AuthenticateBaseOptions): Promise<any> {
    return Promise.resolve(options);
  }
}

const CapacitorMicrosoftAuth = new CapacitorMicrosoftAuthWeb();

export { CapacitorMicrosoftAuth };

import { registerWebPlugin } from '@capacitor/core';
registerWebPlugin(CapacitorMicrosoftAuth);
