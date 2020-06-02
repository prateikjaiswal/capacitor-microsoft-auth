import { WebPlugin } from '@capacitor/core';
import { CapacitorMicrosoftAuthPlugin, OAuth2AuthenticateBaseOptions } from "./definitions";
export declare class CapacitorMicrosoftAuthWeb extends WebPlugin implements CapacitorMicrosoftAuthPlugin {
    constructor();
    echo(options: {
        value: string;
    }): Promise<{
        value: string;
    }>;
    authenticate(options: OAuth2AuthenticateBaseOptions): Promise<any>;
}
declare const CapacitorMicrosoftAuth: CapacitorMicrosoftAuthWeb;
export { CapacitorMicrosoftAuth };
