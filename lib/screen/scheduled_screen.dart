import 'dart:io'; // <--- Import IO để xử lý file ảnh
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:image_picker/image_picker.dart'; // <--- Import ảnh
import 'package:speech_to_text/speech_to_text.dart'; // <--- Import giọng nói
import '../provider/task_provider.dart';
import '../models/task_model.dart';
import 'task_detail_screen.dart'; // <--- Import màn hình chi tiết

class ScheduledScreen extends StatefulWidget {
  const ScheduledScreen({super.key});

  @override
  State<ScheduledScreen> createState() => _ScheduledScreenState();
}

class _ScheduledScreenState extends State<ScheduledScreen> {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  void initState() {
    super.initState();
    _selectedDay = _focusedDay;
  }

  // Hàm lấy task theo ngày
  List<Task> _getTasksForDay(DateTime day, List<Task> allTasks) {
    return allTasks.where((task) {
      if (task.dueDate == null) return false;
      final taskDate = DateTime.parse(task.dueDate!);
      return isSameDay(taskDate, day);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Lịch dự kiến', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Consumer<TaskProvider>(
        builder: (context, provider, child) {
          final scheduledTasks = provider.scheduledTasks;
          final selectedTasks = _getTasksForDay(_selectedDay!, scheduledTasks);

          return Column(
            children: [
              // --- PHẦN 1: LỊCH ---
              Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                  ],
                ),
                child: TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2030, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: _calendarFormat,

                  selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                  onDaySelected: (selectedDay, focusedDay) {
                    setState(() {
                      _selectedDay = selectedDay;
                      _focusedDay = focusedDay;
                    });
                  },
                  onFormatChanged: (format) {
                    setState(() {
                      _calendarFormat = format;
                    });
                  },
                  onPageChanged: (focusedDay) {
                    _focusedDay = focusedDay;
                  },

                  eventLoader: (day) {
                    return _getTasksForDay(day, scheduledTasks);
                  },

                  headerStyle: const HeaderStyle(
                      formatButtonVisible: false,
                      titleCentered: true,
                      titleTextStyle: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                  ),
                  calendarStyle: CalendarStyle(
                    markerDecoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                    selectedDecoration: const BoxDecoration(color: Colors.deepPurple, shape: BoxShape.circle),
                    todayDecoration: BoxDecoration(color: Colors.deepPurple.withOpacity(0.5), shape: BoxShape.circle),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    "Công việc ngày ${DateFormat('dd/MM').format(_selectedDay!)}",
                    style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold),
                  ),
                ),
              ),

              const SizedBox(height: 10),

              // --- PHẦN 2: DANH SÁCH TASK ---
              Expanded(
                child: selectedTasks.isEmpty
                    ? _buildEmptyState()
                    : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: selectedTasks.length,
                  itemBuilder: (context, index) {
                    return _buildTaskItem(context, selectedTasks[index]);
                  },
                ),
              ),
            ],
          );
        },
      ),
      // --- NÚT THÊM TASK ---
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTaskSheet(context, null),
        backgroundColor: Colors.deepPurple,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.event_available, size: 64, color: Colors.grey[300]),
          const SizedBox(height: 16),
          Text("Không có việc nào trong ngày này", style: TextStyle(color: Colors.grey[500])),
        ],
      ),
    );
  }

  // --- Widget Task Item (Đã thêm onTap để xem Detail) ---
  Widget _buildTaskItem(BuildContext context, Task task) {
    final isDone = task.isCompleted == 1;
    final dateText = DateFormat('HH:mm').format(DateTime.parse(task.dueDate!));

    // Kiểm tra có ảnh không để hiện icon nhỏ báo hiệu
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
          // --- CHUYỂN SANG DETAIL SCREEN ---
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => TaskDetailScreen(task: task)),
            );
          },
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            leading: Transform.scale(
              scale: 1.2,
              child: Checkbox(
                value: isDone,
                shape: const CircleBorder(),
                activeColor: Colors.deepPurple,
                onChanged: (_) => Provider.of<TaskProvider>(context, listen: false).toggleComplete(task),
              ),
            ),
            title: Text(task.title, style: TextStyle(fontSize: 16, decoration: isDone ? TextDecoration.lineThrough : null, color: isDone ? Colors.grey : Colors.black87, fontWeight: FontWeight.w600)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (task.note != null && task.note!.isNotEmpty) Text(task.note!, maxLines: 1, overflow: TextOverflow.ellipsis),
                if (hasImage)
                  const Padding(
                    padding: EdgeInsets.only(top: 4.0),
                    child: Row(children: [Icon(Icons.image, size: 14, color: Colors.grey), SizedBox(width: 4), Text("Có hình ảnh", style: TextStyle(fontSize: 12, color: Colors.grey))]),
                  )
              ],
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
              child: Text(dateText, style: const TextStyle(color: Colors.blue, fontWeight: FontWeight.bold, fontSize: 12)),
            ),
          ),
        ),
      ),
    );
  }

  // --- POPUP THÊM/SỬA TASK (FULL TÍNH NĂNG) ---
  void _showTaskSheet(BuildContext context, Task? task) {
    final isEditing = task != null;
    final titleController = TextEditingController(text: task?.title ?? '');
    final noteController = TextEditingController(text: task?.note ?? '');

    // Mặc định ngày giờ là ngày đang chọn trên lịch + giờ hiện tại
    DateTime defaultDate = DateTime(
        _selectedDay!.year,
        _selectedDay!.month,
        _selectedDay!.day,
        DateTime.now().hour,
        DateTime.now().minute
    );

    DateTime? selectedDateTime = task?.dueDate != null ? DateTime.parse(task!.dueDate!) : defaultDate;
    String? currentImagePath = task?.attachmentPath;

    String selectedRecurrence = task?.recurrence ?? 'None';
    int selectedOffset = task?.reminderOffset ?? 0;

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

          Future<void> pickImage(ImageSource source) async {
            final XFile? image = await picker.pickImage(source: source);
            if (image != null) {
              setStateModal(() {
                currentImagePath = image.path;
              });
            }
          }

          return Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom, left: 16, right: 16, top: 16),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(isEditing ? 'Chỉnh sửa' : 'Việc mới vào ${DateFormat('dd/MM').format(_selectedDay!)}', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),

                  TextField(
                      controller: titleController,
                      autofocus: !isEditing,
                      style: const TextStyle(fontSize: 18),
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

                  if (currentImagePath != null)
                    Stack(
                      children: [
                        Container(margin: const EdgeInsets.symmetric(vertical: 8), height: 100, width: 100, decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), image: DecorationImage(image: FileImage(File(currentImagePath!)), fit: BoxFit.cover))),
                        Positioned(right: 0, top: 8, child: GestureDetector(onTap: () => setStateModal(() => currentImagePath = null), child: const CircleAvatar(backgroundColor: Colors.white, radius: 10, child: Icon(Icons.close, size: 16, color: Colors.red))))
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
                        final provider = Provider.of<TaskProvider>(context, listen: false);

                        if (isEditing) {
                          provider.updateTaskContent(Task(
                            id: task!.id,
                            title: titleController.text,
                            note: noteController.text,
                            dueDate: selectedDateTime?.toIso8601String(),
                            isCompleted: task.isCompleted,
                            groupId: task.groupId,
                            attachmentPath: currentImagePath,
                            recurrence: selectedRecurrence,
                            reminderOffset: selectedOffset,
                          ));
                        } else {
                          provider.addTask(
                              titleController.text,
                              noteController.text,
                              selectedDateTime,
                              attachmentPath: currentImagePath,
                              recurrence: selectedRecurrence,
                              reminderOffset: selectedOffset
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
            ),
          );
        });
      },
    );
  }
}