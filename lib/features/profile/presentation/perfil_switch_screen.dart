import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/widgets/ui_kit.dart';
import '../../../services/storage_service.dart';
import '../../auth/domain/negocio.dart';
import '../../auth/domain/user_profile.dart';
import '../../auth/presentation/auth_provider.dart';
import '../../explorar/presentation/detalle_producto_screen.dart';
import '../../explorar/presentation/explorar_provider.dart';
import '../../negocio/presentation/catalogo_provider.dart';
import '../../pedidos/presentation/carrito_provider.dart';
import 'registro_negocio_screen.dart';

class PerfilSwitchScreen extends StatelessWidget {
  final bool esPestana;

  const PerfilSwitchScreen({super.key, this.esPestana = false});

  Future<void> _confirmarCerrarSesion(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar Sesión'),
        content: const Text('¿Estás seguro de que deseas salir de tu cuenta?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Cerrar Sesión',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmar == true && context.mounted) {
      context.read<CatalogoProvider>().limpiar();
      context.read<ExplorarProvider>().limpiar();
      context.read<CarritoProvider>().limpiarCarrito();
      await context.read<AuthProvider>().cerrarSesion();
    }
  }

  Future<void> _cambiarFotoFachada(
    BuildContext context,
    Negocio negocio,
  ) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 800,
      maxHeight: 800,
    );
    if (image == null) return;
    if (!context.mounted) return;

    try {
      final url = await StorageService().uploadImage(
        image,
        'negocios_assets',
        'fachadas',
      );
      if (!context.mounted) return;

      await Supabase.instance.client
          .from('negocios')
          .update({'store_photo_url': url})
          .eq('id', negocio.id);
      if (!context.mounted) return;

      await context.read<CatalogoProvider>().cargarNegocioYProductos(
        negocio.ownerId,
      );
      if (!context.mounted) return;

      final auth = context.read<AuthProvider>();
      await auth.restaurarSesion();
      if (!context.mounted) return;

      Notificaciones.mostrar(
        context,
        '¡Foto de fachada actualizada con éxito!',
      );
    } catch (e) {
      if (context.mounted) {
        Notificaciones.mostrar(
          context,
          'Error al actualizar fachada: $e',
          error: true,
        );
      }
    }
  }

  Future<void> _cambiarFotoPerfil(BuildContext context) async {
    try {
      final image = await ImagePicker().pickImage(
        source: ImageSource.gallery,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (image == null || !context.mounted) return;

      await context.read<AuthProvider>().actualizarFotoPerfilPublica(image);
      if (!context.mounted) return;
      Notificaciones.mostrar(context, 'Foto pública actualizada.');
    } catch (error) {
      if (context.mounted) {
        Notificaciones.mostrar(
          context,
          'Error al actualizar la foto pública: $error',
          error: true,
        );
      }
    }
  }

  Widget _buildProfileAvatar(
    BuildContext context,
    UserProfile? profile, {
    required double radius,
  }) {
    final avatarUrl = profile?.avatarUrl;
    final imageUrl = avatarUrl != null && avatarUrl.isNotEmpty
        ? avatarUrl
        : profile?.selfieUrl ?? '';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        GestureDetector(
          onTap: imageUrl.isEmpty
              ? null
              : () => abrirImagenExpandida(
                  context,
                  imageUrl,
                  titulo: profile?.nombre ?? 'Perfil',
                ),
          child: CircleAvatar(
            radius: radius + 2,
            backgroundColor: Colors.white,
            child: CircleAvatar(
              radius: radius - 2,
              backgroundColor: AppTheme.containers,
              backgroundImage: imageUrl.isEmpty
                  ? null
                  : CachedNetworkImageProvider(imageUrl),
              child: imageUrl.isEmpty
                  ? Icon(
                      Icons.person,
                      size: radius,
                      color: AppTheme.primaryButton,
                    )
                  : null,
            ),
          ),
        ),
        Positioned(
          top: 0,
          right: 0,
          child: CircleAvatar(
            radius: 15,
            backgroundColor: AppTheme.primaryButton,
            child: IconButton(
              padding: EdgeInsets.zero,
              iconSize: 16,
              tooltip: 'Cambiar foto pública',
              onPressed: profile == null
                  ? null
                  : () => _cambiarFotoPerfil(context),
              icon: const Icon(
                Icons.photo_camera_outlined,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAvatarPrivacyNote(BuildContext context, UserProfile? profile) {
    return Column(
      children: [
        TextButton.icon(
          onPressed: profile == null ? null : () => _cambiarFotoPerfil(context),
          icon: const Icon(Icons.photo_camera_outlined, size: 18),
          label: Text(
            profile?.avatarPath == null
                ? 'Agregar foto pública'
                : 'Cambiar foto pública',
          ),
        ),
        const Text(
          'Se verá en pedidos y reseñas. Tu selfie y documentos KYC siguen privados.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppTheme.grey, fontSize: 11),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<AuthProvider>();
    final profile = authProvider.userProfile;
    final negocio = authProvider.negocio;
    final isEmprendedor = authProvider.activeRole == 'EMPRENDEDOR';

    if (authProvider.needsBusinessRegistration) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        authProvider.resetBusinessRegistrationFlag();
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const RegistroNegocioScreen()),
        );
      });
    }

    final bool kycVerificado =
        profile != null &&
        profile.ciAnversoUrl.isNotEmpty &&
        profile.ciReversoUrl.isNotEmpty;

    final content = SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppTheme.containers,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Expanded(
                    child: Text(
                      'Modo Emprendedor',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                  ),
                  Switch(
                    value: isEmprendedor,
                    activeThumbColor: AppTheme.primaryButton,
                    onChanged: (value) {
                      final newRole = value ? 'EMPRENDEDOR' : 'VECINO';
                      authProvider.cambiarRol(newRole);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            if (isEmprendedor && negocio != null) ...[
              Stack(
                clipBehavior: Clip.none,
                children: [
                  SizedBox(
                    height: 230,
                    width: double.infinity,
                    child: Stack(
                      children: [
                        Positioned(
                          top: 0,
                          left: 0,
                          right: 0,
                          height: 180,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(16),
                            child: CachedNetworkImage(
                              imageUrl: negocio.storePhotoUrl,
                              fit: BoxFit.cover,
                              placeholder: (context, url) => Container(
                                color: AppTheme.containers,
                                child: const Center(
                                  child: CircularProgressIndicator(),
                                ),
                              ),
                              errorWidget: (context, url, error) => Container(
                                color: AppTheme.containers,
                                child: const Icon(
                                  Icons.storefront,
                                  size: 50,
                                  color: AppTheme.primaryButton,
                                ),
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          left: 12,
                          child: CircleAvatar(
                            backgroundColor: Colors.black.withValues(
                              alpha: 0.6,
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.open_in_full,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: () => abrirImagenExpandida(
                                context,
                                negocio.storePhotoUrl,
                                titulo: negocio.nombre,
                              ),
                            ),
                          ),
                        ),
                        Positioned(
                          top: 12,
                          right: 12,
                          child: CircleAvatar(
                            backgroundColor: Colors.black.withValues(
                              alpha: 0.6,
                            ),
                            child: IconButton(
                              icon: const Icon(
                                Icons.edit,
                                color: Colors.white,
                                size: 20,
                              ),
                              onPressed: () =>
                                  _cambiarFotoFachada(context, negocio),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Center(
                      child: _buildProfileAvatar(context, profile, radius: 50),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Center(
                child: Column(
                  children: [
                    Text(
                      profile?.nombre ?? 'Usuario',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile?.email ?? '',
                      style: const TextStyle(color: AppTheme.grey),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      negocio.nombre,
                      style: const TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.primaryButton,
                      ),
                    ),
                    _buildAvatarPrivacyNote(context, profile),
                  ],
                ),
              ),
            ] else ...[
              Center(
                child: Column(
                  children: [
                    _buildProfileAvatar(context, profile, radius: 50),
                    const SizedBox(height: 12),
                    Text(
                      profile?.nombre ?? 'Usuario',
                      style: Theme.of(context).textTheme.titleLarge
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      profile?.email ?? '',
                      style: const TextStyle(color: AppTheme.grey),
                    ),
                    _buildAvatarPrivacyNote(context, profile),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Información Verificada',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                        color: AppTheme.primaryButton,
                      ),
                    ),
                    const Divider(),
                    _infoRow(Icons.person, 'Nombre', profile?.nombre ?? '-'),
                    _infoRow(Icons.email, 'Email', profile?.email ?? '-'),
                    _infoRow(Icons.badge, 'C.I.', profile?.ci ?? '-'),
                    _infoRow(Icons.phone, 'Teléfono', profile?.telefono ?? '-'),
                    _infoRow(
                      Icons.verified_user,
                      'Rol Activo',
                      authProvider.activeRole,
                    ),
                    _infoRow(
                      Icons.verified,
                      'Estado KYC',
                      kycVerificado
                          ? 'CI Anverso y Reverso Verificados ✓'
                          : 'Pendiente de verificación',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildKycGrid(context, profile),
            const SizedBox(height: 24),
            if (isEmprendedor && negocio == null) ...[
              ElevatedButton.icon(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RegistroNegocioScreen(),
                    ),
                  );
                },
                icon: const Icon(Icons.store),
                label: const Text('Registrar mi Negocio'),
              ),
            ],
            const SizedBox(height: 32),
            OutlinedButton.icon(
              onPressed: () => _confirmarCerrarSesion(context),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.red,
                side: const BorderSide(color: Colors.red),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.logout, color: Colors.red),
              label: const Text(
                'Cerrar Sesión',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );

    if (esPestana) {
      return Scaffold(
        appBar: AppBar(
          title: Text(
            isEmprendedor ? 'Panel de Emprendedor' : 'Mi Perfil - Vecino',
            style: const TextStyle(color: AppTheme.white),
          ),
          backgroundColor: AppTheme.primaryButton,
          actions: [
            IconButton(
              icon: const Icon(Icons.logout, color: AppTheme.white),
              tooltip: 'Cerrar Sesión',
              onPressed: () => _confirmarCerrarSesion(context),
            ),
          ],
        ),
        body: content,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(
          isEmprendedor ? 'Panel de Emprendedor' : 'Mi Perfil - Vecino',
          style: const TextStyle(color: AppTheme.white),
        ),
        backgroundColor: AppTheme.primaryButton,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.white),
            tooltip: 'Cerrar Sesión',
            onPressed: () => _confirmarCerrarSesion(context),
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildKycGrid(BuildContext context, dynamic profile) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Documentos e Imágenes KYC',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
                color: AppTheme.primaryButton,
              ),
            ),
            const Divider(),
            const SizedBox(height: 8),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.1,
              children: [
                _buildKycImageCard(context, 'Selfie', profile?.selfieUrl),
                _buildKycImageCard(context, 'Fachada', profile?.facadeUrl),
                _buildKycImageCard(
                  context,
                  'C.I. Anverso',
                  profile?.ciAnversoUrl,
                ),
                _buildKycImageCard(
                  context,
                  'C.I. Reverso',
                  profile?.ciReversoUrl,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKycImageCard(BuildContext context, String title, String? url) {
    final bool hasUrl = url != null && url.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.containers,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grey.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Column(
            children: [
              Expanded(
                child: hasUrl
                    ? CachedNetworkImage(
                        imageUrl: url,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        placeholder: (context, url) => const Center(
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppTheme.primaryButton,
                          ),
                        ),
                        errorWidget: (context, url, error) => const Center(
                          child: Icon(
                            Icons.broken_image,
                            color: AppTheme.grey,
                            size: 32,
                          ),
                        ),
                      )
                    : const Center(
                        child: Icon(
                          Icons.image_not_supported,
                          color: AppTheme.grey,
                          size: 32,
                        ),
                      ),
              ),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 4),
                color: Colors.black54,
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          if (hasUrl)
            Positioned(
              top: 6,
              right: 6,
              child: GestureDetector(
                onTap: () => abrirImagenExpandida(context, url, titulo: title),
                child: CircleAvatar(
                  radius: 14,
                  backgroundColor: Colors.black.withValues(alpha: 0.6),
                  child: const Icon(
                    Icons.open_in_full,
                    size: 12,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _infoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryButton),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '$label: ',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  TextSpan(text: value),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
