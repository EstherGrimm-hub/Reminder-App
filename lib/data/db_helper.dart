import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/task_model.dart';
import '../models/task_group_model.dart';
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  // Mở kết nối đến database
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('reminder.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
        path,
        version: 1,
        onCreate: _createDB
    );
  }

  Future _createDB(Database db, int version) async {
    // 1. Bảng Công việc (Thêm cột groupId)
    await db.execute('''
      CREATE TABLE tasks (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        title TEXT NOT NULL,
        note TEXT,
        dueDate TEXT,
        createdAt TEXT,
        isCompleted INTEGER NOT NULL,
        groupId INTEGER,
        attachmentPath TEXT,
        recurrence TEXT,
        reminderOffset INTEGER,
        completedAt TEXT, 
        duration INTEGER
      )
    ''');

    // 2. Bảng Danh sách tuỳ chỉnh (MỚI)
    await db.execute('''
      CREATE TABLE task_groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        createdAt TEXT,
        color INTEGER NOT NULL,
        iconCode INTEGER NOT NULL
      )
    ''');
  }

  // --- Các hàm xử lý dữ liệu ---
  Future<int> createTaskGroup(TaskGroup group) async {
    final db = await instance.database;
    return await db.insert('task_groups', group.toMap());
  }

  Future<List<TaskGroup>> readAllGroups() async {
    final db = await instance.database;
    final result = await db.query('task_groups');
    return result.map((json) => TaskGroup.fromMap(json)).toList();
  }

  // Thêm mới
  Future<int> createTask(Task task) async {
    final db = await instance.database;
    return await db.insert('tasks', task.toMap());
  }

  // Lấy danh sách
  Future<List<Task>> readAllTasks() async {
    final db = await instance.database;
    final result = await db.query('tasks', orderBy: 'id DESC'); // Việc mới lên đầu
    return result.map((json) => Task.fromMap(json)).toList();
  }

  // Cập nhật (ví dụ: tick xong)
  Future<int> updateTask(Task task) async {
    final db = await instance.database;
    return await db.update(
      'tasks',
      task.toMap(),
      where: 'id = ?',
      whereArgs: [task.id],
    );
  }

  // Xoá
  Future<int> deleteTask(int id) async {
    final db = await instance.database;
    return await db.delete(
      'tasks',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> updateTaskGroup(TaskGroup group) async {
    final db = await instance.database;
    return await db.update(
      'task_groups',
      group.toMap(),
      where: 'id = ?',
      whereArgs: [group.id],
    );
  }

  // 2. Xóa Group (Và xóa luôn các task trong group đó)
  Future<void> deleteTaskGroup(int groupId) async {
    final db = await instance.database;

    // Bước 1: Xóa tất cả task thuộc group này trước
    await db.delete(
      'tasks',
      where: 'groupId = ?',
      whereArgs: [groupId],
    );

    // Bước 2: Xóa group
    await db.delete(
      'task_groups',
      where: 'id = ?',
      whereArgs: [groupId],
    );
  }
}
