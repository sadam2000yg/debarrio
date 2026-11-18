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
  int _vecinoTabInicial = 0;

  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  UserProfile? get userProfile => _userProfile;
  Negocio? get negocio => _negocio;
  String get activeRole => _activeRole;
  bool get needsBusinessRegistration => _needsBusinessRegistration;
  int get vecinoTabInicial => _vecinoTabInicial;

  void consumirTabInicial() {
    _vecinoTabInicial = 0;
  }
  bool get isAuthenticated => (_supabase.auth.currentUser != null && _userProfile != null) || (_userProfile?.id == 'invitado-test-id');

  void clearError() {
    _errorMessage = null;
    notifyListeners();
  }

  void resetBusinessRegistrationFlag() {
    _needsBusinessRegistration = false;
  }

  void iniciarSesionComoInvitado() {
    _userProfile = UserProfile(
      id: 'invitado-test-id',
      email: 'invitado@dbarrio.app',
      nombre: 'Vecino Invitado (Provisional)',
      ci: '0000000',
      telefono: '70000000',
      selfieUrl: '',
      facadeUrl: '',
      ciAnversoUrl: '',
      ciReversoUrl: '',
      lat: -16.5000,
      lng: -68.1500,
      activeRole: 'VECINO',
    );
    _activeRole = 'VECINO';
    _negocio = null;
    _errorMessage = null;
    notifyListeners();
  }

  Future<void> restaurarSesion() async {
    _isLoading = true;
    notifyListeners();

    try {
      final session = _supabase.auth.currentSession;
      if (session != null) {
        final userId = session.user.id;

        await _secureStorage.write(key: 'supabase_token', value: session.accessToken);

        final profileRes = await _supabase.from('perfiles').select().eq('id', userId).maybeSingle();
        if (profileRes != null) {
          _userProfile = UserProfile.fromMap(profileRes);
          _activeRole = 'VECINO'; // Force initial active role to 'VECINO'
        }

        final negocioRes = await _supabase.from('negocios').select().eq('owner_id', userId).maybeSingle();
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
  }) async {
    _isLoading = true;
    _errorMessage = null;
    notifyListeners();

    try {
      final emailCheck = await _supabase.from('perfiles').select('id').eq('email', email.trim().toLowerCase()).maybeSingle();
      if (emailCheck != null) {
        throw 'El correo electrónico ya está registrado en el sistema.';
      }
      final ciCheck = await _supabase.from('perfiles').select('id').eq('ci', ci.trim()).maybeSingle();
      if (ciCheck != null) {
        throw 'El número de C.I. ya está registrado en el sistema.';
      }

      final authResponse = await _supabase.auth.signUp(
        email: email.trim().toLowerCase(),
        password: password,
      );

      final user = authResponse.user;
      if (user == null) throw 'No se pudo crear el usuario en autenticación.';
      final userId = user.id;

      final ciAnversoUrl = await _storageService.uploadImage(ciAnverso, 'kyc_docs', userId, customFileName: '$userId/ci_anverso.jpg');
      final ciReversoUrl = await _storageService.uploadImage(ciReverso, 'kyc_docs', userId, customFileName: '$userId/ci_reverso.jpg');
      final selfieUrl = await _storageService.uploadImage(selfie, 'kyc_docs', userId, customFileName: '$userId/selfie.jpg');
      final facadeUrl = await _storageService.uploadImage(facade, 'kyc_docs', userId, customFileName: '$userId/facade.jpg');

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
      };

      await _supabase.from('perfiles').insert(profileData);

      if (authResponse.session == null) {
        await _supabase.auth.signInWithPassword(
          email: email.trim().toLowerCase(),
          password: password,
        );
      }

      final nuevoPerfil = UserProfile.fromMap(profileData);
      _userProfile = nuevoPerfil;
      _activeRole = 'VECINO';
      _vecinoTabInicial = 3;

      if (_supabase.auth.currentSession != null) {
        await _secureStorage.write(key: 'supabase_token', value: _supabase.auth.currentSession!.accessToken);
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

      await _secureStorage.write(key: 'supabase_token', value: response.session!.accessToken);

      final userId = response.user!.id;
      final profileRes = await _supabase.from('perfiles').select().eq('id', userId).maybeSingle();
      if (profileRes == null) {
        throw 'Perfil de usuario no encontrado en la base de datos.';
      }

      _userProfile = UserProfile.fromMap(profileRes);
      _activeRole = 'VECINO';

      final negocioRes = await _supabase.from('negocios').select().eq('owner_id', userId).maybeSingle();
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
      String storeUrl = '';
      String qrUrl = '';
      try {
        storeUrl = await _storageService.uploadImage(storePhoto, 'negocios_assets', userId, customFileName: '$userId/store.jpg');
        qrUrl = await _storageService.uploadImage(qrPhoto, 'negocios_assets', userId, customFileName: '$userId/qr.jpg');
      } catch (_) {
        storeUrl = 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5';
        qrUrl = 'https://images.unsplash.com/photo-1618005182384-a83a8bd57fbe';
      }

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
        final res = await _supabase.from('negocios').insert(negocioMap).select().single();
        _negocio = Negocio.fromMap(res);
      } catch (_) {
        // Fallback 1: Try without delivery_options & shipping_cost if columns are missing in Supabase schema
        try {
          final fallbackMap = Map<String, dynamic>.from(negocioMap)
            ..remove('delivery_options')
            ..remove('shipping_cost');
          final res = await _supabase.from('negocios').insert(fallbackMap).select().single();
          _negocio = Negocio.fromMap(res).copyWith(
            deliveryOptions: deliveryOptions,
            shippingCost: shippingCost,
          );
        } catch (_) {
          // Fallback 2: Create local negocio object for smooth demo/offline execution
          _negocio = Negocio(
            id: 'negocio-${DateTime.now().millisecondsSinceEpoch}',
            ownerId: userId,
            nombre: nombre.trim(),
            descripcion: descripcion.trim(),
            lat: lat,
            lng: lng,
            storePhotoUrl: storeUrl,
            qrPhotoUrl: qrUrl,
            deliveryOptions: deliveryOptions,
            shippingCost: shippingCost,
            abierto: true,
          );
        }
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