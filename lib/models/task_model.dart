class Task {
  final int? id;
  final String title;
  final String? note;
  final String? dueDate;
  final int isCompleted; // 0: chưa xong, 1: đã xong
  final int? groupId;
  final String? attachmentPath;
  final String? recurrence; // 'None', 'Weekly', 'Monthly', 'Yearly'
  final int reminderOffset; // 0, 15, 30, 60 (phút)
  final String? completedAt; // Thời gian bấm hoàn thành
  final int duration;

  Task({
    this.id,
    required this.title,
    this.note,
    this.dueDate,
    this.isCompleted = 0,
    this.groupId,
    this.attachmentPath,
    this.recurrence = 'None',
    this.reminderOffset = 0,
    this.completedAt,
    this.duration = 0,
  });

  // Chuyển dữ liệu thành dạng Map để lưu vào Database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'note': note,
      'dueDate': dueDate,
      'isCompleted': isCompleted,
      'groupId': groupId,
      'attachmentPath': attachmentPath,
      'recurrence': recurrence,
      'reminderOffset': reminderOffset,
      'completedAt': completedAt,
      'duration': duration,
    };
  }

  // Đọc dữ liệu từ Database ra thành dạng Object
  factory Task.fromMap(Map<String, dynamic> map) {
    return Task(
      id: map['id'],
      title: map['title'],
      note: map['note'],
      dueDate: map['dueDate'],
      isCompleted: map['isCompleted'],
      groupId: map['groupId'],
      attachmentPath: map['attachmentPath'],
      recurrence: map['recurrence'] ?? 'None',
      reminderOffset: map['reminderOffset'] ?? 0,
      completedAt: map['completedAt'],
      duration: map['duration'] ?? 0,
    );
  }
}