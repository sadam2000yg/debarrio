class Moderacion {
  static const Set<String> _palabrasOfensivas = {
    'puta',
    'puto',
    'putas',
    'putos',
    'mierda',
    'mierdas',
    'joder',
    'jodido',
    'jodida',
    'jodidos',
    'jodidas',
    'jodiendo',
    'coño',
    'coños',
    'cabron',
    'cabrona',
    'cabrones',
    'cabronas',
    'pendejo',
    'pendeja',
    'pendejos',
    'pendejas',
    'idiota',
    'idiotas',
    'imbecil',
    'imbeciles',
    'verga',
    'vergas',
    'chingar',
    'chinga',
    'chingada',
    'chingado',
    'chingados',
    'chingadas',
    'hijueputa',
    'malparido',
    'malparida',
    'fuck',
    'fucking',
    'shit',
    'bitch',
    'asshole',
  };

  static String? validarComentario(String comentario) {
    final normalizado = _normalizarComentario(comentario);

    for (final palabra in _palabrasOfensivas) {
      final letrasSeparadas = palabra
          .split('')
          .map(RegExp.escape)
          .join(r'[^a-z0-9ñ]*');
      final patron =
          '(^|[^a-z0-9ñ])$letrasSeparadas'
          r'($|[^a-z0-9ñ])';
      if (RegExp(patron).hasMatch(normalizado)) {
        return 'Reseña cancelada. No se publicó por el uso de malas palabras.';
      }
    }

    return null;
  }

  static String _normalizarComentario(String comentario) {
    var normalizado = comentario.toLowerCase();
    const equivalencias = {
      'á': 'a',
      'à': 'a',
      'ä': 'a',
      'â': 'a',
      'é': 'e',
      'è': 'e',
      'ë': 'e',
      'ê': 'e',
      'í': 'i',
      'ì': 'i',
      'ï': 'i',
      'î': 'i',
      'ó': 'o',
      'ò': 'o',
      'ö': 'o',
      'ô': 'o',
      'ú': 'u',
      'ù': 'u',
      'ü': 'u',
      'û': 'u',
    };

    for (final equivalencia in equivalencias.entries) {
      normalizado = normalizado.replaceAll(
        equivalencia.key,
        equivalencia.value,
      );
    }

    return normalizado;
  }

  static String? validarReporte({
    required String motivo,
    required String detalle,
  }) {
    if (motivo.trim().length < 3) {
      return 'Selecciona un motivo válido.';
    }
    if (detalle.length > 600) {
      return 'El detalle no puede superar 600 caracteres.';
    }
    return null;
  }

  static bool enfriamientoActivo(DateTime? bloqueadoHasta, DateTime ahora) =>
      bloqueadoHasta != null && bloqueadoHasta.isAfter(ahora);
}
