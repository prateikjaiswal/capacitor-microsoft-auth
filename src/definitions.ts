declare module "@capacitor/core" {
  interface PluginRegistry {
    CapacitorMicrosoftAuth: CapacitorMicrosoftAuthPlugin;
  }
}

export interface CapacitorMicrosoftAuthPlugin {
  /**
   * Authenticate against Microsoft.
   * @param {OAuth2AuthenticateOptions} options
   * @returns {Promise<any>} the resource url response
   */
  authenticate(options: AuthenticationParameters): Promise<any>;
  signout(options: AuthenticationParameters): Promise<any>;
}

export interface AuthenticationParameters {
  /**
   * The app id (client id) you get from the oauth provider like Google, Facebook,...
   *
   * required!
   */
  clientId?: string;
  /**
   * The base url for retrieving tokens depending on the response type from a OAuth 2 provider. e.g. https://accounts.google.com/o/oauth2/auth
   *
   * required!
   */
  authorityUrl?: string;
  /**
   * Tells the authorization server which grant to execute. Be aware that a full code flow is not supported as clientCredentials are not included in requests.
   *
   * But you can retrieve the authorizationCode if you don't set a accessTokenEndpoint.
   *
   * required!
   */
  responseType?: string;
  /**
   * Url to  which the oauth provider redirects after authentication.
   *
   * required!
   */
  redirectUrl?: string;
  /**
   * Url for retrieving the access_token by the authorization code flow.
   */
  accessTokenEndpoint?: string;
  /**
   * Protected resource url. For authentification you only need the basic user details.
   */
  resourceUrl?: string;
  /**
   * A space-delimited list of permissions that identify the resources that your application could access on the user's behalf.
   * If you want to get a refresh token, you most likely will need the offline_access scope (only supported in Code Flow!)
   */
  scopes?: string;
  /**
   * A unique alpha numeric string used to prevent CSRF. If not set the plugin automatically generate a string
   * and sends it as using state is recommended.
   */
  state?: string;
  email?: string;
  tenant?: string
  graphEndpoint?: string;
  /**
   * Additional parameters for the created authorization url
   */
  additionalParameters?: { [key: string]: string }
}