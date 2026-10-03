import 'package:flutter/material.dart';
import '../core/theme/app_colors.dart';

/// Gym ElDeeb brand emblem and typography widget
class BrandLogo extends StatelessWidget {
  final double size;
  final bool showSubtitle;

  const BrandLogo({
    super.key,
    this.size = 80,
    this.showSubtitle = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: const LinearGradient(
              colors: [AppColors.primary, AppColors.primaryDark],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.primary.withOpacity(0.35),
                blurRadius: 24,
                spreadRadius: 2,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Center(
            child: Icon(
              Icons.fitness_center_rounded,
              size: size * 0.52,
              color: const Color(0xFF0F141C),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'جيم الديب',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: 0.5,
              ),
        ),
        if (showSubtitle) ...[
          const SizedBox(height: 4),
          Text(
            'GYM ELDEEB • نظام إدارة الصالة الرياضية',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.primaryLight,
                  fontWeight: FontWeight.w600,
                  fontSize: 11,
                  letterSpacing: 1.2,
                ),
          ),
        ],
      ],
    );
  }
}
