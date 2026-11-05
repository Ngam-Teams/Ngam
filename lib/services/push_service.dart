import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../main.dart';
import '../screens/shared/chat_screen.dart';
import 'supabase_service.dart';

/// Flag supaya app lock tahu reply sedang aktif dan tak perlu lock
final ValueNotifier<bool> isReplyingFromNotification = ValueNotifier(false);

/// Notifier supaya chat screen boleh refresh bila ada reply dari notification
final ValueNotifier<String?> lastNotificationReplyConversationId = ValueNotifier(null);

int getConsistentNotificationId(String string) {
  int hash = 0;
  for (int i = 0; i < string.length; i++) {
    hash = 31 * hash + string.codeUnitAt(i);
  }
  return hash & 0x7FFFFFFF;
}

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("Handling a background message: ${message.messageId}");
}

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) async {
  if (notificationResponse.actionId == 'reply_action' && notificationResponse.input != null) {
    try {
      WidgetsFlutterBinding.ensureInitialized();
      await dotenv.load(fileName: ".env");
      await SupabaseService.initialize();
      
      final String inputMessage = notificationResponse.input!;
      
      final parts = notificationResponse.payload?.split('|') ?? [];
      final conversationId = parts.isNotEmpty ? parts[0] : null;
      final payloadUserId = parts.length > 1 ? parts[1] : null;
      final payloadToken = parts.length > 2 ? parts[2] : null;
      
      if (conversationId != null && conversationId.isNotEmpty) {
        final notificationId = getConsistentNotificationId(conversationId);
        final userId = Supabase.instance.client.auth.currentUser?.id ?? payloadUserId;
        
        if (userId != null && userId.isNotEmpty) {
          final now = DateTime.now().toUtc().toIso8601String();
          
          // Guna custom client supaya tak bergantung pada session restore di background isolate
          final customClient = SupabaseClient(
            dotenv.env['SUPABASE_URL']!,
            dotenv.env['SUPABASE_ANON_KEY']!,
            headers: (payloadToken != null && payloadToken.isNotEmpty) 
                ? {'Authorization': 'Bearer $payloadToken'}
                : {},
          );

          await customClient.from('messages').insert({
            'conversation_id': conversationId,
            'sender_id': userId,
            'content': inputMessage,
            'created_at': now,
          });
          
          await customClient.from('conversations').update({
            'last_message': inputMessage,
            'last_message_sender_id': userId,
            'last_message_is_read': false,
            'updated_at': now,
          }).eq('id', conversationId);

          // Notify chat screen supaya auto-refresh
          lastNotificationReplyConversationId.value = conversationId;
          
          // Papar notification ringkas secara senyap (tanpa sound/heads-up)
          final plugin = FlutterLocalNotificationsPlugin();
          await plugin.show(
            id: notificationId,
            title: 'Ngam',
            body: 'You: $inputMessage',
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                'ngam_high_importance_channel',
                'High Importance Notifications',
                channelDescription: 'This channel is used for important notifications.',
                importance: Importance.max, // Mesti sama dengan channel
                priority: Priority.high,
                onlyAlertOnce: true, // INI PENTING! Update senyap je
                showWhen: true,
                autoCancel: true,
              ),
            ),
          );
        } else {
          await FlutterLocalNotificationsPlugin().cancel(id: notificationId);
        }
      }
    } catch (e) {
      debugPrint('Background reply error: $e');
      if (notificationResponse.payload != null) {
        final parts = notificationResponse.payload!.split('|');
        if (parts.isNotEmpty) {
          await FlutterLocalNotificationsPlugin().cancel(id: getConsistentNotificationId(parts[0]));
        }
      } else if (notificationResponse.id != null) {
        await FlutterLocalNotificationsPlugin().cancel(id: notificationResponse.id!);
      }
    }
  }
}

