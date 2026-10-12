import 'package:google_sign_in/google_sign_in.dart';

class GoogleAccount {
  final String email, firstName, lastName;
  GoogleAccount(this.email, this.firstName, this.lastName);
}

/// Inicio de sesión con Google. Necesita el proyecto de Firebase / Google Cloud configurado
/// (fase 2). Mientras tanto, si falla, el registro permite escribir el correo a mano.
class AuthService {
  static final _gsi = GoogleSignIn(scopes: ['email', 'profile']);

  static Future<GoogleAccount?> signIn() async {
    try {
      final acc = await _gsi.signIn();
      if (acc == null) return null;
      final parts = (acc.displayName ?? '').trim().split(RegExp(r'\s+'));
      return GoogleAccount(acc.email, parts.isNotEmpty ? parts.first : '', parts.length > 1 ? parts.sublist(1).join(' ') : '');
    } catch (_) {
      return null;
    }
  }

  static Future<void> signOut() async {
    try {
      await _gsi.signOut();
    } catch (_) {}
  }

  /// Respaldo: deduce nombre y apellido del correo (nombre.apellido@gmail.com).
  static GoogleAccount fromEmail(String email) {
    final parts = email.split('@').first.split(RegExp(r'[._-]+')).where((s) => s.isNotEmpty).toList();
    String cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
    return GoogleAccount(email, parts.isNotEmpty ? cap(parts[0]) : '', parts.length > 1 ? cap(parts[1]) : '');
  }
}
