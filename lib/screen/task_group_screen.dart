import 'dart:io'; // <--- Thêm import IO để xử lý file ảnh
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart'; // <--- Thêm STT
import 'package:image_picker/image_picker.dart'; // <--- Thêm Image Picker
import '../provider/task_provider.dart';
import '../models/task_model.dart';
import '../models/task_group_model.dart';
import 'task_detail_screen.dart'; // <--- QUAN TRỌNG: Import màn hình chi tiết

class TaskGroupScreen extends StatefulWidget {
  final TaskGroup group;

  const TaskGroupScreen({super.key, required this.group});

  @override
  State<TaskGroupScreen> createState() => _TaskGroupScreenState();
}

class _TaskGroupScreenState extends State<TaskGroupScreen> {
  @override
  Widget build(BuildContext context) {
    // Lấy màu từ group để làm theme cho màn hình này
    final groupColor = Color(widget.group.color);

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        backgroundColor: groupColor,
        title: Text(widget.group.name, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        leading: const BackButton(color: Colors.white),
        actions: [
          // Icon Icon của Group
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Icon(IconData(widget.group.iconCode, fontFamily: 'MaterialIcons'), color: Colors.white),
          )
        ],
      ),
      body: Consumer<TaskProvider>(
        builder: (context, provider, child) {
          // Lọc công việc thuộc nhóm này
          final groupTasks = provider.getTasksByGroup(widget.group.id!);

          if (groupTasks.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.assignment_add, size: 64, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  Text("Chưa có việc nào trong nhóm này", style: TextStyle(color: Colors.grey[500])),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: groupTasks.length,
            itemBuilder: (ctx, index) {
              return _buildTaskItem(context, groupTasks[index], groupColor);
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: groupColor,
        onPressed: () => _showTaskSheet(context, null), // Thêm mới
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // --- Tái sử dụng logic Task Item (Có chỉnh màu theo Group + Thêm ảnh + Navigation) ---
  Widget _buildTaskItem(BuildContext context, Task task, Color activeColor) {
    final isDone = task.isCompleted == 1;
    String dateText = '';
    if (task.dueDate != null) {
      dateText = DateFormat('dd/MM HH:mm').format(DateTime.parse(task.dueDate!));
    }

    // Kiểm tra có ảnh không
    final hasImage = task.attachmentPath != null && task.attachmentPath!.isNotEmpty;

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
          // --- SỬA Ở ĐÂY: Chuyển sang màn hình chi tiết ---
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => TaskDetailScreen(task: task)),
            );
          },
          // ------------------------------------------------
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start, // Căn lên trên
              children: [
                Transform.scale(
                  scale: 1.2,
                  child: Checkbox(
                    value: isDone,
                    shape: const CircleBorder(),
                    activeColor: activeColor, // Checkbox màu theo group
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
                      if (dateText.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [Icon(Icons.access_time, size: 12, color: isDone ? Colors.grey : activeColor), const SizedBox(width: 4), Text(dateText, style: TextStyle(fontSize: 12, color: isDone ? Colors.grey : activeColor))])),

                      // --- HIỂN THỊ ẢNH THU NHỎ NẾU CÓ ---
                      // if (hasImage)
                      //   Padding(
                      //     padding: const EdgeInsets.only(top: 8.0),
                      //     child: ClipRRect(
                      //       borderRadius: BorderRadius.circular(8),
                      //       child: Image.file(File(task.attachmentPath!), height: 80, width: 80, fit: BoxFit.cover),
                      //     ),
                      //   )
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

  // --- Popup Thêm/Sửa (Tự động gán Group ID + STT + Image Picker) ---
  void _showTaskSheet(BuildContext context, Task? task) {
    final isEditing = task != null;
    final titleController = TextEditingController(text: task?.title ?? '');
    final noteController = TextEditingController(text: task?.note ?? '');
    DateTime? selectedDateTime = task?.dueDate != null ? DateTime.parse(task!.dueDate!) : null;

    // Biến lưu ảnh
    String? tempAttachmentPath = task?.attachmentPath;

    final SpeechToText speech = SpeechToText();
    final ImagePicker picker = ImagePicker();
    bool isListening = false;

    showModalBottomSheet(
      context: context, isScrollControlled: true, useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) {
        return StatefulBuilder(builder: (context, setStateModal) {

          // Logic Micro
          void toggleListening() async {
            if (!isListening) {
              bool available = await speech.initialize(
                  onError: (val) => print('Lỗi: $val'),
                  onStatus: (val) { if (val == 'done' || val == 'notListening') setStateModal(() => isListening = false); }
              );
              if (available) {
                setStateModal(() => isListening = true);
                speech.listen(
                  onResult: (result) {
                    setStateModal(() {
                      titleController.text = result.recognizedWords;
                      titleController.selection = TextSelection.fromPosition(TextPosition(offset: titleController.text.length));
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

          // Logic Chọn Ảnh
          Future<void> pickImage(ImageSource source) async {
            final XFile? image = await picker.pickImage(source: source);
            if (image != null) {
              setStateModal(() {
                tempAttachmentPath = image.path;
              });
            }
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(isEditing ? 'Chỉnh sửa' : 'Thêm vào ${widget.group.name}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),

                TextField(
                    controller: titleController,
                    autofocus: !isEditing,
                    style: const TextStyle(fontSize: 18),
                    decoration: InputDecoration(
                        hintText: 'Tên công việc...',
                        border: InputBorder.none,
                        prefixIcon: Icon(Icons.radio_button_unchecked, color: Color(widget.group.color)),
                        // Icon Mic
                        suffixIcon: IconButton(
                          icon: Icon(isListening ? Icons.mic : Icons.mic_none, color: isListening ? Colors.red : Colors.grey),
                          onPressed: toggleListening,
                        )
                    )
                ),
                TextField(controller: noteController, maxLines: 3, minLines: 1, decoration: const InputDecoration(hintText: 'Ghi chú...', border: InputBorder.none, prefixIcon: Icon(Icons.notes))),

                // Hiển thị ảnh đang chọn
                if (tempAttachmentPath != null)
                  Stack(
                    children: [
                      Container(
                        margin: const EdgeInsets.symmetric(vertical: 8),
                        height: 100,
                        width: 100,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          image: DecorationImage(image: FileImage(File(tempAttachmentPath!)), fit: BoxFit.cover),
                        ),
                      ),
                      Positioned(
                        right: 0,
                        top: 8,
                        child: GestureDetector(
                          onTap: () => setStateModal(() => tempAttachmentPath = null),
                          child: const CircleAvatar(backgroundColor: Colors.white, radius: 10, child: Icon(Icons.close, size: 16, color: Colors.red)),
                        ),
                      )
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

                    // Nút chọn ảnh
                    Row(
                      children: [
                        IconButton(
                          icon: const Icon(Icons.image, color: Colors.blue),
                          onPressed: () => pickImage(ImageSource.gallery),
                        ),
                        IconButton(
                          icon: const Icon(Icons.camera_alt, color: Colors.blue),
                          onPressed: () => pickImage(ImageSource.camera),
                        ),
                      ],
                    )
                  ],
                ),
                const SizedBox(height: 16),
                SizedBox(width: double.infinity, child: FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Color(widget.group.color)),
                  onPressed: () {
                    if (titleController.text.isNotEmpty) {
                      final provider = Provider.of<TaskProvider>(context, listen: false);
                      if (isEditing) {
                        provider.updateTaskContent(Task(
                            id: task!.id,
                            title: titleController.text,
                            note: noteController.text,
                            dueDate: selectedDateTime?.toIso8601String(),
                            isCompleted: task.isCompleted,
                            groupId: task.groupId,
                            attachmentPath: tempAttachmentPath // Cập nhật ảnh
                        ));
                      } else {
                        // QUAN TRỌNG: Truyền widget.group.id vào đây + ẢNH
                        provider.addTask(
                            titleController.text,
                            noteController.text,
                            selectedDateTime,
                            groupId: widget.group.id,
                            attachmentPath: tempAttachmentPath // Lưu ảnh
                        );
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