import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:image_picker/image_picker.dart';

// --- IMPORTS CỦA BẠN ---
import '../provider/task_provider.dart';
import '../models/task_model.dart';
import '../models/task_group_model.dart';
import '../screen/task_group_screen.dart';
import 'scheduled_screen.dart';
import 'today_task_screen.dart';
import 'task_detail_screen.dart';
import 'statistic_screen.dart';
import '../utils/data_seeder.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Controller cho ô tìm kiếm
  final TextEditingController _searchController = TextEditingController();

  // --- BIẾN TRẠNG THÁI MỚI: QUẢN LÝ VIỆC THU NHỎ/MỞ RỘNG DANH SÁCH ---
  bool _isMyListsExpanded = true;

  @override
  void initState() {
    super.initState();
    // Load dữ liệu khi mở app
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TaskProvider>(context, listen: false).loadData();
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: Consumer<TaskProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  return ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      // --- PHẦN 1: DASHBOARD (TỔNG QUAN) ---
                      Text('Tổng quan', style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)),
                      const SizedBox(height: 10),
                      _buildDashboardGrid(provider),

                      const SizedBox(height: 24),

                      // --- PHẦN 2: DANH SÁCH NHÓM (MY LISTS) - ĐÃ CẬP NHẬT ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Biến Text thành nút bấm để Thu nhỏ/Mở rộng
                          InkWell(
                            borderRadius: BorderRadius.circular(8),
                            onTap: () {
                              setState(() {
                                _isMyListsExpanded = !_isMyListsExpanded;
                              });
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
                              child: Row(
                                children: [
                                  Text(
                                      'Danh sách của tôi',
                                      style: TextStyle(color: Colors.grey[600], fontWeight: FontWeight.bold)
                                  ),
                                  const SizedBox(width: 8),
                                  // Icon mũi tên xoay dựa theo trạng thái
                                  Icon(
                                    _isMyListsExpanded ? Icons.keyboard_arrow_down : Icons.keyboard_arrow_right,
                                    color: Colors.grey[600],
                                    size: 20,
                                  )
                                ],
                              ),
                            ),
                          ),

                          // Nút thêm danh sách giữ nguyên
                          IconButton(
                            icon: const Icon(Icons.add_circle, color: Colors.deepPurple),
                            tooltip: "Thêm danh sách mới",
                            onPressed: () => _showAddListDialog(context),
                          )
                        ],
                      ),

                      // Hiệu ứng ẩn hiện danh sách
                      AnimatedCrossFade(
                        firstChild: Column(
                          children: [
                            const SizedBox(height: 10),
                            _buildMyListsGrid(context, provider),
                          ],
                        ),
                        secondChild: const SizedBox(width: double.infinity), // Khi thu nhỏ thì không hiện gì
                        crossFadeState: _isMyListsExpanded ? CrossFadeState.showFirst : CrossFadeState.showSecond,
                        duration: const Duration(milliseconds: 300),
                        alignment: Alignment.topCenter,
                      ),

                      const SizedBox(height: 24),

                      // --- PHẦN 3: DANH SÁCH CÔNG VIỆC ---
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // Tiêu đề thay đổi dựa trên trạng thái tìm kiếm
                          Expanded( // Bọc Expanded để tránh lỗi tràn màn hình nếu text dài
                            child: Text(
                              _searchController.text.isNotEmpty
                                  ? 'Kết quả tìm kiếm'
                                  : (provider.selectedGroupId == null ? 'Tất cả công việc' : 'Công việc trong nhóm'),
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (provider.selectedGroupId != null && _searchController.text.isEmpty)
                            TextButton(onPressed: () => provider.selectGroup(null), child: const Text("Xem tất cả"))
                        ],
                      ),
                      const SizedBox(height: 10),

                      provider.tasks.isEmpty
                          ? _buildEmptyState()
                          : ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: provider.tasks.length,
                        itemBuilder: (ctx, index) => _buildTaskItem(context, provider.tasks[index]),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showTaskSheet(context, null),
        child: const Icon(Icons.add),
      ),
    );
  }

  // --- HEADER & TÌM KIẾM ---
  Widget _buildHeader(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // --- NÚT TẠO DATA GIẢ ---
              IconButton(
                icon: const Icon(Icons.cloud_download, color: Colors.grey),
                tooltip: 'Tạo dữ liệu mẫu',
                onPressed: () async {
                  await DataSeeder.generateSamples(context);
                },
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 16),
          // TextField Tìm kiếm
          TextField(
            controller: _searchController,
            onChanged: (value) {
              Provider.of<TaskProvider>(context, listen: false).searchTasks(value);
              setState(() {});
            },
            decoration: InputDecoration(
              hintText: 'Tìm kiếm công việc...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchController.text.isNotEmpty
                  ? IconButton(
                icon: const Icon(Icons.clear, color: Colors.grey),
                onPressed: () {
                  _searchController.clear();
                  Provider.of<TaskProvider>(context, listen: false).searchTasks('');
                  setState(() {});
                  FocusScope.of(context).unfocus();
                },
              )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
              contentPadding: const EdgeInsets.symmetric(vertical: 0),
            ),
          ),
        ],
      ),
    );
  }

  // --- GRID DASHBOARD ---
  Widget _buildDashboardGrid(TaskProvider provider) {
    final weeklyStats = provider.weeklyStats;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [
        _buildCardItem(
          title: 'Hôm nay',
          count: provider.todayTasks.length,
          icon: Icons.calendar_today,
          color: Colors.blue,
          isSelected: false,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const TodayTaskScreen())),
        ),
        _buildCardItem(
          title: 'Dự kiến',
          count: provider.scheduledTasks.length,
          icon: Icons.calendar_month,
          color: Colors.red,
          isSelected: false,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const ScheduledScreen())),
        ),
        _buildCardItem(
          title: 'Hoàn tất',
          count: provider.completedTasks.length,
          icon: Icons.check_circle,
          color: Colors.green,
          isSelected: false,
          onTap: () {},
        ),
        _buildCardItem(
          title: 'Thống kê',
          count: weeklyStats['count'],
          icon: Icons.bar_chart,
          color: Colors.orange,
          isSelected: false,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const StatisticScreen())),
        ),
      ],
    );
  }

  // --- GRID NHÓM (MY LISTS) ---
  Widget _buildMyListsGrid(BuildContext context, TaskProvider provider) {
    if (provider.groups.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        width: double.infinity,
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
        child: const Center(child: Text("Chưa có danh sách nào. Nhấn + để tạo!", style: TextStyle(color: Colors.grey))),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 1.5,
      ),
      itemCount: provider.groups.length,
      itemBuilder: (ctx, index) {
        final group = provider.groups[index];
        final count = provider.allTasks.where((t) => t.groupId == group.id && t.isCompleted == 0).length;

        return _buildCardItem(
          title: group.name,
          count: count,
          icon: IconData(group.iconCode, fontFamily: 'MaterialIcons'),
          color: Color(group.color),
          isSelected: false,
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TaskGroupScreen(group: group))),
          onLongPress: () => _showGroupOptions(context, group),
        );
      },
    );
  }

  // --- WIDGET CARD CHUNG ---
  Widget _buildCardItem({
    required String title, required int count, required IconData icon, required Color color,
    required bool isSelected, required VoidCallback onTap, VoidCallback? onLongPress,
  }) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
            color: isSelected ? color.withOpacity(0.1) : Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: isSelected ? Border.all(color: color, width: 2) : null,
            boxShadow: [if (!isSelected) BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 4, offset: const Offset(0, 2))]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CircleAvatar(backgroundColor: color.withOpacity(0.2), radius: 16, child: Icon(icon, color: color, size: 18)),
                if (count >= 0) Text(count == 0 ? "" : "$count", style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: Colors.grey[700], fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  // --- WIDGET TASK ITEM ---
  Widget _buildTaskItem(BuildContext context, Task task) {
    final isDone = task.isCompleted == 1;
    String dateText = '';
    if (task.dueDate != null) {
      final date = DateTime.parse(task.dueDate!);
      dateText = DateFormat('dd/MM HH:mm').format(date);
    }
    final hasImage = task.attachmentPath != null && task.attachmentPath!.isNotEmpty;

    return Dismissible(
      key: Key(task.id.toString()),
      background: Container(
        color: Colors.red.shade100, alignment: Alignment.centerRight, padding: const EdgeInsets.only(right: 20),
        child: const Icon(Icons.delete, color: Colors.red),
      ),
      onDismissed: (_) => Provider.of<TaskProvider>(context, listen: false).deleteTask(task.id!),
      child: Card(
        elevation: 0,
        color: isDone ? Colors.grey[50] : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: Colors.grey.shade200)),
        margin: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => TaskDetailScreen(task: task))),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Transform.scale(
                  scale: 1.2,
                  child: Checkbox(
                    value: isDone,
                    shape: const CircleBorder(),
                    activeColor: Colors.deepPurple,
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
                      if (dateText.isNotEmpty) Padding(padding: const EdgeInsets.only(top: 4), child: Row(children: [Icon(Icons.access_time, size: 12, color: isDone ? Colors.grey : Colors.blue), const SizedBox(width: 4), Text(dateText, style: TextStyle(fontSize: 12, color: isDone ? Colors.grey : Colors.blue))])),
                      if (hasImage)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(8),
                            child: Image.file(File(task.attachmentPath!), height: 80, width: 80, fit: BoxFit.cover),
                          ),
                        )
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(top: 40),
        child: Column(
          children: [
            Icon(Icons.task_alt, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text("Không có công việc nào!", style: TextStyle(color: Colors.grey[500])),
          ],
        ),
      ),
    );
  }

  // --- POPUP TẠO/SỬA NHÓM ---
  void _showAddListDialog(BuildContext context, {TaskGroup? group}) {
    final isEditing = group != null;
    final nameController = TextEditingController(text: isEditing ? group.name : '');
    int selectedColor = isEditing ? group.color : Colors.blue.value;
    int selectedIcon = isEditing ? group.iconCode : Icons.list.codePoint;

    final colors = [Colors.blue, Colors.red, Colors.green, Colors.orange, Colors.purple, Colors.teal, Colors.pink];
    final icons = [Icons.work, Icons.home, Icons.school, Icons.fitness_center, Icons.shopping_cart, Icons.flight, Icons.restaurant, Icons.list];

    showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                title: Text(isEditing ? "Chỉnh sửa danh sách" : "Tạo danh sách mới"),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(controller: nameController, decoration: const InputDecoration(labelText: "Tên danh sách", border: OutlineInputBorder())),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: colors.map((c) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: GestureDetector(
                            onTap: () => setState(() => selectedColor = c.value),
                            child: CircleAvatar(backgroundColor: c, radius: 18, child: selectedColor == c.value ? const Icon(Icons.check, color: Colors.white, size: 20) : null),
                          ),
                        )).toList(),
                      ),
                    ),
                    const SizedBox(height: 16),
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: icons.map((i) => Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: GestureDetector(
                            onTap: () => setState(() => selectedIcon = i.codePoint),
                            child: Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(color: selectedIcon == i.codePoint ? Color(selectedColor).withOpacity(0.2) : Colors.transparent, borderRadius: BorderRadius.circular(8)),
                              child: Icon(i, size: 28, color: selectedIcon == i.codePoint ? Color(selectedColor) : Colors.grey),
                            ),
                          ),
                        )).toList(),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Huỷ")),
                  FilledButton(
                    onPressed: () {
                      if (nameController.text.isNotEmpty) {
                        final provider = Provider.of<TaskProvider>(context, listen: false);
                        if (isEditing) {
                          provider.updateGroup(TaskGroup(id: group.id, name: nameController.text, color: selectedColor, iconCode: selectedIcon));
                        } else {
                          provider.addGroup(nameController.text, selectedColor, selectedIcon);
                        }
                        Navigator.pop(ctx);
                      }
                    },
                    style: FilledButton.styleFrom(backgroundColor: Color(selectedColor)),
                    child: Text(isEditing ? "Lưu" : "Tạo"),
                  )
                ],
              );
            }
        )
    );
  }

  // --- POPUP TẠO/SỬA TASK ---
  void _showTaskSheet(BuildContext context, Task? task) {
    final isEditing = task != null;
    final titleController = TextEditingController(text: task?.title ?? '');
    final noteController = TextEditingController(text: task?.note ?? '');
    DateTime? selectedDateTime = task?.dueDate != null ? DateTime.parse(task!.dueDate!) : null;
    String? currentImagePath = task?.attachmentPath;

    String selectedRecurrence = task?.recurrence ?? 'None';
    int selectedOffset = task?.reminderOffset ?? 0;
    int selectedDuration = task?.duration ?? 0;

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
                  Text(isEditing ? 'Chỉnh sửa' : 'Việc mới', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold)),
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
                  DropdownButtonFormField<int>(
                    value: selectedDuration,
                    decoration: const InputDecoration(labelText: 'Thời gian thực hiện (dự kiến)', border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 0)),
                    items: const [
                      DropdownMenuItem(value: 0, child: Text('Không xác định')),
                      DropdownMenuItem(value: 15, child: Text('15 phút')),
                      DropdownMenuItem(value: 30, child: Text('30 phút')),
                      DropdownMenuItem(value: 60, child: Text('1 tiếng')),
                      DropdownMenuItem(value: 120, child: Text('2 tiếng')),
                      DropdownMenuItem(value: 180, child: Text('3 tiếng')),
                    ],
                    onChanged: (val) => setStateModal(() => selectedDuration = val!),
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
                            duration: selectedDuration,
                          ));
                        } else {
                          provider.addTask(
                              titleController.text,
                              noteController.text,
                              selectedDateTime,
                              attachmentPath: currentImagePath,
                              recurrence: selectedRecurrence,
                              reminderOffset: selectedOffset,
                              duration: selectedDuration
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

  // --- CÁC HÀM QUẢN LÝ NHÓM ---
  void _showGroupOptions(BuildContext context, TaskGroup group) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) {
        return SafeArea(
          child: Wrap(
            children: [
              ListTile(
                leading: const Icon(Icons.edit, color: Colors.blue),
                title: const Text('Chỉnh sửa danh sách'),
                onTap: () {
                  Navigator.pop(ctx);
                  _showAddListDialog(context, group: group);
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete, color: Colors.red),
                title: const Text('Xóa danh sách'),
                subtitle: const Text('Lưu ý: Tất cả công việc trong nhóm sẽ bị xóa!'),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteGroup(context, group);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _confirmDeleteGroup(BuildContext context, TaskGroup group) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Xác nhận xóa"),
        content: Text("Bạn có chắc muốn xóa nhóm '${group.name}' và toàn bộ công việc bên trong không?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Hủy")),
          TextButton(
            onPressed: () {
              Provider.of<TaskProvider>(context, listen: false).deleteGroup(group.id!);
              Navigator.pop(ctx);
            },
            child: const Text("Xóa", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}