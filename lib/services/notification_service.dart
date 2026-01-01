import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:flutter_timezone/flutter_timezone.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();

  // --- Giữ nguyên ID channel của bạn ---
  final String channelId = 'task_channel_alarm_v4';
  // ------------------------------------

  Future<void> init() async {
    print("NotificationService.init() - START");

    // timezone init
    try {
      tzdata.initializeTimeZones();
      print("NotificationService: tzdata.initializeTimeZones() OK");
    } catch (e, st) {
      print("NotificationService: tzdata.initializeTimeZones() FAILED: $e\n$st");
    }

    try {
      final String timeZoneName = await FlutterTimezone.getLocalTimezone();
      try {
        tz.setLocalLocation(tz.getLocation(timeZoneName));
        print("NotificationService: timezone set to $timeZoneName");
      } catch (e, st) {
        tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
        print("NotificationService: tz.getLocation failed, fallback to Asia/Ho_Chi_Minh. Error: $e\n$st");
      }
    } catch (e, st) {
      try {
        tz.setLocalLocation(tz.getLocation('Asia/Ho_Chi_Minh'));
      } catch (_) {}
      print("NotificationService: can't get device timezone, fallback to Asia/Ho_Chi_Minh. Error: $e\n$st");
    }

    const AndroidInitializationSettings initializationSettingsAndroid =
    AndroidInitializationSettings('@mipmap/ic_launcher');

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
    );

    try {
      await flutterLocalNotificationsPlugin.initialize(
        initializationSettings,
        onDidReceiveNotificationResponse: (details) {
          try {
            final payload = details.payload;
            print("Notification tapped. payload: $payload");
          } catch (e) {
            print("Error in onDidReceiveNotificationResponse: $e");
          }
        },
      );
      print("NotificationService: flutterLocalNotificationsPlugin initialized");
    } catch (e, st) {
      print("NotificationService: initialize() threw: $e\n$st");
    }

    final androidImplementation = flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

    if (androidImplementation != null) {
      print("NotificationService: Android implementation available");

      // Tạo channel
      try {
        final AndroidNotificationChannel channel = AndroidNotificationChannel(
          channelId,
          'Nhắc nhở công việc',
          description: 'Thông báo quan trọng như báo thức',
          importance: Importance.max,
          playSound: true,
        );

        await androidImplementation.createNotificationChannel(channel);
        print("NotificationService: Android channel '$channelId' created");
      } catch (e, st) {
        print("NotificationService: createNotificationChannel failed: $e\n$st");
      }

      // Xin quyền thông báo (Notification Permission)
      try {
        await androidImplementation.requestNotificationsPermission();
      } catch (e) {
        // Bỏ qua lỗi nếu version cũ không hỗ trợ
      }

      // --- [THÊM MỚI QUAN TRỌNG] Xin quyền Hẹn giờ chính xác (Exact Alarm) ---
      try {
        await androidImplementation.requestExactAlarmsPermission();
        print("NotificationService: Đã yêu cầu quyền Exact Alarm");
      } catch (e) {
        print("NotificationService: Lỗi khi xin quyền Exact Alarm (có thể do version cũ): $e");
      }
      // -----------------------------------------------------------------------

    } else {
      print("NotificationService: Android implementation NOT available.");
    }

    print("NotificationService.init() - END");
  }

  // --- HÀM NÀY ĐÃ ĐƯỢC SỬA ĐỂ HỖ TRỢ LẶP LẠI (RECURRENCE) ---
  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
    String? payload,
    String recurrence = 'None', // <--- 1. Thêm tham số này
  }) async {
    try {
      print("NotificationService.scheduleNotification() called - id=$id");

      final now = DateTime.now();
      final tz.TZDateTime scheduledTZDate = tz.TZDateTime.from(scheduledDate, tz.local);

      print("--- DEBUG HẸN GIỜ (CHẾ ĐỘ EXACT) ---");
      print("Giờ hiện tại: $now");
      print("Giờ hẹn: $scheduledTZDate");
      print("Chế độ lặp: $recurrence");

      // Logic kiểm tra giờ quá khứ:
      // Nếu KHÔNG lặp lại, mà giờ hẹn nhỏ hơn giờ hiện tại -> Hủy (Lỗi)
      // Nếu CÓ lặp lại, thì thư viện sẽ tự tính lần tiếp theo, nên không chặn ở đây.
      if (recurrence == 'None' && scheduledTZDate.isBefore(tz.TZDateTime.now(tz.local))) {
        print("LỖI: Giờ đặt là quá khứ và không lặp lại! Không thể hẹn giờ.");
        return;
      }

      // --- 2. CẤU HÌNH KIỂU LẶP ---
      DateTimeComponents? matchComponent;
      if (recurrence == 'Daily') {
        matchComponent = DateTimeComponents.time; // Lặp lại mỗi ngày vào giờ này
      } else if (recurrence == 'Weekly') {
        matchComponent = DateTimeComponents.dayOfWeekAndTime; // Lặp lại thứ này hàng tuần
      } else if (recurrence == 'Monthly') {
        matchComponent = DateTimeComponents.dayOfMonthAndTime; // Lặp lại ngày này hàng tháng
      } else if (recurrence == 'Yearly') {
        matchComponent = DateTimeComponents.dateAndTime; // Lặp lại ngày này hàng năm
      }
      // ----------------------------

      await flutterLocalNotificationsPlugin.zonedSchedule(
        id,
        title,
        body,
        scheduledTZDate,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            'Nhắc nhở công việc',
            channelDescription: 'Thông báo nhắc nhở task',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
            fullScreenIntent: true,
          ),
        ),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
        androidAllowWhileIdle: true,
        uiLocalNotificationDateInterpretation: UILocalNotificationDateInterpretation.absoluteTime,
        payload: payload,
        matchDateTimeComponents: matchComponent, // <--- 3. Truyền cấu hình lặp vào đây
      );

      print("THÀNH CÔNG: Đã đặt lịch (Lặp: $recurrence)!");
      print("--- KẾT THÚC DEBUG ---");

    } catch (e, st) {
      print("LỖI NGHIÊM TRỌNG KHI HẸN GIỜ: $e\n$st");
    }
  }

  Future<void> showInstantNotification(String title, String body, {String? payload}) async {
    print("LOG: Đang hiện thông báo ngay lập tức...");
    try {
      await flutterLocalNotificationsPlugin.show(
        888,
        title,
        body,
        NotificationDetails(
          android: AndroidNotificationDetails(
            channelId,
            'Test Thông Báo',
            importance: Importance.max,
            priority: Priority.high,
            playSound: true,
            enableVibration: true,
          ),
        ),
        payload: payload,
      );
      print("LOG: show() completed");
    } catch (e, st) {
      print("LOG: show() failed: $e\n$st");
    }
  }

  Future<void> cancelNotification(int id) async {
    try {
      await flutterLocalNotificationsPlugin.cancel(id);
      print("NotificationService: cancelled notification id=$id");
    } catch (e, st) {
      print("NotificationService: cancel failed for id=$id -> $e\n$st");
    }
  }
}