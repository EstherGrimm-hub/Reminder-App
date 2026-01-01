import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../provider/task_provider.dart';
import '../models/task_model.dart';

class MonthDetailScreen extends StatelessWidget {
  final int month;
  final int year;

  const MonthDetailScreen({super.key, required this.month, required this.year});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<TaskProvider>(context, listen: false);

    // Lấy tất cả task của tháng này
    final tasks = provider.getCompletedTasksForMonth(year, month);

    // Gom nhóm theo Tuần
    Map<int, List<Task>> weeklyGroups = _groupTasksByWeek(tasks);
    List<int> weeks = weeklyGroups.keys.toList()..sort(); // Sắp xếp tuần 1, 2, 3...

    int totalMinutes = provider.calculateTotalMinutes(tasks);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: Text("Tháng $month / $year", style: const TextStyle(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      body: Column(
        children: [
          // Tổng quan tháng
          Container(
            padding: const EdgeInsets.all(16),
            color: Colors.white,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildStatItem("Đã xong", "${tasks.length} việc"),
                _buildStatItem("Tổng thời gian", "${totalMinutes}p"),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // Danh sách các Tuần (ExpansionTile)
          Expanded(
            child: weeks.isEmpty
                ? const Center(child: Text("Không có dữ liệu trong tháng này", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: weeks.length,
              itemBuilder: (context, index) {
                int weekNum = weeks[index];
                List<Task> weekTasks = weeklyGroups[weekNum]!;
                int weekMinutes = provider.calculateTotalMinutes(weekTasks);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  child: ExpansionTile(
                    leading: CircleAvatar(
                      backgroundColor: Colors.orange.withOpacity(0.2),
                      child: Text("$weekNum", style: const TextStyle(color: Colors.orange, fontWeight: FontWeight.bold)),
                    ),
                    title: Text("Tuần $weekNum", style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text("${weekTasks.length} việc • $weekMinutes phút"),
                    children: weekTasks.map((task) => _buildTaskRow(task)).toList(),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Logic gom nhóm: Tuần 1 (Ngày 1-7), Tuần 2 (8-14)...
  Map<int, List<Task>> _groupTasksByWeek(List<Task> tasks) {
    Map<int, List<Task>> groups = {};
    for (var task in tasks) {
      if (task.completedAt == null) continue;
      DateTime date = DateTime.parse(task.completedAt!);

      // Tính số tuần đơn giản: (Ngày - 1) chia 7 + 1
      int weekNum = ((date.day - 1) ~/ 7) + 1;

      if (groups[weekNum] == null) groups[weekNum] = [];
      groups[weekNum]!.add(task);
    }
    return groups;
  }

  Widget _buildStatItem(String label, String value) {
    return Column(
      children: [
        Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.deepPurple)),
        Text(label, style: TextStyle(fontSize: 13, color: Colors.grey[600])),
      ],
    );
  }

  Widget _buildTaskRow(Task task) {
    return ListTile(
      dense: true,
      leading: const Icon(Icons.check_circle, size: 16, color: Colors.green),
      title: Text(task.title, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: Text(
        DateFormat('dd/MM').format(DateTime.parse(task.completedAt!)),
        style: TextStyle(fontSize: 12, color: Colors.grey[500]),
      ),
    );
  }
}