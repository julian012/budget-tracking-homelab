import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';

// OAuth client ID de tipo WEB del proyecto (google-services.json →
// oauth_client client_type 3). google_sign_in 7.x en Android lo exige en
// initialize() para obtener el idToken con el que Firebase arma la credencial.
// Es un identificador público (no un secreto); el secreto vive server-side.
//
// Definilo en build (no lo hardcodees):
//   flutter run --dart-define=GOOGLE_SERVER_CLIENT_ID=xxxx.apps.googleusercontent.com
const _googleServerClientId = String.fromEnvironment('GOOGLE_SERVER_CLIENT_ID');

class AuthService {
  final FirebaseAuth _auth;
  final GoogleSignIn _googleSignIn;
  final Duration tokenTimeout;
  bool _googleInitialized = false;

  AuthService({
    FirebaseAuth? auth,
    GoogleSignIn? googleSignIn,
    this.tokenTimeout = const Duration(seconds: 10),
  }) : _auth = auth ?? FirebaseAuth.instance,
       _googleSignIn = googleSignIn ?? GoogleSignIn.instance;

  User? get currentUser => _auth.currentUser;

  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential> signInWithEmail(String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<UserCredential> signUpWithEmail(String email, String password) async {
    return await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// En google_sign_in 7.x [authenticate] lanza en vez de devolver null cuando
  /// el usuario cancela; se traduce `canceled` a `null` para que login_screen
  /// siga tratando el cancel como "no pasó nada" (comportamiento de la 6.x).
  Future<UserCredential?> signInWithGoogle() async {
    try {
      if (!_googleInitialized) {
        if (_googleServerClientId.isEmpty) {
          throw StateError(
            'Falta GOOGLE_SERVER_CLIENT_ID. Compilá con '
            '--dart-define=GOOGLE_SERVER_CLIENT_ID=<web-client-id>',
          );
        }
        await _googleSignIn.initialize(serverClientId: _googleServerClientId);
        _googleInitialized = true;
      }

      final GoogleSignInAccount googleUser = await _googleSignIn.authenticate();
      final GoogleSignInAuthentication googleAuth = googleUser.authentication;

      // En 7.x la credencial Firebase se arma solo con idToken (firmado para
      // el serverClientId); accessToken ya no forma parte de `authentication`.
      final credential = GoogleAuthProvider.credential(
        idToken: googleAuth.idToken,
      );

      return await _auth.signInWithCredential(credential);
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      rethrow;
    }
  }

  /// Si el token expiró, el SDK intenta refrescarlo contra Google; sin conexión
  /// esa llamada puede no resolver nunca y dejar la pantalla cargando para
  /// siempre (#81). Con timeout falla con [TimeoutException], que
  /// `isConnectivityError` reconoce como "sin conexión".
  Future<String?> getToken() async {
    return await _auth.currentUser?.getIdToken().timeout(tokenTimeout);
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
    } catch (_) {
      // En 7.x signOut() siempre toca el platform (antes se cortocircuitaba sin
      // sesión Google). La sesión Firebase es la que controla el acceso a la
      // app: si la pata Google falla, el logout de la app no debe bloquearse.
    }
    await _auth.signOut();
  }
}
