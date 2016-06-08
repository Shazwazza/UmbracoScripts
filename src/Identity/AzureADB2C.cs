/// <summary>
/// Extension methods used to configure Azure AD B2C OAuth provider for the Umbraco Back Office
/// - This is more or less working but there's many 'questions' I have regarding a few things (see notes)
/// - Parts of this example could work for front-end member implementation with the removal of the /umbraco callback
///     paths and the auto-link stuff.
/// </summary>
/// <example>
/// <![CDATA[
/// 
///     //this would be used in your OWIN startup class
///     app.ConfigureBackOfficeAzureActiveDirectoryA2BAuth(
///         tenant:                 "yourtenantid.onmicrosoft.com",
///         clientId:               "your-client-id-guid",
///         clientSecret:           "yoURClientSECreT",
///         redirectUri:            "https://yourdomain.local/umbraco/",
///         signUpPolicyId:         "YOUR_SIGN_UP_POLICY_NAME",
///         signInPolicyId:         "YOUR_SIGN_IN_POLICY_NAME",
///         userProfilePolicyId:    "YOUR_PROFIL_POLICY_NAME",
///         adminClientId:          "your-admin-client-id-guid",
///         adminClientSecret:      "YouRADminClientSeCRet",
///         caption:                "My cool AD Oauth provider");
/// 
/// ]]>
/// </example>
public static class UmbracoADAuthExtensions
{

	//SEE: https://azure.microsoft.com/en-us/documentation/articles/active-directory-b2c-devquickstarts-web-dotnet/

	// The ACR claim is used to indicate which policy was executed
	public const string AcrClaimType = "http://schemas.microsoft.com/claims/authnclassreference";
	public const string PolicyKey = "b2cpolicy";
	public const string OIDCMetadataSuffix = "/.well-known/openid-configuration";
	public const string AADInstance = "https://login.microsoftonline.com/{0}{1}{2}";

