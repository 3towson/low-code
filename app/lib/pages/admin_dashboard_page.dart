import 'package:flutter/material.dart';

import '../services/admin_service.dart';
import '../services/app_settings.dart';

/// หน้าจอ Admin Moderation Console สำหรับตรวจสอบและอนุมัติรายงานลูกค้า COD
class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({
    super.key,
    required this.adminService,
    this.onBack,
  });

  final AdminService adminService;
  final VoidCallback? onBack;

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  bool _loading = true;
  String? _error;
  int _selectedTab = 0; // 0 = Reports, 1 = Merchants
  List<PendingReport> _reports = [];
  List<PendingMerchant> _merchants = [];
  AdminStats _stats = const AdminStats(
    pendingCount: 0,
    approvedToday: 0,
    rejectedToday: 0,
  );

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final stats = await widget.adminService.getStats();
      if (mounted) setState(() => _stats = stats);
    } catch (_) {
      // ใช้สถิติล่าสุดหรือ default
    }

    try {
      final reports = await widget.adminService.getPendingReports();
      List<PendingMerchant> merchants = [];
      try {
        merchants = await widget.adminService.getPendingMerchants();
      } catch (_) {
        // Fallback หากยังไม่ได้รัน migration merchant_kyc
      }
      if (!mounted) return;
      setState(() {
        _reports = reports;
        _merchants = merchants;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final errorStr = e.toString();
      String message = 'โหลดข้อมูลไม่สำเร็จ: $errorStr';
      if (errorStr.contains('other_details')) {
        message = 'ยังไม่ได้รัน Migration เพิ่มคอลัมน์ other_details ใน Supabase\n'
            'กรุณารัน SQL: ALTER TABLE public.cod_reports ADD COLUMN IF NOT EXISTS other_details text NULL;';
      }
      setState(() {
        _error = message;
        _loading = false;
      });
    }
  }

  Future<void> _approve(PendingReport report) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.check_circle_outline, color: Color(0xFF10B981)),
            SizedBox(width: 10),
            Text('ยืนยันอนุมัติรายงาน'),
          ],
        ),
        content: Text(
          report.customerName.isNotEmpty
              ? 'คุณต้องการอนุมัติรายงานของลูกค้า "${report.customerName}" หรือไม่?\n'
                  'เมื่ออนุมัติแล้ว ข้อมูลจะถูกนำไปคำนวณระดับความเสี่ยงทันที'
              : 'คุณต้องการอนุมัติ "${report.displayName}" หรือไม่?\n'
                  'เมื่ออนุมัติแล้ว ข้อมูลจะถูกนำไปคำนวณระดับความเสี่ยงทันที',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
            ),
            child: const Text('อนุมัติ'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final success = await widget.adminService.approveReport(report.id);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text(
              report.customerName.isNotEmpty
                  ? 'อนุมัติรายงาน "${report.customerName}" เรียบร้อยแล้ว'
                  : 'อนุมัติ "${report.displayName}" เรียบร้อยแล้ว',
            ),
          ),
        );
        _loadData();
      }
    } catch (e) {
      debugPrint('Admin approve report error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('เกิดข้อผิดพลาดในการอนุมัติรายงาน กรุณาลองใหม่อีกครั้ง'),
        ),
      );
    }
  }

  Future<void> _reject(PendingReport report) async {
    final controller = TextEditingController(text: 'หลักฐานไม่ชัดเจน');
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Color(0xFFEF4444)),
            SizedBox(width: 10),
            Text('ปฏิเสธรายงาน'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              report.customerName.isNotEmpty
                  ? 'ระบุเหตุผลในการปฏิเสธรายงาน "${report.customerName}":'
                  : 'ระบุเหตุผลในการปฏิเสธ "${report.displayName}":',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'เหตุผล เช่น ภาพหลักฐานไม่ชัดเจน หรือข้อมูลไม่ครบ',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('ยืนยันปฏิเสธ'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final success = await widget.adminService.rejectReport(
        report.id,
        controller.text.trim(),
      );
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text(
              report.customerName.isNotEmpty
                  ? 'ปฏิเสธรายงาน "${report.customerName}" เรียบร้อยแล้ว'
                  : 'ปฏิเสธ "${report.displayName}" เรียบร้อยแล้ว',
            ),
          ),
        );
        _loadData();
      }
    } catch (e) {
      debugPrint('Admin reject report error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('เกิดข้อผิดพลาดในการปฏิเสธรายงาน กรุณาลองใหม่อีกครั้ง'),
        ),
      );
    }
  }

  void _openEvidenceViewer(PendingReport report) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _EvidenceViewerDialog(
        report: report,
        adminService: widget.adminService,
        onApprove: () {
          Navigator.of(ctx).pop();
          _approve(report);
        },
        onReject: () {
          Navigator.of(ctx).pop();
          _reject(report);
        },
      ),
    );
  }

  Future<void> _approveMerchant(PendingMerchant merchant) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.verified_user_rounded, color: Color(0xFF10B981)),
            SizedBox(width: 10),
            Text('ยืนยันอนุมัติร้านค้า'),
          ],
        ),
        content: Text(
          'คุณต้องการอนุมัติร้านค้า "${merchant.shopName}" ให้เป็นร้านค้าที่ผ่านการยืนยัน (Verified Merchant) หรือไม่?\n\n'
          'เมื่ออนุมัติแล้ว ร้านค้านี้จะได้รับสิทธิ์ส่งรายงานพฤติกรรมลูกค้า COD ทันที',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF10B981),
            ),
            child: const Text('อนุมัติร้านค้า'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final success = await widget.adminService.approveMerchant(merchant.id);
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF10B981),
            content: Text('อนุมัติร้านค้า "${merchant.shopName}" เรียบร้อยแล้ว'),
          ),
        );
        _loadData();
      }
    } catch (e) {
      debugPrint('Admin approve merchant error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('เกิดข้อผิดพลาดในการอนุมัติร้านค้า กรุณาลองใหม่อีกครั้ง'),
        ),
      );
    }
  }

  Future<void> _rejectMerchant(PendingMerchant merchant) async {
    final controller = TextEditingController(
      text: 'หลักฐานการขายไม่ชัดเจน หรือยอดส่งไม่ถึง 50 ออเดอร์',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cancel_outlined, color: Color(0xFFEF4444)),
            SizedBox(width: 10),
            Text('ไม่อนุมัติร้านค้า'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('ระบุเหตุผลในการไม่อนุมัติร้านค้า "${merchant.shopName}":'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'เช่น ลิงก์หน้าร้านไม่ถูกต้อง หรือภาพหลักฐานไม่ชัดเจน',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('ยืนยันปฏิเสธ'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final success = await widget.adminService.rejectMerchant(
        merchant.id,
        controller.text.trim(),
      );
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('ปฏิเสธคำขอของร้าน "${merchant.shopName}" เรียบร้อยแล้ว'),
          ),
        );
        _loadData();
      }
    } catch (e) {
      debugPrint('Admin reject merchant error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('เกิดข้อผิดพลาดในการปฏิเสธร้านค้า กรุณาลองใหม่อีกครั้ง'),
        ),
      );
    }
  }

  Future<void> _suspendMerchant(PendingMerchant merchant) async {
    final controller = TextEditingController(
      text: 'ละเมิดข้อกำหนดการใช้งาน UGC หรือสร้างรายงานเท็จ',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.block_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 10),
            Text('ยืนยันระงับร้านค้า'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('ระบุเหตุผลในการระงับร้านค้า "${merchant.shopName}":'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'เช่น ละเมิดข้อกำหนด UGC หรือสร้างข้อมูลเท็จ',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            key: const Key('admin-confirm-suspend-button'),
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('ยืนยันระงับร้านค้า'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final success = await widget.adminService.suspendMerchant(
        merchant.id,
        controller.text.trim(),
      );
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('ระงับร้านค้า "${merchant.shopName}" เรียบร้อยแล้ว'),
          ),
        );
        _loadData();
      }
    } catch (e) {
      debugPrint('Admin suspend merchant error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('เกิดข้อผิดพลาดในการระงับบัญชีร้านค้า กรุณาลองใหม่อีกครั้ง'),
        ),
      );
    }
  }

  Future<void> _suspendMerchantFromReport(PendingReport report) async {
    if (report.sellerId == null || report.sellerId!.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('ไม่พบข้อมูลร้านค้า หรือบัญชีร้านค้าถูกลบไปแล้ว'),
        ),
      );
      return;
    }

    final controller = TextEditingController(
      text: 'ส่งรายงานอันเป็นเท็จหรือละเมิดนโยบาย UGC',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.block_rounded, color: Color(0xFFEF4444)),
            SizedBox(width: 10),
            Text('ระงับร้านค้าผู้รายงาน'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('คุณต้องการระงับร้านค้า "${report.shopName}" ที่ส่งรายงานนี้หรือไม่?'),
            const SizedBox(height: 12),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'ระบุเหตุผล เช่น ส่งข้อมูลเท็จ หรือกลั่นแกล้งลูกค้า',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('ยกเลิก'),
          ),
          FilledButton(
            key: const Key('admin-confirm-suspend-report-merchant-button'),
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            child: const Text('ยืนยันระงับร้านค้า'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final success = await widget.adminService.suspendMerchant(
        report.sellerId!,
        controller.text.trim(),
      );
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFFEF4444),
            content: Text('ระงับร้านค้า "${report.shopName}" เรียบร้อยแล้ว'),
          ),
        );
        _loadData();
      }
    } catch (e) {
      debugPrint('Admin suspend merchant error: $e');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: Colors.red,
          content: Text('เกิดข้อผิดพลาดในการระงับบัญชีร้านค้า กรุณาลองใหม่อีกครั้ง'),
        ),
      );
    }
  }

  void _openMerchantEvidenceViewer(PendingMerchant merchant) {
    showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => _MerchantEvidenceViewerDialog(
        merchant: merchant,
        adminService: widget.adminService,
        onApprove: () {
          Navigator.of(ctx).pop();
          _approveMerchant(merchant);
        },
        onReject: () {
          Navigator.of(ctx).pop();
          _rejectMerchant(merchant);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final bg = isDark ? const Color(0xFF090D16) : const Color(0xFFF1F5F9);
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);

    return Scaffold(
      backgroundColor: bg,
      body: SafeArea(
        child: Column(
          children: [
            // Admin Top Header
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: cardBg,
                border: Border(bottom: BorderSide(color: borderColor)),
              ),
              child: LayoutBuilder(
                builder: (context, headerConstraints) {
                  final isCompact = headerConstraints.maxWidth < 600;
                  return Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.admin_panel_settings_rounded,
                          color: Color(0xFF3B82F6),
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ระบบจัดการผู้ดูแลระบบ (Admin Console)',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            Text(
                              'ตรวจสอบหลักฐานและอนุมัติรายงานลูกค้า COD',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11, color: Colors.grey),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        tooltip: 'รีเฟรชข้อมูล',
                        onPressed: _loading ? null : _loadData,
                        icon: const Icon(Icons.refresh_rounded, size: 20),
                      ),
                      const SizedBox(width: 4),
                      if (isCompact)
                        IconButton(
                          tooltip: 'กลับหน้าหลัก',
                          onPressed:
                              widget.onBack ?? () => Navigator.of(context).pop(),
                          icon: const Icon(Icons.arrow_back_rounded, size: 20),
                        )
                      else
                        OutlinedButton.icon(
                          onPressed:
                              widget.onBack ?? () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            minimumSize: const Size(0, 36),
                            padding: const EdgeInsets.symmetric(horizontal: 14),
                          ),
                          icon: const Icon(Icons.arrow_back_rounded, size: 16),
                          label: const Text('กลับหน้าหลัก'),
                        ),
                    ],
                  );
                },
              ),
            ),

            // Content Area
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(_error!,
                                  style: const TextStyle(color: Colors.red)),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: _loadData,
                                child: const Text('ลองใหม่'),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              // Metric Cards
                              _buildMetricCards(),
                              const SizedBox(height: 20),

                              // Tab Switcher
                              _buildTabSelector(),
                              const SizedBox(height: 18),

                              // Header Queue Section
                              Row(
                                children: [
                                  Icon(
                                    _selectedTab == 0
                                        ? Icons.pending_actions_rounded
                                        : Icons.verified_user_rounded,
                                    size: 20,
                                    color: const Color(0xFF3B82F6),
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _selectedTab == 0
                                          ? 'คิวรายงานลูกค้าที่รอตรวจ (${_reports.length} รายการ)'
                                          : 'คิวคำขอยืนยันตัวตนร้านค้า (${_merchants.length} ร้าน)',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 14),

                              if (_selectedTab == 0) ...[
                                if (_reports.isEmpty)
                                  _buildEmptyState()
                                else
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: _reports.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (ctx, i) =>
                                        _buildReportCard(_reports[i]),
                                  ),
                              ] else ...[
                                if (_merchants.isEmpty)
                                  _buildEmptyMerchantState()
                                else
                                  ListView.separated(
                                    shrinkWrap: true,
                                    physics:
                                        const NeverScrollableScrollPhysics(),
                                    itemCount: _merchants.length,
                                    separatorBuilder: (_, _) =>
                                        const SizedBox(height: 12),
                                    itemBuilder: (ctx, i) =>
                                        _buildMerchantCard(_merchants[i]),
                                  ),
                              ],
                            ],
                          ),
                        ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTabSelector() {
    final isDark = context.isDarkMode;
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF16233B) : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(12),
      ),
      padding: const EdgeInsets.all(4),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              key: const Key('admin-tab-reports'),
              onTap: () => setState(() => _selectedTab = 0),
              borderRadius: BorderRadius.circular(9),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9),
                decoration: BoxDecoration(
                  color: _selectedTab == 0
                      ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: _selectedTab == 0
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.report_problem_outlined,
                      size: 16,
                      color:
                          _selectedTab == 0 ? const Color(0xFF3B82F6) : null,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'รายงานลูกค้า COD (${_reports.length})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: _selectedTab == 0
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 13,
                          color: _selectedTab == 0
                              ? (isDark ? Colors.white : const Color(0xFF0F172A))
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 4),
          Expanded(
            child: InkWell(
              key: const Key('admin-tab-merchants'),
              onTap: () => setState(() => _selectedTab = 1),
              borderRadius: BorderRadius.circular(9),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 9, horizontal: 4),
                decoration: BoxDecoration(
                  color: _selectedTab == 1
                      ? (isDark ? const Color(0xFF0F172A) : Colors.white)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(9),
                  boxShadow: _selectedTab == 1
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.08),
                            blurRadius: 4,
                          )
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.verified_user_outlined,
                      size: 16,
                      color:
                          _selectedTab == 1 ? const Color(0xFF3B82F6) : null,
                    ),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text(
                        'คำขออนุมัติร้านค้า (${_merchants.length})',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: _selectedTab == 1
                              ? FontWeight.w700
                              : FontWeight.w500,
                          fontSize: 13,
                          color: _selectedTab == 1
                              ? (isDark ? Colors.white : const Color(0xFF0F172A))
                              : Colors.grey,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricCards() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isNarrow = constraints.maxWidth < 650;
        final items = [
          _MetricCard(
            title: 'รอการตรวจสอบ',
            count: _stats.pendingCount,
            color: const Color(0xFFF59E0B),
            icon: Icons.hourglass_top_rounded,
          ),
          _MetricCard(
            title: 'ร้านค้ารออนุมัติ',
            count: _merchants.length,
            color: const Color(0xFF3B82F6),
            icon: Icons.storefront_outlined,
          ),
          _MetricCard(
            title: 'อนุมัติแล้ววันนี้',
            count: _stats.approvedToday,
            color: const Color(0xFF10B981),
            icon: Icons.check_circle_outline_rounded,
          ),
          _MetricCard(
            title: 'ปฏิเสธแล้ววันนี้',
            count: _stats.rejectedToday,
            color: const Color(0xFFEF4444),
            icon: Icons.cancel_outlined,
          ),
        ];

        if (isNarrow) {
          return Column(
            children: items
                .map((w) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: w,
                    ))
                .toList(),
          );
        }

        return Row(
          children: items
              .map((w) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: w,
                    ),
                  ))
              .toList(),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.task_alt_rounded,
              size: 48,
              color: Color(0xFF10B981),
            ),
            SizedBox(height: 12),
            Text(
              'ไม่มีรายงานที่รอการตรวจสอบ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 4),
            Text(
              'รายงานลูกค้าทั้งหมดได้รับการตรวจสอบและอนุมัติครบถ้วนแล้ว',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyMerchantState() {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
      ),
      child: const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.verified_user_rounded,
              size: 48,
              color: Color(0xFF10B981),
            ),
            SizedBox(height: 12),
            Text(
              'ไม่มีคำขออนุมัติร้านค้าที่รอการตรวจสอบ',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            SizedBox(height: 4),
            Text(
              'คำขอยืนยันตัวตนร้านค้าทั้งหมดได้รับการตรวจสอบเรียบร้อยแล้ว',
              style: TextStyle(fontSize: 13, color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMerchantCard(PendingMerchant merchant) {
    final isDark = context.isDarkMode;
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.storefront_rounded,
                  color: Color(0xFF3B82F6),
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        Text(
                          merchant.shopName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (merchant.category != null &&
                            merchant.category!.isNotEmpty)
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              merchant.category!,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFF3B82F6),
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    if (merchant.shopUrl != null &&
                        merchant.shopUrl!.isNotEmpty)
                      Row(
                        children: [
                          const Icon(Icons.link_rounded,
                              size: 14, color: Colors.grey),
                          const SizedBox(width: 4),
                          Expanded(
                            child: SelectableText(
                              merchant.shopUrl!,
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFF2563EB),
                              ),
                            ),
                          ),
                        ],
                      ),
                    if (merchant.contactPhone != null &&
                        merchant.contactPhone!.isNotEmpty) ...[
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          const Icon(Icons.phone_outlined,
                              size: 13, color: Colors.grey),
                          const SizedBox(width: 4),
                          Text(
                            merchant.contactPhone!,
                            style: const TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // Evidence info
          if (merchant.evidencePaths.isNotEmpty) ...[
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 4,
              children: [
                Text(
                  'หลักฐานยอดขาย (>50 ออเดอร์): ${merchant.evidencePaths.length} ภาพ',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                TextButton.icon(
                  onPressed: () => _openMerchantEvidenceViewer(merchant),
                  icon: const Icon(Icons.zoom_in_rounded, size: 15),
                  label: const Text('คลิกเพื่อตรวจดูหลักฐาน'),
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
          // Action Buttons: Suspend / Reject / Approve
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                key: Key('admin-suspend-merchant-${merchant.id}'),
                onPressed: () => _suspendMerchant(merchant),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFDC2626),
                  side: const BorderSide(color: Color(0xFFDC2626)),
                ),
                icon: const Icon(Icons.block_rounded, size: 15),
                label: const Text('ระงับร้านค้า'),
              ),
              OutlinedButton.icon(
                key: Key('admin-reject-merchant-${merchant.id}'),
                onPressed: () => _rejectMerchant(merchant),
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444)),
                ),
                icon: const Icon(Icons.close_rounded, size: 15),
                label: const Text('ไม่อนุมัติ'),
              ),
              FilledButton.icon(
                key: Key('admin-approve-merchant-${merchant.id}'),
                onPressed: () => _approveMerchant(merchant),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF10B981),
                ),
                icon: const Icon(Icons.check_rounded, size: 15),
                label: const Text('อนุมัติร้านค้า (Verified)'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildReportCard(PendingReport report) {
    final isDark = context.isDarkMode;
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header: Name & Platform
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.person_outline_rounded,
                  color: Color(0xFFEF4444),
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      report.displayName,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'รายงานโดย: ${report.shopName} • ${_formatDate(report.createdAt)}',
                      style: const TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              // Platform tag
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF3B82F6).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  report.platform.toUpperCase(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF3B82F6),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Detail details
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Text('เหตุผล: ',
                        style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    Text(report.reason, style: const TextStyle(fontSize: 13)),
                    if (report.amount != null) ...[
                      const SizedBox(width: 16),
                      const Text('ความเสียหาย: ',
                          style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                      Text('฿${report.amount}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: Color(0xFFEF4444),
                            fontWeight: FontWeight.w600,
                          )),
                    ],
                  ],
                ),
                if (report.otherDetails != null &&
                    report.otherDetails!.trim().isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    'รายละเอียด: ${report.otherDetails}',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Action Buttons: View Evidence, Approve, Reject
          Wrap(
            spacing: 10,
            runSpacing: 8,
            alignment: WrapAlignment.end,
            children: [
              OutlinedButton.icon(
                onPressed: report.evidencePaths.isEmpty
                    ? null
                    : () => _openEvidenceViewer(report),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                ),
                icon: Icon(
                  report.evidencePaths.isEmpty
                      ? Icons.image_not_supported_outlined
                      : Icons.image_search_rounded,
                  size: 16,
                ),
                label: Text(
                  report.evidencePaths.isEmpty
                      ? 'ไม่มีรูปหลักฐาน'
                      : report.evidencePaths.length > 1
                          ? 'ดูรูปหลักฐาน (${report.evidencePaths.length})'
                          : 'ดูรูปหลักฐาน',
                ),
              ),
              if (report.sellerId != null && report.sellerId!.isNotEmpty)
                OutlinedButton.icon(
                  key: Key('admin-suspend-report-seller-${report.id}'),
                  onPressed: () => _suspendMerchantFromReport(report),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 36),
                    foregroundColor: const Color(0xFFDC2626),
                    side: const BorderSide(color: Color(0xFFDC2626)),
                  ),
                  icon: const Icon(Icons.block_rounded, size: 16),
                  label: const Text('ระงับร้านค้า'),
                ),
              OutlinedButton.icon(
                onPressed: () => _reject(report),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  foregroundColor: const Color(0xFFEF4444),
                  side: const BorderSide(color: Color(0xFFEF4444)),
                ),
                icon: const Icon(Icons.close_rounded, size: 16),
                label: const Text('ปฏิเสธ'),
              ),
              FilledButton.icon(
                onPressed: () => _approve(report),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 36),
                  backgroundColor: const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                ),
                icon: const Icon(Icons.check_rounded, size: 16),
                label: const Text('อนุมัติ'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day}/${dt.month}/${dt.year} ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
  }
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.count,
    required this.color,
    required this.icon,
  });

  final String title;
  final int count;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final cardBg = isDark ? const Color(0xFF111827) : Colors.white;
    final borderColor =
        isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  count.toString(),
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Dialog ขยายดูรูปภาพหลักฐานแบบ Interactive Viewer (ซูม/เลื่อนได้)
class _EvidenceViewerDialog extends StatefulWidget {
  const _EvidenceViewerDialog({
    required this.report,
    required this.adminService,
    required this.onApprove,
    required this.onReject,
  });

