import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<String> uploadProfileAvatar(XFile file, String userId) async {
    final bytes = await file.readAsBytes();
    if (bytes.isEmpty) {
      throw const FormatException('La foto seleccionada está vacía.');
    }
    if (bytes.length > 5 * 1024 * 1024) {
      throw const FormatException(
        'La foto de perfil no puede superar los 5 MB.',
      );
    }

    final fileExtension = p
        .extension(file.name.isEmpty ? file.path : file.name)
        .replaceFirst('.', '')
        .toLowerCase();
    final fallbackMimeType = switch (fileExtension) {
      'jpg' || 'jpeg' => 'image/jpeg',
      'png' => 'image/png',
      'webp' => 'image/webp',
      _ => null,
    };
    final mimeType = file.mimeType == 'image/jpg'
        ? 'image/jpeg'
        : file.mimeType ?? fallbackMimeType;
    final extension = switch (mimeType) {
      'image/jpeg' => 'jpg',
      'image/png' => 'png',
      'image/webp' => 'webp',
      _ => null,
    };
    if (extension == null) {
      throw const FormatException(
        'Formato no compatible. Usa una imagen JPG, PNG o WebP.',
      );
    }

    final path =
        '$userId/${DateTime.now().microsecondsSinceEpoch}_avatar.$extension';
    await _supabase.storage
        .from('profile_avatars')
        .uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            cacheControl: '60',
            upsert: false,
            contentType: mimeType,
          ),
        );
    return path;
  }

  String getProfileAvatarUrl(String path) {
    return _supabase.storage.from('profile_avatars').getPublicUrl(path);
  }

  Future<void> deleteProfileAvatar(String path, String userId) async {
    final segments = path.split('/');
    if (segments.length != 2 ||
        segments.first != userId ||
        segments.last.isEmpty) {
      throw const FormatException('La ruta de la foto de perfil no es válida.');
    }
    await _supabase.storage.from('profile_avatars').remove([path]);
  }

  Future<String> uploadImage(
    XFile file,
    String bucket,
    String pathPrefix, {
    String? customFileName,
  }) async {
    final fileName =
        customFileName ??
        '$pathPrefix/${DateTime.now().millisecondsSinceEpoch}_${p.basename(file.path)}';

    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      await _supabase.storage
          .from(bucket)
          .uploadBinary(
            fileName,
            bytes,
            fileOptions: const FileOptions(upsert: true),
          );
    } else {
      try {
        final tempDir = await getTemporaryDirectory();
        final targetPath = p.join(
          tempDir.path,
          '${DateTime.now().millisecondsSinceEpoch}_compressed.jpg',
        );

        final compressedFile = await FlutterImageCompress.compressAndGetFile(
          file.path,
          targetPath,
          minWidth: 800,
          minHeight: 800,
          quality: 75,
        );

        final File uploadFile = compressedFile != null
            ? File(compressedFile.path)
            : File(file.path);

        await _supabase.storage
            .from(bucket)
            .upload(
              fileName,
              uploadFile,
              fileOptions: const FileOptions(upsert: true),
            );
      } catch (_) {
        final bytes = await file.readAsBytes();
        await _supabase.storage
            .from(bucket)
            .uploadBinary(
              fileName,
              bytes,
              fileOptions: const FileOptions(upsert: true),
            );
      }
    }

    if (bucket == 'kyc_docs') return fileName;
    return _supabase.storage.from(bucket).getPublicUrl(fileName);
  }

  Future<String> createKycSignedUrl(String storedPathOrUrl) async {
    final uri = Uri.tryParse(storedPathOrUrl);
    final segments = uri?.hasScheme == true
        ? uri!.pathSegments
        : storedPathOrUrl.split('/');
    final bucketIndex = segments.indexOf('kyc_docs');
    final objectPath = bucketIndex >= 0
        ? segments.skip(bucketIndex + 1).join('/')
        : storedPathOrUrl;

    if (objectPath.isEmpty || objectPath.startsWith('/')) {
      throw const FormatException('Ruta de archivo KYC inválida.');
    }

    return _supabase.storage.from('kyc_docs').createSignedUrl(objectPath, 3600);
  }

  Future<List<String>> uploadImages(
    List<XFile> files,
    String bucket,
    String pathPrefix,
  ) async {
    if (files.isEmpty) return [];
    final archivosLimitados = files.take(5).toList();
    return Future.wait(
      archivosLimitados.map((file) => uploadImage(file, bucket, pathPrefix)),
    );
  }
}
