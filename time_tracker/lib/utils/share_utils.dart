import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import '../models/work_day.dart';
import '../models/task.dart';
import '../models/session.dart';
import '../database/dao/task_photo_dao.dart';
import 'time_utils.dart';
import '../models/task_session.dart';

class ShareUtils {
  /// Build plain text summary
  static String buildTextSummary({
    required WorkDay day,
    required List<Task> tasks,
    required List<Session> sessions,
    required Map<int, List<TaskSession>> taskSessions,
  }) {
    final buffer = StringBuffer();

    buffer.writeln(TimeUtils.formatDateShort(day.date));
    for (final s in sessions) {
      buffer.writeln(
          '${TimeUtils.formatTime(s.clockInTime)} - ${s.clockOutTime != null ? TimeUtils.formatTime(s.clockOutTime!) : 'Active'}');
    }
    buffer.writeln('');

    for (final t in tasks) {
      final tSessions = (taskSessions[t.id] ?? [])
          .where((s) => !s.isActive)
          .toList();
      buffer.writeln(t.name);
      for (final s in tSessions) {
        buffer.writeln(
            '${TimeUtils.formatTime(s.startTime)} - ${TimeUtils.formatTime(s.endTime!)}');
      }
      if (t.division != null && t.division!.isNotEmpty)
        buffer.writeln('Division: ${t.division}');
      if (t.notes != null && t.notes!.isNotEmpty)
        buffer.writeln('Summary: ${t.notes}');
      buffer.writeln('');
    }

    final totalMinutes = sessions
        .where((s) => s.clockOutTime != null)
        .fold<int>(
            0,
            (sum, s) =>
                sum +
                TimeUtils.roundToNearest15(
                        s.clockOutTime!.difference(s.clockInTime))
                    .inMinutes);
    buffer.writeln(
        'Total: ${TimeUtils.formatHoursDecimal(totalMinutes)} hours');

    return buffer.toString();
  }

  /// Share text only
  static Future<void> shareText({
    required WorkDay day,
    required List<Task> tasks,
    required List<Session> sessions,
    required Map<int, List<TaskSession>> taskSessions,
  }) async {
    final text = buildTextSummary(
      day: day,
      tasks: tasks,
      sessions: sessions,
      taskSessions: taskSessions,
    );
    await Share.share(text,
        subject:
            'Work Summary — ${TimeUtils.formatDateShort(day.date)}');
  }

  static Future<void> shareWithPhotos({
    required WorkDay day,
    required List<Task> tasks,
    required List<Session> sessions,
    required Map<int, List<TaskSession>> taskSessions,
    required BuildContext context,
  }) async {
    final text = buildTextSummary(
      day: day,
      tasks: tasks,
      sessions: sessions,
      taskSessions: taskSessions,
    );

    final List<XFile> files = [];
    for (final s in sessions) {
      for (final path in [s.clockInPhoto, s.clockOutPhoto]) {
        if (path != null && File(path).existsSync())
          files.add(XFile(path));
      }
    }
    for (final task in tasks) {
      if (task.id != null) {
        final extras =
            await TaskPhotoDao().getByTask(task.id!);
        for (final photo in extras) {
          if (File(photo.photoPath).existsSync())
            files.add(XFile(photo.photoPath));
        }
      }
    }
    final seen = <String>{};
    final unique =
        files.where((f) => seen.add(f.path)).toList();

    if (unique.isEmpty) {
      await Share.share(text,
          subject:
              'Work Summary — ${TimeUtils.formatDateShort(day.date)}');
    } else {
      await Share.shareXFiles(unique,
          text: text,
          subject:
              'Work Summary — ${TimeUtils.formatDateShort(day.date)}');
    }
  }

