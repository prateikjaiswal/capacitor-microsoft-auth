var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
import { registerWebPlugin, WebPlugin } from "@capacitor/core";
import * as Msal from "msal";
export class CapacitorMicrosoftAuthWeb extends WebPlugin {
    constructor() {
        super({
            name: "CapacitorMicrosoftAuth",
            platforms: ["web"]
        });
    }
    authenticate(options) {
        this.oAuthconfiguration = {
            scopes: options.scopes,
            clientId: options.clientId,
            email: options.email,
            tenant: options.tenant
        };
        this.configure();
        this.msalInstance = new Msal.UserAgentApplication(this.msalConfig);
        return new Promise((resolve, reject) => __awaiter(this, void 0, void 0, function* () {
            yield this.loginWithPopup(resolve, reject);
        }));
    }
    loginWithPopup(resolve, reject) {
        return __awaiter(this, void 0, void 0, function* () {
            const response = yield this.msalInstance.loginPopup(this.ssoRequest)
                .catch((error) => {
                reject(error);
            });
            yield this.acquireTokenSilently(resolve, reject);
        });
    }
    acquireTokenSilently(resolve, reject) {
        return __awaiter(this, void 0, void 0, function* () {
            // if the user is already logged in you can acquire a token
            if (this.msalInstance.getAccount()) {
                const tokenRequest = {
                    scopes: this.oAuthconfiguration.scopes
                };
                const response = yield this.msalInstance.acquireTokenSilent(tokenRequest)
                    .catch((error) => __awaiter(this, void 0, void 0, function* () {
                    if (error.name === "InteractionRequiredAuthError") {
                        yield this.loginWithPopup(resolve, reject);
                    }
                    else {
                        reject(error);
                    }
                }));
                resolve(response);
            }
            else {
                yield this.loginWithPopup(resolve, reject);
            }
        });
    }
    configure() {
        this.msalConfig = {
            auth: {
                clientId: this.oAuthconfiguration.clientId
            }
        };
        this.ssoRequest = {
            scopes: this.oAuthconfiguration.scopes,
            loginHint: this.oAuthconfiguration.email,
            extraQueryParameters: { domain_hint: this.oAuthconfiguration.tenant }
        };
    }
}
const CapacitorMicrosoftAuth = new CapacitorMicrosoftAuthWeb();
export { CapacitorMicrosoftAuth };
registerWebPlugin(CapacitorMicrosoftAuth);
//# sourceMappingURL=web.js.map