	public static void ConfigureBackOfficeAzureActiveDirectoryA2BAuth(this IAppBuilder app, 
		string tenant, 
		string clientId, 
		string clientSecret, 
		string redirectUri, 
		string signUpPolicyId, 
		string signInPolicyId, 
		string userProfilePolicyId,
		
		string adminClientId,
		string adminClientSecret,
		
		//Guid issuerId,
		string caption = "Active Directory", string style = "btn-microsoft", string icon = "fa-windows")
	{

		//ORIGINAL OPTIONS SUPPLIED BY SAMPLE B2C APP

		//var options = new OpenIdConnectAuthenticationOptions
		//{
		//    // These are standard OpenID Connect parameters, with values pulled from web.config
		//    ClientId = clientId,
		//    RedirectUri = redirectUri,
		//    PostLogoutRedirectUri = redirectUri,
		//    Notifications = new OpenIdConnectAuthenticationNotifications
		//    {
		//        AuthenticationFailed = AuthenticationFailed,
		//        RedirectToIdentityProvider = OnRedirectToIdentityProvider,
		//    },
		//    Scope = "openid",
		//    ResponseType = "id_token",

		//    // The PolicyConfigurationManager takes care of getting the correct Azure AD authentication
		//    // endpoints from the OpenID Connect metadata endpoint.  It is included in the PolicyAuthHelpers folder.
		//    ConfigurationManager = new PolicyConfigurationManager(
		//        string.Format(CultureInfo.InvariantCulture, AADInstance, tenant, "/v2.0", OIDCMetadataSuffix),
		//        new string[] { signUpPolicyId, signInPolicyId, userProfilePolicyId }),

		//    // This piece is optional - it is used for displaying the user's name in the navigation bar.
		//    TokenValidationParameters = new TokenValidationParameters
		//    {
		//        NameClaimType = "name"
		//    },
		//};

		var adOptions = new OpenIdConnectAuthenticationOptions
		{                         
			ClientId = clientId,                
			RedirectUri = redirectUri,
			PostLogoutRedirectUri = redirectUri,
			Notifications = new OpenIdConnectAuthenticationNotifications
			{
				//AuthenticationFailed = AuthenticationFailed,
				RedirectToIdentityProvider = OnRedirectToIdentityProvider,

				////When the user is authorized and we are not asking for an id_token (see way below for details on that),
				//// we will get an auth code which we can then use to retrieve information about the user.
				//AuthorizationCodeReceived = async notification =>
				//{
				//    // The user's objectId is extracted from the claims provided in the id_token, and used to cache tokens in ADAL
				//    // The authority is constructed by appending your B2C directory's name to "https://login.microsoftonline.com/"
				//    // The client credential is where you provide your application secret, and is used to authenticate the application to Azure AD
				//    var userObjectId = notification.AuthenticationTicket.Identity.FindFirst("http://schemas.microsoft.com/identity/claims/objectidentifier").Value;
				//    var authority = string.Format(CultureInfo.InvariantCulture, AADInstance, tenant, string.Empty, string.Empty);
				//    var credential = new ClientCredential(clientId, clientSecret);

				//    // We don't care which policy is used to access the TaskService, so let's use the most recent policy as indicated in the sign-in token
				//    var mostRecentPolicy = notification.AuthenticationTicket.Identity.FindFirst(AcrClaimType).Value;

				//    // The Authentication Context is ADAL's primary class, which represents your connection to your B2C directory
				//    // ADAL uses an in-memory token cache by default.  In this case, we've extended the default cache to use a simple per-user session cache
				//    var authContext = new AuthenticationContext(authority, new NaiveSessionCache(userObjectId));

				//    // Here you ask for a token using the web app's clientId as the scope, since the web app and service share the same clientId.
				//    // The token will be stored in the ADAL token cache, for use in our controllers
				//    var result = await authContext.AcquireTokenByAuthorizationCodeAsync(notification.Code, new Uri(redirectUri), credential, new string[] { clientId }, mostRecentPolicy);

				//    //var userDetails = await GetUserByObjectId(result, userObjectId, tenant, clientId, clientSecret);

				//    var asdf = result;
				//},
				MessageReceived = notification =>
				{
					return Task.FromResult(0);
				},
				SecurityTokenReceived = notification =>
				{
					return Task.FromResult(0);
				},
				SecurityTokenValidated = notification =>
				{
					//var userObjectId = notification.AuthenticationTicket.Identity.FindFirst("http://schemas.microsoft.com/identity/claims/objectidentifier").Value;
					//var authority = string.Format(CultureInfo.InvariantCulture, AADInstance, tenant, string.Empty, string.Empty);
					//var credential = new ClientCredential(clientId, clientSecret);

					// We don't care which policy is used to access the TaskService, so let's use the most recent policy
					//var mostRecentPolicy = notification.AuthenticationTicket.Identity.FindFirst(AcrClaimType).Value;

					// Here you ask for a token using the web app's clientId as the scope, since the web app and service share the same clientId.
					// AcquireTokenSilentAsync will return a token from the token cache, and throw an exception if it cannot do so.
					//var authContext = new AuthenticationContext(authority, new NaiveSessionCache(userObjectId));

					//var result = await authContext.AcquireTokenSilentAsync(new string[] { clientId }, credential, UserIdentifier.AnyUser, mostRecentPolicy);

					// Here you ask for a token using the web app's clientId as the scope, since the web app and service share the same clientId.
					// The token will be stored in the ADAL token cache, for use in our controllers
					//var result = await authContext.AcquireTokenByAuthorizationCodeAsync(notification.Code, new Uri(redirectUri), credential, new string[] { clientId }, mostRecentPolicy);

					//var asdf = result;



					//The returned identity doesn't actually have 'email' as a claim, but instead has a collection of "emails", so we're going to ensure one is 
					// in there and then set the Email claim to be the first so that auto-signin works
					var emails = notification.AuthenticationTicket.Identity.FindFirst("emails");
					if (emails != null)
					{
						var email = emails.Value;
						notification.AuthenticationTicket.Identity.AddClaim(new Claim(ClaimTypes.Email, email));
					}
					

					return Task.FromResult(0);
				}                    
			},

			//NOTE: in this article they are requesting this scope: https://azure.microsoft.com/en-us/documentation/articles/active-directory-b2c-devquickstarts-web-api-dotnet/
			// I'm unsure if we leave off the offline_access part if we'd get an authcode request back or not, so leaving it here
			// for now since it is working.
			//Scope = "openid offline_access",

			Scope = "openid",

			//NOTE: If we ask for this, then we'll simply get an ID Token back which we cannot use to request
			// additional data of the user. We need to get an authorization code reponse (I'm not sure what the 
			// string value for that is but if we don't specify then it's the default). 
			ResponseType = "id_token",

			// The PolicyConfigurationManager takes care of getting the correct Azure AD authentication
			// endpoints from the OpenID Connect metadata endpoint.  It is included in the PolicyAuthHelpers folder.
			// The first parameter is the metadata URL of your B2C directory
			// The second parameter is an array of the policies that your app will use.
			ConfigurationManager = new PolicyConfigurationManager(
				string.Format(CultureInfo.InvariantCulture, AADInstance, tenant, "/v2.0", OIDCMetadataSuffix),
				new string[] { signUpPolicyId, signInPolicyId, userProfilePolicyId }),

			// This piece is optional - it is used for displaying the user's name in the navigation bar.
			TokenValidationParameters = new TokenValidationParameters
			{
				NameClaimType = "name",
			},

			SignInAsAuthenticationType = Umbraco.Core.Constants.Security.BackOfficeExternalAuthenticationType
		};

		adOptions.SetChallengeResultCallback(context => new AuthenticationProperties(
			new Dictionary<string, string>
			{
				{UmbracoADAuthExtensions.PolicyKey, signInPolicyId}
			})
		{
			RedirectUri = "/Umbraco",
		});
		
		var orig = adOptions.AuthenticationType;
		adOptions.ForUmbracoBackOffice(style, icon);
		adOptions.AuthenticationType = orig;

		adOptions.Caption = caption;

		//NOTE: This needs to be set after the ForUmbracoBackOffice
		// this needs to be set to what AD returns otherwise you cannot unlink an account
		adOptions.AuthenticationType = string.Format(
			CultureInfo.InvariantCulture,
			"https://login.microsoftonline.com/{0}/v2.0/",
			//Not sure where this comes from! ... perhaps 'issuerId', but i don't know where to find this,
			// i just know this based on the response we get from B2C
			"ae25bf5e-871e-454a-a1b6-a3560a09ec5e");

		//This will auto-create users based on the authenticated user if they are new
		//NOTE: This needs to be set after the explicit auth type is set
		adOptions.SetExternalSignInAutoLinkOptions(new ExternalSignInAutoLinkOptions(autoLinkExternalAccount: true));

		app.UseOpenIdConnectAuthentication(adOptions);            
	}
	
