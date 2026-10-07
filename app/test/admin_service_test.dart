import 'package:cod_customer_check/services/admin_service.dart';
import 'package:cod_customer_check/services/evidence_storage_service.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeEvidenceStorage implements EvidenceStorageService {
  @override
  Future<String> createSignedUrl(String path, {int expiresIn = 900}) async {
    return 'https://signed.example.com/$path?expires=$expiresIn';
  }

  @override
  Future<String> uploadEvidence({
    required String userId,
    required dynamic bytes,
    required String extension,
  }) async {
    return '$userId/mock.$extension';
  }
}

void main() {
  group('PendingReport & AdminStats Deserialization', () {
    test('PendingReport.fromJson parses all fields correctly', () {
      final json = {
        'id': 'rep-123',
        'customer_name': 'สมศรี มีทรัพย์',
        'platform': 'shopee',
        'reason': 'refused_delivery',
        'amount': 2500,
        'other_details': 'ไม่รับสายคนส่ง',
        'evidence_path': 'user1/evidence_1.jpg',
        'shop_name': 'ร้านมีตังค์',
        'created_at': '2026-10-07T08:30:00Z',
      };

      final report = PendingReport.fromJson(json);

      expect(report.id, 'rep-123');
      expect(report.customerName, 'สมศรี มีทรัพย์');
      expect(report.platform, 'shopee');
      expect(report.reason, 'refused_delivery');
      expect(report.amount, 2500);
      expect(report.otherDetails, 'ไม่รับสายคนส่ง');
      expect(report.evidencePath, 'user1/evidence_1.jpg');
      expect(report.shopName, 'ร้านมีตังค์');
      expect(report.createdAt.toUtc().year, 2026);
    });

    test('PendingReport.fromJson handles missing optional fields gracefully', () {
      final json = {
        'id': 'rep-999',
      };

      final report = PendingReport.fromJson(json);

      expect(report.id, 'rep-999');
      expect(report.customerName, '');
      expect(report.platform, 'other');
      expect(report.reason, 'other');
      expect(report.amount, isNull);
      expect(report.otherDetails, isNull);
      expect(report.evidencePath, isNull);
      expect(report.shopName, 'ร้านค้า');
    });

    test('AdminStats.fromJson parses numbers and falls back to 0', () {
      final json = {
        'pending_count': 12,
        'approved_today': 5,
        'rejected_today': 2,
      };

      final stats = AdminStats.fromJson(json);

      expect(stats.pendingCount, 12);
      expect(stats.approvedToday, 5);
      expect(stats.rejectedToday, 2);

      final emptyStats = AdminStats.fromJson({});
      expect(emptyStats.pendingCount, 0);
      expect(emptyStats.approvedToday, 0);
      expect(emptyStats.rejectedToday, 0);
    });
  });

  group('AdminService Operations', () {
    test('getPendingReports calls RPC with limit and offset and returns list',
        () async {
      String? calledFn;
      Map<String, dynamic>? calledParams;

      final service = AdminService(
        null,
        rpcCaller: (fn, {params}) async {
          calledFn = fn;
          calledParams = params;
          return [
            {
              'id': 'rep-01',
              'customer_name': 'นายทดสอบ',
              'platform': 'tiktok',
              'reason': 'fake_address',
              'evidence_path': 'u1/slip.png',
              'created_at': '2026-10-07T00:00:00Z',
            }
          ];
        },
      );

      final list = await service.getPendingReports(limit: 20, offset: 5);

      expect(calledFn, 'admin_get_pending_reports');
      expect(calledParams, {'p_limit': 20, 'p_offset': 5});
      expect(list.length, 1);
      expect(list.first.id, 'rep-01');
      expect(list.first.platform, 'tiktok');
    });

    test('getStats calls admin_get_stats RPC and parses result', () async {
      final service = AdminService(
        null,
        rpcCaller: (fn, {params}) async {
          expect(fn, 'admin_get_stats');
          return [
            {
              'pending_count': 7,
              'approved_today': 15,
              'rejected_today': 1,
            }
          ];
        },
      );

      final stats = await service.getStats();

      expect(stats.pendingCount, 7);
      expect(stats.approvedToday, 15);
      expect(stats.rejectedToday, 1);
    });

    test('approveReport sends admin_review_report with action approve', () async {
      String? calledFn;
      Map<String, dynamic>? calledParams;

      final service = AdminService(
        null,
        rpcCaller: (fn, {params}) async {
          calledFn = fn;
          calledParams = params;
          return true;
        },
      );

      final ok = await service.approveReport('rep-777');

      expect(calledFn, 'admin_review_report');
      expect(calledParams, {
        'p_report_id': 'rep-777',
        'p_action': 'approve',
      });
      expect(ok, isTrue);
    });

    test('rejectReport sends admin_review_report with action reject and reason',
        () async {
      String? calledFn;
      Map<String, dynamic>? calledParams;

      final service = AdminService(
        null,
        rpcCaller: (fn, {params}) async {
          calledFn = fn;
          calledParams = params;
          return true;
        },
      );

      final ok = await service.rejectReport(
          'rep-888', '  หลักฐานไม่ชัดเจน เบลอมาก  ');

      expect(calledFn, 'admin_review_report');
      expect(calledParams, {
        'p_report_id': 'rep-888',
        'p_action': 'reject',
        'p_reason': 'หลักฐานไม่ชัดเจน เบลอมาก',
      });
      expect(ok, isTrue);
    });

    test('getEvidenceSignedUrl uses storage service', () async {
      final storage = FakeEvidenceStorage();

      final service = AdminService(null, storageService: storage);
      final url = await service.getEvidenceSignedUrl('u1/chat.jpg');

      expect(url, 'https://signed.example.com/u1/chat.jpg?expires=900');
    });
  });
}
