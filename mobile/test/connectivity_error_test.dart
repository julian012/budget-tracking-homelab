import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:budget_tracking/utils/connectivity_error.dart';

void main() {
  test('recognizes connectivity-related exceptions', () {
    expect(isConnectivityError(TimeoutException('x')), isTrue);
    expect(isConnectivityError(const SocketException('x')), isTrue);
    expect(isConnectivityError(http.ClientException('x')), isTrue);
  });

  // Con el token expirado y sin red, el SDK de Firebase no se cuelga: falla
  // rápido con este código (visto en dispositivo real en modo avión, #99).
  test('recognizes Firebase Auth network failures as connectivity errors', () {
    expect(isConnectivityError(FirebaseAuthException(code: 'network-request-failed')), isTrue);
  });

  test('does not flag other Firebase Auth errors as connectivity errors', () {
    expect(isConnectivityError(FirebaseAuthException(code: 'wrong-password')), isFalse);
    expect(isConnectivityError(FirebaseAuthException(code: 'user-disabled')), isFalse);
  });

  test('does not flag business/server errors as connectivity errors', () {
    expect(isConnectivityError(Exception('createExpense failed: 400 categoria ajena')), isFalse);
    expect(isConnectivityError(const FormatException('bad json')), isFalse);
    expect(isConnectivityError('not even an exception'), isFalse);
  });
}
