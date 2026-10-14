import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../pages/report_customer_page.dart' show EvidenceFile;
import '../services/app_settings.dart';
import '../services/merchant_kyc_service.dart';
import '../utils/phone_utils.dart';
import '../utils/url_helper.dart';

const List<String> kShopCategories = [
  'เสื้อผ้าและแฟชั่น',
  'เครื่องสำอางและความงาม',
  'อิเล็กทรอนิกส์และอุปกรณ์เสริม',
  'อาหาร ขนม และเครื่องดื่ม',
  'ของใช้ในบ้านและตกแต่ง',
  'สินค้าแม่และเด็ก',
  'สุขภาพและอาหารเสริม',
  'สินค้าอื่นๆ',
];

/// กล่องโต้ตอบสำหรับยื่นขอรับการยืนยันตัวตนร้านค้า (Merchant KYC Dialog)
class MerchantKycDialog extends StatefulWidget {
  const MerchantKycDialog({
    super.key,
    required this.shopName,
    required this.kycService,
    this.initialInfo,
    this.imagePickerOverride,
    this.onSubmitted,
  });

  final String shopName;
  final MerchantKycService kycService;
  final MerchantKycInfo? initialInfo;
  final Future<EvidenceFile?> Function()? imagePickerOverride;
  final VoidCallback? onSubmitted;

  @override
  State<MerchantKycDialog> createState() => _MerchantKycDialogState();
}

