
class TaskGroup {
  final int? id;
  final String name;
  final int color; // Lưu màu dưới dạng số nguyên (Value của Color)
  final int iconCode; // Lưu mã icon

  TaskGroup({this.id, required this.name, required this.color, required this.iconCode});

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'color': color,
      'iconCode': iconCode,
    };
  }

  factory TaskGroup.fromMap(Map<String, dynamic> map) {
    return TaskGroup(
      id: map['id'],
      name: map['name'],
      color: map['color'],
      iconCode: map['iconCode'],
    );
  }
}