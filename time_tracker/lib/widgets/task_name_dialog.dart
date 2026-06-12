import 'package:flutter/material.dart';
import '../utils/divisions.dart';

class TaskNameDialog extends StatefulWidget {
  const TaskNameDialog({super.key});

  @override
  State<TaskNameDialog> createState() => _TaskNameDialogState();
}

class _TaskNameDialogState extends State<TaskNameDialog> {
  final _nameController = TextEditingController();
  final _notesController = TextEditingController();
  final _divisionSearchController = TextEditingController();
  String? _selectedDivision;
  List<String> _filteredDivisions = Divisions.all;
  bool _showDivisionList = false;

  @override
  void dispose() {
    _nameController.dispose();
    _notesController.dispose();
    _divisionSearchController.dispose();
    super.dispose();
  }

  void _filterDivisions(String query) {
    setState(() {
      _filteredDivisions = query.isEmpty
          ? Divisions.all
          : Divisions.all
              .where((d) =>
                  d.toLowerCase().contains(query.toLowerCase()))
              .toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    final cardColor = Theme.of(context).cardColor;
    final surfaceAlt = Theme.of(context).dividerColor;
    final mutedColor =
        Theme.of(context).textTheme.bodyMedium?.color;
    final bodyColor =
        Theme.of(context).textTheme.bodyLarge?.color;

    return Dialog(
      backgroundColor: cardColor,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('NAME THIS TASK',
                  style:
                      Theme.of(context).textTheme.labelLarge),
              const SizedBox(height: 16),

              // Task name
              TextField(
                controller: _nameController,
                autofocus: true,
                style: TextStyle(color: bodyColor),
                decoration: const InputDecoration(
                  hintText: 'e.g. Framing — Master Bedroom',
                ),
              ),
              const SizedBox(height: 12),

              // Division searchable dropdown
              Text('Division (optional)',
                  style: TextStyle(
                      color: mutedColor, fontSize: 12)),
              const SizedBox(height: 6),

              // Selected division chip or search field
              if (_selectedDivision != null && !_showDivisionList)
                GestureDetector(
                  onTap: () => setState(() {
                    _showDivisionList = true;
                    _divisionSearchController.text =
                        _selectedDivision!;
                    _filterDivisions(_selectedDivision!);
                  }),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      color: primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                          color: primary.withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _selectedDivision!,
                            style: TextStyle(
                                color: primary,
                                fontWeight: FontWeight.w600),
                          ),
                        ),
                        Icon(Icons.edit,
                            size: 14, color: primary),
                      ],
                    ),
                  ),
                )
              else ...[
                TextField(
                  controller: _divisionSearchController,
                  style: TextStyle(color: bodyColor),
                  decoration: InputDecoration(
                    hintText: 'Search divisions...',
                    prefixIcon: Icon(Icons.search,
                        color: mutedColor, size: 18),
                    suffixIcon: _divisionSearchController
                            .text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear,
                                color: mutedColor, size: 16),
                            onPressed: () {
                              _divisionSearchController
                                  .clear();
                              _filterDivisions('');
                              setState(() =>
                                  _selectedDivision = null);
                            },
                          )
                        : null,
                  ),
                  onTap: () =>
                      setState(() => _showDivisionList = true),
                  onChanged: (v) {
                    _filterDivisions(v);
                    setState(() => _showDivisionList = true);
                  },
                ),
                if (_showDivisionList) ...[
                  const SizedBox(height: 4),
                  Container(
                    constraints:
                        const BoxConstraints(maxHeight: 180),
                    decoration: BoxDecoration(
                      color: surfaceAlt,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: ListView.builder(
                      shrinkWrap: true,
                      itemCount: _filteredDivisions.length,
                      itemBuilder: (context, index) {
                        final div =
                            _filteredDivisions[index];
                        return InkWell(
                          onTap: () {
                            setState(() {
                              _selectedDivision = div;
                              _showDivisionList = false;
                              _divisionSearchController
                                  .text = div;
                            });
                          },
                          child: Padding(
                            padding: const EdgeInsets
                                .symmetric(
                                horizontal: 14,
                                vertical: 10),
                            child: Text(div,
                                style: TextStyle(
                                    color: bodyColor,
                                    fontSize: 14)),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ],

              const SizedBox(height: 12),

              // Notes
              TextField(
                controller: _notesController,
                style: TextStyle(color: bodyColor),
                maxLines: 2,
                decoration: const InputDecoration(
                  hintText:
                      'Notes (optional) — materials, issues...',
                ),
              ),
              const SizedBox(height: 20),

              Row(
                children: [
                  Expanded(
                    child: TextButton(
                      onPressed: () => Navigator.pop(
                          context, {
                        'name': 'Unnamed Task',
                        'notes': '',
                        'division': null,
                      }),
                      child: Text('Skip',
                          style:
                              TextStyle(color: mutedColor)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => Navigator.pop(
                          context, {
                        'name': _nameController.text
                                .trim()
                                .isEmpty
                            ? 'Unnamed Task'
                            : _nameController.text.trim(),
                        'notes':
                            _notesController.text.trim(),
                        'division': _selectedDivision,
                      }),
                      child: const Text('Save'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}