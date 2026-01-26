import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() {
  runApp(const FakeNewsDetectorApp());
}

class FakeNewsDetectorApp extends StatelessWidget {
  const FakeNewsDetectorApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Fake News Detector',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.blue,
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.blue,
          brightness: Brightness.light,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}
