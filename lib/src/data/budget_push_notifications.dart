import 'dart:convert';
import 'dart:html' as html;
import 'dart:js_util' as js_util;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Web Push subscription lives on the installed device; subscription metadata
/// is linked to the signed-in user with Supabase Row Level Security.
class BudgetPushNotifications {
  static const publicVapidKey =
      'BLP4MeCqt6lRgkvl9nOT4S-ccSMuIu9gAQUnoYDyPXuksDcbVOqif-rDhpqMWZG-xkyQUcJVjkAHL29t0Ngc0-c';

  static dynamic get _bridge => js_util.getProperty(html.window, 'budgetPush');

  static Future<String?> _call(String method, [List<dynamic> args = const []]) async {
    final bridge = _bridge;
    if (bridge == null) throw StateError('Push notifications are not available in this app version.');
    final raw = await js_util.promiseToFuture<dynamic>(
      js_util.callMethod(bridge, method, args),
    );
    return raw as String?;
  }

  static Future<void> _save(String? json) async {
    if (json == null || json.isEmpty) return;
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw StateError('Sign in before enabling notifications.');
    final payload = Map<String, dynamic>.from(jsonDecode(json) as Map);
    final endpoint = payload['endpoint'] as String?;
    if (endpoint == null || endpoint.isEmpty) throw StateError('No push endpoint was returned.');
    await client.from('push_subscriptions').upsert({
      'user_id': uid,
      'endpoint': endpoint,
      'subscription': payload,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }, onConflict: 'user_id,endpoint');
  }

  /// Call in response to a user tap to satisfy iOS's notification permission requirements.
  static Future<void> enable() async {
    final json = await _call('subscribe', [publicVapidKey]);
    await _save(json);
  }

  /// Re-associate an existing device subscription on sign-in without prompting.
  static Future<void> restoreExisting() async {
    final json = await _call('existing');
    await _save(json);
  }

  static Future<bool> get hasExisting async {
    try {
      final json = await _call('existing');
      return json != null && json.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  static Future<int> sendTest() async {
    await enable();
    final client = Supabase.instance.client;
    final token = client.auth.currentSession?.accessToken;
    if (token == null) throw StateError('Sign in before testing notifications.');
    final response = await client.functions.invoke(
      'budget-payment-push',
      body: {'action': 'test'},
      headers: {'Authorization': 'Bearer $token'},
    );
    final data = response.data;
    if (response.status != 200 || data is! Map) {
      throw StateError('Push server returned an error: $data');
    }
    final count = (data['sent'] as num?)?.toInt() ?? 0;
    if (count < 1) throw StateError('No registered device accepted the push message. Check notification permissions.');
    return count;
  }

  static Future<void> removeOnSignOut() async {
    final client = Supabase.instance.client;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      final existing = await _call('existing');
      if (existing == null) return;
      final data = Map<String, dynamic>.from(jsonDecode(existing) as Map);
      final endpoint = data['endpoint'] as String?;
      if (endpoint != null) {
        await client.from('push_subscriptions').delete()
          .eq('user_id', uid).eq('endpoint', endpoint);
      }
    } catch (_) {
      // Do not prevent sign-out if a device is offline.
    }
  }
}
