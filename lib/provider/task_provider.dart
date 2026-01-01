import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../data/db_helper.dart';
import '../models/task_model.dart';
import '../models/task_group_model.dart';
import '../services/notification_service.dart';

class TaskProvider with ChangeNotifier {
  List<Task> _tasks = [];
  List<TaskGroup> _groups = [];
  String _searchQuery = '';
  int? _selectedGroupId;
  bool _isLoading = false;

  // --- GETTERS ---
  List<Task> get tasks {
    List<Task> temp = _searchQuery.isEmpty
        ? _tasks
        : _tasks.where((t) => t.title.toLowerCase().contains(_searchQuery.toLowerCase())).toList();

    if (_selectedGroupId != null) {
      temp = temp.where((t) => t.groupId == _selectedGroupId).toList();
    }
    return temp;
  }

  List<TaskGroup> get groups => _groups;
  bool get isLoading => _isLoading;
  int? get selectedGroupId => _selectedGroupId;

  List<Task> get todayTasks {
    final now = DateTime.now();
    return _tasks.where((t) {
      if (t.dueDate == null || t.isCompleted == 1) return false;
      final date = DateTime.parse(t.dueDate!);
      return date.year == now.year && date.month == now.month && date.day == now.day;
    }).toList();
  }

  List<Task> get scheduledTasks => _tasks.where((t) => t.dueDate != null && t.isCompleted == 0).toList();
  List<Task> get completedTasks => _tasks.where((t) => t.isCompleted == 1).toList();
  List<Task> get allTasks => _tasks;

  List<Task> getTasksByGroup(int groupId) {
    return _tasks.where((t) => t.groupId == groupId).toList();
  }

  // --- ACTIONS ---
  void selectGroup(int? groupId) {
    _selectedGroupId = groupId;
    notifyListeners();
  }

  void searchTasks(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  // ============================================================
  // === LOGIC TÍNH TOÁN GIỜ NHẮC VÀ ĐẶT LỊCH (ĐÃ FIX LỖI) ===
  // ============================================================
  Future<void> _scheduleHelper(Task task) async {
    // 1. Kiểm tra điều kiện cơ bản
    if (task.dueDate == null || task.id == null || task.isCompleted == 1) return;

    final dueDate = DateTime.parse(task.dueDate!);

    // 2. Tính toán giờ kích hoạt ban đầu (Trừ đi thời gian nhắc trước)
    DateTime triggerDate = dueDate.subtract(Duration(minutes: task.reminderOffset));
    final now = DateTime.now();

    // 3. [QUAN TRỌNG] Nếu có lặp lại, phải đảm bảo triggerDate ở TƯƠNG LAI
    // Nếu giờ tính ra đã qua rồi -> Cộng thêm chu kỳ cho đến khi > hiện tại
    if (task.recurrence != 'None' && triggerDate.isBefore(now)) {
      print("PROVIDER DEBUG: Giờ $triggerDate đã qua. Đang tính lại giờ tương lai...");

      while (triggerDate.isBefore(now)) {
        if (task.recurrence == 'Daily') {
          triggerDate = triggerDate.add(const Duration(days: 1));
        }
        else if (task.recurrence == 'Weekly') {
          triggerDate = triggerDate.add(const Duration(days: 7));
        }
        else if (task.recurrence == 'Monthly') {
          // Cộng 1 tháng (cách đơn giản)
          triggerDate = DateTime(triggerDate.year, triggerDate.month + 1, triggerDate.day, triggerDate.hour, triggerDate.minute);
        }
        else if (task.recurrence == 'Yearly') {
          triggerDate = DateTime(triggerDate.year + 1, triggerDate.month, triggerDate.day, triggerDate.hour, triggerDate.minute);
        }
      }
      print("PROVIDER DEBUG: Giờ mới sau khi fix: $triggerDate");
    }

    // 4. Kiểm tra lần cuối: Nếu vẫn ở quá khứ (với task không lặp) -> Bỏ qua
    if (triggerDate.isBefore(now) && task.recurrence == 'None') {
      print("PROVIDER: Task quá khứ không lặp lại -> Không đặt báo thức.");
      return;
    }

    // 5. Xử lý nội dung thông báo
    String bodyText = task.note ?? "Có việc cần làm!";
    if (task.reminderOffset > 0) {
      // Hiển thị giờ gốc (dueDate) trong thông báo để người dùng không nhầm lẫn
      // Lưu ý: dueDate hiển thị ở đây chỉ mang tính chất text thông báo
      bodyText = "Sắp đến hạn (Deadline: ${DateFormat('HH:mm').format(dueDate)}). $bodyText";
    }

    // 6. Gọi Service đặt lịch
    await NotificationService().scheduleNotification(
      id: task.id!,
      title: task.title,
      body: bodyText,
      scheduledDate: triggerDate, // Đây là giờ TƯƠNG LAI chắc chắn
      recurrence: task.recurrence ?? 'None',
      payload: "taskId:${task.id}",
    );
  }

  // --- DATABASE OPERATIONS ---

  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();
    _tasks = await DatabaseHelper.instance.readAllTasks();
    _groups = await DatabaseHelper.instance.readAllGroups();

    try {
      for (final t in _tasks) {
        if (t.id == null) continue;
        if (t.dueDate != null && t.isCompleted == 0) {
          await _scheduleHelper(t); // Dùng hàm helper mới
        } else {
          await NotificationService().cancelNotification(t.id!);
        }
      }
    } catch (e) {
      print("ERROR rescheduling: $e");
    }

    _isLoading = false;
    notifyListeners();
  }

