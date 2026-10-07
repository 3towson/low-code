import 'package:cod_customer_check/services/evidence_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SupabaseEvidenceStorageService.resolveMimeType', () {
    test('แปลง .jpg และ .jpeg เป็น image/jpeg', () {
      expect(SupabaseEvidenceStorageService.resolveMimeType('jpg'), 'image/jpeg');
      expect(SupabaseEvidenceStorageService.resolveMimeType('.jpg'), 'image/jpeg');
      expect(SupabaseEvidenceStorageService.resolveMimeType('jpeg'), 'image/jpeg');
      expect(SupabaseEvidenceStorageService.resolveMimeType('JPG'), 'image/jpeg');
      expect(SupabaseEvidenceStorageService.resolveMimeType('JPEG'), 'image/jpeg');
    });

    test('แปลง .png เป็น image/png', () {
      expect(SupabaseEvidenceStorageService.resolveMimeType('png'), 'image/png');
      expect(SupabaseEvidenceStorageService.resolveMimeType('.PNG'), 'image/png');
    });

    test('แปลง .webp เป็น image/webp', () {
      expect(SupabaseEvidenceStorageService.resolveMimeType('webp'), 'image/webp');
      expect(SupabaseEvidenceStorageService.resolveMimeType('.WEBP'), 'image/webp');
    });

    test('ค่าเริ่มต้นเป็น image/jpeg เพื่อความปลอดภัยบน bucket', () {
      expect(SupabaseEvidenceStorageService.resolveMimeType(''), 'image/jpeg');
      expect(SupabaseEvidenceStorageService.resolveMimeType('unknown'), 'image/jpeg');
    });
  });
}
