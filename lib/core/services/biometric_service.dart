import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

class BiometricService {
  BiometricService._();
  static final BiometricService instance = BiometricService._();

  final LocalAuthentication _auth = LocalAuthentication();
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  static const String _keyEmail = 'biometric_email';
  static const String _keyPassword = 'biometric_password';
  static const String _keyEnabled = 'biometric_enabled';

  /// Check if hardware supports biometrics and user has enrolled fingerprint / face
  Future<bool> canAuthenticate() async {
    try {
      final bool canAuthenticateWithBiometrics = await _auth.canCheckBiometrics;
      final bool isDeviceSupported = await _auth.isDeviceSupported();
      return canAuthenticateWithBiometrics || isDeviceSupported;
    } catch (e) {
      debugPrint('Biometric check error: $e');
      return false;
    }
  }

  /// Get available biometric hardware type (FaceID vs Fingerprint)
  Future<BiometricType?> getPrimaryBiometricType() async {
    try {
      final available = await _auth.getAvailableBiometrics();
      if (available.contains(BiometricType.face)) {
        return BiometricType.face;
      } else if (available.contains(BiometricType.fingerprint) || available.contains(BiometricType.strong)) {
        return BiometricType.fingerprint;
      }
    } catch (e) {
      debugPrint('Error getting biometric type: $e');
    }
    return null;
  }

  /// Triggers native OS biometric prompt (Fingerprint / TouchID / FaceID)
  Future<bool> authenticate({String reason = 'Scan your fingerprint or face to sign in to Darzi Pro'}) async {
    try {
      final bool canAuth = await canAuthenticate();
      if (!canAuth) return false;

      return await _auth.authenticate(
        localizedReason: reason,
      );

    } on PlatformException catch (e) {
      debugPrint('Biometric auth platform error: $e');
      return false;
    } catch (e) {
      debugPrint('Biometric auth error: $e');
      return false;
    }
  }

  /// Securely save credentials for biometric quick login
  Future<void> saveCredentials({required String email, required String password}) async {
    try {
      await _storage.write(key: _keyEmail, value: email);
      await _storage.write(key: _keyPassword, value: password);
      await _storage.write(key: _keyEnabled, value: 'true');
    } catch (e) {
      debugPrint('Error saving biometric credentials: $e');
    }
  }

  /// Check if credentials are stored securely
  Future<bool> hasSavedCredentials() async {
    try {
      final email = await _storage.read(key: _keyEmail);
      final password = await _storage.read(key: _keyPassword);
      final enabled = await _storage.read(key: _keyEnabled);
      return enabled == 'true' && email != null && email.isNotEmpty && password != null && password.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  /// Retrieve stored credentials for quick login
  Future<Map<String, String>?> getSavedCredentials() async {
    try {
      final email = await _storage.read(key: _keyEmail);
      final password = await _storage.read(key: _keyPassword);
      if (email != null && email.isNotEmpty && password != null && password.isNotEmpty) {
        return {'email': email, 'password': password};
      }
    } catch (e) {
      debugPrint('Error reading biometric credentials: $e');
    }
    return null;
  }

  /// Clear stored credentials
  Future<void> clearCredentials() async {
    try {
      await _storage.delete(key: _keyEmail);
      await _storage.delete(key: _keyPassword);
      await _storage.delete(key: _keyEnabled);
    } catch (e) {
      debugPrint('Error clearing biometric credentials: $e');
    }
  }
}
