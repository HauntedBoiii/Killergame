import 'package:flutter/material.dart';

class AppButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool outlined;
  final IconData? icon;
  final Color? color;
  final double? width;

  const AppButton({
    super.key,
    required this.label,
    this.onPressed,
    this.isLoading = false,
    this.outlined = false,
    this.icon,
    this.color,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final child = isLoading
        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[Icon(icon, size: 18), const SizedBox(width: 8)],
              Text(label),
            ],
          );

    final btn = outlined
        ? OutlinedButton(
            onPressed: isLoading ? null : onPressed,
            style: color != null
                ? OutlinedButton.styleFrom(
                    foregroundColor: color,
                    side: BorderSide(color: color!),
                  )
                : null,
            child: child,
          )
        : ElevatedButton(
            onPressed: isLoading ? null : onPressed,
            style: color != null
                ? ElevatedButton.styleFrom(backgroundColor: color, foregroundColor: Colors.white)
                : null,
            child: child,
          );

    return SizedBox(width: width ?? double.infinity, child: btn);
  }
}
