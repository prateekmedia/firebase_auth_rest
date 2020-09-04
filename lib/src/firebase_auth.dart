import 'package:http/http.dart';

import 'firebase_account.dart';
import 'models/fetch_provider_request.dart';
import 'models/idp_provider.dart';
import 'models/oob_code_request.dart';
import 'models/password_reset_request.dart';
import 'models/signin_request.dart';
import 'rest_api.dart';

/// A Firebase Authentication class, that allows you to log into firebase.
///
/// Provides methods to create new firebase accounts, log a user into
/// firebase and more. Most methods here create an instance of a
/// [FirebaseAccount], which can be used to manage an individual account. All
/// methods provided here are global methods for firebase auth.
class FirebaseAuth {
  final RestApi _api;

  /// The default locale to be used for E-Mails sent by Firebase.
  String locale;

  /// Creates a new firebase auth instance.
  ///
  /// The instance uses [client] and [apiKey] for accessing the Firebase REST
  /// endpoints. If [locale] is specified, it is used to initialize
  /// the [FirebaseAuth.locale] property.
  FirebaseAuth(
    Client client,
    String apiKey, [
    this.locale,
  ]) : _api = RestApi(client, apiKey);

  /// Creates a new firebase auth instance.
  ///
  /// The instance uses the [_api] for accessing the Firebase REST endpoints. If
  /// [locale] is specified, it is used to initialize the [FirebaseAuth.locale]
  /// property.
  FirebaseAuth.api(
    this._api, [
    this.locale,
  ]);

  /// The internally used [RestApi] instance.
  RestApi get api => _api;

  /// Returns a list of all providers that can be used to login.
  ///
  /// The given [email] and [continueUri] are sent to firebase to figure out
  /// which providers can be used. Returns the provider names as in
  /// [IdpProvider.id] or the string `"email"`, if the user can login with the
  /// email and a password.
  ///
  /// If the request fails, an [AuthError] will be thrown.
  Future<List<String>> fetchProviders(
    String email, [
    Uri continueUri,
  ]) async {
    final response = await _api.fetchProviders(FetchProviderRequest(
      identifier: email,
      continueUri: continueUri ?? Uri.http("localhost", ""),
    ));
    return [
      if (response.registered) "email",
      ...response.allProviders,
    ];
  }

  /// Signs up to firebase as an anonymous user.
  ///
  /// This will return a newly created [FirebaseAccount] with no login method
  /// attached. This means, you can only keep using this account by regularly
  /// refreshing the idToken. This happens automatically if [autoRefresh] is
  /// true or via [FirebaseAccount.refresh()].
  ///
  /// If the request fails, an [AuthError] will be thrown. This also happens if
  /// anonymous logins have not been enabled in the firebase console.
  ///
  /// If you ever want to "promote" an anonymous account to a normal account,
  /// you can do so by using [FirebaseAccount.linkEmail()] or
  /// [FirebaseAccount.linkIdp()] to add credentials to the account. This will
  /// preserve any data associated with this account.
  Future<FirebaseAccount> signUpAnonymous({bool autoRefresh = true}) async =>
      FirebaseAccount.apiCreate(
        _api,
        await _api.signUpAnonymous(const AnonymousSignInRequest()),
        autoRefresh: autoRefresh,
        locale: locale,
      );

  /// Signs up to firebase with an email and a password.
  ///
  /// This creates a new firebase account and returns it's credentials as
  /// [FirebaseAccount] if the request succeeds, or throws an [AuthError] if it
  /// fails. From now on, the user can log into this account by using the same
  /// [email] and [password] used for this request via [signInWithPassword()].
  ///
  /// If [autoVerify] is true (the default), this method will also send an email
  /// confirmation request for that email so the users mail can be verified. See
  /// [FirebaseAccount.requestEmailConfirmation()] for more details. The
  /// language of that mail is determined by [locale], if specified,
  /// [FirebaseAuth.locale] otherwise.
  ///
  /// If [autoRefresh] is enabled (the default), the created accounts
  /// [FirebaseAccount.autoRefresh] is set to true as well, wich will start an
  /// automatic token refresh in the background, as soon as the current token
  /// comes close to expiring. See [FirebaseAccount.autoRefresh] for more
  /// details.
  Future<FirebaseAccount> signUpWithPassword(
    String email,
    String password, {
    bool autoVerify = true,
    bool autoRefresh = true,
    String locale,
  }) async {
    final response = await _api.signUpWithPassword(PasswordSignInRequest(
      email: email,
      password: password,
    ));
    if (autoVerify) {
      await _api.sendOobCode(
        OobCodeRequest.verifyEmail(
          idToken: response.idToken,
        ),
        locale ?? this.locale,
      );
    }
    return FirebaseAccount.apiCreate(
      _api,
      response,
      locale: this.locale,
      autoRefresh: autoRefresh,
    );
  }

  /// Signs into firebase with an IDP-Provider.
  ///
  /// This logs the user into firebase by using an [IdpProvider] - aka google,
  /// facebook, twitter, etc. As long as the provider has been enabled in the
  /// firebase console, it can be used. If the passed [provider] and
  /// [requestUri] are valid, the associated firebase account is returned or a
  /// new one gets created. On a failure, an [AuthError] is thrown instead.
  ///
  /// If [autoRefresh] is enabled (the default), the created accounts
  /// [FirebaseAccount.autoRefresh] is set to true as well, wich will start an
  /// automatic token refresh in the background, as soon as the current token
  /// comes close to expiring. See [FirebaseAccount.autoRefresh] for more
  /// details.
  Future<FirebaseAccount> signInWithIdp(
    IdpProvider provider,
    Uri requestUri, {
    bool autoRefresh = true,
  }) async =>
      FirebaseAccount.apiCreate(
        _api,
        await _api.signInWithIdp(IdpSignInRequest(
          postBody: provider.postBody,
          requestUri: requestUri,
        )),
        autoRefresh: autoRefresh,
        locale: locale,
      );

  Future<FirebaseAccount> signInWithPassword(
    String email,
    String password, {
    bool autoRefresh = true,
  }) async =>
      FirebaseAccount.apiCreate(
        _api,
        await _api.signInWithPassword(PasswordSignInRequest(
          email: email,
          password: password,
        )),
        autoRefresh: autoRefresh,
        locale: locale,
      );

  Future<FirebaseAccount> signInWithCustomToken(
    String token, {
    bool autoRefresh = true,
  }) async =>
      FirebaseAccount.apiCreate(
        _api,
        await _api.signInWithCustomToken(CustomTokenSignInRequest(
          token: token,
        )),
        autoRefresh: autoRefresh,
        locale: locale,
      );

  Future requestPasswordReset(
    String email, {
    String locale,
  }) async =>
      _api.sendOobCode(
        OobCodeRequest.passwordReset(email: email),
        locale ?? this.locale,
      );

  Future validatePasswordReset(String oobCode) async =>
      _api.resetPassword(PasswordResetRequest.verify(oobCode: oobCode));

  Future resetPassword(String oobCode, String newPassword) async =>
      _api.resetPassword(PasswordResetRequest.confirm(
        oobCode: oobCode,
        newPassword: newPassword,
      ));
}
