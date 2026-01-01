import 'dart:io'; // <--- 1. BẮT BUỘC CÓ ĐỂ HIỂN THỊ ẢNH FILE
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:speech_to_text/speech_to_text.dart';
import '../models/task_model.dart';
import '../provider/task_provider.dart';

class TaskDetailScreen extends StatefulWidget {
  final Task task;
  const TaskDetailScreen({super.key, required this.task});

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  @override
  Widget build(BuildContext context) {
    // Lấy dữ liệu mới nhất từ Provider
    final taskList = Provider.of<TaskProvider>(context).tasks;

    // Tìm task hiện tại
    Task task;
    try {
      task = taskList.firstWhere((t) => t.id == widget.task.id);
    } catch (e) {
      Navigator.pop(context);
      return const SizedBox();
    }

    // Logic hiển thị ảnh
    bool hasImage = task.attachmentPath != null && task.attachmentPath!.isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: const BackButton(color: Colors.black),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.blue),
            onPressed: () => _showEditSheet(context, task),
          ),
          IconButton(
            icon: const Icon(Icons.delete, color: Colors.red),
            onPressed: () => _confirmDelete(context, task),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Tiêu đề + Checkbox
            Row(
              children: [
                Transform.scale(
                  scale: 1.5,
                  child: Checkbox(
                    value: task.isCompleted == 1,
                    shape: const CircleBorder(),
                    activeColor: Colors.deepPurple,
                    onChanged: (_) => Provider.of<TaskProvider>(context, listen: false).toggleComplete(task),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    task.title,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      decoration: task.isCompleted == 1 ? TextDecoration.lineThrough : null,
                      color: task.isCompleted == 1 ? Colors.grey : Colors.black,
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 20),

            // 2. Ngày giờ & Thông tin lặp lại
            if (task.dueDate != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.access_time, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Text(
                          DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(task.dueDate!)),
                          style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.w600, fontSize: 16),
                        ),
                      ],
                    ),
                    // Hiển thị thêm thông tin lặp lại/nhắc trước nếu có
                    if (task.recurrence != 'None' || task.reminderOffset > 0)
                      Padding(
                        padding: const EdgeInsets.only(top: 4, left: 28),
                        child: Text(
                          "Lặp: ${_getRecurrenceText(task.recurrence)} • Nhắc trước: ${task.reminderOffset}p",
                          style: TextStyle(fontSize: 12, color: Colors.blue[800]),
                        ),
                      )
                  ],
                ),
              ),

            const SizedBox(height: 20),

            // 3. Ghi chú
            if (task.note != null && task.note!.isNotEmpty) ...[
              const Text("Ghi chú:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(12)),
                child: Text(task.note!, style: const TextStyle(fontSize: 16, height: 1.5)),
              ),
              const SizedBox(height: 20),
            ],

            // 4. HÌNH ẢNH
            if (hasImage) ...[
              const Text("Hình ảnh đính kèm:", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey)),
              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.file(
                  File(task.attachmentPath!),
                  width: double.infinity,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      height: 150,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.grey[200],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.broken_image, size: 40, color: Colors.grey),
                          const SizedBox(height: 8),
                          Text("Không tải được ảnh\n${task.attachmentPath}",
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.red, fontSize: 12)
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  String _getRecurrenceText(String? value) {
    switch (value) {
      case 'Daily': return 'Hàng ngày';
      case 'Weekly': return 'Hàng tuần';
      case 'Monthly': return 'Hàng tháng';
      case 'Yearly': return 'Hàng năm';
      default: return 'Không';
    }
  }

  void _confirmDelete(BuildContext context, Task task) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Xóa công việc?"),
        content: const Text("Bạn có chắc muốn xóa không?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Huỷ")),
          TextButton(
            onPressed: () {
              Provider.of<TaskProvider>(context, listen: false).deleteTask(task.id!);
              Navigator.pop(ctx);
              Navigator.pop(context);
            },
            child: const Text("Xóa", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showEditSheet(BuildContext context, Task task) {
    final titleController = TextEditingController(text: task.title);
    final noteController = TextEditingController(text: task.note);
    DateTime? selectedDateTime = task.dueDate != null ? DateTime.parse(task.dueDate!) : null;
    String? tempAttachmentPath = task.attachmentPath;

    // --- 1. KHỞI TẠO BIẾN CHO 2 DROPDOWN ---
    String selectedRecurrence = task.recurrence ?? 'None';
    int selectedOffset = task.reminderOffset;

    final SpeechToText speech = SpeechToText();
    final ImagePicker picker = ImagePicker();
    bool isListening = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setStateModal) {

          void toggleListening() async {
            if (!isListening) {
              bool available = await speech.initialize();
              if (available) {
                setStateModal(() => isListening = true);
                speech.listen(
                  onResult: (result) {
                    setStateModal(() {
                      titleController.text = result.recognizedWords;
                    });
                  },
                  localeId: 'vi_VN',
                );
              }
            } else {
              setStateModal(() => isListening = false);
              speech.stop();
            }
          }

          Future<void> pickImage(ImageSource source) async {
            final XFile? image = await picker.pickImage(source: source);
            if (image != null) setStateModal(() => tempAttachmentPath = image.path);
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
            child: SingleChildScrollView( // Thêm Scroll để tránh bị che bởi bàn phím
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Chỉnh sửa công việc', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  TextField(
                      controller: titleController,
                      decoration: InputDecoration(
                          hintText: 'Tên công việc...',
                          border: InputBorder.none,
                          prefixIcon: const Icon(Icons.radio_button_unchecked),
                          suffixIcon: IconButton(
                            icon: Icon(isListening ? Icons.mic : Icons.mic_none, color: isListening ? Colors.red : Colors.grey),
                            onPressed: toggleListening,
                          )
                      )
                  ),
                  TextField(controller: noteController, maxLines: 3, minLines: 1, decoration: const InputDecoration(hintText: 'Ghi chú...', border: InputBorder.none, prefixIcon: Icon(Icons.notes))),

                  if (tempAttachmentPath != null)
                    Stack(
                      children: [
                        Container(margin: const EdgeInsets.symmetric(vertical: 8), height: 150, width: double.infinity, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), image: DecorationImage(image: FileImage(File(tempAttachmentPath!)), fit: BoxFit.cover))),
                        Positioned(right: 0, top: 8, child: GestureDetector(onTap: () => setStateModal(() => tempAttachmentPath = null), child: const CircleAvatar(backgroundColor: Colors.white, radius: 10, child: Icon(Icons.close, size: 16, color: Colors.red))))
                      ],
                    ),

                  const Divider(),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      ActionChip(
                        avatar: const Icon(Icons.calendar_month, size: 16),
                        label: Text(selectedDateTime == null ? 'Đặt lịch' : DateFormat('dd/MM HH:mm').format(selectedDateTime!)),
                        onPressed: () async {
                          final date = await showDatePicker(context: context, initialDate: selectedDateTime ?? DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                          if (date != null && context.mounted) {
                            final time = await showTimePicker(context: context, initialTime: TimeOfDay.fromDateTime(selectedDateTime ?? DateTime.now()));
                            if (time != null) setStateModal(() => selectedDateTime = DateTime(date.year, date.month, date.day, time.hour, time.minute));
                          }
                        },
                      ),
                      Row(
                        children: [
                          IconButton(icon: const Icon(Icons.image, color: Colors.blue), onPressed: () => pickImage(ImageSource.gallery)),
                          IconButton(icon: const Icon(Icons.camera_alt, color: Colors.blue), onPressed: () => pickImage(ImageSource.camera)),
                        ],
                      )
                    ],
                  ),

                  const SizedBox(height: 10),

                  // --- 2. THÊM DROPDOWN LẶP LẠI & NHẮC TRƯỚC ---
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: selectedRecurrence,
                          decoration: const InputDecoration(labelText: 'Lặp lại', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0)),
                          items: const [
                            DropdownMenuItem(value: 'None', child: Text('Không')),
                            DropdownMenuItem(value: 'Daily', child: Text('Hàng ngày')),
                            DropdownMenuItem(value: 'Weekly', child: Text('Hàng tuần')),
                            DropdownMenuItem(value: 'Monthly', child: Text('Hàng tháng')),
                            DropdownMenuItem(value: 'Yearly', child: Text('Hàng năm')),
                          ],
                          onChanged: (val) => setStateModal(() => selectedRecurrence = val!),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          value: selectedOffset,
                          decoration: const InputDecoration(labelText: 'Nhắc trước', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0)),
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('Đúng giờ')),
                            DropdownMenuItem(value: 15, child: Text('15 phút')),
                            DropdownMenuItem(value: 30, child: Text('30 phút')),
                            DropdownMenuItem(value: 60, child: Text('1 tiếng')),
                          ],
                          onChanged: (val) => setStateModal(() => selectedOffset = val!),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 16),

                  SizedBox(width: double.infinity, child: FilledButton(
                    onPressed: () {
                      if (titleController.text.isNotEmpty) {
                        Provider.of<TaskProvider>(context, listen: false).updateTaskContent(Task(
                          id: task.id,
                          title: titleController.text,
                          note: noteController.text,
                          dueDate: selectedDateTime?.toIso8601String(),
                          isCompleted: task.isCompleted,
                          groupId: task.groupId,
                          attachmentPath: tempAttachmentPath,
                          // --- 3. CẬP NHẬT 2 TRƯỜNG MỚI ---
                          recurrence: selectedRecurrence,
                          reminderOffset: selectedOffset,
                        ));
                        Navigator.pop(ctx);
                      }
                    },
                    child: const Text('Cập nhật'),
                  )),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        });
      },
    );
  }
}