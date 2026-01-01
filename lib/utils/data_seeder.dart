import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:math';
import '../data/db_helper.dart';
import '../provider/task_provider.dart';

class DataSeeder {
  static Future<void> generateSamples(BuildContext context) async {
    final db = await DatabaseHelper.instance.database;
    final provider = Provider.of<TaskProvider>(context, listen: false);
    final random = Random();

    print("--- BẮT ĐẦU TẠO DỮ LIỆU MẪU KHỔNG LỒ (2025 - 2026) ---");

    // Tùy chọn: Xóa sạch dữ liệu cũ để tránh trùng lặp
    await db.delete('tasks');
    await db.delete('task_groups');

    // ==========================================
    // 1. TẠO CÁC NHÓM (GROUPS)
    // ==========================================

    Future<int> insertGroup(String name, int color, int icon) async {
      // Kiểm tra xem nhóm đã có chưa, nếu chưa thì tạo, có rồi thì lấy ID cũ
      final List<Map<String, dynamic>> existing = await db.query('task_groups', where: 'name = ?', whereArgs: [name]);
      if (existing.isNotEmpty) return existing.first['id'] as int;

      return await db.insert('task_groups', {
        'name': name,
        'color': color,
        'iconCode': icon,
      });
    }

    int idCaNhan = await insertGroup('Cá nhân', Colors.green.value, Icons.person.codePoint);
    int idCongViec = await insertGroup('Công việc', Colors.blue.value, Icons.work.codePoint);
    int idSucKhoe = await insertGroup('Sức khỏe', Colors.orange.value, Icons.fitness_center.codePoint);
    int idHocTap = await insertGroup('Học tập', Colors.purple.value, Icons.school.codePoint);
    int idTaiChinh = await insertGroup('Tài chính', Colors.teal.value, Icons.attach_money.codePoint);
    int idGiaDinh = await insertGroup('Gia đình', Colors.pink.value, Icons.family_restroom.codePoint);

    // ==========================================
    // 2. HÀM PHỤ ĐỂ TẠO NHANH
    // ==========================================
    Future<void> insertTask({
      required String title,
      String note = '',
      required DateTime dueDate,
      required int groupId,
      int isCompleted = 0,
      String recurrence = 'None',
      int reminderOffset = 0,
      int duration = 30,
    }) async {
      await db.insert('tasks', {
        'title': title,
        'note': note,
        'dueDate': dueDate.toIso8601String(),
        'isCompleted': isCompleted,
        'groupId': groupId,
        'recurrence': recurrence,
        'reminderOffset': reminderOffset,
        'duration': duration,
        // Nếu đã xong, lấy luôn dueDate làm ngày hoàn thành (để test thống kê quá khứ)
        'completedAt': (isCompleted == 1) ? dueDate.toIso8601String() : null,
        'attachmentPath': null
      });
    }

    // Danh sách mẫu để random
    final List<Map<String, dynamic>> sampleTasks = [
      {'title': 'Chạy bộ 5km', 'group': idSucKhoe, 'duration': 45},
      {'title': 'Tập Gym (Ngực)', 'group': idSucKhoe, 'duration': 60},
      {'title': 'Uống 2 lít nước', 'group': idSucKhoe, 'duration': 5},
      {'title': 'Gửi báo cáo ngày', 'group': idCongViec, 'duration': 30},
      {'title': 'Họp team đầu tuần', 'group': idCongViec, 'duration': 90},
      {'title': 'Check email khách hàng', 'group': idCongViec, 'duration': 20},
      {'title': 'Học từ vựng Tiếng Anh', 'group': idHocTap, 'duration': 45},
      {'title': 'Đọc sách 30 trang', 'group': idHocTap, 'duration': 60},
      {'title': 'Ghi chép chi tiêu', 'group': idTaiChinh, 'duration': 10},
      {'title': 'Đi siêu thị', 'group': idGiaDinh, 'duration': 90},
      {'title': 'Dọn dẹp phòng', 'group': idCaNhan, 'duration': 45},
    ];

    // ==========================================
    // 3. SINH DỮ LIỆU TỰ ĐỘNG (2025 -> 6/2026)
    // ==========================================

    // Vòng lặp từng tháng từ 1/2025 đến 6/2026 (18 tháng)
    DateTime startDate = DateTime(2025, 1, 1);

    for (int i = 0; i < 18; i++) {
      // Ngày đầu của tháng đang xét
      DateTime currentMonth = DateTime(startDate.year, startDate.month + i, 1);

      // Số lượng việc trong tháng này (Random từ 10 đến 30 việc)
      int tasksCount = 10 + random.nextInt(20);

      print("Đang tạo $tasksCount việc cho tháng ${currentMonth.month}/${currentMonth.year}...");

      for (int k = 0; k < tasksCount; k++) {
        // Random ngày trong tháng (tối đa ngày 28 cho an toàn mọi tháng)
        int day = 1 + random.nextInt(28);
        int hour = 8 + random.nextInt(12); // Giờ làm việc từ 8h - 20h

        DateTime taskDate = DateTime(currentMonth.year, currentMonth.month, day, hour, 0);

        // Random nội dung công việc từ danh sách mẫu
        var sample = sampleTasks[random.nextInt(sampleTasks.length)];

        // Nếu ngày của task nhỏ hơn hiện tại -> Đánh dấu là ĐÃ XONG (để lên biểu đồ)
        // Nếu ngày lớn hơn hiện tại -> Đánh dấu CHƯA XONG (để hiện ở Lịch/Dự kiến)
        bool isPast = taskDate.isBefore(DateTime.now());

        await insertTask(
          title: sample['title'],
          dueDate: taskDate,
          groupId: sample['group'],
          isCompleted: isPast ? 1 : 0, // Quá khứ thì xong, Tương lai thì chưa
          duration: sample['duration'],
        );
      }
    }

    // ==========================================
    // 4. DỮ LIỆU CỤ THỂ HÔM NAY (Để App đẹp khi mở lên)
    // ==========================================
    final today = DateTime.now();

    await insertTask(
      title: 'Kiểm tra thống kê năm 2025',
      note: 'Xem thử code hoạt động chưa',
      dueDate: DateTime(today.year, today.month, today.day, 10, 0),
      groupId: idCongViec,
      isCompleted: 0,
      duration: 15,
    );

    await insertTask(
      title: 'Code Flutter xuyên màn đêm',
      dueDate: DateTime(today.year, today.month, today.day, 22, 0),
      groupId: idHocTap,
      isCompleted: 0,
      duration: 120,
    );

    print("--- ĐÃ TẠO XONG DỮ LIỆU ---");

    // Load lại dữ liệu lên màn hình
    await provider.loadData();

    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Đã tạo dữ liệu từ 2025 đến giữa 2026!"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }
}