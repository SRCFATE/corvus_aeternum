enum SignupRole { collector, crow }

extension SignupRoleX on SignupRole {
  String get code => name; // 'collector' | 'crow'

  String get label {
    switch (this) {
      case SignupRole.collector:
        return 'Coleccionista';
      case SignupRole.crow:
        return 'Cuervo';
    }
  }
}
