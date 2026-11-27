import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../services/storage_service.dart';
import '../domain/negocio.dart';
import '../domain/user_profile.dart';

class AuthProvider extends ChangeNotifier {
  final SupabaseClient _supabase = Supabase.instance.client;
  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();
  final StorageService _storageService = StorageService();

  bool _isLoading = false;
  String? _errorMessage;
  UserProfile? _userProfile;
  Negocio? _negocio;
  String _activeRole = 'VECINO'; // 'VECINO' or 'EMPRENDEDOR'
  bool _needsBusinessRegistration = false;
  int? _vecinoTabInicial;
  String? _pedidoDestacadoId;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  UserProfile? get userProfile => _userProfile;
  Negocio? get negocio => _negocio;
  String get activeRole => _activeRole;
  bool get needsBusinessRegistration => _needsBusinessRegistration;
  int? get vecinoTabInicial => _vecinoTabInicial;
  String? get pedidoDestacadoId => _pedidoDestacadoId;

  void consumirTabInicial() {
    _vecinoTabInicial = null;
  }

  void seleccionarTabVecino(int tabIndex, {String? pedidoId}) {
    _vecinoTabInicial = tabIndex;
    _pedidoDestacadoId = pedidoId;
    notifyListeners();
  }

  void consumirPedidoDestacado() {
    _pedidoDestacadoId = null;
  }

  bool get isAuthenticated =>
      _supabase.auth.currentUser != null && _userProfile != null;

  Future<UserProfile> _perfilConFotosFirmadas(UserProfile profile) async {
    Future<String> firmar(String path) => path.isEmpty
        ? Future.value('')
        : _storageService.createKycSignedUrl(path);

    final fotos = await Future.wait<String>([
      firmar(profile.selfieUrl),
      firmar(profile.facadeUrl),
      firmar(profile.ciAnversoUrl),
      firmar(profile.ciReversoUrl),
    ]);

    return profile.copyWith(
      selfieUrl: fotos[0],
      facadeUrl: fotos[1],
      ciAnversoUrl: fotos[2],
      ciReversoUrl: fotos[3],
      avatarUrl: profile.avatarPath == null || profile.avatarPath!.isEmpty
          ? null
          : _storageService.getProfileAvatarUrl(profile.avatarPath!),
    );
  }

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void resetBusinessRegistrationFlag() {
    _needsBusinessRegistration = false;
  }

  void actualizarNegocio(Negocio negocioActualizado) {
    _negocio = negocioActualizado;
    notifyListeners();
  }

  Future<void> _validarFotosRegistro({
    required XFile selfie,
    required XFile facade,
    required XFile ciAnverso,
    required XFile ciReverso,
  }) async {
    final fotos = <MapEntry<String, XFile>>[
      MapEntry('C.I. Anverso', ciAnverso),
      MapEntry('C.I. Reverso', ciReverso),
      MapEntry('selfie', selfie),
      MapEntry('fachada', facade),
    ];

    for (final foto in fotos) {
      if (await foto.value.length() == 0) {
        throw 'La foto de ${foto.key} es obligatoria y no puede estar vacía.';
      }
    }
  }

