// Copyright (c) Microsoft Corporation.
// All rights reserved.
//
// This code is licensed under the MIT License.
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files(the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and / or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions :
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "MSIDInteractiveTokenRequest+Internal.h"
#import "MSIDInteractiveTokenRequestParameters.h"
#import "MSIDAuthority.h"
#import "MSIDAuthorizeWebRequestConfiguration.h"
#import "MSIDOpenIdProviderMetadata.h"
#import "MSIDWebviewResponse.h"
#import "MSIDWebOAuth2AuthCodeResponse.h"
#import "MSIDWebAADAuthCodeResponse.h"
#import "MSIDWebWPJResponse.h"
#import "MSIDWebOpenBrowserResponse.h"
#import "MSIDCBAWebAADAuthResponse.h"
#import "MSIDWebviewAuthorization.h"
#import "MSIDAADAuthorizationCodeGrantRequest.h"
#import "MSIDPkce.h"
#import "MSIDTokenResponseValidator.h"
#import "MSIDTokenResult.h"
#import "MSIDAccountIdentifier.h"
#import "MSIDWebviewFactory.h"
#import "MSIDSystemWebViewControllerFactory.h"
#import "MSIDTokenResponseHandler.h"
#import "MSIDAccount.h"
#import "MSIDLastRequestTelemetry.h"
#import "NSError+MSIDServerTelemetryError.h"

#if TARGET_OS_IPHONE
#import "MSIDAppExtensionUtil.h"
#endif

#if TARGET_OS_OSX
#import "MSIDExternalAADCacheSeeder.h"
#endif

@interface MSIDInteractiveTokenRequest()

@property (nonatomic) MSIDAuthorizeWebRequestConfiguration *webViewConfiguration;
@property (nonatomic) MSIDClientInfo *authCodeClientInfo;
@property (nonatomic) MSIDTokenResponseHandler *tokenResponseHandler;
@property (nonatomic) MSIDLastRequestTelemetry *lastRequestTelemetry;

@end

@implementation MSIDInteractiveTokenRequest

- (nullable instancetype)initWithRequestParameters:(nonnull MSIDInteractiveTokenRequestParameters *)parameters
                                      oauthFactory:(nonnull MSIDOauth2Factory *)oauthFactory
                            tokenResponseValidator:(nonnull MSIDTokenResponseValidator *)tokenResponseValidator
                                        tokenCache:(nonnull id<MSIDCacheAccessor>)tokenCache
                              accountMetadataCache:(nullable MSIDAccountMetadataCacheAccessor *)accountMetadataCache
{
    self = [super init];

    if (self)
    {
        _requestParameters = parameters;
        _oauthFactory = oauthFactory;
        _tokenResponseValidator = tokenResponseValidator;
        _tokenCache = tokenCache;
        _accountMetadataCache = accountMetadataCache;
        _tokenResponseHandler = [MSIDTokenResponseHandler new];
        _lastRequestTelemetry = [MSIDLastRequestTelemetry sharedInstance];
    }

    return self;
}

- (void)executeRequestWithCompletion:(nonnull MSIDInteractiveRequestCompletionBlock)completionBlock
{
    NSString *upn = self.requestParameters.accountIdentifier.displayableId ?: self.requestParameters.loginHint;

    [self.requestParameters.authority resolveAndValidate:self.requestParameters.validateAuthority
                                       userPrincipalName:upn
                                                 context:self.requestParameters
                                         completionBlock:^(__unused NSURL *openIdConfigurationEndpoint,
                                         __unused BOOL validated, NSError *error)
     {
         if (error)
         {
             completionBlock(nil, error, nil);
             return;
         }

         [self.requestParameters.authority loadOpenIdMetadataWithContext:self.requestParameters
                                                         completionBlock:^(__unused MSIDOpenIdProviderMetadata *metadata, NSError *error)
          {
              if (error)
              {
                  completionBlock(nil, error, nil);
                  return;
              }

              [self acquireTokenImpl:completionBlock];
          }];
     }];
}

- (void)acquireTokenImpl:(nonnull MSIDInteractiveRequestCompletionBlock)completionBlock
{
    void (^webAuthCompletion)(MSIDWebviewResponse *, NSError *) = ^void(MSIDWebviewResponse *response, NSError *error)
    {
        void (^returnErrorBlock)(NSError *) = ^(NSError *error)
        {
            NSString *errorString = [error msidServerTelemetryErrorString];
            if (errorString)
            {
                [self.lastRequestTelemetry updateWithApiId:[self.requestParameters.telemetryApiId integerValue]
                                               errorString:errorString
                                                   context:self.requestParameters];
            }
            
            completionBlock(nil, error, nil);
        };
        
        if (error)
        {
            returnErrorBlock(error);
            return;
        }

        /*

         TODO: this code has been moved from MSAL almost as is to avoid any changes in the MSIDWebviewAuthorization logic.
         Some minor refactoring to MSIDWebviewAuthorization response logic and to the interactive requests tests will be done separately: https://github.com/AzureAD/microsoft-authentication-library-common-for-objc/issues/297
         */

        if ([response isKindOfClass:MSIDWebOAuth2AuthCodeResponse.class])
        {
            MSIDWebOAuth2AuthCodeResponse *oauthResponse = (MSIDWebOAuth2AuthCodeResponse *)response;

            if (oauthResponse.authorizationCode)
            {
                if ([response isKindOfClass:MSIDCBAWebAADAuthResponse.class])
                {
                    MSIDCBAWebAADAuthResponse *cbaResponse = (MSIDCBAWebAADAuthResponse *)response;
                    self.requestParameters.redirectUri = cbaResponse.redirectUri;
                }
                // handle instance aware flow (cloud host)
                
                if ([response isKindOfClass:MSIDWebAADAuthCodeResponse.class])
                {
                    MSIDWebAADAuthCodeResponse *aadResponse = (MSIDWebAADAuthCodeResponse *)response;
                    [self.requestParameters setCloudAuthorityWithCloudHostName:aadResponse.cloudHostName];
                    self.authCodeClientInfo = aadResponse.clientInfo;
                }

                [self acquireTokenWithCode:oauthResponse.authorizationCode completion:completionBlock];
                return;
            }

            returnErrorBlock(oauthResponse.oauthError);
            return;
        }
        else if ([response isKindOfClass:MSIDWebWPJResponse.class])
        {
            completionBlock(nil, nil, (MSIDWebWPJResponse *)response);
        }
        else if ([response isKindOfClass:MSIDWebOpenBrowserResponse.class])
        {
            NSURL *browserURL = ((MSIDWebOpenBrowserResponse *)response).browserURL;

#if TARGET_OS_IPHONE
            if (![MSIDAppExtensionUtil isExecutingInAppExtension])
            {
                MSID_LOG_WITH_CTX_PII(MSIDLogLevelInfo, nil, @"Opening a browser - %@", MSID_PII_LOG_MASKABLE(browserURL));
                [MSIDAppExtensionUtil sharedApplicationOpenURL:browserURL];
            }
            else
            {
                NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorAttemptToOpenURLFromExtension, @"unable to redirect to browser from extension", nil, nil, nil, self.requestParameters.correlationId, nil, YES);
                returnErrorBlock(error);
                return;
            }
#else
            [[NSWorkspace sharedWorkspace] openURL:browserURL];
#endif
            NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorSessionCanceledProgrammatically, @"Authorization session was cancelled programatically.", nil, nil, nil, self.requestParameters.correlationId, nil, YES);
            returnErrorBlock(error);
            return;
        }
    };

    self.webViewConfiguration = [self.oauthFactory.webviewFactory authorizeWebRequestConfigurationWithRequestParameters:self.requestParameters];
    [self showWebComponentWithCompletion:webAuthCompletion];
}

