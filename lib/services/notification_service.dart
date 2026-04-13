import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    debugPrint('Handling a background message: ${message.messageId}');
  }
}

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot>? _friendInviteSubscription;
  StreamSubscription<QuerySnapshot>? _habitInviteSubscription;
  StreamSubscription<QuerySnapshot>? _groupInviteSubscription;
  final Set<String> _seenFriendInviteIds = <String>{};
  final Set<String> _seenHabitInviteIds = <String>{};
  final Set<String> _seenGroupInviteIds = <String>{};

  Future<void> initialize() async {
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    NotificationSettings settings = await _fcm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      if (kDebugMode) debugPrint('User granted permission');
    } else {
      if (kDebugMode) {
        debugPrint('User declined or has not accepted permission');
      }
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings();
    const InitializationSettings initializationSettings =
        InitializationSettings(
          android: initializationSettingsAndroid,
          iOS: initializationSettingsDarwin,
          macOS: initializationSettingsDarwin,
        );
    await _localNotifications.initialize(settings: initializationSettings);

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      RemoteNotification? notification = message.notification;
      AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        _localNotifications.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'high_importance_channel', // id
              'High Importance Notifications', // name
              channelDescription: 'This channel is used for important notifications.',
              importance: Importance.max,
              priority: Priority.high,
            ),
          ),
        );
      }
    });

    _watchRealtimeAlerts();
    await _scheduleDailyReminder();
  }

  Future<void> _scheduleDailyReminder() async {
    try {
      await _localNotifications.periodicallyShow(
        id: 9001,
        title: 'Trackly reminder',
        body: 'Check today\'s habits and keep your streak alive.',
        repeatInterval: RepeatInterval.daily,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'daily_reminders_channel',
            'Daily Reminders',
            channelDescription: 'Daily reminder notifications for habits.',
            importance: Importance.defaultImportance,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (e) {
      if (kDebugMode) debugPrint('Error scheduling daily reminders: $e');
    }
  }

  void _watchRealtimeAlerts() {
    _authSubscription?.cancel();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
      _friendInviteSubscription?.cancel();
      _habitInviteSubscription?.cancel();
      _groupInviteSubscription?.cancel();
      _seenFriendInviteIds.clear();
      _seenHabitInviteIds.clear();
      _seenGroupInviteIds.clear();

      if (user == null) {
        return;
      }

      final db = FirebaseFirestore.instance;
      _friendInviteSubscription = db
          .collection('friendRequests')
          .where('to', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen(
        (snapshot) => _notifyOnNewDocs(
          snapshot: snapshot,
          seenIds: _seenFriendInviteIds,
          title: 'New friend request',
          body: 'Someone sent you a friend request.',
        ),
      );

      _habitInviteSubscription = db
          .collection('habitInvites')
          .where('to', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen(
        (snapshot) => _notifyOnNewDocs(
          snapshot: snapshot,
          seenIds: _seenHabitInviteIds,
          title: 'New habit invite',
          body: 'You were invited to join a shared task.',
        ),
      );

      _groupInviteSubscription = db
          .collection('groupInvites')
          .where('to', isEqualTo: user.uid)
          .where('status', isEqualTo: 'pending')
          .snapshots()
          .listen(
        (snapshot) => _notifyOnNewDocs(
          snapshot: snapshot,
          seenIds: _seenGroupInviteIds,
          title: 'New group invite',
          body: 'You were invited to join a group.',
        ),
      );
    });
  }

  Future<void> _notifyOnNewDocs({
    required QuerySnapshot snapshot,
    required Set<String> seenIds,
    required String title,
    required String body,
  }) async {
    for (final doc in snapshot.docs) {
      final id = doc.id;
      final isNew = seenIds.add(id);
      if (!isNew) {
        continue;
      }
      await _localNotifications.show(
        id: id.hashCode,
        title: title,
        body: body,
        notificationDetails: const NotificationDetails(
          android: AndroidNotificationDetails(
            'social_alerts_channel',
            'Social Alerts',
            channelDescription: 'Alerts for invites and incoming requests.',
            importance: Importance.high,
            priority: Priority.high,
          ),
          iOS: DarwinNotificationDetails(),
          macOS: DarwinNotificationDetails(),
        ),
      );
    }
  }

  Future<void> saveTokenToDatabase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      String? token = await _fcm.getToken();
      if (token != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
              'fcmTokens': FieldValue.arrayUnion([token]),
            }, SetOptions(merge: true));
      }

      _fcm.onTokenRefresh.listen((newToken) async {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set({
              'fcmTokens': FieldValue.arrayUnion([newToken]),
            }, SetOptions(merge: true));
      });
    } catch (e) {
      if (kDebugMode) debugPrint('Error saving FCM token: $e');
    }
  }

  static Future<void> sendLocalReminder(String title, String body) async {
    final ln = FlutterLocalNotificationsPlugin();
    await ln.show(
      id: 0,
      title: title,
      body: body,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders_channel',
          'Reminders',
          importance: Importance.defaultImportance,
        ),
      ),
    );
  }
}
