import 'package:flutter/material.dart';
import '../../database/dao/job_dao.dart';
import '../../database/dao/work_day_dao.dart';
import '../../database/dao/task_dao.dart';
import '../../models/job.dart';
import '../../models/work_day.dart';
import '../../models/task.dart';
import '../../theme/app_theme.dart';
import '../../utils/time_utils.dart';
import '../summary/summary_screen.dart';
import '../../utils/prefs_utils.dart';

class JobsScreen extends StatefulWidget {
  const JobsScreen({super.key});

  @override
  State<JobsScreen> createState() => _JobsScreenState();
}

class _JobsScreenState extends State<JobsScreen> {
  List<Job> _jobs = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final jobs = await JobDao().getAll();
    setState(() {
      _jobs = jobs;
      _loading = false;
    });
  }

  void _newJob() async {
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).cardColor,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _NewJobSheet(onSaved: _load),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jobs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: _newJob,
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
          : _jobs.isEmpty
              ? _EmptyState(onAdd: _newJob)
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ..._jobs.map((job) => _JobCard(
                          job: job,
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    JobDetailScreen(job: job)),
                          ),
                          onRefresh: _load,
                        )),
                  ],
                ),
      floatingActionButton: _jobs.isNotEmpty
          ? FloatingActionButton(
              backgroundColor: Theme.of(context).colorScheme.primary,
              foregroundColor: Colors.black,
              onPressed: _newJob,
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}

// ── Job Card ─────────────────────────────────────────────────────────────────

class _JobCard extends StatelessWidget {
  final Job job;
  final VoidCallback onTap;
  final VoidCallback onRefresh;

  const _JobCard({
    required this.job,
    required this.onTap,
    required this.onRefresh,
  });

  Color get _statusColor {
    switch (job.status) {
      case 'active':
        return AppColors.success;
      case 'completed':
        return Theme.of(context).colorScheme.primary;
      default:
        return Theme.of(context).textTheme.bodyMedium!.color!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(job.name,
                        style:
                            Theme.of(context).textTheme.titleMedium),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: _statusColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      job.status.toUpperCase(),
                      style: TextStyle(
                        color: _statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ],
              ),
              if (job.address != null) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Icon(Icons.location_on,
                        size: 14, color: Theme.of(context).textTheme.bodyMedium!.color!),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(job.address!,
                          style:
                              Theme.of(context).textTheme.bodyMedium),
                    ),
                  ],
                ),
              ],
              if (job.clientName != null) ...[
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(Icons.person_outline,
                        size: 14, color: Theme.of(context).textTheme.bodyMedium!.color!),
                    const SizedBox(width: 4),
                    Text(job.clientName!,
                        style:
                            Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ],
              const SizedBox(height: 8),
              Text(
                'Started ${TimeUtils.formatDate(job.startDate)}',
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(color: Theme.of(context).textTheme.bodyMedium!.color!),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Job Detail Screen ────────────────────────────────────────────────────────

class JobDetailScreen extends StatefulWidget {
  final Job job;
  const JobDetailScreen({super.key, required this.job});

  @override
  State<JobDetailScreen> createState() => _JobDetailScreenState();
}

class _JobDetailScreenState extends State<JobDetailScreen> {
  List<WorkDay> _days = [];
  Map<int, List<Task>> _tasksByDay = {};
  bool _loading = true;
  late Job _job;

  @override
  void initState() {
    super.initState();
    _job = widget.job;
    _load();
  }

  Future<void> _load() async {
    final days = await WorkDayDao().getByJob(_job.id!);
    final Map<int, List<Task>> taskMap = {};
    for (final day in days) {
      if (day.id != null) {
        taskMap[day.id!] = await TaskDao().getByWorkDay(day.id!);
      }
    }
    setState(() {
      _days = days;
      _tasksByDay = taskMap;
      _loading = false;
    });
  }

  int get _totalMinutes => _tasksByDay.values
      .expand((tasks) => tasks)
      .where((t) => t.isComplete)
      .fold(0, (s, t) => s + t.durationMinutesRounded);

  Future<void> _updateStatus(String status) async {
    final updated = _job.copyWith(status: status);
    await JobDao().update(updated);
    setState(() => _job = updated);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_job.name),
        actions: [
          PopupMenuButton<String>(
            color: Theme.of(context).cardColor,
            onSelected: _updateStatus,
            itemBuilder: (_) => [
              PopupMenuItem(
                value: 'active',
                child: Text('Mark Active',
                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!)),
              ),
              PopupMenuItem(
                value: 'completed',
                child: Text('Mark Completed',
                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!)),
              ),
              PopupMenuItem(
                value: 'paused',
                child: Text('Mark Paused',
                    style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!)),
              ),
            ],
            child: const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Icon(Icons.more_vert),
            ),
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: CircularProgressIndicator(color: Theme.of(context).colorScheme.primary))
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Job info card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_job.address != null)
                          _InfoRow(
                              icon: Icons.location_on,
                              text: _job.address!),
                        if (_job.clientName != null) ...[
                          const SizedBox(height: 8),
                          _InfoRow(
                              icon: Icons.person_outline,
                              text: _job.clientName!),
                        ],
                        const SizedBox(height: 12),
                        Divider(color: Theme.of(context).dividerColor),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            _StatBlock(
                              label: 'TOTAL HOURS',
                              value: TimeUtils.formatDuration(
                                  Duration(minutes: _totalMinutes)),
                            ),
                            _StatBlock(
                              label: 'DAYS WORKED',
                              value: '${_days.length}',
                            ),
                            _StatBlock(
                              label: 'TASKS DONE',
                              value: '${_tasksByDay.values.expand((t) => t).where((t) => t.isComplete).length}',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                if (_days.isEmpty)
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Text('No days logged for this job yet.',
                          style:
                              TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color!)),
                    ),
                  )
                else ...[
                  Text('WORKDAYS (${_days.length})',
                      style: Theme.of(context).textTheme.labelLarge),
                  const SizedBox(height: 12),
                  ..._days.map((day) {
                    final tasks = _tasksByDay[day.id] ?? [];
                    final minutes = tasks
                        .where((t) => t.isComplete)
                        .fold(
                            0,
                            (s, t) =>
                                s + t.durationMinutesRounded);
                    return _DayRow(
                      day: day,
                      taskCount: tasks
                          .where((t) => t.isComplete)
                          .length,
                      totalMinutes: minutes,
                      onTap: () async {
                        final name =
                            await PrefsUtils.getWorkerName();
                        if (!context.mounted) return;
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => SummaryScreen(
                              day: day,
                              workerName: name,
                            ),
                          ),
                        );
                      },
                    );
                  }),
                ],
                const SizedBox(height: 32),
              ],
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _InfoRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) => Row(
        children: [
          Icon(icon, size: 16, color: Theme.of(context).textTheme.bodyMedium!.color!),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: Theme.of(context).textTheme.bodyMedium)),
        ],
      );
}