	// This notification can be used to manipulate the OIDC request before it is sent.  Here we use it to send the correct policy.
	private static async Task OnRedirectToIdentityProvider(RedirectToIdentityProviderNotification<OpenIdConnectMessage, OpenIdConnectAuthenticationOptions> notification)
	{
		PolicyConfigurationManager mgr = notification.Options.ConfigurationManager as PolicyConfigurationManager;
		if (notification.ProtocolMessage.RequestType == OpenIdConnectRequestType.LogoutRequest)
		{
			OpenIdConnectConfiguration config = await mgr.GetConfigurationByPolicyAsync(CancellationToken.None, notification.OwinContext.Authentication.AuthenticationResponseRevoke.Properties.Dictionary[UmbracoADAuthExtensions.PolicyKey]);
			notification.ProtocolMessage.IssuerAddress = config.EndSessionEndpoint;
		}
		else
		{
			OpenIdConnectConfiguration config = await mgr.GetConfigurationByPolicyAsync(CancellationToken.None, notification.OwinContext.Authentication.AuthenticationResponseChallenge.Properties.Dictionary[UmbracoADAuthExtensions.PolicyKey]);
			notification.ProtocolMessage.IssuerAddress = config.AuthorizationEndpoint;
		}
	}

	//// Used for avoiding yellow-screen-of-death
	//private static Task AuthenticationFailed(AuthenticationFailedNotification<OpenIdConnectMessage, OpenIdConnectAuthenticationOptions> notification)
	//{
	//    notification.HandleResponse();
	//    notification.Response.Redirect("/Home/Error?message=" + notification.Exception.Message);
	//    return Task.FromResult(0);
	//}

	public static async Task<string> GetUserByObjectId(AuthenticationResult authResult, string objectId, string tenant, string adminClientId, string adminClientSecret)
	{
		return await SendGraphGetRequest(authResult, "/users/" + objectId, null, tenant, adminClientId, adminClientSecret);
	}