  final PendingReport report;
  final AdminService adminService;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  State<_EvidenceViewerDialog> createState() => _EvidenceViewerDialogState();
}

class _EvidenceViewerDialogState extends State<_EvidenceViewerDialog> {
  final List<String> _signedUrls = [];
  int _currentIndex = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSignedUrls();
  }

  Future<void> _fetchSignedUrls() async {
    final paths = widget.report.evidencePaths;
    if (paths.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'ไม่มีไฟล์หลักฐานแนบมากับรายงานนี้';
      });
      return;
    }

    try {
      final urls = <String>[];
      for (final p in paths) {
        final url = await widget.adminService.getEvidenceSignedUrl(p);
        urls.add(url);
      }
      if (!mounted) return;
      setState(() {
        _signedUrls.addAll(urls);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Open evidence error: $e');
      if (!mounted) return;
      setState(() {
        _error = 'ไม่สามารถเปิดรูปหลักฐานได้ กรุณาลองใหม่อีกครั้ง';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 800),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.image_outlined, color: Color(0xFF3B82F6)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      widget.report.customerName.isNotEmpty
                          ? 'หลักฐานของ "${widget.report.customerName}"'
                          : 'หลักฐานของ ${widget.report.displayName}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_signedUrls.length > 1) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'รูปที่ ${_currentIndex + 1} จาก ${_signedUrls.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),

              // Image Viewer Area
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      widget.report.evidencePaths.isEmpty
                                          ? Icons.image_not_supported_outlined
                                          : Icons.broken_image_outlined,
                                      size: 48,
                                      color: const Color(0xFFEF4444),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      _error!,
                                      style: const TextStyle(
                                        color: Color(0xFFEF4444),
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                    if (widget.report.evidencePaths.isNotEmpty) ...[
                                      const SizedBox(height: 16),
                                      OutlinedButton.icon(
                                        onPressed: () {
                                          setState(() {
                                            _loading = true;
                                            _error = null;
                                            _signedUrls.clear();
                                          });
                                          _fetchSignedUrls();
                                        },
                                        icon: const Icon(Icons.refresh_rounded, size: 16),
                                        label: const Text('ลองโหลดใหม่อีกครั้ง'),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            )
                          : Stack(
                              children: [
                                Center(
                                  child: InteractiveViewer(
                                    key: ValueKey(_signedUrls[_currentIndex]),
                                    minScale: 0.8,
                                    maxScale: 4.0,
                                    child: Image.network(
                                      _signedUrls[_currentIndex],
                                      fit: BoxFit.contain,
                                      loadingBuilder: (ctx, child, progress) {
                                        if (progress == null) return child;
                                        final total = progress.expectedTotalBytes;
                                        final loaded = progress.cumulativeBytesLoaded;
                                        return Center(
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              CircularProgressIndicator(
                                                value: (total != null && total > 0)
                                                    ? loaded / total
                                                    : null,
                                              ),
                                              const SizedBox(height: 12),
                                              const Text(
                                                'กำลังโหลดภาพหลักฐาน...',
                                                style: TextStyle(fontSize: 12),
                                              ),
                                            ],
                                          ),
                                        );
                                      },
                                      errorBuilder: (_, _, _) => Center(
                                        child: Padding(
                                          padding: const EdgeInsets.all(16),
                                          child: Column(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              const Icon(
                                                Icons.broken_image_rounded,
                                                size: 44,
                                                color: Colors.orange,
                                              ),
                                              const SizedBox(height: 8),
                                              const Text(
                                                'ไม่สามารถแสดงรูปภาพได้ กรุณาตรวจสอบการเชื่อมต่อ',
                                                style: TextStyle(fontSize: 13),
                                              ),
                                              const SizedBox(height: 12),
                                              OutlinedButton.icon(
                                                onPressed: () {
                                                  setState(() {
                                                    _loading = true;
                                                    _error = null;
                                                    _signedUrls.clear();
                                                  });
                                                  _fetchSignedUrls();
                                                },
                                                icon: const Icon(Icons.refresh_rounded, size: 14),
                                                label: const Text('ลองใหม่'),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                                if (_signedUrls.length > 1) ...[
                                  if (_currentIndex > 0)
                                    Positioned(
                                      left: 12,
                                      top: 0,
                                      bottom: 0,
                                      child: Center(
                                        child: IconButton.filled(
                                          style: IconButton.styleFrom(
                                            backgroundColor: Colors.black45,
                                          ),
                                          tooltip: 'รูปก่อนหน้า',
                                          icon: const Icon(
                                            Icons.chevron_left,
                                            color: Colors.white,
                                          ),
                                          onPressed: () => setState(
                                            () => _currentIndex--,
                                          ),
                                        ),
                                      ),
                                    ),
                                  if (_currentIndex < _signedUrls.length - 1)
                                    Positioned(
                                      right: 12,
                                      top: 0,
                                      bottom: 0,
                                      child: Center(
                                        child: IconButton.filled(
                                          style: IconButton.styleFrom(
                                            backgroundColor: Colors.black45,
                                          ),
                                          tooltip: 'รูปถัดไป',
                                          icon: const Icon(
                                            Icons.chevron_right,
                                            color: Colors.white,
                                          ),
                                          onPressed: () => setState(
                                            () => _currentIndex++,
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                              ],
                            ),
                ),
              ),
              if (_signedUrls.length > 1) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < _signedUrls.length; i++)
                      InkWell(
                        onTap: () => setState(() => _currentIndex = i),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _currentIndex == i
                                ? const Color(0xFF3B82F6)
                                : Colors.grey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'รูปที่ ${i + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _currentIndex == i
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

              // Bottom Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: widget.onReject,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      foregroundColor: const Color(0xFFEF4444),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('ปฏิเสธรายงาน'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: widget.onApprove,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 36),
                      backgroundColor: const Color(0xFF10B981),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('อนุมัติรายงาน'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dialog ขยายดูรูปภาพหลักฐานการยืนยันร้านค้า (>50 ออเดอร์)
class _MerchantEvidenceViewerDialog extends StatefulWidget {
  const _MerchantEvidenceViewerDialog({
    required this.merchant,
    required this.adminService,
    required this.onApprove,
    required this.onReject,
  });

  final PendingMerchant merchant;
  final AdminService adminService;
  final VoidCallback onApprove;
  final VoidCallback onReject;

  @override
  State<_MerchantEvidenceViewerDialog> createState() =>
      _MerchantEvidenceViewerDialogState();
}

class _MerchantEvidenceViewerDialogState
    extends State<_MerchantEvidenceViewerDialog> {
  final List<String> _signedUrls = [];
  int _currentIndex = 0;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchSignedUrls();
  }

  Future<void> _fetchSignedUrls() async {
    final paths = widget.merchant.evidencePaths;
    if (paths.isEmpty) {
      setState(() {
        _loading = false;
        _error = 'ไม่มีไฟล์หลักฐานแนบมากับคำขอนี้';
      });
      return;
    }

    try {
      final urls = <String>[];
      for (final p in paths) {
        final url = await widget.adminService
            .getEvidenceSignedUrl(p, bucket: 'merchant-evidences');
        urls.add(url);
      }
      if (!mounted) return;
      setState(() {
        _signedUrls.addAll(urls);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Open merchant evidence error: $e');
      if (!mounted) return;
      setState(() {
        _error = 'ไม่สามารถเปิดรูปหลักฐานได้ กรุณาลองใหม่อีกครั้ง';
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 700, maxHeight: 800),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Header
              Row(
                children: [
                  const Icon(Icons.storefront_outlined,
                      color: Color(0xFF3B82F6)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'หลักฐานร้านค้า "${widget.merchant.shopName}"',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (_signedUrls.length > 1) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF3B82F6).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'รูปที่ ${_currentIndex + 1} จาก ${_signedUrls.length}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3B82F6),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
              const Divider(),
              const SizedBox(height: 8),

              // Image Viewer Area
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _error != null
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Text(
                                  _error!,
                                  style: const TextStyle(
                                    color: Color(0xFFEF4444),
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            )
                          : Center(
                              child: InteractiveViewer(
                                key: ValueKey(_signedUrls[_currentIndex]),
                                minScale: 0.8,
                                maxScale: 4.0,
                                child: Image.network(
                                  _signedUrls[_currentIndex],
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, _, _) => const Center(
                                    child: Icon(
                                      Icons.broken_image_rounded,
                                      size: 44,
                                      color: Colors.orange,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                ),
              ),
              if (_signedUrls.length > 1) ...[
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (int i = 0; i < _signedUrls.length; i++)
                      InkWell(
                        onTap: () => setState(() => _currentIndex = i),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 4),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _currentIndex == i
                                ? const Color(0xFF3B82F6)
                                : Colors.grey.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'รูปที่ ${i + 1}',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: _currentIndex == i
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
              const SizedBox(height: 16),

              // Bottom Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    onPressed: widget.onReject,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFFEF4444),
                    ),
                    icon: const Icon(Icons.close_rounded, size: 16),
                    label: const Text('ไม่อนุมัติ'),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    onPressed: widget.onApprove,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 16),
                    label: const Text('อนุมัติร้านค้า (Verified)'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