  Future<void> restaurarSesion() async {
    _isLoading = true;
    notifyListeners();

    try {
      final session = _supabase.auth.currentSession;
      if (session != null) {
        final userId = session.user.id;

        await _secureStorage.write(
          key: 'supabase_token',
          value: session.accessToken,
        );

        final profileRes = await _supabase
            .from('perfiles')
            .select()
            .eq('id', userId)
            .maybeSingle();
        if (profileRes != null) {
          _userProfile = await _perfilConFotosFirmadas(
            UserProfile.fromMap(profileRes),
          );
          _activeRole = 'VECINO'; // Force initial active role to 'VECINO'
        }

        final negocioRes = await _supabase
            .from('negocios')
            .select()
            .eq('owner_id', userId)
            .maybeSingle();
        if (negocioRes != null) {
          _negocio = Negocio.fromMap(negocioRes);
        }
      }
    } catch (e) {
      _errorMessage = 'Error al restaurar sesión: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<bool> registrarUsuario({
    required String email,
    required String password,
    required String nombre,
    required String ci,
    required String telefono,
    required XFile selfie,
    required XFile facade,
    required XFile ciAnverso,
    required XFile ciReverso,
    required double lat,
    required double lng,
    required String termsVersion,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      await _validarFotosRegistro(
        selfie: selfie,
        facade: facade,
        ciAnverso: ciAnverso,
        ciReverso: ciReverso,
      );

      final authResponse = await _supabase.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
      );

      final user = authResponse.user;
      if (user == null) throw 'No se pudo crear el usuario en autenticación.';
      final userId = user.id;

      if (_supabase.auth.currentSession == null) {
        await _supabase.auth.signInWithPassword(
          email: email.trim().toLowerCase(),
          password: password,
        );
      }
      if (_supabase.auth.currentUser?.id != userId) {
        throw 'Inicia sesión con la cuenta recién creada para continuar el registro.';
      }

      final ciAnversoUrl = await _storageService.uploadImage(
        ciAnverso,
        'kyc_docs',
        userId,
        customFileName: '$userId/ci_anverso.jpg',
      );
      final ciReversoUrl = await _storageService.uploadImage(
        ciReverso,
        'kyc_docs',
        userId,
        customFileName: '$userId/ci_reverso.jpg',
      );
      final selfieUrl = await _storageService.uploadImage(
        selfie,
        'kyc_docs',
        userId,
        customFileName: '$userId/selfie.jpg',
      );
      final facadeUrl = await _storageService.uploadImage(
        facade,
        'kyc_docs',
        userId,
        customFileName: '$userId/facade.jpg',
      );

      final profileData = {
        'id': userId,
        'email': email.trim().toLowerCase(),
        'nombre': nombre.trim(),
        'ci': ci.trim(),
        'telefono': telefono.trim(),
        'selfie_url': selfieUrl,
        'facade_url': facadeUrl,
        'ci_anverso_url': ciAnversoUrl,
        'ci_reverso_url': ciReversoUrl,
        'lat': lat,
        'lng': lng,
        'active_role': 'VECINO',
        'terms_version': termsVersion,
        'terms_accepted_at': DateTime.now().toUtc().toIso8601String(),
      };

      await _supabase.from('perfiles').insert(profileData);

      final nuevoPerfil = await _perfilConFotosFirmadas(
        UserProfile.fromMap(profileData),
      );
      _userProfile = nuevoPerfil;
      _activeRole = 'VECINO';
      _vecinoTabInicial = 3;

      if (_supabase.auth.currentSession != null) {
        await _secureStorage.write(
          key: 'supabase_token',
          value: _supabase.auth.currentSession!.accessToken,
        );
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<bool> iniciarSesion({
    required String email,
    required String password,
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final response = await _supabase.auth.signInWithPassword(
        email: email.trim().toLowerCase(),
        password: password,
      );

      if (response.session == null || response.user == null) {
        throw 'Credenciales inválidas o sesión no iniciada.';
      }

      await _secureStorage.write(
        key: 'supabase_token',
        value: response.session!.accessToken,
      );

      final userId = response.user!.id;
      final profileRes = await _supabase
          .from('perfiles')
          .select()
          .eq('id', userId)
          .maybeSingle();
      if (profileRes == null) {
        throw 'Perfil de usuario no encontrado en la base de datos.';
      }

      _userProfile = await _perfilConFotosFirmadas(
        UserProfile.fromMap(profileRes),
      );
      _activeRole = 'VECINO';

      final negocioRes = await _supabase
          .from('negocios')
          .select()
          .eq('owner_id', userId)
          .maybeSingle();
      if (negocioRes != null) {
        _negocio = Negocio.fromMap(negocioRes);
      } else {
        _negocio = null;
      }

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  void cambiarRol(String role) {
    if (role == 'EMPRENDEDOR' && _negocio == null) {
      _needsBusinessRegistration = true;
    } else {
      _activeRole = role;
      _needsBusinessRegistration = false;
    }
    notifyListeners();
  }

  Future<void> actualizarFotoPerfilPublica(XFile image) async {
    final profile = _userProfile;
    if (profile == null || profile.id.isEmpty) {
      throw StateError('No hay un perfil autenticado para actualizar.');
    }

    final newPath = await _storageService.uploadProfileAvatar(
      image,
      profile.id,
    );
    String? previousPath;
    try {
      final response = await _supabase.rpc(
        'actualizar_avatar_perfil',
        params: {'p_avatar_path': newPath},
      );
      previousPath = response?.toString();
    } catch (error, stackTrace) {
      try {
        await _storageService.deleteProfileAvatar(newPath, profile.id);
      } catch (cleanupError) {
        Error.throwWithStackTrace(
          StateError(
            'No se pudo guardar la foto de perfil ($error) y tampoco se pudo '
            'limpiar el archivo temporal ($cleanupError).',
          ),
          stackTrace,
        );
      }
      Error.throwWithStackTrace(error, stackTrace);
    }

    _userProfile = profile.copyWith(
      avatarPath: newPath,
      avatarUrl: _storageService.getProfileAvatarUrl(newPath),
    );
    notifyListeners();

    if (previousPath != null &&
        previousPath.isNotEmpty &&
        previousPath != newPath) {
      try {
        await _storageService.deleteProfileAvatar(previousPath, profile.id);
      } catch (error) {
        throw StateError(
          'La nueva foto se guardó, pero no se pudo eliminar la anterior: '
          '$error',
        );
      }
    }
  }

  Future<bool> registrarNegocio({
    required String nombre,
    required String descripcion,
    required XFile storePhoto,
    required XFile qrPhoto,
    required List<String> deliveryOptions,
    required int shippingCost,
    required double lat,
    required double lng,
  }) async {
    if (_userProfile == null) return false;

    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final userId = _userProfile!.id;
      final storeUrl = await _storageService.uploadImage(
        storePhoto,
        'negocios_assets',
        userId,
        customFileName: '$userId/store.jpg',
      );
      final qrUrl = await _storageService.uploadImage(
        qrPhoto,
        'negocios_assets',
        userId,
        customFileName: '$userId/qr.jpg',
      );

      final negocioMap = <String, dynamic>{
        'owner_id': userId,
        'nombre': nombre.trim(),
        'descripcion': descripcion.trim(),
        'lat': lat,
        'lng': lng,
        'store_photo_url': storeUrl,
        'qr_photo_url': qrUrl,
        'delivery_options': deliveryOptions,
        'shipping_cost': shippingCost,
      };

      try {
        final res = await _supabase
            .from('negocios')
            .insert(negocioMap)
            .select()
            .single();
        _negocio = Negocio.fromMap(res);
      } catch (_) {
        final fallbackMap = Map<String, dynamic>.from(negocioMap)
          ..remove('delivery_options')
          ..remove('shipping_cost');
        final res = await _supabase
            .from('negocios')
            .insert(fallbackMap)
            .select()
            .single();
        _negocio = Negocio.fromMap(res).copyWith(
          deliveryOptions: deliveryOptions,
          shippingCost: shippingCost,
        );
      }

      _activeRole = 'EMPRENDEDOR';
      _needsBusinessRegistration = false;

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _errorMessage = e.toString();
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  Future<void> cerrarSesion() async {
    await _supabase.auth.signOut();
    await _secureStorage.delete(key: 'supabase_token');
    _userProfile = null;
    _negocio = null;
    _activeRole = 'VECINO';
    _needsBusinessRegistration = false;
    notifyListeners();
  }
}