  Future<void> addGroup(String name, int color, int iconCode) async {
    final newGroup = TaskGroup(name: name, color: color, iconCode: iconCode);
    await DatabaseHelper.instance.createTaskGroup(newGroup);
    await loadData();
  }

  Future<void> addTask(String title, String? note, DateTime? dueDate,
      {int? groupId, String? attachmentPath, String recurrence = 'None', int reminderOffset = 0, int duration = 0}) async {

    final newTask = Task(
      title: title,
      note: note,
      dueDate: dueDate?.toIso8601String(),
      groupId: groupId ?? _selectedGroupId,
      attachmentPath: attachmentPath,
      recurrence: recurrence,
      reminderOffset: reminderOffset,
      duration: duration,
    );

    final id = await DatabaseHelper.instance.createTask(newTask);

    final savedTask = Task(
        id: id,
        title: title,
        note: note,
        dueDate: dueDate?.toIso8601String(),
        recurrence: recurrence,
        reminderOffset: reminderOffset
    );

    if (dueDate != null) {
      await _scheduleHelper(savedTask); // Dùng hàm helper mới
    }
    await loadData();
  }

  Future<void> updateTaskContent(Task task) async {
    await DatabaseHelper.instance.updateTask(task);

    if (task.id != null) await NotificationService().cancelNotification(task.id!);

    if (task.dueDate != null && task.isCompleted == 0) {
      await _scheduleHelper(task); // Dùng hàm helper mới
    }
    await loadData();
  }

  Future<void> toggleComplete(Task task) async {
    // 1. Logic dời lịch cho Task Lặp lại
    if (task.recurrence != 'None' && task.isCompleted == 0 && task.dueDate != null) {
      DateTime oldDate = DateTime.parse(task.dueDate!);
      DateTime nextDate = oldDate;

      if (task.recurrence == 'Daily') {
        nextDate = oldDate.add(const Duration(days: 1));
      } else if (task.recurrence == 'Weekly') {
        nextDate = oldDate.add(const Duration(days: 7));
      } else if (task.recurrence == 'Monthly') {
        nextDate = DateTime(oldDate.year, oldDate.month + 1, oldDate.day, oldDate.hour, oldDate.minute);
      } else if (task.recurrence == 'Yearly') {
        nextDate = DateTime(oldDate.year + 1, oldDate.month, oldDate.day, oldDate.hour, oldDate.minute);
      }

      final updatedTask = Task(
          id: task.id,
          title: task.title,
          note: task.note,
          dueDate: nextDate.toIso8601String(),
          isCompleted: 0, // Vẫn chưa xong để làm tiếp lần sau
          groupId: task.groupId,
          attachmentPath: task.attachmentPath, // Giữ ảnh
          recurrence: task.recurrence,
          reminderOffset: task.reminderOffset,
          duration: task.duration,
          completedAt: null
      );

      await DatabaseHelper.instance.updateTask(updatedTask);
      if (task.id != null) await NotificationService().cancelNotification(task.id!);
      await _scheduleHelper(updatedTask);

    } else {
      // 2. Logic Task Thường
      final newStatus = task.isCompleted == 0 ? 1 : 0;
      final completedAt = newStatus == 1 ? DateTime.now().toIso8601String() : null;

      final updatedTask = Task(
          id: task.id,
          title: task.title,
          note: task.note,
          dueDate: task.dueDate,
          isCompleted: newStatus,
          groupId: task.groupId,
          attachmentPath: task.attachmentPath, // Giữ ảnh
          recurrence: task.recurrence,
          reminderOffset: task.reminderOffset,
          duration: task.duration,
          completedAt: completedAt
      );

      await DatabaseHelper.instance.updateTask(updatedTask);

      if (newStatus == 1 && task.id != null) {
        await NotificationService().cancelNotification(task.id!);
      } else if (newStatus == 0) {
        await _scheduleHelper(updatedTask);
      }
    }
    await loadData();
  }

