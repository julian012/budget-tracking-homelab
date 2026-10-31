import 'dart:async';
import 'dart:io';
import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:http/http.dart' as http;

/// True si [e] es un error de conectividad real (sin señal, timeout, servidor
/// inalcanzable) — no un error de negocio devuelto por el backend (esos sí
/// llegaron al servidor y no deben tratarse como "sin conexión").
///
/// Incluye `network-request-failed` de Firebase Auth: con el token expirado y
/// sin red, `getIdToken()` falla rápido con ese código en vez de colgarse.
bool isConnectivityError(Object e) =>
    e is TimeoutException ||
    e is SocketException ||
    e is http.ClientException ||
    (e is FirebaseAuthException && e.code == 'network-request-failed');
