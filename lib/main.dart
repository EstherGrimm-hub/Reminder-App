import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'provider/task_provider.dart';
import 'services/notification_service.dart';
import 'screen/home_screen.dart'; // Import file bạn vừa tạo ở trên

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await NotificationService().init();

  runApp(
    ChangeNotifierProvider(
      create: (_) => TaskProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo Dashboard',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.deepPurple,
        scaffoldBackgroundColor: const Color(0xFFF3F4F6),
      ),
      home: const HomeScreen(), // Gọi class HomeScreen từ file kia
    );
  }
}