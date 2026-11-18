import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/utils/validadores.dart';
import '../../../core/widgets/ui_kit.dart';
import 'auth_provider.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreController = TextEditingController();
  final _ciController = TextEditingController();
  final _telefonoController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  XFile? _selfieFile;
  XFile? _facadeFile;
  XFile? _ciAnversoFile;
  XFile? _ciReversoFile;
  LatLng _selectedLocation = const LatLng(-16.5000, -68.1500);

  final ImagePicker _picker = ImagePicker();

  @override
  void dispose() {
    _nombreController.dispose();
    _ciController.dispose();
    _telefonoController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _tomarFoto(String tipo) async {
    final XFile? image = await _picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: tipo == 'selfie' ? CameraDevice.front : CameraDevice.rear,
      maxWidth: 1000,
      maxHeight: 1000,
    );
    if (image != null) {
      setState(() {
        if (tipo == 'selfie') _selfieFile = image;
        if (tipo == 'facade') _facadeFile = image;
        if (tipo == 'ciAnverso') _ciAnversoFile = image;
        if (tipo == 'ciReverso') _ciReversoFile = image;
      });
    }
  }

  Future<void> _registrar() async {
    if (!_formKey.currentState!.validate()) return;

    if (_ciAnversoFile == null) {
      Notificaciones.mostrar(context, 'La foto de C.I. Anverso es obligatoria', error: true);
      return;
    }
    if (_ciReversoFile == null) {
      Notificaciones.mostrar(context, 'La foto de C.I. Reverso es obligatoria', error: true);
      return;
    }
    if (_selfieFile == null) {
      Notificaciones.mostrar(context, 'La foto de selfie es obligatoria', error: true);
      return;
    }
    if (_facadeFile == null) {
      Notificaciones.mostrar(context, 'La foto de la fachada es obligatoria', error: true);
      return;
    }

    final authProvider = context.read<AuthProvider>();
    final success = await authProvider.registrarUsuario(
      email: _emailController.text,
      password: _passwordController.text,
      nombre: _nombreController.text,
      ci: _ciController.text,
      telefono: _telefonoController.text,
      selfie: _selfieFile!,
      facade: _facadeFile!,
      ciAnverso: _ciAnversoFile!,
      ciReverso: _ciReversoFile!,
      lat: _selectedLocation.latitude,
      lng: _selectedLocation.longitude,
    );

    if (success && mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      Notificaciones.mostrar(context, '¡Registro exitoso! Bienvenido.');
    } else if (mounted) {
      Notificaciones.mostrar(context, authProvider.errorMessage ?? 'Error en el registro', error: true);
    }
  }

  Widget _buildPhotoSelector({
    required String title,
    required XFile? file,
    required IconData icon,
    required VoidCallback onPressed,
  }) {
    return Column(
      children: [
        file != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: XFileImagePreview(file: file, height: 85, width: 85, fit: BoxFit.cover),
              )
            : Container(
                height: 85,
                width: 85,
                decoration: BoxDecoration(color: AppTheme.containers, borderRadius: BorderRadius.circular(8)),
                child: Icon(icon, size: 36, color: AppTheme.primaryButton),
              ),
        const SizedBox(height: 6),
        OutlinedButton.icon(
          onPressed: onPressed,
          icon: const Icon(Icons.camera_alt, size: 14),
          label: Text(title, style: const TextStyle(fontSize: 11)),
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            minimumSize: Size.zero,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registro de Usuario', style: TextStyle(color: AppTheme.white)),
        backgroundColor: AppTheme.primaryButton,
        iconTheme: const IconThemeData(color: AppTheme.white),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Crea tu cuenta de Vecino',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AppTheme.primaryButton),
                ),
                const SizedBox(height: 16),
                CampoTexto(
                  controller: _nombreController,
                  label: 'Nombre completo',
                  validator: (v) => Validadores.validarTextoRequerido(v, 'Nombre completo'),
                  prefixIcon: const Icon(Icons.person, color: AppTheme.primaryButton),
                ),
                const SizedBox(height: 16),
                CampoTexto(
                  controller: _ciController,
                  label: 'Cédula de Identidad (C.I.)',
                  validator: Validadores.validarCi,
                  prefixIcon: const Icon(Icons.badge, color: AppTheme.primaryButton),
                ),
                const SizedBox(height: 16),
                CampoTexto(
                  controller: _telefonoController,
                  label: 'Teléfono / Celular',
                  keyboardType: TextInputType.phone,
                  validator: Validadores.validarTelefono,
                  prefixIcon: const Icon(Icons.phone, color: AppTheme.primaryButton),
                ),
                const SizedBox(height: 16),
                CampoTexto(
                  controller: _emailController,
                  label: 'Correo electrónico',
                  keyboardType: TextInputType.emailAddress,
                  validator: Validadores.validarEmail,
                  prefixIcon: const Icon(Icons.email, color: AppTheme.primaryButton),
                ),
                const SizedBox(height: 16),
                CampoContrasena(
                  controller: _passwordController,
                  validator: Validadores.validarPassword,
                ),
                const SizedBox(height: 24),
                Text('Verificación de Identidad (KYC)', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                const Text('Sube C.I. Anverso, C.I. Reverso, Selfie y Fachada', style: TextStyle(color: AppTheme.grey, fontSize: 13)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(
                      child: _buildPhotoSelector(
                        title: 'C.I. Anverso',
                        file: _ciAnversoFile,
                        icon: Icons.credit_card,
                        onPressed: () => _tomarFoto('ciAnverso'),
                      ),
                    ),
                    Expanded(
                      child: _buildPhotoSelector(
                        title: 'C.I. Reverso',
                        file: _ciReversoFile,
                        icon: Icons.credit_card_outlined,
                        onPressed: () => _tomarFoto('ciReverso'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    Expanded(
                      child: _buildPhotoSelector(
                        title: 'Selfie',
                        file: _selfieFile,
                        icon: Icons.camera_front,
                        onPressed: () => _tomarFoto('selfie'),
                      ),
                    ),
                    Expanded(
                      child: _buildPhotoSelector(
                        title: 'Fachada',
                        file: _facadeFile,
                        icon: Icons.home,
                        onPressed: () => _tomarFoto('facade'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Ubicación de Residencia', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                SelectorMapaUbicacion(
                  initialLocation: _selectedLocation,
                  onLocationSelected: (loc) {
                    setState(() {
                      _selectedLocation = loc;
                    });
                  },
                ),
                const SizedBox(height: 32),
                BotonPrincipal(
                  texto: 'Registrarse',
                  cargando: authProvider.isLoading,
                  onPressed: _registrar,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
