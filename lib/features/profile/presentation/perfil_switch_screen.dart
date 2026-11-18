import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/presentation/auth_provider.dart';
import 'registro_negocio_screen.dart';

class PerfilSwitchScreen extends StatelessWidget {
  final bool esPestana;

  const PerfilSwitchScreen({super.key, this.esPestana = false});

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

    final bool kycVerificado = profile != null &&
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
                  const Text(
                    'Modo Emprendedor',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.textPrimary),
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
            Center(
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: AppTheme.containers,
                    backgroundImage: profile?.selfieUrl != null && profile!.selfieUrl.isNotEmpty
                        ? CachedNetworkImageProvider(profile.selfieUrl) as ImageProvider
                        : null,
                    child: profile?.selfieUrl == null || profile!.selfieUrl.isEmpty
                        ? const Icon(Icons.person, size: 50, color: AppTheme.primaryButton)
                        : null,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    profile?.nombre ?? 'Usuario',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(profile?.email ?? '', style: const TextStyle(color: AppTheme.grey)),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Card(
              elevation: 2,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Información Verificada', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryButton)),
                    const Divider(),
                    _infoRow(Icons.person, 'Nombre', profile?.nombre ?? '-'),
                    _infoRow(Icons.email, 'Email', profile?.email ?? '-'),
                    _infoRow(Icons.badge, 'C.I.', profile?.ci ?? '-'),
                    _infoRow(Icons.phone, 'Teléfono', profile?.telefono ?? '-'),
                    _infoRow(Icons.verified_user, 'Rol Activo', authProvider.activeRole),
                    _infoRow(
                      Icons.verified,
                      'Estado KYC',
                      kycVerificado ? 'CI Anverso y Reverso Verificados ✓' : 'Pendiente de verificación',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
            _buildKycGrid(profile),
            const SizedBox(height: 24),
            if (isEmprendedor) ...[
              if (negocio != null) ...[
                Card(
                  elevation: 2,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(negocio.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppTheme.primaryButton)),
                            const Chip(label: Text('Mi Negocio', style: TextStyle(color: Colors.white)), backgroundColor: AppTheme.primaryButton),
                          ],
                        ),
                        const Divider(),
                        Text(negocio.descripcion),
                        const SizedBox(height: 8),
                        Text('Opciones de delivery: ${negocio.deliveryOptions.join(', ')}'),
                        Text('Costo de envío: Bs ${(negocio.shippingCost / 100).toStringAsFixed(2)}'),
                      ],
                    ),
                  ),
                ),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const RegistroNegocioScreen()),
                    );
                  },
                  icon: const Icon(Icons.store),
                  label: const Text('Registrar mi Negocio'),
                ),
              ],
            ],
          ],
        ),
      ),
    );

    if (esPestana) {
      return Scaffold(
        appBar: AppBar(
          title: Text(isEmprendedor ? 'Panel de Emprendedor' : 'Mi Perfil - Vecino', style: const TextStyle(color: AppTheme.white)),
          backgroundColor: AppTheme.primaryButton,
        ),
        body: content,
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isEmprendedor ? 'Panel de Emprendedor' : 'Mi Perfil - Vecino', style: const TextStyle(color: AppTheme.white)),
        backgroundColor: AppTheme.primaryButton,
        actions: [
          IconButton(
            icon: const Icon(Icons.logout, color: AppTheme.white),
            onPressed: () => authProvider.cerrarSesion(),
          ),
        ],
      ),
      body: content,
    );
  }

  Widget _buildKycGrid(dynamic profile) {
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
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppTheme.primaryButton),
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
                _buildKycImageCard('Selfie', profile?.selfieUrl),
                _buildKycImageCard('Fachada', profile?.facadeUrl),
                _buildKycImageCard('C.I. Anverso', profile?.ciAnversoUrl),
                _buildKycImageCard('C.I. Reverso', profile?.ciReversoUrl),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildKycImageCard(String title, String? url) {
    final bool hasUrl = url != null && url.trim().isNotEmpty;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.containers,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.grey.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Expanded(
            child: hasUrl
                ? CachedNetworkImage(
                    imageUrl: url,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    placeholder: (context, url) => const Center(
                      child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.primaryButton),
                    ),
                    errorWidget: (context, url, error) => const Center(
                      child: Icon(Icons.broken_image, color: AppTheme.grey, size: 32),
                    ),
                  )
                : const Center(
                    child: Icon(Icons.image_not_supported, color: AppTheme.grey, size: 32),
                  ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            color: Colors.black54,
            child: Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
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
          Text('$label: ', style: const TextStyle(fontWeight: FontWeight.bold)),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}
