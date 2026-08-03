import 'package:flutter/material.dart';

/// Main screen that lists every todo.
///
/// This is a placeholder skeleton. The full list, with add / edit / complete /
/// delete, is implemented in a later commit once the data layer is in place.
class TodoListScreen extends StatelessWidget {
  const TodoListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('stiko')),
      body: const Center(
        child: Text('할 일이 없습니다'),
      ),
    );
  }
}