class _MerchantKycDialogState extends State<MerchantKycDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _urlController;
  late final TextEditingController _phoneController;
  late String _selectedCategory;
  final List<EvidenceFile> _selectedEvidences = [];

  bool _submitting = false;
  String? _error;
  String? _evidenceError;
  final Map<EvidenceFile, String> _uploadedEvidencePaths = {};

  @override
  void initState() {
    super.initState();
    _urlController = TextEditingController(
      text: widget.initialInfo?.shopUrl ?? '',
    );
    _phoneController = TextEditingController(
      text: widget.initialInfo?.contactPhone ?? '',
    );
    _selectedCategory = widget.initialInfo?.category != null &&
            kShopCategories.contains(widget.initialInfo!.category)
        ? widget.initialInfo!.category!
        : kShopCategories.first;
  }

  @override
  void dispose() {
    _urlController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _pickEvidence() async {
    if (_submitting) return;
    if (_selectedEvidences.length >= 3) return;
    try {
      final file = widget.imagePickerOverride != null
          ? await widget.imagePickerOverride!()
          : await _defaultPickImage();
      if (file != null) {
        setState(() {
          if (_selectedEvidences.length < 3) {
            _selectedEvidences.add(file);
          }
          _evidenceError = null;
        });
      }
    } catch (e) {
      debugPrint('Pick KYC evidence error: $e');
      setState(() => _evidenceError = 'ไม่สามารถเลือกรูปภาพได้ กรุณาลองใหม่อีกครั้ง');
    }
  }

  Future<EvidenceFile?> _defaultPickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 85,
    );
    if (picked == null) return null;
    final bytes = await picked.readAsBytes();
    final ext = picked.name.contains('.')
        ? picked.name.split('.').last.toLowerCase()
        : 'jpg';
    return EvidenceFile(
      name: picked.name,
      bytes: bytes,
      extension: ext,
    );
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
      _evidenceError = null;
    });

    if (!_formKey.currentState!.validate()) return;

    if (_selectedEvidences.isEmpty) {
      setState(() {
        _evidenceError = 'กรุณาแนบภาพหลักฐานยอดขายหรือประวัติการส่งพัสดุอย่างน้อย 1 ภาพ';
      });
      return;
    }

    setState(() => _submitting = true);

    try {
      final ok = await widget.kycService.submitKyc(
        shopUrl: _urlController.text,
        category: _selectedCategory,
        contactPhone: _phoneController.text,
        evidences: _selectedEvidences,
        uploadedPathCache: _uploadedEvidencePaths,
      );

      if (!mounted) return;

      if (ok) {
        _uploadedEvidencePaths.clear();
        if (widget.onSubmitted != null) {
          widget.onSubmitted!();
        }
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Color(0xFF10B981),
            content: Row(
              children: [
                Icon(Icons.check_circle_outline, color: Colors.white),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'ยื่นคำขอยืนยันตัวตนสำเร็จ! เจ้าหน้าที่จะตรวจสอบภายใน 24-48 ชั่วโมง',
                  ),
                ),
              ],
            ),
          ),
        );
      } else {
        setState(() {
          _error = 'ยื่นคำขอไม่สำเร็จ กรุณาลองใหม่อีกครั้ง';
          _submitting = false;
        });
      }
    } catch (e) {
      debugPrint('Submit KYC error: $e');
      if (!mounted) return;
      setState(() {
        _error = 'เกิดข้อผิดพลาดในการยื่นข้อมูล กรุณาลองใหม่อีกครั้ง';
        _submitting = false;
      });
    }
  }

  bool get _hasUnsavedChanges {
    final initialUrl = widget.initialInfo?.shopUrl ?? '';
    final initialPhone = widget.initialInfo?.contactPhone ?? '';
    return (_urlController.text.trim() != initialUrl &&
            _urlController.text.trim().isNotEmpty) ||
        (_phoneController.text.trim() != initialPhone &&
            _phoneController.text.trim().isNotEmpty) ||
        _selectedEvidences.isNotEmpty;
  }

  Future<bool> _confirmDiscard() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ยกเลิกการยืนยันตัวตน?'),
        content: const Text(
          'ข้อมูลและภาพหลักฐานที่คุณกรอกไว้จะสูญหาย ต้องการปิดหน้าต่างนี้หรือไม่?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('กรอกต่อ'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFEF4444),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('ปิดและละทิ้งข้อมูล'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<void> _handleClose() async {
    if (_hasUnsavedChanges) {
      final discard = await _confirmDiscard();
      if (!discard) return;
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.isDarkMode;
    final cardBg = isDark ? const Color(0xFF131D31) : Colors.white;
    final borderColor = isDark ? const Color(0xFF22304A) : const Color(0xFFE2E8F0);

    return PopScope(
      canPop: !_hasUnsavedChanges,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        final discard = await _confirmDiscard();
        if (discard && context.mounted) {
          navigator.pop();
        }
      },
      child: Dialog(
        backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 580),
        child: Container(
          decoration: BoxDecoration(
            color: cardBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isDark ? 0.5 : 0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. Header with Badge
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF3B82F6).withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.verified_user_rounded,
                          color: Color(0xFF3B82F6),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'ยืนยันตัวตนร้านค้า (Merchant KYC)',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'เปิดสิทธิ์การรายงานลูกค้า COD เพื่อความน่าเชื่อถือของระบบ',
                              style: TextStyle(
                                fontSize: 12.5,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        key: const Key('merchant-kyc-close-button'),
                        onPressed: _submitting ? null : _handleClose,
                        icon: const Icon(Icons.close_rounded, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),

                  // Alert if suspended
                  if (widget.initialInfo?.isSuspended == true) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.block_rounded,
                            color: Color(0xFFEF4444),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'บัญชีร้านค้านี้ถูกระงับการใช้งาน: ${widget.initialInfo?.rejectionReason ?? "ละเมิดข้อกำหนด UGC"}\nไม่สามารถยื่นยืนยันตัวตนได้ กรุณาติดต่อ ${AppUrls.supportEmail}',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFFEF4444),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  // 2. Alert if rejected previously
                  if (widget.initialInfo?.isRejected == true &&
                      widget.initialInfo?.rejectionReason != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(
                            Icons.error_outline_rounded,
                            color: Color(0xFFEF4444),
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'คำขอก่อนหน้าไม่ผ่านการอนุมัติ: ${widget.initialInfo!.rejectionReason}\nกรุณาแนบข้อมูลและหลักฐานใหม่เพื่อยื่นพิจารณาอีกครั้ง',
                              style: const TextStyle(
                                fontSize: 12.5,
                                color: Color(0xFFEF4444),
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],

                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFFEF4444).withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        _error!,
                        style: const TextStyle(color: Color(0xFFEF4444), fontSize: 13),
                      ),
                    ),
                    const SizedBox(height: 14),
                  ],

                  // 3. Shop Name (Read-only)
                  TextFormField(
                    initialValue: widget.shopName,
                    enabled: false,
                    decoration: const InputDecoration(
                      labelText: 'ชื่อร้านค้า',
                      prefixIcon: Icon(Icons.storefront_outlined, size: 18),
                      helperText: 'ชื่อร้านที่ลงทะเบียนไว้ในระบบ',
                    ),
                  ),
                  const SizedBox(height: 14),

                  // 4. Store URL / Social Page
                  TextFormField(
                    key: const Key('kyc-store-url'),
                    controller: _urlController,
                    enabled: !_submitting,
                    decoration: const InputDecoration(
                      labelText: 'ลิงก์หน้าร้าน (Store URL / Social Page)',
                      hintText: 'เช่น facebook.com/shop หรือ tiktok.com/@shop',
                      prefixIcon: Icon(Icons.link_rounded, size: 18),
                    ),
                    validator: (v) {
                      final val = (v ?? '').trim();
                      if (val.isEmpty) return 'กรุณาระบุลิงก์หน้าร้านจริง';
                      if (val.length < 4) return 'ลิงก์หน้าร้านสั้นเกินไป';
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),

                  // 5. Category & Phone Row
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isNarrow = constraints.maxWidth < 420;
                      final categoryField = DropdownButtonFormField<String>(
                        key: const Key('kyc-category'),
                        isExpanded: true,
                        initialValue: _selectedCategory,
                        decoration: const InputDecoration(
                          labelText: 'หมวดหมู่สินค้าหลัก',
                          prefixIcon: Icon(Icons.category_outlined, size: 18),
                        ),
                        items: kShopCategories
                            .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                            .toList(),
                        onChanged: _submitting
                            ? null
                            : (val) {
                                if (val != null) setState(() => _selectedCategory = val);
                              },
                      );

                      final phoneField = TextFormField(
                        key: const Key('kyc-contact-phone'),
                        controller: _phoneController,
                        enabled: !_submitting,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'เบอร์ติดต่อเจ้าของร้าน',
                          hintText: '08XXXXXXXX',
                          prefixIcon: Icon(Icons.phone_outlined, size: 18),
                        ),
                        validator: validateThaiPhone,
                      );

                      if (isNarrow) {
                        return Column(
                          children: [
                            categoryField,
                            const SizedBox(height: 14),
                            phoneField,
                          ],
                        );
                      }

                      return Row(
                        children: [
                          Expanded(child: categoryField),
                          const SizedBox(width: 12),
                          Expanded(child: phoneField),
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 18),

                  // 6. Evidence Upload Section (>50 Orders)
                  Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF16233B) : const Color(0xFFF8FAFF),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.receipt_long_rounded,
                              size: 18,
                              color: Color(0xFF3B82F6),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'หลักฐานการขายจริง (>50 ออเดอร์)',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                ),
                              ),
                            ),
                            Text(
                              '${_selectedEvidences.length}/3 รูป',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: isDark
                                    ? const Color(0xFF94A3B8)
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'แนบภาพแคปหน้าจอ Seller Center หรือใบสรุปยอดจัดส่งพัสดุจากขนส่ง (Flash / J&T / Kerry / ไปรษณีย์) ที่แสดงยอดรวมมากกว่า 50 รายการ',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark
                                ? const Color(0xFF94A3B8)
                                : const Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Thumbnails & Add button
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (int i = 0; i < _selectedEvidences.length; i++)
                              Stack(
                                children: [
                                  Container(
                                    width: 76,
                                    height: 76,
                                    decoration: BoxDecoration(
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(
                                        color: const Color(0xFF3B82F6),
                                      ),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: Image.memory(
                                      _selectedEvidences[i].bytes,
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  Positioned(
                                    top: 2,
                                    right: 2,
                                    child: InkWell(
                                      onTap: _submitting
                                          ? null
                                          : () => setState(() {
                                              final removed = _selectedEvidences.removeAt(i);
                                              _uploadedEvidencePaths.remove(removed);
                                            }),
                                      child: Container(
                                        padding: const EdgeInsets.all(2),
                                        decoration: const BoxDecoration(
                                          color: Colors.black87,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.close,
                                          size: 14,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            if (_selectedEvidences.length < 3)
                              InkWell(
                                key: const Key('kyc-add-evidence'),
                                onTap: _submitting ? null : _pickEvidence,
                                borderRadius: BorderRadius.circular(10),
                                child: Container(
                                  width: 76,
                                  height: 76,
                                  decoration: BoxDecoration(
                                    color: isDark
                                        ? const Color(0xFF0F172A)
                                        : Colors.white,
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      color: borderColor,
                                      style: BorderStyle.solid,
                                    ),
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.add_photo_alternate_outlined,
                                        size: 22,
                                        color: Color(0xFF3B82F6),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'เพิ่มรูป',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                          ],
                        ),
                        if (_evidenceError != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            _evidenceError!,
                            style: const TextStyle(
                              color: Color(0xFFEF4444),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),

                  // 7. Actions (Cancel & Submit)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _submitting
                            ? null
                            : () => Navigator.of(context).pop(false),
                        child: const Text('ยกเลิก'),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        key: const Key('kyc-submit-button'),
                        onPressed: (_submitting || widget.initialInfo?.isSuspended == true) ? null : _submit,
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF2563EB),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 12,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        icon: _submitting
                            ? const SizedBox(
                                width: 16,
                                height: 16,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.send_rounded, size: 16),
                        label: Text(_submitting ? 'กำลังส่งข้อมูล...' : 'ส่งคำขอยืนยันตัวตน'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    ));
  }
}
