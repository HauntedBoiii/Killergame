import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

@JS('requestPushSubscription')
external JSPromise<JSString?> _jsRequestPush(String vapidKey);

class PushNotificationService {
  static const _vapidPublicKey =
      'BBpdcMbNP9tiooqZx0lQgQQuoJcT0Lhmlly_55RmZaJMhclt_wmqH22qLquOx7xSxfatnguqfpmcrDhOwrWxUSM';

  static Future<void> init() async {
    if (!kIsWeb) return;
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final jsResult = await _jsRequestPush(_vapidPublicKey).toDart;
      if (jsResult == null) return;

      final subJson = jsResult.toDart;
      final parsed = jsonDecode(subJson) as Map<String, dynamic>;
      final endpoint = parsed['endpoint'] as String;

      await Supabase.instance.client.from('push_subscriptions').upsert({
        'user_id': userId,
        'subscription': subJson,
        'endpoint': endpoint,
      }, onConflict: 'endpoint');
    } catch (e) {
      debugPrint('Push init error: $e');
    }
  }
}
