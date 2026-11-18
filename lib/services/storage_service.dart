import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:supabase_flutter/supabase_flutter.dart';

class StorageService {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<String> uploadImage(XFile file, String bucket, String pathPrefix, {String? customFileName}) async {
    final fileName = customFileName ?? '$pathPrefix/${DateTime.now().millisecondsSinceEpoch}_${p.basename(file.path)}';

    if (kIsWeb) {
      final bytes = await file.readAsBytes();
      await _supabase.storage.from(bucket).uploadBinary(
        fileName,
        bytes,
        fileOptions: const FileOptions(upsert: true),
      );
    } else {
      try {
        final tempDir = await getTemporaryDirectory();
        final targetPath = p.join(tempDir.path, '${DateTime.now().millisecondsSinceEpoch}_compressed.jpg');

        final compressedFile = await FlutterImageCompress.compressAndGetFile(
          file.path,
          targetPath,
          minWidth: 800,
          minHeight: 800,
          quality: 75,
        );

        final File uploadFile = compressedFile != null ? File(compressedFile.path) : File(file.path);

        await _supabase.storage.from(bucket).upload(
          fileName,
          uploadFile,
          fileOptions: const FileOptions(upsert: true),
        );
      } catch (_) {
        final bytes = await file.readAsBytes();
        await _supabase.storage.from(bucket).uploadBinary(
          fileName,
          bytes,
          fileOptions: const FileOptions(upsert: true),
        );
      }
    }

    final publicUrl = _supabase.storage.from(bucket).getPublicUrl(fileName);
    return publicUrl;
  }
}