	public static async Task<string> SendGraphGetRequest(AuthenticationResult authResult, string api, string query, string tenant, string adminClientId, string adminClientSecret)
	{
		var authContext = new Microsoft.IdentityModel.Clients.ActiveDirectory.AuthenticationContext("https://login.microsoftonline.com/" + tenant);
		var credential = new Microsoft.IdentityModel.Clients.ActiveDirectory.ClientCredential(adminClientId, adminClientSecret);

		// Here you ask for a token using the web app's clientId as the scope, since the web app and service share the same clientId.
		// AcquireTokenSilentAsync will return a token from the token cache, and throw an exception if it cannot do so.
		//var authContext = new AuthenticationContext(authority, new NaiveSessionCache(userObjectId));

		//// We don't care which policy is used to access the TaskService, so let's use the most recent policy
		//var mostRecentPolicy = authTicket.Identity.FindFirst(AcrClaimType).Value;
		//var result = await authContext.AcquireTokenSilentAsync(new string[] { clientId }, credential, UserIdentifier.AnyUser, mostRecentPolicy);

		//// First, use ADAL to acquire a token using the app's identity (the credential)
		//// The first parameter is the resource we want an access_token for; in this case, the Graph API.
		var result = authContext.AcquireToken("https://graph.windows.net", credential);

		// For B2C user managment, be sure to use the beta Graph API version.
		var http = new HttpClient();
		var url = "https://graph.windows.net/" + tenant + api + "?" + "api-version=beta";
		if (!string.IsNullOrEmpty(query))
		{
			url += "&" + query;
		}

		//Console.ForegroundColor = ConsoleColor.Cyan;
		//Console.WriteLine("GET " + url);
		//Console.WriteLine("Authorization: Bearer " + result.AccessToken.Substring(0, 80) + "...");
		//Console.WriteLine("");

		// Append the access token for the Graph API to the Authorization header of the request, using the Bearer scheme.
		var request = new HttpRequestMessage(HttpMethod.Get, url);
		//request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", authResult.Token);
		request.Headers.Authorization = new AuthenticationHeaderValue("Bearer", result.AccessToken);
		var response = await http.SendAsync(request);

		if (!response.IsSuccessStatusCode)
		{
			string error = await response.Content.ReadAsStringAsync();
			object formatted = JsonConvert.DeserializeObject(error);
			throw new WebException("Error Calling the Graph API: \n" + JsonConvert.SerializeObject(formatted, Formatting.Indented));
		}

		//Console.ForegroundColor = ConsoleColor.Green;
		//Console.WriteLine((int)response.StatusCode + ": " + response.ReasonPhrase);
		//Console.WriteLine("");

		return await response.Content.ReadAsStringAsync();
	}

}

public class NaiveSessionCache : TokenCache
{
	private static readonly object FileLock = new object();
	string UserObjectId = string.Empty;
	string CacheId = string.Empty;
	public NaiveSessionCache(string userId)
	{
		UserObjectId = userId;
		CacheId = UserObjectId + "_TokenCache";

		this.AfterAccess = AfterAccessNotification;
		this.BeforeAccess = BeforeAccessNotification;
		Load();
	}

	public void Load()
	{
		lock (FileLock)
		{
			this.Deserialize((byte[])HttpContext.Current.Session[CacheId]);
		}
	}

	public void Persist()
	{
		lock (FileLock)
		{
			// reflect changes in the persistent store
			HttpContext.Current.Session[CacheId] = this.Serialize();
			// once the write operation took place, restore the HasStateChanged bit to false
			this.HasStateChanged = false;
		}
	}

	// Empties the persistent store.
	public override void Clear()
	{
		base.Clear();
		System.Web.HttpContext.Current.Session.Remove(CacheId);
	}

	public override void DeleteItem(TokenCacheItem item)
	{
		base.DeleteItem(item);
		Persist();
	}

	// Triggered right before ADAL needs to access the cache.
	// Reload the cache from the persistent store in case it changed since the last access.
	void BeforeAccessNotification(TokenCacheNotificationArgs args)
	{
		Load();
	}

	// Triggered right after ADAL accessed the cache.
	void AfterAccessNotification(TokenCacheNotificationArgs args)
	{
		// if the access operation resulted in a cache update
		if (this.HasStateChanged)
		{
			Persist();
		}
	}
}