/// Handle reply dari notification bila app dalam foreground
void _handleForegroundNotificationResponse(NotificationResponse notificationResponse) async {
  if (notificationResponse.actionId == 'reply_action' && notificationResponse.input != null) {
    isReplyingFromNotification.value = true;
    try {
      final String inputMessage = notificationResponse.input!;
      
      final parts = notificationResponse.payload?.split('|') ?? [];
      final conversationId = parts.isNotEmpty ? parts[0] : null;
      final payloadUserId = parts.length > 1 ? parts[1] : null;
      
      if (conversationId != null && conversationId.isNotEmpty) {
        final notificationId = getConsistentNotificationId(conversationId);
        final userId = Supabase.instance.client.auth.currentUser?.id ?? payloadUserId;
        if (userId != null) {
          final now = DateTime.now().toUtc().toIso8601String();
          await Supabase.instance.client.from('messages').insert({
            'conversation_id': conversationId,
            'sender_id': userId,
            'content': inputMessage,
            'created_at': now,
          });
          
          await Supabase.instance.client.from('conversations').update({
            'last_message': inputMessage,
            'last_message_sender_id': userId,
            'last_message_is_read': false,
            'updated_at': now,
          }).eq('id', conversationId);
          
          // Notify chat screen supaya auto-refresh
          lastNotificationReplyConversationId.value = conversationId;
          
          // Smooth update without popping up again
          await FlutterLocalNotificationsPlugin().show(
            id: notificationId,
            title: 'Ngam',
            body: 'You: $inputMessage',
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                'ngam_high_importance_channel',
                'High Importance Notifications',
                channelDescription: 'This channel is used for important notifications.',
                importance: Importance.max,
                priority: Priority.high,
                onlyAlertOnce: true,
                showWhen: true,
                autoCancel: true,
              ),
            ),
          );
        } else {
          await FlutterLocalNotificationsPlugin().cancel(id: notificationId);
        }
      }
    } catch (e) {
      debugPrint('Foreground reply error: $e');
    } finally {
      isReplyingFromNotification.value = false;
    }
  } else {
    // Kalau user tap notification tu sendiri (bukan reply button)
    _navigateToChatWithRetry();
  }
}

Future<void> _navigateToChatWithRetry() async {
  for (int i = 0; i < 20; i++) { // Retry sampai navigator ready
    if (navigatorKey.currentState != null && navigatorKey.currentContext != null) {
      navigatorKey.currentState!.push(
        MaterialPageRoute(builder: (_) => const ChatScreen()),
      );
      return;
    }
    await Future.delayed(const Duration(milliseconds: 100));
  }
}

class PushService {
  static final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();

