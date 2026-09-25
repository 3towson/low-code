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
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final primary = theme.colorScheme.primary;

    return Stack(
      children: [
        if (isDark)
          Positioned.fill(
            child: IgnorePointer(
              child: CustomPaint(
                painter: _AmbientGlowPainter(primary: primary),
              ),
            ),
          ),
        SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isDesktop = constraints.maxWidth >= 640;
              final minHeight = centerVertically
                  ? math.max(0.0, constraints.maxHeight - AppSpacing.page.vertical)
                  : 0.0;
              return SingleChildScrollView(
                padding: isDesktop
                    ? const EdgeInsets.symmetric(horizontal: 24, vertical: 36)
                    : AppSpacing.page,
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
                      child: isDesktop
                          ? Container(
                              padding: const EdgeInsets.all(28),
                              decoration: BoxDecoration(
                                color: (theme.cardTheme.color ?? const Color(0xFF131D31))
                                    .withOpacity(0.9),
                                borderRadius: BorderRadius.circular(24),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.08),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.4),
                                    blurRadius: 36,
                                    offset: const Offset(0, 12),
                                  ),
                                  BoxShadow(
                                    color: primary.withOpacity(0.05),
                                    blurRadius: 40,
                                    spreadRadius: 2,
                                  ),
                                ],
                              ),
                              child: child,
                            )
                          : child,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AmbientGlowPainter extends CustomPainter {
  const _AmbientGlowPainter({required this.primary});
  final Color primary;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint1 = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0, -0.9),
        radius: 1.2,
        colors: [
          primary.withOpacity(0.18),
          primary.withOpacity(0.05),
          Colors.transparent,
        ],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint1);

    final paint2 = Paint()
      ..shader = RadialGradient(
        center: const Alignment(0.8, 0.8),
        radius: 1.0,
        colors: [
          const Color(0xFF06B6D4).withOpacity(0.08),
          Colors.transparent,
        ],
        stops: const [0.0, 1.0],
      ).createShader(rect);
    canvas.drawRect(rect, paint2);
  }

  @override
  bool shouldRepaint(covariant _AmbientGlowPainter oldDelegate) =>
      oldDelegate.primary != primary;
}
