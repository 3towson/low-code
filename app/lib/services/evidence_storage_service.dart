import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

/// สัญญาณบริการจัดการไฟล์ภาพหลักฐานบน Supabase Storage
abstract class EvidenceStorageService {
  /// อัปโหลดไฟล์หลักฐานไปยังโฟลเดอร์ของร้านค้า (userId)
  /// คืนค่าเป็นพาธของไฟล์ เช่น `userId/evidence_1696000000.jpg`
  Future<String> uploadEvidence({
    required String userId,
    required Uint8List bytes,
    required String extension,
  });

  /// ขอ Signed URL สำหรับการเปิดดูไฟล์แบบชั่วคราว (หมดอายุอัตโนมัติ)
  Future<String> createSignedUrl(String path, {int expiresIn = 900});
}

/// การทำงานจริงเชื่อมต่อกับ Supabase Storage
class SupabaseEvidenceStorageService implements EvidenceStorageService {
  SupabaseEvidenceStorageService(this._supabase, {this.bucket = 'report-evidences'});

  final SupabaseClient _supabase;
  final String bucket;

  /// แปลงนามสกุลไฟล์เป็น MIME type ที่มาตรฐาน IANA และ Supabase Storage Bucket อนุญาต (jpeg, png, webp)
  static String resolveMimeType(String extension) {
    final clean = extension.replaceAll('.', '').toLowerCase().trim();
    switch (clean) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }

  @override
  Future<String> uploadEvidence({
    required String userId,
    required Uint8List bytes,
    required String extension,
  }) async {
    final cleanExt = extension.replaceAll('.', '').toLowerCase().trim();
    // Bucket อนุญาตเฉพาะ jpg/jpeg, png, webp เท่านั้น หากเป็น heic/gif หรือรูปแบบอื่นให้บันทึกเป็น jpg
    final ext = (cleanExt == 'png' || cleanExt == 'webp' || cleanExt == 'jpeg')
        ? cleanExt
        : 'jpg';
    final timestamp = DateTime.now().millisecondsSinceEpoch;
    final rand = DateTime.now().microsecondsSinceEpoch % 10000;
    final path = '$userId/evidence_${timestamp}_$rand.$ext';
    final mimeType = resolveMimeType(ext);

    await _supabase.storage.from(bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: mimeType,
            upsert: false,
          ),
        );
    return path;
  }

  @override
  Future<String> createSignedUrl(String path, {int expiresIn = 900}) async {
    return _supabase.storage
        .from(bucket)
        .createSignedUrl(path, expiresIn);
  }
}
