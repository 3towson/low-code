import 'package:supabase_flutter/supabase_flutter.dart';

import '../pages/report_customer_page.dart' show EvidenceFile;
import 'evidence_storage_service.dart';

/// สถานะการยืนยันตัวตนของร้านค้า
enum MerchantKycStatus {
  unverified('unverified', 'ยังไม่ยืนยัน'),
  pending('pending', 'รอการอนุมัติ'),
  approved('approved', 'ยืนยันแล้ว'),
  rejected('rejected', 'ไม่อนุมัติ'),
  suspended('suspended', 'ถูกระงับการใช้งาน');

  const MerchantKycStatus(this.value, this.label);
  final String value;
  final String label;

  static MerchantKycStatus fromValue(String? value) {
    for (final s in values) {
      if (s.value == value) return s;
    }
    return unverified;
  }
}

/// ข้อมูลการยืนยันตัวตนของร้านค้า
class MerchantKycInfo {
  const MerchantKycInfo({
    required this.shopName,
    required this.status,
    this.shopUrl,
    this.category,
    this.contactPhone,
    this.evidencePath,
    this.rejectionReason,
    this.submittedAt,
    this.verifiedAt,
  });

  final String shopName;
  final MerchantKycStatus status;
  final String? shopUrl;
  final String? category;
  final String? contactPhone;
  final String? evidencePath;
  final String? rejectionReason;
  final DateTime? submittedAt;
  final DateTime? verifiedAt;

  bool get isApproved => status == MerchantKycStatus.approved;
  bool get isPending => status == MerchantKycStatus.pending;
  bool get isUnverified => status == MerchantKycStatus.unverified;
  bool get isRejected => status == MerchantKycStatus.rejected;
  bool get isSuspended => status == MerchantKycStatus.suspended;

  /// รายการพาธไฟล์ภาพหลักฐานทั้งหมด
  List<String> get evidencePaths {
    if (evidencePath == null || evidencePath!.trim().isEmpty) return const [];
    return evidencePath!
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
  }

  factory MerchantKycInfo.fromJson(Map<String, dynamic> json) {
    return MerchantKycInfo(
      shopName: json['shop_name'] as String? ?? '',
      status: MerchantKycStatus.fromValue(json['verification_status'] as String?),
      shopUrl: json['shop_url'] as String?,
      category: json['category'] as String?,
      contactPhone: json['contact_phone'] as String?,
      evidencePath: json['evidence_path'] as String?,
      rejectionReason: json['rejection_reason'] as String?,
      submittedAt: DateTime.tryParse(json['submitted_at']?.toString() ?? ''),
      verifiedAt: DateTime.tryParse(json['verified_at']?.toString() ?? ''),
    );
  }
}

typedef KycRpcCaller = Future<dynamic> Function(
  String fn, {
  Map<String, dynamic>? params,
});

/// บริการจัดการและยื่นเรื่องยืนยันตัวตนร้านค้า (Merchant KYC)
class MerchantKycService {
  MerchantKycService(
    this._supabase, {
    EvidenceStorageService? storageService,
    this._rpcCaller,
  })  : _storageService = storageService ??
            (_supabase != null
                ? SupabaseEvidenceStorageService(
                    _supabase,
                    bucket: 'merchant-evidences',
                  )
                : null);

  final SupabaseClient? _supabase;
  final EvidenceStorageService? _storageService;
  final KycRpcCaller? _rpcCaller;

  EvidenceStorageService? get storageService => _storageService;

  Future<dynamic> _callRpc(String fn, {Map<String, dynamic>? params}) {
    final caller = _rpcCaller;
    if (caller != null) {
      return caller(fn, params: params);
    }
    final client = _supabase;
    if (client == null) {
      throw StateError('Supabase client or rpcCaller must be provided');
    }
    return client.rpc(fn, params: params);
  }

  /// ดึงสถานะ KYC ปัจจุบันของร้านค้า
  Future<MerchantKycInfo> getKycStatus() async {
    final res = await _callRpc('get_my_kyc_status');
    if (res is Map<String, dynamic>) {
      return MerchantKycInfo.fromJson(res);
    } else if (res is Map) {
      return MerchantKycInfo.fromJson(Map<String, dynamic>.from(res));
    }
    return const MerchantKycInfo(
      shopName: '',
      status: MerchantKycStatus.unverified,
    );
  }

  /// ยื่นข้อมูลและภาพหลักฐานยืนยันร้านค้า (>50 ออเดอร์)
  Future<bool> submitKyc({
    required String shopUrl,
    required String category,
    required String contactPhone,
    required List<EvidenceFile> evidences,
    String? userId,
    Map<EvidenceFile, String>? uploadedPathCache,
  }) async {
    final effectiveUserId = userId ?? _supabase?.auth.currentUser?.id;
    if (effectiveUserId == null) {
      throw StateError('User must be signed in to submit KYC');
    }
    if (evidences.isEmpty) {
      throw ArgumentError('กรุณาแนบภาพหลักฐานอย่างน้อย 1 รูป');
    }

    final uploadedPaths = <String>[];
    final storage = _storageService;
    for (final evidence in evidences) {
      if (uploadedPathCache != null && uploadedPathCache.containsKey(evidence)) {
        uploadedPaths.add(uploadedPathCache[evidence]!);
      } else if (storage != null) {
        final path = await storage.uploadEvidence(
          userId: effectiveUserId,
          bytes: evidence.bytes,
          extension: evidence.extension,
        );
        if (uploadedPathCache != null) {
          uploadedPathCache[evidence] = path;
        }
        uploadedPaths.add(path);
      }
    }

    final combinedPaths = uploadedPaths.join(',');
    final res = await _callRpc('submit_merchant_kyc', params: {
      'p_shop_url': shopUrl.trim(),
      'p_category': category.trim(),
      'p_contact_phone': contactPhone.trim(),
      'p_evidence_paths': combinedPaths,
    });

    if (res is Map && res['ok'] == true) {
      return true;
    }
    return false;
  }
}
