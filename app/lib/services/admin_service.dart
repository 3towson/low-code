import 'package:supabase_flutter/supabase_flutter.dart';

import 'evidence_storage_service.dart';

/// ข้อมูลรายงานที่รอการตรวจสอบ
class PendingReport {
  const PendingReport({
    required this.id,
    required this.customerName,
    required this.platform,
    required this.reason,
    required this.amount,
    required this.otherDetails,
    required this.evidencePath,
    required this.shopName,
    required this.createdAt,
  });

  final String id;
  final String customerName;
  final String platform;
  final String reason;
  final num? amount;
  final String? otherDetails;
  final String? evidencePath;
  final String shopName;
  final DateTime createdAt;

  /// รายการพาธไฟล์ภาพหลักฐานทั้งหมด (1-3 รูป)
  List<String> get evidencePaths {
    if (evidencePath == null || evidencePath!.trim().isEmpty) return const [];
    return evidencePath!
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  factory PendingReport.fromJson(Map<String, dynamic> json) {
    return PendingReport(
      id: json['id'] as String,
      customerName: json['customer_name'] as String? ?? '',
      platform: json['platform'] as String? ?? 'other',
      reason: json['reason'] as String? ?? 'other',
      amount: json['amount'] as num?,
      otherDetails: json['other_details'] as String?,
      evidencePath: json['evidence_path'] as String?,
      shopName: json['shop_name'] as String? ?? 'ร้านค้า',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }
}

/// สถิติภาพรวมสำหรับ Admin Dashboard
class AdminStats {
  const AdminStats({
    required this.pendingCount,
    required this.approvedToday,
    required this.rejectedToday,
  });

  final int pendingCount;
  final int approvedToday;
  final int rejectedToday;

  factory AdminStats.fromJson(Map<String, dynamic> json) {
    return AdminStats(
      pendingCount: (json['pending_count'] as num?)?.toInt() ?? 0,
      approvedToday: (json['approved_today'] as num?)?.toInt() ?? 0,
      rejectedToday: (json['rejected_today'] as num?)?.toInt() ?? 0,
    );
  }
}

typedef AdminRpcCaller = Future<dynamic> Function(
  String fn, {
  Map<String, dynamic>? params,
});

/// บริการสำหรับผู้ดูแลระบบ (Admin Moderation Service)
class AdminService {
  AdminService(
    SupabaseClient? supabase, {
    EvidenceStorageService? storageService,
    this._rpcCaller,
  })  : _supabase = supabase,
        _storageService = storageService ??
            (supabase != null ? SupabaseEvidenceStorageService(supabase) : null);

  final SupabaseClient? _supabase;
  final EvidenceStorageService? _storageService;
  final AdminRpcCaller? _rpcCaller;

  Future<dynamic> _callRpc(String fn, {Map<String, dynamic>? params}) {
    if (_rpcCaller != null) {
      return _rpcCaller(fn, params: params);
    }
    if (_supabase == null) {
      throw StateError('Supabase client or rpcCaller must be provided');
    }
    return _supabase.rpc(fn, params: params);
  }

  /// ดึงรายการรายงานสถานะ pending จากตาราง
  Future<List<PendingReport>> getPendingReports({
    int limit = 50,
    int offset = 0,
  }) async {
    final res = await _callRpc(
      'admin_get_pending_reports',
      params: {'p_limit': limit, 'p_offset': offset},
    );
    if (res is List) {
      return res
          .map((item) =>
              PendingReport.fromJson(Map<String, dynamic>.from(item as Map)))
          .toList();
    }
    return [];
  }

  /// ดึงข้อมูลสถิติจำนวนรายงานที่รอตรวจ และที่ตรวจแล้ววันนี้
  Future<AdminStats> getStats() async {
    final res = await _callRpc('admin_get_stats');
    if (res is List && res.isNotEmpty) {
      return AdminStats.fromJson(Map<String, dynamic>.from(res.first as Map));
    }
    if (res is Map) {
      return AdminStats.fromJson(Map<String, dynamic>.from(res));
    }
    return const AdminStats(
      pendingCount: 0,
      approvedToday: 0,
      rejectedToday: 0,
    );
  }

  /// อนุมัติรายงาน (เปลี่ยนสถานะเป็น active ทันที)
  Future<bool> approveReport(String reportId) async {
    final res = await _callRpc(
      'admin_review_report',
      params: {
        'p_report_id': reportId,
        'p_action': 'approve',
      },
    );
    return res == true;
  }

  /// ปฏิเสธรายงานพร้อมระบุเหตุผล
  Future<bool> rejectReport(String reportId, String reason) async {
    final res = await _callRpc(
      'admin_review_report',
      params: {
        'p_report_id': reportId,
        'p_action': 'reject',
        'p_reason': reason.trim(),
      },
    );
    return res == true;
  }

  /// ขอ Signed URL สำหรับเปิดดูรูปภาพหลักฐาน
  Future<String> getEvidenceSignedUrl(String evidencePath) {
    if (_storageService == null) {
      throw StateError('Storage service is not configured');
    }
    return _storageService.createSignedUrl(evidencePath, expiresIn: 900);
  }
}
