import { registerWebPlugin, WebPlugin } from "@capacitor/core";
import * as Msal from "msal";
import { CapacitorMicrosoftAuthPlugin, AuthenticationParameters } from "./definitions";

export class CapacitorMicrosoftAuthWeb extends WebPlugin implements CapacitorMicrosoftAuthPlugin {

    private msalConfig: { auth: { clientId: string; }; };
    private msalInstance: any;
    private ssoRequest: any;
    private oAuthconfiguration: AuthenticationParameters;

    constructor() {
        super({
            name: "CapacitorMicrosoftAuth",
            platforms: ["web"]
        });
    }
    authenticate(options: AuthenticationParameters): Promise<any> {
        this.oAuthconfiguration = {
            authorityUrl: options.authorityUrl,
            scopes: options.scopes,
            clientId: options.clientId,
            tenant: options.tenant
        };
        this.configure();
        this.msalInstance = new Msal.UserAgentApplication(this.msalConfig);
        return new Promise<any>(async (resolve, reject: any) => {
            await this.loginWithPopup(resolve, reject);
        });
    }

    async loginWithPopup(resolve: any, reject: any) {
        const response = await this.msalInstance.loginPopup(this.ssoRequest)
            .catch((error: any) => {
                reject(error);
            });
        await this.acquireTokenSilently(resolve, reject)
    }

    async acquireTokenSilently(resolve: any, reject: any) {
        // if the user is already logged in you can acquire a token
        if (this.msalInstance.getAccount()) {
            const tokenRequest = {
                scopes: this.oAuthconfiguration.scopes
            };
            const response = await this.msalInstance.acquireTokenSilent(tokenRequest)
                .catch(async (error: any) => {

                    if (error.name === "InteractionRequiredAuthError") {
                        await this.loginWithPopup(resolve, reject);
                    } else {
                        reject(error);
                    }
                });
            resolve(response);
        } else {
            await this.loginWithPopup(resolve, reject);
        }
    }

    signout(options: AuthenticationParameters): Promise<any> {
        this.oAuthconfiguration = {
            authorityUrl: options.authorityUrl,
            scopes: options.scopes,
            clientId: options.clientId,
            tenant: options.tenant
        };
        this.configure();
        if (!this.msalInstance) {
            this.msalInstance = new Msal.UserAgentApplication(this.msalConfig);
        }
        return new Promise<any>(async (resolve, reject: any) => {
            this.msalInstance.logout()
            resolve()
        });
    }

    configure() {
        this.msalConfig = {
            auth: {
                clientId: this.oAuthconfiguration.clientId
            }
        };
    }
}

const CapacitorMicrosoftAuth = new CapacitorMicrosoftAuthWeb();

export { CapacitorMicrosoftAuth };

registerWebPlugin(CapacitorMicrosoftAuth);
