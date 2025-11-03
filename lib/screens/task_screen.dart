import 'package:flutter/material.dart';

// A simple model for a task
class Task {
  String description;
  bool isCompleted;

  Task({required this.description, this.isCompleted = false});
}

class TasksScreen extends StatefulWidget {
  const TasksScreen({super.key});

  @override
  State<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends State<TasksScreen> {
  final List<Task> _tasks = [];
  final TextEditingController _taskController = TextEditingController();

  void _addTask() {
    if (_taskController.text.isNotEmpty) {
      setState(() {
        _tasks.add(Task(description: _taskController.text));
        _taskController.clear();
      });
      Navigator.of(context).pop(); // Close the dialog
    }
  }

  void _showAddTaskDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Add New Task', style: TextStyle(color: Colors.black87)),
          content: TextField(
            controller: _taskController,
            autofocus: true,
            decoration: const InputDecoration(
              labelText: 'Task Description',

              border: OutlineInputBorder(),
            ),
            onSubmitted: (_) => _addTask(),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel', style: TextStyle(color: Colors.black54)),
            ),
            FilledButton(
              onPressed: _addTask,
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Daily Tasks'),
        elevation: 0,
      ),
      body: _tasks.isEmpty
          ? const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.checklist_rtl_rounded, size: 80, color: Colors.white38),
            SizedBox(height: 16),
            Text(
              'No tasks for today.',
              style: TextStyle(color: Colors.white70, fontSize: 18),
            ),
            Text(
              'Tap the \'+\' button to add one.',
              style: TextStyle(color: Colors.white54),
            ),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.all(8.0),
        itemCount: _tasks.length,
        itemBuilder: (context, index) {
          final task = _tasks[index];
          return Card(
            elevation: 2,
            margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 8),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              leading: Checkbox(
                value: task.isCompleted,
                onChanged: (bool? value) {
                  setState(() {
                    task.isCompleted = value!;
                  });
                },
              ),
              title: Text(
                task.description,
                style: TextStyle(
                  color: Colors.black87,
                  decoration: task.isCompleted
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
              ),
              trailing: IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                onPressed: () {
                  setState(() {
                    _tasks.removeAt(index);
                  });
                },
              ),
            ),
          );
        },
      ),

      floatingActionButton: FloatingActionButton.large(
        onPressed: _showAddTaskDialog,
        child: const Icon(Icons.add),
      ),
    );
  }
}
