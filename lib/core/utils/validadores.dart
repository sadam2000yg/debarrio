class Validadores {
  static String? validarEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El correo electrónico es requerido';
    }
    final emailRegex = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
    if (!emailRegex.hasMatch(value.trim().toLowerCase())) {
      return 'Ingrese un correo electrónico válido';
    }
    return null;
  }

  static String? validarTelefono(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El teléfono es requerido';
    }
    final clean = value.replaceAll(RegExp(r'\D'), '');
    if (clean.length < 7 || clean.length > 15) {
      return 'El teléfono debe tener entre 7 y 15 dígitos';
    }
    return null;
  }

  static String? validarCi(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'El número de C.I. es requerido';
    }
    if (value.trim().length < 5) {
      return 'El C.I. debe tener al menos 5 caracteres';
    }
    return null;
  }

  static String? validarPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'La contraseña es requerida';
    }
    if (value.length < 8) {
      return 'La contraseña debe tener al menos 8 caracteres';
    }
    return null;
  }

  static String? validarTextoRequerido(String? value, String campo) {
    if (value == null || value.trim().isEmpty) {
      return 'El campo $campo es requerido';
    }
    return null;
  }

  static double? parsearDecimal(String? value) {
    if (value == null || value.trim().isEmpty) return null;
    final normalized = value.trim().replaceAll(',', '.');
    return double.tryParse(normalized);
  }
}
