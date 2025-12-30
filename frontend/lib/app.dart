import 'package:flutter/material.dart';

class VibeitApp extends StatelessWidget {
  const VibeitApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const Scaffold(
        body: Center(
          child: Text(
            'Vibeit – Setup Complete',
            style: TextStyle(fontSize: 18),
          ),
        ),
      ),
    );
  }
}
