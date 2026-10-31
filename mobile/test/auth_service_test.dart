import 'dart:async';
import 'package:firebase_auth_mocks/firebase_auth_mocks.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:budget_tracking/services/auth_service.dart';
import 'package:budget_tracking/utils/connectivity_error.dart';

/// Simula el SDK intentando refrescar el token sin conexión: nunca resuelve.
// ignore: must_be_immutable
class _HangingTokenUser extends MockUser {
  _HangingTokenUser() : super(uid: 'u1', email: 'a@b.com');

  @override
  Future<String> getIdToken([bool forceRefresh = false]) => Completer<String>().future;
}

void main() {
  test('getToken devuelve el token del usuario actual', () async {
    final auth = AuthService(auth: MockFirebaseAuth(signedIn: true, mockUser: MockUser(uid: 'u1', email: 'a@b.com')));

    expect(await auth.getToken(), isNotNull);
  });

  test('getToken devuelve null sin usuario', () async {
    final auth = AuthService(auth: MockFirebaseAuth(signedIn: false));

    expect(await auth.getToken(), isNull);
  });

  // Regresión #81: sin timeout, un refresh colgado dejaba Inicio cargando para siempre.
  test('getToken no se cuelga: lanza TimeoutException reconocida como error de conectividad', () async {
    final auth = AuthService(
      auth: MockFirebaseAuth(signedIn: true, mockUser: _HangingTokenUser()),
      tokenTimeout: const Duration(milliseconds: 50),
    );

    await expectLater(
      auth.getToken(),
      throwsA(predicate((e) => e is TimeoutException && isConnectivityError(e))),
    );
  });
}
