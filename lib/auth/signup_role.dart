// Todos los usuarios de Corvus Aeternum son Cuervos (artistas).
// El enum se conserva para no romper firmas existentes, pero solo
// expone un único valor.
enum SignupRole { crow }

extension SignupRoleX on SignupRole {
  String get code => name; // 'crow'

  String get label => 'Cuervo';
}
