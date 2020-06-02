import {registerWebPlugin , WebPlugin} from "@capacitor/core";
import * as Msal from "msal";
import {CapacitorMicrosoftAuthPlugin , OAuth2AuthenticateBaseOptions} from "./definitions";

export class CapacitorMicrosoftAuthWeb extends WebPlugin implements CapacitorMicrosoftAuthPlugin {

    private msalConfig: { auth: { clientId: string; }; };
    private msalInstance : any;
    private ssoRequest: any;
    private oAuthconfiguration: OAuth2AuthenticateBaseOptions;

    constructor() {
        super({
            name: "CapacitorMicrosoftAuth" ,
            platforms: ["web"]
        });
    }
    authenticate(options: OAuth2AuthenticateBaseOptions): Promise<any> {
        this.oAuthconfiguration = {
            scopes: options.scopes ,
            clientId: options.clientId ,
            email: options.email ,
            tenant: options.tenant
        };
        this.configure();
        this.msalInstance = new Msal.UserAgentApplication(this.msalConfig);
        return new Promise<any>(async (resolve , reject: any) => {
            await this.loginWithPopup(resolve , reject);
        });
    }

    async loginWithPopup(resolve: any , reject: any) {
        const response = await this.msalInstance.loginPopup(this.ssoRequest)
            .catch((error: any) => {
                reject(error);
            });
        await this.acquireTokenSilently(resolve , reject)
    }

    async acquireTokenSilently(resolve: any , reject: any) {
        // if the user is already logged in you can acquire a token
        if (this.msalInstance.getAccount()) {
            const tokenRequest = {
                scopes: this.oAuthconfiguration.scopes
            };
            const response = await this.msalInstance.acquireTokenSilent(tokenRequest)
                .catch(async (error: any) => {

                    if (error.name === "InteractionRequiredAuthError") {
                        await this.loginWithPopup(resolve , reject);
                    } else {
                        reject(error);
                    }
                });
            resolve(response);
        } else {
            await this.loginWithPopup(resolve , reject);
        }
    }

    configure() {
        this.msalConfig = {
            auth: {
                clientId: this.oAuthconfiguration.clientId
            }
        };
        this.ssoRequest = {
            scopes: this.oAuthconfiguration.scopes ,
            loginHint: this.oAuthconfiguration.email ,
            extraQueryParameters: {domain_hint: this.oAuthconfiguration.tenant}
        };
    }
}

const CapacitorMicrosoftAuth = new CapacitorMicrosoftAuthWeb();

export {CapacitorMicrosoftAuth};

registerWebPlugin(CapacitorMicrosoftAuth);
