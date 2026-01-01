import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../provider/task_provider.dart';
import '../models/task_model.dart';
import 'month_detail_screen.dart'; // <--- Import màn hình chi tiết tháng

class StatisticScreen extends StatefulWidget {
  const StatisticScreen({super.key});

  @override
  State<StatisticScreen> createState() => _StatisticScreenState();
}

class _StatisticScreenState extends State<StatisticScreen> {
  // Mặc định chọn năm hiện tại
  int _selectedYear = DateTime.now().year;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text('Thống kê theo Năm', style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          // Dropdown chọn Năm ở góc phải
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: DropdownButton<int>(
              value: _selectedYear,
              underline: const SizedBox(), // Bỏ gạch chân
              style: const TextStyle(color: Colors.deepPurple, fontWeight: FontWeight.bold, fontSize: 16),
              icon: const Icon(Icons.arrow_drop_down, color: Colors.deepPurple),
              // Tạo danh sách năm: Năm ngoái, Năm nay, 3 Năm tới
              items: List.generate(5, (index) {
                int year = DateTime.now().year - 1 + index;
                return DropdownMenuItem(value: year, child: Text("Năm $year"));
              }),
              onChanged: (val) {
                if (val != null) setState(() => _selectedYear = val);
              },
            ),
          )
        ],
      ),
      body: Consumer<TaskProvider>(
        builder: (context, provider, child) {
          // 1. Lấy dữ liệu tổng quan của Năm đang chọn
          final yearTasks = provider.getCompletedTasksForYear(_selectedYear);
          final totalYearMinutes = provider.calculateTotalMinutes(yearTasks);

          return Column(
            children: [
              // --- A. THẺ TỔNG KẾT NĂM ---
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [Colors.deepPurple, Colors.purpleAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.deepPurple.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))
                  ],
                ),
                child: Column(
                  children: [
                    Text("Tổng kết năm $_selectedYear", style: const TextStyle(color: Colors.white70, fontSize: 16)),
                    const SizedBox(height: 8),
                    Text(
                        "${yearTasks.length}",
                        style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold)
                    ),
                    const Text("công việc đã hoàn thành", style: TextStyle(color: Colors.white, fontSize: 14)),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(20)),
                      child: Text(
                          _formatDuration(totalYearMinutes),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)
                      ),
                    )
                  ],
                ),
              ),

              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text("Chi tiết từng tháng", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey))
                ),
              ),

              // --- B. DANH SÁCH 12 THÁNG ---
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: 12,
                  itemBuilder: (context, index) {
                    int month = index + 1;
                    // Lấy task riêng của từng tháng để hiển thị sơ lược
                    List<Task> monthTasks = provider.getCompletedTasksForMonth(_selectedYear, month);

                    // Chỉ làm nổi bật tháng nào có dữ liệu
                    bool hasData = monthTasks.isNotEmpty;

                    return Card(
                      elevation: 0,
                      color: Colors.white,
                      margin: const EdgeInsets.only(bottom: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () {
                          // Bấm vào tháng -> Chuyển sang màn hình chi tiết Tháng
                          Navigator.push(context, MaterialPageRoute(builder: (_) => MonthDetailScreen(
                            month: month,
                            year: _selectedYear,
                          )));
                        },
                        child: ListTile(
                          leading: Container(
                            width: 50,
                            alignment: Alignment.center,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                                color: hasData ? Colors.blue.withOpacity(0.1) : Colors.grey[100],
                                borderRadius: BorderRadius.circular(8)
                            ),
                            child: Text(
                                "T$month",
                                style: TextStyle(fontWeight: FontWeight.bold, color: hasData ? Colors.blue : Colors.grey)
                            ),
                          ),
                          title: Text("Tháng $month", style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: hasData ? Colors.black : Colors.grey[600]
                          )),
                          subtitle: hasData
                              ? Text("${monthTasks.length} việc hoàn thành", style: const TextStyle(color: Colors.green))
                              : const Text("Chưa có dữ liệu", style: TextStyle(fontSize: 12)),
                          trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: Colors.grey),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // Hàm format thời gian (VD: 90 -> 1 giờ 30 phút)
  String _formatDuration(int minutes) {
    if (minutes == 0) return "0 phút";
    final int hours = minutes ~/ 60;
    final int mins = minutes % 60;
    if (hours > 0) {
      return "$hours giờ $mins phút";
    }
    return "$mins phút";
  }
}