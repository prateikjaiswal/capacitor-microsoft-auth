import Foundation
import Capacitor
import MSAL

@objc(CapacitorMicrosoftAuth)
public class CapacitorMicrosoftAuth: CAPPlugin {
    
    typealias AccountCompletion = (MSALAccount?) -> Void
    
    let CLIENT_ID = "clientId"
    let GRAPH_ENDPOINT = "graphEndpoint"
    let AUTHORITY_URL = "authorityUrl"
    let SCOPES = "scopes"
    
    var accessToken = String()
    var applicationContext : MSALPublicClientApplication?
    var webViewParamaters : MSALWebviewParameters?
    var currentAccount: MSALAccount?
    
    
    @objc func authenticate(_ call: CAPPluginCall) {
        do {
            try self.initMSAL(call)
        }
        catch let error{
            call.reject(error.localizedDescription, "", error)
        }
    }
    
    func initMSAL(_ call: CAPPluginCall) throws {
        
        guard  let clientId = call.getString(self.CLIENT_ID) else {
            call.reject("Must provide an clientId")
            return
        }
        
        guard let authUrl =  call.getString(self.AUTHORITY_URL) else {
            call.reject("Must provide an authorityUrl")
            return
        }
        
        guard let authorityURL = URL(string: authUrl) else { return  }
        
        let authority = try MSALAADAuthority(url: authorityURL)
        
        let msalConfiguration = MSALPublicClientApplicationConfig(clientId: clientId, redirectUri: nil, authority: authority)
        self.applicationContext = try? MSALPublicClientApplication(configuration: msalConfiguration)
        self.initWebViewParams()
        self.callGraphAPI(call)
    }
    
    func initWebViewParams() {
        self.webViewParamaters = MSALWebviewParameters(authPresentationViewController: self.bridge.viewController)
    }
    
    func callGraphAPI(_ call: CAPPluginCall) {
        self.loadCurrentAccount { (account) in
            
            guard let currentAccount = account else {
                
                // We check to see if we have a current logged in account.
                // If we don't, then we need to sign someone in.
                self.acquireTokenInteractively(call)
                return
            }
            
            self.acquireTokenSilently(currentAccount, call)
        }
    }
    
    func acquireTokenInteractively(_ call: CAPPluginCall){
        guard let scopes = call.options[self.SCOPES] as? [String] else {
            call.reject("Must provide an scopes")
            return
        }
        
        guard let applicationContext = self.applicationContext else { return }
        guard let webViewParameters = self.webViewParamaters else { return }
        
        let parameters = MSALInteractiveTokenParameters(scopes: scopes, webviewParameters: webViewParameters)
        parameters.promptType = .selectAccount
        
        applicationContext.acquireToken(with: parameters) { (result, error) in
            
            if error != nil {
                return
            }
            
            guard let result = result else {
                return
            }
            
            self.accessToken = result.accessToken
            self.currentAccount = result.account
            self.getContentWithToken(call)
        }
    }
    
    func acquireTokenSilently(_ account : MSALAccount!, _ call: CAPPluginCall) {
        guard let applicationContext = self.applicationContext else { return }
        guard let scopes = call.options[self.SCOPES] as? [String] else {
            call.reject("Must provide an scopes")
            return
        }
        /**
         
         Acquire a token for an existing account silently
         
         - forScopes:           Permissions you want included in the access token received
         in the result in the completionBlock. Not all scopes are
         guaranteed to be included in the access token returned.
         - account:             An account object that we retrieved from the application object before that the
         authentication flow will be locked down to.
         - completionBlock:     The completion block that will be called when the authentication
         flow completes, or encounters an error.
         */
        
        let parameters = MSALSilentTokenParameters(scopes: scopes, account: account)
        
        applicationContext.acquireTokenSilent(with: parameters) { (result, error) in
            
            if let error = error {
                
                let nsError = error as NSError
                
                // interactionRequired means we need to ask the user to sign-in. This usually happens
                // when the user's Refresh Token is expired or if the user has changed their password
                // among other possible reasons.
                
                if (nsError.domain == MSALErrorDomain) {
                    
                    if (nsError.code == MSALError.interactionRequired.rawValue) {
                        
                        DispatchQueue.main.async {
                            self.acquireTokenInteractively(call)
                        }
                        return
                    }
                }
                
                return
            }
            
            guard let result = result else {
                
                return
            }
            
            self.accessToken = result.accessToken
            self.getContentWithToken(call)
        }
    }
    
    func loadCurrentAccount(completion: AccountCompletion? = nil) {
        
        guard let applicationContext = self.applicationContext else { return }
        
        let msalParameters = MSALParameters()
        msalParameters.completionBlockQueue = DispatchQueue.main
        
        // Note that this sample showcases an app that signs in a single account at a time
        applicationContext.getCurrentAccount(with: msalParameters, completionBlock: { (currentAccount, previousAccount, error) in
            
            if error != nil {
                return
            }
            
            if let currentAccount = currentAccount {
                self.currentAccount = currentAccount
                
                if let completion = completion {
                    completion(self.currentAccount)
                }
                return
            }
            
            self.accessToken = ""
            self.currentAccount = nil
            if let completion = completion {
                completion(nil)
            }
        })
    }
    
    
    func getGraphEndpoint(_ call: CAPPluginCall) -> String {
        let graphEndpoint = call.getString(self.GRAPH_ENDPOINT) ?? ""
        return (graphEndpoint.hasSuffix("/")) ? (graphEndpoint + "v1.0/me/") : (graphEndpoint + "/v1.0/me/");
    }
    
    
    /**
     This will invoke the call to the Microsoft Graph API. It uses the
     built in URLSession to create a connection.
     */
    
    func getContentWithToken(_ call: CAPPluginCall) {
        
        // Specify the Graph API endpoint
        let graphURI = getGraphEndpoint(call)
        let url = URL(string: graphURI)
        var request = URLRequest(url: url!)
        
        // Set the Authorization header for the request. We use Bearer tokens, so we specify Bearer + the token we got from the result
        request.setValue("Bearer \(self.accessToken)", forHTTPHeaderField: "Authorization")
        
        URLSession.shared.dataTask(with: request) { data, response, error in
            
            if error != nil {
                return
            }
            
            guard let result = try? JSONSerialization.jsonObject(with: data!, options: []) as AnyObject? else {
                
                return
            }
            call.resolve([
                "access_token": self.accessToken,
                "user": result.object(forKey: "error") != nil ? "": result
            ])
            
        }.resume()
    }
}