  // --- LOGIC THỐNG KÊ (Mới thêm) ---
  List<Task> _getCompletedTasksInDateRange(DateTime start, DateTime end) {
    return _tasks.where((t) {
      if (t.isCompleted == 0 || t.completedAt == null) return false;
      final date = DateTime.parse(t.completedAt!);
      return date.isAfter(start) && date.isBefore(end);
    }).toList();
  }

  Map<String, dynamic> get weeklyStats {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1)).copyWith(hour: 0, minute: 0, second: 0);
    final endOfWeek = startOfWeek.add(const Duration(days: 7)).subtract(const Duration(seconds: 1));
    final tasks = _getCompletedTasksInDateRange(startOfWeek, endOfWeek);
    final totalMinutes = tasks.fold(0, (sum, item) => sum + item.duration);
    return {'count': tasks.length, 'minutes': totalMinutes};
  }

  Map<String, dynamic> get monthlyStats {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0, 23, 59, 59);
    final tasks = _getCompletedTasksInDateRange(startOfMonth, endOfMonth);
    final totalMinutes = tasks.fold(0, (sum, item) => sum + item.duration);
    return {'count': tasks.length, 'minutes': totalMinutes};
  }

  Map<String, dynamic> get yearlyStats {
    final now = DateTime.now();
    final startOfYear = DateTime(now.year, 1, 1);
    final endOfYear = DateTime(now.year, 12, 31, 23, 59, 59);
    final tasks = _getCompletedTasksInDateRange(startOfYear, endOfYear);
    final totalMinutes = tasks.fold(0, (sum, item) => sum + item.duration);
    return {'count': tasks.length, 'minutes': totalMinutes};
  }
  // ---------------------------------

  Future<void> deleteTask(int id) async {
    await DatabaseHelper.instance.deleteTask(id);
    await NotificationService().cancelNotification(id);
    await loadData();
  }

  Future<void> updateGroup(TaskGroup group) async {
    await DatabaseHelper.instance.updateTaskGroup(group);
    await loadData();
  }

  Future<void> deleteGroup(int groupId) async {
    await DatabaseHelper.instance.deleteTaskGroup(groupId);
    if (_selectedGroupId == groupId) {
      _selectedGroupId = null;
    }
    await loadData();
  }

  // Hàm trả về danh sách các Task đã hoàn thành trong khoảng thời gian cụ thể
  List<Task> getCompletedTasksInRange(DateTime start, DateTime end) {
    return _tasks.where((t) {
      if (t.isCompleted == 0 || t.completedAt == null) return false;
      final date = DateTime.parse(t.completedAt!); // Lấy ngày hoàn thành thực tế
      return date.isAfter(start) && date.isBefore(end);
    }).toList();
  }

  // Helper lấy ngày đầu/cuối của Tuần/Tháng/Năm hiện tại
  DateTime get startOfWeek => DateTime.now().subtract(Duration(days: DateTime.now().weekday - 1)).copyWith(hour: 0, minute: 0, second: 0);
  DateTime get endOfWeek => startOfWeek.add(const Duration(days: 7)).subtract(const Duration(seconds: 1));

  DateTime get startOfMonth => DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime get endOfMonth => DateTime(DateTime.now().year, DateTime.now().month + 1, 0, 23, 59, 59);

  DateTime get startOfYear => DateTime(DateTime.now().year, 1, 1);
  DateTime get endOfYear => DateTime(DateTime.now().year, 12, 31, 23, 59, 59);

  // --- CÁC HÀM HỖ TRỢ THỐNG KÊ MỚI (LINH HOẠT) ---

  // 1. Lấy danh sách task đã xong trong một năm cụ thể
  List<Task> getCompletedTasksForYear(int year) {
    DateTime start = DateTime(year, 1, 1);
    DateTime end = DateTime(year, 12, 31, 23, 59, 59);
    return _getCompletedTasksInDateRange(start, end);
  }

  // 2. Lấy danh sách task đã xong trong một tháng cụ thể của năm
  List<Task> getCompletedTasksForMonth(int year, int month) {
    DateTime start = DateTime(year, month, 1);
    // Logic lấy ngày cuối tháng an toàn (chuyển sang ngày 0 của tháng sau)
    DateTime end = DateTime(year, month + 1, 0, 23, 59, 59);
    return _getCompletedTasksInDateRange(start, end);
  }

  // Hàm tính tổng thời gian (dùng chung)
  int calculateTotalMinutes(List<Task> tasks) {
    return tasks.fold(0, (sum, item) => sum + item.duration);
  }
}