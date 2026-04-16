import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import '../models/habit.dart';
import '../services/social_service.dart';
import '../services/database_service.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  if (kDebugMode) {
    debugPrint('NotificationService: Background message received ${message.messageId}');
  }
}

class NotificationService {
  static const int _morningSummaryId = 1001;
  static const int _eveningSummaryId = 1002;
  static const int _habitReminderBaseId = 20000;
  static const int _habitReminderModulo = 700000;

  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FirebaseMessaging _fcm = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications = FlutterLocalNotificationsPlugin();
  
  StreamSubscription<User?>? _authSubscription;
  StreamSubscription<QuerySnapshot>? _friendInviteSubscription;
  StreamSubscription<QuerySnapshot>? _habitInviteSubscription;
  StreamSubscription<QuerySnapshot>? _groupInviteSubscription;
  StreamSubscription<QuerySnapshot>? _friendInviteResponseSubscription;
  StreamSubscription<QuerySnapshot>? _habitInviteResponseSubscription;
  StreamSubscription<QuerySnapshot>? _groupInviteResponseSubscription;
  StreamSubscription<QuerySnapshot>? _habitNoticeSubscription;
  
  Set<String> _notifiedInviteIds = {};
  bool _isInitialized = false;
  bool _isTimeZoneInitialized = false;
  String? _lastReminderSignature;

  Future<void> initialize() async {
    if (_isInitialized) return;
    if (kDebugMode) debugPrint('NotificationService: Initializing...');

    try {
      // 1. SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      _notifiedInviteIds = prefs.getStringList('notified_invite_ids')?.toSet() ?? {};

      // 2. Request permissions (with timeout to avoid hanging main)
      if (kDebugMode) debugPrint('NotificationService: Requesting FCM permissions...');
      try {
        await _fcm.requestPermission(
          alert: true,
          badge: true,
          sound: true,
        ).timeout(const Duration(seconds: 5));
      } on TimeoutException {
        if (kDebugMode) debugPrint('NotificationService: Permission request timed out.');
      }

      // 3. Setup Local Notifications
      const AndroidInitializationSettings initializationSettingsAndroid =
          AndroidInitializationSettings('@mipmap/ic_launcher');
      const DarwinInitializationSettings initializationSettingsDarwin =
          DarwinInitializationSettings();
      
      const InitializationSettings initializationSettings = InitializationSettings(
        android: initializationSettingsAndroid,
        iOS: initializationSettingsDarwin,
      );

      if (kDebugMode) debugPrint('NotificationService: Initializing Local Notifications...');
      await _localNotifications.initialize(
        settings: initializationSettings,
        onDidReceiveNotificationResponse: (response) {
          _handleNotificationTap(response.payload);
        },
      );

      try {
        await _requestLocalNotificationPermissions();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('NotificationService: Local notification permission request failed: $e');
        }
      }

      try {
        await _initializeTimeZone();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('NotificationService: Timezone initialization failed: $e');
        }
      }

