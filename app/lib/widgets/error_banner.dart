import 'package:flutter/material.dart';

import '../theme.dart';

/// กล่องข้อความ error สีแดงอ่อนใต้ฟอร์ม
class ErrorBanner extends StatelessWidget {
  const ErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final app = AppColors.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: app.dangerBackground,
        borderRadius: BorderRadius.circular(AppSpacing.controlRadius),
        border: Border.all(color: app.danger),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.error_outline, color: app.danger, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: app.danger),
            ),
          ),
        ],
      ),
    );
  }
}
