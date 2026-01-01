import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../provider/task_provider.dart';
import '../models/task_model.dart';

class TodayTaskScreen extends StatefulWidget {
  const TodayTaskScreen({super.key});

  @override
  State<TodayTaskScreen> createState() => _TodayTaskScreenState();
}

class _TodayTaskScreenState extends State<TodayTaskScreen> {
  @override
  Widget build(BuildContext context) {
    const themeColor = Colors.blue; // Màu chủ đạo của màn hình Hôm nay

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: themeColor,
        title: const Text("Hôm nay", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: const BackButton(color: Colors.white),
      ),
      body: Consumer<TaskProvider>(
        builder: (context, provider, child) {
          // Lấy danh sách việc hôm nay từ Provider
          final todayTasks = provider.todayTasks;

          if (todayTasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.calendar_today, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text("Hôm nay rảnh rỗi!", style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: todayTasks.length,
            itemBuilder: (ctx, index) {
              return _buildTaskItem(context, todayTasks[index], themeColor);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: themeColor,
        onPressed: () => _showTaskSheet(context, null),
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildTaskItem(BuildContext context, Task task, Color activeColor) {
    final isDone = task.isCompleted == 1;
    // Format giờ (Vì ngày chắc chắn là hôm nay rồi nên chỉ cần hiện giờ)
    String timeText = '';
    if (task.dueDate != null) {
      timeText = DateFormat('HH:mm').format(DateTime.parse(task.dueDate!));
    }

    return Dismissible(
      key: Key(task.id.toString()),
      background: Container(color: Colors.red, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20), child: const Icon(Icons.delete, color: Colors.white)),
      onDismissed: (_) => Provider.of<TaskProvider>(context, listen: false).deleteTask(task.id!),
      child: Card(
        elevation: 0,
        color: isDone ? Colors.grey[50] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => _showTaskSheet(context, task), // Sửa task
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                Transform.scale(
                  scale: 1.2,
                  child: Checkbox(
                    value: isDone,
                    shape: const CircleBorder(),
                    activeColor: activeColor,
                    onChanged: (_) => Provider.of<TaskProvider>(context, listen: false).toggleComplete(task),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(task.title, style: TextStyle(fontSize: 16, decoration: isDone ? TextDecoration.lineThrough : null, color: isDone ? Colors.grey : Colors.black87, fontWeight: FontWeight.w600)),
                      if (task.note != null && task.note!.isNotEmpty) Text(task.note!, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[600])),
                      if (timeText.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [Icon(Icons.access_time, size: 12, color: isDone ? Colors.grey : activeColor), const SizedBox(width: 4), Text(timeText, style: TextStyle(fontSize: 12, color: isDone ? Colors.grey : activeColor))]))
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showTaskSheet(BuildContext context, Task? task) {
    final isEditing = task != null;
    final titleController = TextEditingController(text: task?.title ?? '');
    final noteController = TextEditingController(text: task?.note ?? '');
    // [QUAN TRỌNG] Nếu thêm mới -> Mặc định là NOW (để lọt vào danh sách Hôm nay)
    DateTime? selectedDateTime = task?.dueDate != null ? DateTime.parse(task!.dueDate!) : DateTime.now();

    showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setStateModal) {
          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isEditing ? 'Chỉnh sửa' : 'Việc hôm nay', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                TextField(controller: titleController, autofocus: !isEditing, style: const TextStyle(fontSize: 18), decoration: const InputDecoration(hintText: 'Tên công việc...', border: InputBorder.none, prefixIcon: Icon(Icons.radio_button_unchecked))),
                TextField(controller: noteController, maxLines: 3, minLines: 1, decoration: const InputDecoration(hintText: 'Ghi chú...', border: InputBorder.none, prefixIcon: Icon(Icons.notes))),
                const Divider(),
                Row(
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.calendar_today, size: 16), // Icon lịch hôm nay
                      // Chỉ cho chọn GIỜ, không cho chọn NGÀY (vì đây là màn hình Hôm nay)
                      label: Text(DateFormat('HH:mm').format(selectedDateTime!)),
                      onPressed: () async {
                        final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(selectedDateTime!));
                        if (time != null) {
                          final now = DateTime.now();
                          // Giữ nguyên ngày tháng năm hiện tại, chỉ thay đổi giờ phút
                          setStateModal(() => selectedDateTime = DateTime(now.year, now.month, now.day, time.hour, time.minute));
                        }
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: FilledButton(
                  onPressed: () {
                    if (titleController.text.isNotEmpty) {
                      final provider = Provider.of<TaskProvider>(context, listen: false);
                      if (isEditing) {
                        provider.updateTaskContent(Task(id: task!.id, title: titleController.text, note: noteController.text, dueDate: selectedDateTime?.toIso8601String(), isCompleted: task.isCompleted, groupId: task.groupId));
                      } else {
                        provider.addTask(titleController.text, noteController.text, selectedDateTime);
                      }
                      Navigator.pop(ctx);
                    }
                  },
                  child: Text(isEditing ? 'Cập nhật' : 'Lưu'),
                )),
                const SizedBox(height: 16),
              ],
            ),
          );
        });
      },
    );
  }
}