- (void)showWebComponentWithCompletion:(MSIDWebviewAuthCompletionHandler)completionHandler
{    
    NSObject<MSIDWebviewInteracting> *webView = [self.oauthFactory.webviewFactory webViewWithConfiguration:self.webViewConfiguration
                                                                                         requestParameters:self.requestParameters
                                                                                                   context:self.requestParameters];
    
    if (!webView)
    {
        NSError *error = MSIDCreateError(MSIDErrorDomain, MSIDErrorInternal, @"Unexpected error. Didn't find any supported web browsers.", nil, nil, nil, nil, nil, YES);
        if (completionHandler) completionHandler(nil, error);
        return;
    }
    
    [MSIDWebviewAuthorization startSessionWithWebView:webView
                                        oauth2Factory:self.oauthFactory
                                        configuration:self.webViewConfiguration
                                              context:self.requestParameters
                                    completionHandler:completionHandler];

}

#pragma mark - Helpers

- (void)acquireTokenWithCode:(NSString *)authCode
                  completion:(MSIDInteractiveRequestCompletionBlock)completionBlock
{
    MSIDAuthorizationCodeGrantRequest *tokenRequest = [self.oauthFactory authorizationGrantRequestWithRequestParameters:self.requestParameters
                                                                                                           codeVerifier:self.webViewConfiguration.pkce.codeVerifier
                                                                                                               authCode:authCode
                                                                                                          homeAccountId:self.authCodeClientInfo.accountIdentifier];

    [tokenRequest sendWithBlock:^(MSIDTokenResponse *tokenResponse, NSError *error)
    {
#if TARGET_OS_OSX
        self.tokenResponseHandler.externalCacheSeeder = self.externalCacheSeeder;
#endif
        [self.tokenResponseHandler handleTokenResponse:tokenResponse
                                     requestParameters:self.requestParameters
                                         homeAccountId:self.authCodeClientInfo.accountIdentifier
                                tokenResponseValidator:self.tokenResponseValidator
                                          oauthFactory:self.oauthFactory
                                            tokenCache:self.tokenCache
                                  accountMetadataCache:self.accountMetadataCache
                                       validateAccount:self.requestParameters.shouldValidateResultAccount
                                      saveSSOStateOnly:NO
                                                 error:error
                                       completionBlock:^(MSIDTokenResult *result, NSError *error)
         {
            completionBlock(result, error, nil);
        }];
    }];
}

@end