  static Future<void> sharePdf({
    required WorkDay day,
    required List<Task> tasks,
    required List<Session> sessions,
    required Map<int, List<TaskSession>> taskSessions,
  }) async {
    final pdf = pw.Document();

    final totalMinutes = sessions
        .where((s) => s.clockOutTime != null)
        .fold<int>(
            0,
            (sum, s) =>
                sum +
                TimeUtils.roundToNearest15(
                        s.clockOutTime!.difference(s.clockInTime))
                    .inMinutes);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          pw.Text(TimeUtils.formatDateShort(day.date),
              style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 8),
          ...sessions.map((s) => pw.Text(
                '${TimeUtils.formatTime(s.clockInTime)} - ${s.clockOutTime != null ? TimeUtils.formatTime(s.clockOutTime!) : 'Active'}',
                style: const pw.TextStyle(fontSize: 11),
              )),
          pw.SizedBox(height: 16),

          ...tasks.map((task) {
            final tSessions = (taskSessions[task.id] ?? [])
                .where((s) => !s.isActive)
                .toList();

            return pw.Container(
              margin: const pw.EdgeInsets.only(bottom: 12),
              child: pw.Column(
                crossAxisAlignment:
                    pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(task.name,
                      style: pw.TextStyle(
                          fontSize: 13,
                          fontWeight: pw.FontWeight.bold)),
                  ...tSessions.map((s) => pw.Text(
                        '${TimeUtils.formatTime(s.startTime)} - ${TimeUtils.formatTime(s.endTime!)}',
                        style: const pw.TextStyle(fontSize: 10),
                      )),
                  if (task.division != null &&
                      task.division!.isNotEmpty)
                    pw.Text('Division: ${task.division}',
                        style: const pw.TextStyle(fontSize: 10)),
                  if (task.notes != null &&
                      task.notes!.isNotEmpty)
                    pw.Text('Summary: ${task.notes}',
                        style: const pw.TextStyle(fontSize: 10)),
                ],
              ),
            );
          }),

          pw.SizedBox(height: 8),
          pw.Text(
              'Total: ${TimeUtils.formatHoursDecimal(totalMinutes)} hours',
              style: pw.TextStyle(
                  fontSize: 12,
                  fontWeight: pw.FontWeight.bold)),
        ],
      ),
    );

    final dir =
        await getApplicationDocumentsDirectory();
    final fileName =
        'FieldClock_${day.date.toIso8601String().substring(0, 10)}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles(
      [XFile(file.path)],
      subject:
          'Work Summary — ${TimeUtils.formatDateShort(day.date)}',
    );
  }

  static Future<void> shareTask({
    required Task task,
    required List<TaskSession> sessions,
  }) async {
    final buffer = StringBuffer();
    buffer.writeln('🔨 TASK SUMMARY');
    buffer.writeln('Task:     ${task.name}');
    if (task.division != null)
      buffer.writeln('Division: ${task.division}');

    final total = sessions
        .where((s) => !s.isActive)
        .fold(0,
            (sum, s) => sum + s.durationMinutesRounded);
    buffer.writeln(
        'Total:    ${TimeUtils.formatDuration(Duration(minutes: total))}');

    for (final s
        in sessions.where((s) => !s.isActive)) {
      buffer.writeln(
          '  · ${TimeUtils.formatTime(s.startTime)} → ${TimeUtils.formatTime(s.endTime!)}  (${TimeUtils.formatDuration(s.durationRounded)})');
    }

    if (task.startLocation != null)
      buffer.writeln('📍 ${task.startLocation}');
    if (task.notes != null && task.notes!.isNotEmpty)
      buffer.writeln('Notes: ${task.notes}');
    buffer.writeln('');
    buffer.writeln('Sent via FieldClock');

    final List<XFile> files = [];
    if (task.id != null) {
      final extras =
          await TaskPhotoDao().getByTask(task.id!);
      for (final photo in extras) {
        if (File(photo.photoPath).existsSync())
          files.add(XFile(photo.photoPath));
      }
    }
    final seen = <String>{};
    final unique =
        files.where((f) => seen.add(f.path)).toList();

    if (unique.isEmpty) {
      await Share.share(buffer.toString(),
          subject: 'Task: ${task.name}');
    } else {
      await Share.shareXFiles(unique,
          text: buffer.toString(),
          subject: 'Task: ${task.name}');
    }
  }
}