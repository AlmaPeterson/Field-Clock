import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class TaskNameDialog extends StatefulWidget {
  const TaskNameDialog({super.key});

  @override
  State<TaskNameDialog> createState() => _TaskNameDialogState();
}

class _TaskNameDialogState extends State<TaskNameDialog> {
  final _controller = TextEditingController();
  final _notesController = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    _notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: AppTheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('NAME THIS TASK',
                style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              autofocus: true,
              style: const TextStyle(color: AppTheme.onBackground),
              decoration: InputDecoration(
                hintText: 'e.g. Framing — Master Bedroom',
                hintStyle: const TextStyle(color: AppTheme.onSurface),
                filled: true,
                fillColor: AppTheme.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.primary),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _notesController,
              style: const TextStyle(color: AppTheme.onBackground),
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'Notes (optional) — materials, issues...',
                hintStyle: const TextStyle(color: AppTheme.onSurface),
                filled: true,
                fillColor: AppTheme.surfaceAlt,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: const BorderSide(color: AppTheme.primary),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.pop(context,
                        {'name': 'Unnamed Task', 'notes': ''}),
                    child: const Text('Skip',
                        style: TextStyle(color: AppTheme.onSurface)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.pop(context, {
                      'name': _controller.text.trim().isEmpty
                          ? 'Unnamed Task'
                          : _controller.text.trim(),
                      'notes': _notesController.text.trim(),
                    }),
                    child: const Text('Save'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}