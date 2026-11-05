import 'package:flutter/material.dart';

void main() {
  runApp(const ITesterApp());
}

class ITesterApp extends StatelessWidget {
  const ITesterApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'iTester',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blue),
      ),
      home: const HelloPage(),
    );
  }
}

class HelloPage extends StatelessWidget {
  const HelloPage({super.key});

  static const greetings = [
    ('中文', '你好'),
    ('日本語', 'こんにちは'),
    ('English', 'Hello'),
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('iTester'),
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
      ),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final (lang, text) in greetings)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Column(
                  children: [
                    Text(text, style: textTheme.displayMedium),
                    Text(lang, style: textTheme.titleMedium),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
