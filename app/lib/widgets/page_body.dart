import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme.dart';

/// เนื้อหาหน้าที่เลื่อนได้ กว้างไม่เกิน 480 และอยู่กลางจอบนจอใหญ่
class PageBody extends StatelessWidget {
  const PageBody({
    super.key,
    required this.child,
    this.centerVertically = false,
  });

  final Widget child;

  /// จัดเนื้อหาให้อยู่กลางจอแนวตั้งเมื่อเนื้อหาสั้นกว่าจอ
  final bool centerVertically;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final minHeight = centerVertically
              ? math.max(0.0, constraints.maxHeight - AppSpacing.page.vertical)
              : 0.0;
          return SingleChildScrollView(
            padding: AppSpacing.page,
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: minHeight),
              child: Align(
                alignment: centerVertically
                    ? Alignment.center
                    : Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: AppSpacing.maxContentWidth,
                  ),
                  child: child,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}
