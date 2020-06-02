import { WebPlugin } from "@capacitor/core";
import { CapacitorMicrosoftAuthPlugin, OAuth2AuthenticateBaseOptions } from "./definitions";
export declare class CapacitorMicrosoftAuthWeb extends WebPlugin implements CapacitorMicrosoftAuthPlugin {
    private msalConfig;
    private msalInstance;
    private ssoRequest;
    private oAuthconfiguration;
    constructor();
    authenticate(options: OAuth2AuthenticateBaseOptions): Promise<any>;
    loginWithPopup(resolve: any, reject: any): Promise<void>;
    acquireTokenSilently(resolve: any, reject: any): Promise<void>;
    configure(): void;
}
declare const CapacitorMicrosoftAuth: CapacitorMicrosoftAuthWeb;
export { CapacitorMicrosoftAuth };
