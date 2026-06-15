import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String formatDate(DateTime dt) => DateFormat('dd.MM.yyyy HH:mm').format(dt.toLocal());

String timeAgo(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inSeconds < 60) return 'gerade eben';
  if (diff.inMinutes < 60) return 'vor ${diff.inMinutes} Min.';
  if (diff.inHours < 24) return 'vor ${diff.inHours} Std.';
  return 'vor ${diff.inDays} Tagen';
}

void showSnack(BuildContext context, String message, {bool isError = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      backgroundColor: isError ? Colors.red[700] : null,
    ),
  );
}

extension StringX on String {
  String capitalize() => isEmpty ? this : this[0].toUpperCase() + substring(1);
}
