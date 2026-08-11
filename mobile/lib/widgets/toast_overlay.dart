import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../theme/app_colors.dart';
import '../theme/app_radii.dart';
import '../state/toast_provider.dart';

/// Fade+slide-up toast pinned near the top of the app shell, reacting to
/// [ToastProvider].
class ToastOverlay extends StatelessWidget {
  const ToastOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final toast = context.watch<ToastProvider>();
    final colors = Theme.of(context).extension<AppColors>()!;
    return IgnorePointer(
      child: Align(
        alignment: Alignment.topCenter,
        child: SafeArea(
          child: AnimatedOpacity(
            opacity: toast.visible ? 1 : 0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.ease,
            child: AnimatedSlide(
              offset: toast.visible ? Offset.zero : const Offset(0, -0.4),
              duration: const Duration(milliseconds: 300),
              curve: Curves.ease,
              child: Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: colors.txt,
                    borderRadius: BorderRadius.circular(AppRadii.md),
                  ),
                  child: Text(
                    toast.message,
                    style: TextStyle(color: colors.bg, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