      if (!kIsWeb) {
        const AndroidNotificationChannel highImportanceChannel = AndroidNotificationChannel(
          'high_importance_channel',
          'High Importance Notifications',
          description: 'This channel is used for important notifications.',
          importance: Importance.max,
        );

        const AndroidNotificationChannel socialAlertsChannel = AndroidNotificationChannel(
          'social_alerts_channel',
          'Social Alerts',
          description: 'Friend, habit, and group invitations.',
          importance: Importance.high,
        );

        const AndroidNotificationChannel dailySummaryChannel = AndroidNotificationChannel(
          'daily_summary',
          'Daily Summaries',
          description: 'Morning and evening daily summaries.',
          importance: Importance.defaultImportance,
        );

        const AndroidNotificationChannel habitRemindersChannel = AndroidNotificationChannel(
          'habit_reminders',
          'Habit Reminders',
          description: 'Scheduled reminders for individual habits.',
          importance: Importance.high,
        );

        final androidPlugin = _localNotifications
            .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

        try {
          await androidPlugin?.createNotificationChannel(highImportanceChannel);
          await androidPlugin?.createNotificationChannel(socialAlertsChannel);
          await androidPlugin?.createNotificationChannel(dailySummaryChannel);
          await androidPlugin?.createNotificationChannel(habitRemindersChannel);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('NotificationService: Failed creating channels: $e');
          }
        }
      }

      // 4. Listeners
      FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

      FirebaseMessaging.onMessage.listen((RemoteMessage message) {
        _showForegroundNotification(message);
      });

      FirebaseMessaging.onMessageOpenedApp.listen((message) {
        _handleNotificationTap(message.data.toString());
      });

      _fcm.onTokenRefresh.listen((token) async {
        final uid = FirebaseAuth.instance.currentUser?.uid;
        if (uid == null || uid.isEmpty) return;
        try {
          await _saveToken(uid, token);
        } catch (e) {
          if (kDebugMode) {
            debugPrint('NotificationService: Error saving refreshed FCM token: $e');
          }
        }
      });

      // Mark initialized before wiring auth listeners because auth callbacks
      // may fire immediately and trigger reminder scheduling.
      _isInitialized = true;
      _watchRealtimeAlerts();
      
      if (kDebugMode) debugPrint('NotificationService: Initialization Complete.');
    } catch (e) {
      if (kDebugMode) debugPrint('NotificationService: Critical Initialization Error: $e');
    }
  }

  void _showForegroundNotification(RemoteMessage message) {
    RemoteNotification? notification = message.notification;
    AndroidNotification? android = message.notification?.android;

    if (notification != null) {
      _localNotifications.show(
        id: notification.hashCode,
        title: notification.title,
        body: notification.body,
        notificationDetails: NotificationDetails(
          android: AndroidNotificationDetails(
            'high_importance_channel',
            'High Importance Notifications',
            importance: Importance.max,
            priority: Priority.high,
            icon: android?.smallIcon ?? '@mipmap/ic_launcher',
          ),
          iOS: const DarwinNotificationDetails(
            presentAlert: true,
            presentBadge: true,
            presentSound: true,
          ),
        ),
        payload: message.data.toString(),
      );
    }
  }

  void _handleNotificationTap(String? payload) {
    if (payload == null) return;
    if (kDebugMode) debugPrint('Notification tapped with payload: $payload');
  }

  // --- Realtime Invites ---

  void _watchRealtimeAlerts() {
    _authSubscription?.cancel();
    _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) async {
      _friendInviteSubscription?.cancel();
      _habitInviteSubscription?.cancel();
      _groupInviteSubscription?.cancel();
      _friendInviteResponseSubscription?.cancel();
      _habitInviteResponseSubscription?.cancel();
      _groupInviteResponseSubscription?.cancel();
      _habitNoticeSubscription?.cancel();

      if (user == null) {
        if (kDebugMode) debugPrint('NotificationService: User Logged Out.');
        _lastReminderSignature = null;
        return;
      }
      
      if (kDebugMode) debugPrint('NotificationService: User Logged In (${user.uid}). Setting up watchers...');
      
      await saveTokenToDatabase();
      // We don't await scheduleAllHabitReminders here to avoid blocking
      scheduleAllHabitReminders().catchError((e) => debugPrint('Error scheduling: $e'));

      // Production notifications should be delivered by backend FCM triggers.
      // Keep Firestore listener-based local alerts only in debug as fallback.
      if (kDebugMode) {
        final db = FirebaseFirestore.instance;

        _friendInviteSubscription = db
            .collection('friendRequests')
            .where('to', isEqualTo: user.uid)
            .where('status', isEqualTo: 'pending')
            .snapshots()
            .listen(
              (s) => _processInviteSnapshot(s, 'friendRequest'),
              onError: (e) => debugPrint('Friend invite stream error: $e'),
            );

        _habitInviteSubscription = db
            .collection('habitInvites')
            .where('to', isEqualTo: user.uid)
            .where('status', isEqualTo: 'pending')
            .snapshots()
            .listen(
              (s) => _processInviteSnapshot(s, 'habitInvite'),
              onError: (e) => debugPrint('Habit invite stream error: $e'),
            );

        _groupInviteSubscription = db
            .collection('groupInvites')
            .where('to', isEqualTo: user.uid)
            .where('status', isEqualTo: 'pending')
            .snapshots()
            .listen(
              (s) => _processInviteSnapshot(s, 'groupInvite'),
              onError: (e) => debugPrint('Group invite stream error: $e'),
            );

        // Notify sender when outgoing invites are accepted or declined.
        _friendInviteResponseSubscription = db
            .collection('friendRequests')
            .where('from', isEqualTo: user.uid)
            .snapshots()
            .listen(
              (s) => _processInviteResponseSnapshot(s, 'friendRequest'),
              onError: (e) => debugPrint('Friend invite response stream error: $e'),
            );

        _habitInviteResponseSubscription = db
            .collection('habitInvites')
            .where('from', isEqualTo: user.uid)
            .snapshots()
            .listen(
              (s) => _processInviteResponseSnapshot(s, 'habitInvite'),
              onError: (e) => debugPrint('Habit invite response stream error: $e'),
            );

        _groupInviteResponseSubscription = db
            .collection('groupInvites')
            .where('from', isEqualTo: user.uid)
            .snapshots()
            .listen(
              (s) => _processInviteResponseSnapshot(s, 'groupInvite'),
              onError: (e) => debugPrint('Group invite response stream error: $e'),
            );

        _habitNoticeSubscription = db
            .collection('habitNotices')
            .where('to', isEqualTo: user.uid)
            .where('status', isEqualTo: 'unread')
            .snapshots()
            .listen(
              _processHabitNoticeSnapshot,
              onError: (e) => debugPrint('Habit notice stream error: $e'),
            );
      }
    });
  }

    Future<void> _processHabitNoticeSnapshot(QuerySnapshot snapshot) async {
      final prefs = await SharedPreferences.getInstance();

      for (final doc in snapshot.docs) {
        final eventKey = 'habitNotice:${doc.id}';
        if (_notifiedInviteIds.contains(eventKey)) {
          continue;
        }

        final data = doc.data() as Map<String, dynamic>;
        final message = (data['message'] as String?)?.trim();
        final fallbackTitle = (data['groupName'] as String?)?.trim();
        final habitTitle = (data['habitTitle'] as String?)?.trim();
        final displayTitle = (fallbackTitle != null && fallbackTitle.isNotEmpty)
            ? fallbackTitle
            : ((habitTitle != null && habitTitle.isNotEmpty) ? habitTitle : 'Shared habit');

        try {
          await _localNotifications.show(
            id: eventKey.hashCode,
            title: 'Participant Left',
            body: message ?? 'A participant left "$displayTitle".',
            notificationDetails: const NotificationDetails(
              android: AndroidNotificationDetails(
                'social_alerts_channel',
                'Social Alerts',
                importance: Importance.high,
                priority: Priority.high,
              ),
              iOS: DarwinNotificationDetails(),
            ),
          );

          _notifiedInviteIds.add(eventKey);
          await prefs.setStringList('notified_invite_ids', _notifiedInviteIds.toList());
          await FirebaseFirestore.instance
              .collection('habitNotices')
              .doc(doc.id)
              .update({
                'status': 'notified',
                'notifiedAt': FieldValue.serverTimestamp(),
              });
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Error processing habit notice notification: $e');
          }
        }
      }
    }

  Future<void> _processInviteSnapshot(QuerySnapshot snapshot, String type) async {
    final prefs = await SharedPreferences.getInstance();
    
    for (var doc in snapshot.docs) {
      final eventKey = '$type:${doc.id}:pending';
      if (_notifiedInviteIds.contains(eventKey)) continue;

      final data = doc.data() as Map<String, dynamic>;
      final fromUserId = data['from'] as String?;
      
      if (fromUserId == null) continue;

      try {
        // 1. Fetch Sender Name (with timeout)
        final sender = await SocialService().getUserProfile(fromUserId).timeout(const Duration(seconds: 3));
        final senderName = sender?.displayName ?? 'A user';

        String title = 'Social Alert';
        String body = 'You have a new invitation.';

        if (type == 'friendRequest') {
          title = 'New Friend Request';
          body = '$senderName wants to connect with you.';
        } else if (type == 'habitInvite') {
          final habitId = data['habitId'] as String?;
          final habit = habitId != null ? await DatabaseService().getHabitById(habitId).timeout(const Duration(seconds: 3)) : null;
          title = 'Habit Invite';
          body = '$senderName invited you to join "${habit?.title ?? 'a habit'}"';
        } else if (type == 'groupInvite') {
          final groupName = data['groupName'] as String?;
          title = 'Group Invite';
          body = '$senderName invited you to join "$groupName"';
        }

        await _localNotifications.show(
          id: doc.id.hashCode,
          title: title,
          body: body,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'social_alerts_channel',
              'Social Alerts',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
        );

        _notifiedInviteIds.add(eventKey);
        await prefs.setStringList('notified_invite_ids', _notifiedInviteIds.toList());
      } catch (e) {
        if (kDebugMode) debugPrint('Error processing invite notification: $e');
      }
    }
  }

  Future<void> _processInviteResponseSnapshot(QuerySnapshot snapshot, String type) async {
    final prefs = await SharedPreferences.getInstance();

    for (var doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final status = (data['status'] as String?) ?? '';
      if (status != 'accepted' && status != 'declined') {
        continue;
      }

      final eventKey = '$type:${doc.id}:$status';
      if (_notifiedInviteIds.contains(eventKey)) {
        continue;
      }

      try {
        final toUserId = data['to'] as String?;
        final target = toUserId != null
            ? await SocialService().getUserProfile(toUserId).timeout(const Duration(seconds: 3))
            : null;
        final targetName = target?.displayName ?? 'A user';
        final isAccepted = status == 'accepted';

        String title;
        String body;

        if (type == 'friendRequest') {
          title = isAccepted ? 'Friend Request Accepted' : 'Friend Request Declined';
          body = isAccepted
              ? '$targetName accepted your friend request.'
              : '$targetName declined your friend request.';
        } else if (type == 'habitInvite') {
          final habitId = data['habitId'] as String?;
          final habit = habitId != null
              ? await DatabaseService().getHabitById(habitId).timeout(const Duration(seconds: 3))
              : null;
          final habitTitle = habit?.title ?? 'your habit';
          title = isAccepted ? 'Habit Invite Accepted' : 'Habit Invite Declined';
          body = isAccepted
              ? '$targetName accepted your invite to "$habitTitle".'
              : '$targetName declined your invite to "$habitTitle".';
        } else {
          final groupName = (data['groupName'] as String?)?.trim();
          final resolvedGroupName = (groupName == null || groupName.isEmpty)
              ? 'your group'
              : groupName;
          title = isAccepted ? 'Group Invite Accepted' : 'Group Invite Declined';
          body = isAccepted
              ? '$targetName accepted your invite to "$resolvedGroupName".'
              : '$targetName declined your invite to "$resolvedGroupName".';
        }

        await _localNotifications.show(
          id: eventKey.hashCode,
          title: title,
          body: body,
          notificationDetails: const NotificationDetails(
            android: AndroidNotificationDetails(
              'social_alerts_channel',
              'Social Alerts',
              importance: Importance.high,
              priority: Priority.high,
            ),
            iOS: DarwinNotificationDetails(),
          ),
        );

        _notifiedInviteIds.add(eventKey);
        await prefs.setStringList('notified_invite_ids', _notifiedInviteIds.toList());
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error processing invite response notification: $e');
        }
      }
    }
  }

  // --- Habit Reminders ---

  Future<void> scheduleAllHabitReminders() async {
    if (kIsWeb) return;

    if (!_isInitialized) {
      if (kDebugMode) {
        debugPrint(
          'NotificationService: Skipping reminder scheduling until initialization completes.',
        );
      }
      return;
    }

    if (!_isTimeZoneInitialized) {
      await _initializeTimeZone();
    }

    if (kDebugMode) debugPrint('NotificationService: Refreshing habit reminders...');

    try {
      final db = DatabaseService();
      final uid = db.userId;
      if (uid.isEmpty) return;

      // Use a one-time fetch instead of .first to avoid hanging on stream behavior
      final snapshot = await FirebaseFirestore.instance
          .collection('habits')
          .where('participants', arrayContains: uid)
          .get()
          .timeout(const Duration(seconds: 5));

      final habits = snapshot.docs.map((doc) => Habit.fromMap(doc.data(), id: doc.id)).toList();
      final prefs = await SharedPreferences.getInstance();
      final morningTime = prefs.getString('morning_time') ?? '8:00';
      final eveningTime = prefs.getString('evening_time') ?? '21:00';

      final signature = _buildReminderSignature(
        uid: uid,
        habits: habits,
        morningTime: morningTime,
        eveningTime: eveningTime,
      );
      if (_lastReminderSignature == signature) {
        if (kDebugMode) {
          debugPrint('NotificationService: Reminder configuration unchanged, skipping re-schedule.');
        }
        return;
      }

      await _cancelReminderNotificationsOnly();

      // 1. Morning Plan (8 AM)
      await _scheduleDailySummary(
        id: _morningSummaryId,
        prefKey: 'morning_time',
        defaultHour: 8,
        isMorning: true,
      );

      // 2. Evening Brief (9 PM)
      await _scheduleDailySummary(
        id: _eveningSummaryId,
        prefKey: 'evening_time',
        defaultHour: 21,
        isMorning: false,
      );

      // 3. Individual Habits
      for (var habit in habits) {
        final parsed = _parseReminderTime(habit.reminderTime);
        if (parsed == null) {
          continue;
        }

        await _scheduleHabitSpecific(
          id: _habitReminderId(habit.id),
          habitTitle: habit.title,
          hour: parsed.$1,
          minute: parsed.$2,
        );
      }
      if (kDebugMode) {
        debugPrint(
          'NotificationService: Scheduled ${habits.length + 2} timed reminders (including daily summaries).',
        );
      }

      _lastReminderSignature = signature;
    } catch (e) {
      if (kDebugMode) debugPrint('NotificationService: Error scheduling habits: $e');
    }
  }

  Future<void> _scheduleDailySummary({
    required int id,
    required String prefKey,
    required int defaultHour,
    required bool isMorning,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final timeStr = prefs.getString(prefKey) ?? '$defaultHour:00';
    final parsed = _parseReminderTime(timeStr) ?? (defaultHour, 0);
    final hour = parsed.$1;
    final minute = parsed.$2;

    String title = isMorning ? 'Today\'s Plan' : 'Today\'s Wrap-up';
    String body = isMorning
        ? 'Plan your day and stay consistent with your habits.'
        : 'Check your progress and finish your habits strong.';

    await _localNotifications.zonedSchedule(
      id: id,
      title: title,
      body: body,
      scheduledDate: _nextDateTime(hour, minute),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_summary',
          'Daily Summaries',
          importance: Importance.defaultImportance,
          priority: Priority.defaultPriority,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _scheduleHabitSpecific({
    required int id,
    required String habitTitle,
    required int hour,
    required int minute,
  }) async {
    await _localNotifications.zonedSchedule(
      id: id,
      title: 'Habit Reminder',
      body: 'Time for: $habitTitle',
      scheduledDate: _nextDateTime(hour, minute),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'habit_reminders',
          'Habit Reminders',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  Future<void> _initializeTimeZone() async {
    if (_isTimeZoneInitialized) return;

    tzdata.initializeTimeZones();
    try {
      final localTimeZone = await FlutterTimezone.getLocalTimezone();
      final normalized = _normalizeTimeZoneId(localTimeZone);
      tz.setLocalLocation(tz.getLocation(normalized));
      if (kDebugMode) {
        debugPrint('NotificationService: Local timezone set to $normalized');
      }
    } catch (_) {
      // Prefer a common device timezone fallback before UTC.
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Kolkata'));
      } catch (_) {
        tz.setLocalLocation(tz.UTC);
      }
      if (kDebugMode) {
        debugPrint('NotificationService: Falling back timezone to ${tz.local.name}');
      }
    }

    _isTimeZoneInitialized = true;
  }

  Future<void> _requestLocalNotificationPermissions() async {
    if (kIsWeb) return;

    final android = _localNotifications
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
    await android?.requestNotificationsPermission();

    final ios = _localNotifications
        .resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
    await ios?.requestPermissions(alert: true, badge: true, sound: true);

    final macos = _localNotifications
        .resolvePlatformSpecificImplementation<MacOSFlutterLocalNotificationsPlugin>();
    await macos?.requestPermissions(alert: true, badge: true, sound: true);
  }

  String _normalizeTimeZoneId(String raw) {
    final value = raw.trim();
    if (value.isEmpty) return value;

    const aliases = <String, String>{
      'Asia/Calcutta': 'Asia/Kolkata',
      'US/Pacific': 'America/Los_Angeles',
      'US/Central': 'America/Chicago',
      'US/Mountain': 'America/Denver',
      'US/Eastern': 'America/New_York',
    };

    return aliases[value] ?? value;
  }

  tz.TZDateTime _nextDateTime(int hour, int minute) {
    final now = tz.TZDateTime.now(tz.local);
    var scheduled = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);

    if (!scheduled.isAfter(now)) {
      scheduled = scheduled.add(const Duration(days: 1));
    }

    return scheduled;
  }

  (int, int)? _parseReminderTime(String? rawTime) {
    if (rawTime == null) return null;

    final parts = rawTime.split(':');
    if (parts.length != 2) return null;

    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;

    return (hour, minute);
  }

  int _habitReminderId(String habitId) {
    var hash = 0;
    for (final codeUnit in habitId.codeUnits) {
      hash = ((hash * 31) + codeUnit) & 0x3fffffff;
    }
    return _habitReminderBaseId + (hash % _habitReminderModulo);
  }

  Future<void> _cancelReminderNotificationsOnly() async {
    final pending = await _localNotifications.pendingNotificationRequests();

    for (final req in pending) {
      final id = req.id;
      final isSummary = id == _morningSummaryId || id == _eveningSummaryId;
      final isHabitReminder =
          id >= _habitReminderBaseId &&
          id < _habitReminderBaseId + _habitReminderModulo;

      if (isSummary || isHabitReminder) {
        await _localNotifications.cancel(id: id);
      }
    }
  }

  String _buildReminderSignature({
    required String uid,
    required List<Habit> habits,
    required String morningTime,
    required String eveningTime,
  }) {
    final reminderEntries = habits
        .where((habit) => habit.reminderTime != null && habit.reminderTime!.trim().isNotEmpty)
        .map((habit) => '${habit.id}|${habit.title}|${habit.reminderTime!.trim()}')
        .toList()
      ..sort();

    return [uid, morningTime.trim(), eveningTime.trim(), ...reminderEntries].join('||');
  }

  Future<void> saveTokenToDatabase() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      if (!kIsWeb &&
          (defaultTargetPlatform == TargetPlatform.iOS ||
              defaultTargetPlatform == TargetPlatform.macOS)) {
        final apnsToken = await _fcm.getAPNSToken().timeout(
          const Duration(seconds: 5),
          onTimeout: () => null,
        );

        if (apnsToken == null || apnsToken.isEmpty) {
          if (kDebugMode) {
            debugPrint(
              'NotificationService: APNS token not available yet. FCM token save deferred.',
            );
          }
          return;
        }
      }

      String? token = await _fcm.getToken().timeout(const Duration(seconds: 15));
      if (token != null) {
        await _saveToken(user.uid, token);
      } else if (kDebugMode) {
        debugPrint('NotificationService: FCM token unavailable at this moment.');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('NotificationService: Error saving FCM token: $e');
    }
  }

  Future<void> _saveToken(String uid, String token) async {
    await FirebaseFirestore.instance.collection('users').doc(uid).set({
      'fcmTokens': FieldValue.arrayUnion([token]),
      'lastTokenUpdate': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
