import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/task_model.dart';

// Enum để phân loại kiểu xem
enum StatType { week, month, year }

class StatisticDetailScreen extends StatelessWidget {
  final String title;
  final List<Task> tasks;
  final StatType type;

  const StatisticDetailScreen({
    super.key,
    required this.title,
    required this.tasks,
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Gom nhóm dữ liệu
    Map<String, List<Task>> groupedTasks = _groupTasks();
    List<String> keys = groupedTasks.keys.toList();

    // Sắp xếp keys (Ngày/Tháng) giảm dần hoặc tăng dần
    // Ở đây sắp xếp giảm dần (mới nhất lên đầu)
    keys.sort((a, b) => b.compareTo(a));

    int totalTasks = tasks.length;
    int totalMinutes = tasks.fold(0, (sum, t) => sum + t.duration);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
      ),
      body: Column(
        children: [
          // Header Tổng quan
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem("Tổng việc", "$totalTasks"),
                _buildSummaryItem("Tổng thời gian", "${totalMinutes}p"),
                _buildSummaryItem("Số nhóm", "${keys.length} ${type == StatType.year ? 'tháng' : 'ngày'}"),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Danh sách chi tiết
          Expanded(
            child: tasks.isEmpty
                ? const Center(child: Text("Chưa có dữ liệu hoàn thành", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: keys.length,
              itemBuilder: (context, index) {
                String key = keys[index];
                List<Task> sectionTasks = groupedTasks[key]!;

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header của nhóm (VD: Thứ 2, 12/01 hoặc Tháng 5)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4),
                      child: Text(
                          key,
                          style: TextStyle(
                              color: Colors.blue[800],
                              fontWeight: FontWeight.bold,
                              fontSize: 16
                          )
                      ),
                    ),
                    // List các task trong nhóm đó
                    ...sectionTasks.map((task) => _buildTaskItem(task)).toList(),
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Logic gom nhóm thông minh
  Map<String, List<Task>> _groupTasks() {
    Map<String, List<Task>> groups = {};

    for (var task in tasks) {
      if (task.completedAt == null) continue;
      DateTime date = DateTime.parse(task.completedAt!);
      String key = "";

      if (type == StatType.year) {
        // Nếu xem Năm -> Gom theo Tháng (VD: "Tháng 05/2025")
        key = "Tháng ${date.month.toString().padLeft(2, '0')}/${date.year}";
      } else {
        // Nếu xem Tuần/Tháng -> Gom theo Ngày (VD: "Thứ Hai - 12/05")
        String dayName = _getDayName(date.weekday);
        key = "$dayName - ${DateFormat('dd/MM').format(date)}";
      }

      if (groups[key] == null) groups[key] = [];
      groups[key]!.add(task);
    }
    return groups;
  }

  String _getDayName(int weekday) {
    const days = ['Thứ Hai', 'Thứ Ba', 'Thứ Tư', 'Thứ Năm', 'Thứ Sáu', 'Thứ Bảy', 'Chủ Nhật'];
    return days[weekday - 1];
  }

  Widget _buildSummaryItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
        const SizedBox(height: 4),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildTaskItem(Task task) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.shade200)
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle, color: Colors.green, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(task.title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15)),
                if (task.duration > 0)
                  Text("Thời gian: ${task.duration} phút", style: TextStyle(fontSize: 12, color: Colors.grey[600])),
              ],
            ),
          ),
          if (task.completedAt != null)
            Text(
              DateFormat('HH:mm').format(DateTime.parse(task.completedAt!)),
              style: TextStyle(color: Colors.grey[400], fontSize: 12),
            )
        ],
      ),
    );
  }
}