class _StatBlock extends StatelessWidget {
  final String label;
  final String value;
  const _StatBlock({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Expanded(
        child: Column(
          children: [
            Text(value,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontSize: 20, color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 2),
            Text(label,
                style: Theme.of(context)
                    .textTheme
                    .labelLarge
                    ?.copyWith(fontSize: 9),
                textAlign: TextAlign.center),
          ],
        ),
      );
}

class _DayRow extends StatelessWidget {
  final WorkDay day;
  final int taskCount;
  final int totalMinutes;
  final VoidCallback onTap;

  const _DayRow({
    required this.day,
    required this.taskCount,
    required this.totalMinutes,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(
                horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(TimeUtils.formatDate(day.date),
                          style:
                              Theme.of(context).textTheme.bodyLarge),
                      if (day.clockInTime != null)
                        Text(
                          day.isComplete
                              ? '${TimeUtils.formatTime(day.clockInTime!)} → ${TimeUtils.formatTime(day.clockOutTime!)}'
                              : 'In: ${TimeUtils.formatTime(day.clockInTime!)}',
                          style: Theme.of(context)
                              .textTheme
                              .bodyMedium,
                        ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      TimeUtils.formatDuration(
                          Duration(minutes: totalMinutes)),
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text('$taskCount tasks',
                        style:
                            Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
                const SizedBox(width: 4),
                Icon(Icons.chevron_right,
                    color: Theme.of(context).textTheme.bodyMedium!.color!, size: 18),
              ],
            ),
          ),
        ),
      );
}

// ── New Job Bottom Sheet ─────────────────────────────────────────────────────

class _NewJobSheet extends StatefulWidget {
  final VoidCallback onSaved;
  const _NewJobSheet({required this.onSaved});

  @override
  State<_NewJobSheet> createState() => _NewJobSheetState();
}

class _NewJobSheetState extends State<_NewJobSheet> {
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _clientController = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _clientController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) return;
    setState(() => _saving = true);

    final job = Job(
      name: _nameController.text.trim(),
      address: _addressController.text.trim().isEmpty
          ? null
          : _addressController.text.trim(),
      clientName: _clientController.text.trim().isEmpty
          ? null
          : _clientController.text.trim(),
      startDate: DateTime.now(),
    );

    await JobDao().insert(job);
    widget.onSaved();
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24, right: 24, top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('NEW JOB',
              style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 16),
          _SheetField(
              controller: _nameController,
              label: 'Job Name *',
              hint: 'e.g. 123 Oak Street Renovation'),
          const SizedBox(height: 12),
          _SheetField(
              controller: _addressController,
              label: 'Address',
              hint: 'e.g. 123 Oak Street, Salt Lake City'),
          const SizedBox(height: 12),
          _SheetField(
              controller: _clientController,
              label: 'Client Name',
              hint: 'e.g. Johnson Family'),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.black),
                    )
                  : const Text('Create Job'),
            ),
          ),
          SizedBox(
              height: MediaQuery.of(context).padding.bottom + 8),
        ],
      ),
    );
  }
}

class _SheetField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String hint;

  const _SheetField({
    required this.controller,
    required this.label,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) => TextField(
        controller: controller,
        style: TextStyle(color: Theme.of(context).textTheme.bodyLarge!.color!),
        decoration: InputDecoration(
          labelText: label,
          labelStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color!),
          hintText: hint,
          hintStyle: TextStyle(color: Theme.of(context).textTheme.bodyMedium!.color!),
          filled: true,
          fillColor: Theme.of(context).dividerColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide:
                BorderSide(color: Theme.of(context).colorScheme.primary),
          ),
        ),
      );
}

// ── Empty State ──────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.work_outline,
                size: 64, color: Theme.of(context).textTheme.bodyMedium!.color!),
            const SizedBox(height: 16),
            Text('No jobs yet',
                style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text('Create a job to group your workdays',
                style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              icon: const Icon(Icons.add),
              label: const Text('Create First Job'),
              onPressed: onAdd,
            ),
          ],
        ),
      );
}