  static Future<void> initialize() async {
    if (kIsWeb) {
      debugPrint('[PushService] Web environment detected - browser notifications handled by NotificationBridge');
      return;
    }
    try {
      await Firebase.initializeApp();
      
      // Minta kebenaran notification (Wajib untuk iOS dan Android 13+)
      await FirebaseMessaging.instance.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('notification');

      const InitializationSettings initializationSettings =
          InitializationSettings(android: initializationSettingsAndroid);

      await _localNotifications.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: _handleForegroundNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      // Buat Notification Channel kat Android
      const AndroidNotificationChannel channel = AndroidNotificationChannel(
        'ngam_high_importance_channel', // id
        'High Importance Notifications', // tajuk
        description: 'This channel is used for important notifications.', // penerangan
        importance: Importance.max,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.createNotificationChannel(channel);

      // Minta secara explicit permission notification Android 13+
      await _localNotifications
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>()
          ?.requestNotificationsPermission();

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        debugPrint('Got a message whilst in the foreground!');
        debugPrint('Message data: ${message.data}');

        if (message.notification != null || message.data.containsKey('title') || message.data.containsKey('body')) {
          _showLocalNotification(message);
        }
      });

      // Handle bila user tap masa app kat background
      FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
        _handleTap(message);
      });

      // Handle bila user tap masa app dah tutup habis
      final initialMsg = await FirebaseMessaging.instance.getInitialMessage();
      if (initialMsg != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleTap(initialMsg);
        });
      }
    } catch (e) {
      debugPrint('Firebase not configured: $e');
      // User kena bubuh google-services.json baru jadi
    }
  }

  static void _handleTap(RemoteMessage message) {
    if (message.data.containsKey('type')) {
      final context = navigatorKey.currentContext;
      if (context != null) {
        // Untuk chat dengan update, kita campak user terus ke list Chat
        // tempat mana diorang boleh tengok chat aktif dan chat dalam task
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const ChatScreen()),
        );
      }
    }
  }

  static Future<void> _showLocalNotification(RemoteMessage message) async {
    final title = message.notification?.title ?? message.data['title'];
    String? body = message.notification?.body ?? message.data['body'];

    if (title == null && body == null) return;

    StyleInformation? styleInfo;
    if (body != null) {
      final lines = body.split('\n').map((line) {
        if (line.startsWith('__SYSTEM__:')) return line.replaceFirst('__SYSTEM__:', '');
        if (line.startsWith('You: __SYSTEM__:')) return line.replaceFirst('You: __SYSTEM__:', 'You: ');
        if (line.startsWith('__TASK_CARD__:')) return 'Sent a Task Card';
        if (line.startsWith('You: __TASK_CARD__:')) return 'You: Sent a Task Card';
        if (line.startsWith('__QUOTE__:')) return 'Sent a Custom Quote';
        if (line.startsWith('You: __QUOTE__:')) return 'You: Sent a Custom Quote';
        if (line.startsWith('__COUNTER__:')) return 'Sent a Counter-Offer';
        if (line.startsWith('You: __COUNTER__:')) return 'You: Sent a Counter-Offer';
        if (line == '__REQUEST_LOC__') return 'Requested your Location';
        if (line == 'You: __REQUEST_LOC__') return 'You: Requested your Location';
        return line;
      }).toList();

      body = lines.first; // Baris nombor 1 sekarang ni mesej yang paling baru

      if (lines.length > 1) {
        styleInfo = InboxStyleInformation(
          lines,
          contentTitle: title,
          summaryText: '${lines.length} new messages',
        );
      } else {
        styleInfo = BigTextStyleInformation(body);
      }
    }

    final bool hasConversation = message.data['conversation_id'] != null;

    final AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'ngam_high_importance_channel', // id
      'High Importance Notifications', // tajuk
      channelDescription: 'This channel is used for important notifications.',
      importance: Importance.max,
      priority: Priority.high,
      showWhen: true,
      playSound: true,
      enableVibration: true,
      icon: 'notification',
      styleInformation: styleInfo,
      actions: hasConversation ? <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'reply_action',
          'Reply',
          inputs: <AndroidNotificationActionInput>[
            AndroidNotificationActionInput(
              label: 'Type a message...',
            ),
          ],
        ),
      ] : null,
    );
    final NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);

    // Groupkan notifikasi ikut gig ID supaya dia replace notification yang lama
    final String tagId = message.data['conversation_id'] ?? message.data['gig_id'] ?? message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString();

    final session = Supabase.instance.client.auth.currentSession;
    final payloadStr = "${message.data['conversation_id']}|${session?.user.id ?? ''}|${session?.accessToken ?? ''}";

    await _localNotifications.show(
      id: getConsistentNotificationId(tagId),
      title: title,
      body: body,
      notificationDetails: platformChannelSpecifics,
      payload: payloadStr,
    );
  }

  static Future<String?> getToken() async {
    try {
      return await FirebaseMessaging.instance.getToken();
    } catch (e) {
      return null;
    }
  }

  static Future<void> saveTokenToSupabase(String userId) async {
    try {
      final token = await getToken();
      if (token != null) {
        await SupabaseService.updateProfile(userId: userId, fcmToken: token);
      }
    } catch (e) {
      debugPrint('Failed to save FCM token: $e');
    }
  }

  static Future<void> clearTokenFromSupabase(String userId) async {
    try {
      await SupabaseService.updateProfile(userId: userId, fcmToken: '');
    } catch (e) {
      debugPrint('Failed to clear FCM token: $e');
    }
  }
}
