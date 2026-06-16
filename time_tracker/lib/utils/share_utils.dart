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
    required String workerName,
    required Map<int, List<TaskSession>> taskSessions,
    bool condensed = false,
  }) {
    final buffer = StringBuffer();

    if (condensed) {
      // ── Condensed ──────────────────────────────
      buffer.writeln('📋 DAILY WORK SUMMARY');
      buffer.writeln('Worker:  $workerName');
      buffer.writeln(
          'Date:    ${TimeUtils.formatDate(day.date)}');
      buffer.writeln('');

      final onSiteMinutes = sessions
          .where((s) => !s.isActive)
          .fold(0, (sum, s) => sum + s.durationMinutes);
      buffer.writeln(
          'On Site: ${TimeUtils.formatDuration(Duration(minutes: onSiteMinutes))}  (${sessions.where((s) => !s.isActive).length} session${sessions.where((s) => !s.isActive).length == 1 ? '' : 's'})');
      buffer.writeln('');
      buffer.writeln('TASKS');
      buffer.writeln('─────────────────────────');

      for (int i = 0; i < tasks.length; i++) {
        final t = tasks[i];
        final tSessions = taskSessions[t.id] ?? [];
        final total = tSessions
            .where((s) => !s.isActive)
            .fold(0,
                (sum, s) => sum + s.durationMinutesRounded);
        final totalStr = TimeUtils.formatDuration(
            Duration(minutes: total));
        final name = t.division != null
            ? '${t.name}  [${t.division}]'
            : t.name;
        buffer.writeln(
            '${i + 1}. $name'.padRight(40) + totalStr);
      }

      final taskTotal = taskSessions.values
          .expand((s) => s)
          .where((s) => !s.isActive)
          .fold(0,
              (sum, s) => sum + s.durationMinutesRounded);
      buffer.writeln('─────────────────────────');
      buffer.writeln(
          'Total Task Hours: ${TimeUtils.formatDuration(Duration(minutes: taskTotal))}');
      buffer.writeln('');
      buffer.writeln('Sent via FieldClock');
    } else {
      // ── Full ────────────────────────────────────
      buffer.writeln('📋 DAILY WORK SUMMARY');
      buffer.writeln('Worker:  $workerName');
      buffer.writeln(
          'Date:    ${TimeUtils.formatDate(day.date)}');
      buffer.writeln('');

      for (int i = 0; i < sessions.length; i++) {
        final s = sessions[i];
        buffer.writeln(
            '⏰ Session ${i + 1}:  ${TimeUtils.formatTime(s.clockInTime)} → ${s.clockOutTime != null ? TimeUtils.formatTime(s.clockOutTime!) : 'Active'}  (${TimeUtils.formatDuration(s.duration)})');
      }

      if (day.clockInLocation != null)
        buffer.writeln(
            '📍 Location:  ${day.clockInLocation}');

      final taskTotal = taskSessions.values
          .expand((s) => s)
          .where((s) => !s.isActive)
          .fold(0,
              (sum, s) => sum + s.durationMinutesRounded);
      buffer.writeln(
          '⏱  Task Hours: ${TimeUtils.formatDuration(Duration(minutes: taskTotal))}');
      buffer.writeln('');
      buffer.writeln('─────────────────────────');
      buffer.writeln('TASKS');
      buffer.writeln('─────────────────────────');

      for (int i = 0; i < tasks.length; i++) {
        final t = tasks[i];
        final tSessions = taskSessions[t.id] ?? [];
        final total = tSessions
            .where((s) => !s.isActive)
            .fold(0,
                (sum, s) => sum + s.durationMinutesRounded);
        buffer.writeln('');
        buffer.writeln('${i + 1}. ${t.name}');
        if (t.division != null)
          buffer.writeln('   Division: ${t.division}');
        buffer.writeln(
            '   Total: ${TimeUtils.formatDuration(Duration(minutes: total))}');
        for (final s in tSessions.where((s) => !s.isActive)) {
          buffer.writeln(
              '   · ${TimeUtils.formatTime(s.startTime)} → ${TimeUtils.formatTime(s.endTime!)}  (${TimeUtils.formatDuration(s.durationRounded)})');
        }
        if (t.startLocation != null)
          buffer.writeln('   📍 ${t.startLocation}');
        if (t.notes != null && t.notes!.isNotEmpty)
          buffer.writeln('   Notes: ${t.notes}');
      }

      buffer.writeln('');
      buffer.writeln('─────────────────────────');
      buffer.writeln('Sent via FieldClock');
    }

    return buffer.toString();
  }

  /// Share text only
  static Future<void> shareText({
    required WorkDay day,
    required List<Task> tasks,
    required List<Session> sessions,
    required String workerName,
    required Map<int, List<TaskSession>> taskSessions,
    bool condensed = false,
  }) async {
    final text = buildTextSummary(
      day: day,
      tasks: tasks,
      sessions: sessions,
      workerName: workerName,
      taskSessions: taskSessions,
      condensed: condensed,
    );
    await Share.share(text,
        subject:
            'Work Summary — ${TimeUtils.formatDate(day.date)}');
  }

  static Future<void> shareWithPhotos({
    required WorkDay day,
    required List<Task> tasks,
    required List<Session> sessions,
    required String workerName,
    required Map<int, List<TaskSession>> taskSessions,
    required BuildContext context,
    bool condensed = false,
  }) async {
    final text = buildTextSummary(
      day: day,
      tasks: tasks,
      sessions: sessions,
      workerName: workerName,
      taskSessions: taskSessions,
      condensed: condensed,
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
              'Work Summary — ${TimeUtils.formatDate(day.date)}');
    } else {
      await Share.shareXFiles(unique,
          text: text,
          subject:
              'Work Summary — ${TimeUtils.formatDate(day.date)}');
    }
  }

  static Future<void> sharePdf({
    required WorkDay day,
    required List<Task> tasks,
    required List<Session> sessions,
    required String workerName,
    required Map<int, List<TaskSession>> taskSessions,
    bool condensed = false,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (context) => [
          // Header
          pw.Container(
            padding:
                const pw.EdgeInsets.only(bottom: 16),
            decoration: const pw.BoxDecoration(
              border: pw.Border(
                  bottom: pw.BorderSide(
                      color: PdfColors.grey300)),
            ),
            child: pw.Column(
              crossAxisAlignment:
                  pw.CrossAxisAlignment.start,
              children: [
                pw.Text(
                  condensed
                      ? 'DAILY WORK SUMMARY — CONDENSED'
                      : 'DAILY WORK SUMMARY',
                  style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold)),
                pw.SizedBox(height: 4),
                pw.Text('Worker: $workerName'),
                pw.Text(
                    'Date: ${TimeUtils.formatDate(day.date)}'),
              ],
            ),
          ),
          pw.SizedBox(height: 16),

          // Sessions
          pw.Text('ON SITE',
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700)),
          pw.Divider(),
          ...sessions.map((s) => pw.Padding(
                padding:
                    const pw.EdgeInsets.only(bottom: 4),
                child: pw.Row(
                  mainAxisAlignment:
                      pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      '${TimeUtils.formatTime(s.clockInTime)} → ${s.clockOutTime != null ? TimeUtils.formatTime(s.clockOutTime!) : 'Active'}',
                      style: const pw.TextStyle(
                          fontSize: 10),
                    ),
                    pw.Text(
                      TimeUtils.formatDuration(
                          s.duration),
                      style: pw.TextStyle(
                          fontSize: 10,
                          fontWeight:
                              pw.FontWeight.bold),
                    ),
                  ],
                ),
              )),

          pw.SizedBox(height: 20),

          // Tasks
          pw.Text('TASKS',
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700)),
          pw.Divider(),

          ...tasks.map((task) {
            final tSessions =
                taskSessions[task.id] ?? [];
            final total = tSessions
                .where((s) => !s.isActive)
                .fold(
                    0,
                    (sum, s) =>
                        sum + s.durationMinutesRounded);

            return pw.Container(
              margin: const pw.EdgeInsets.only(
                  bottom: 12),
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(
                    color: PdfColors.grey200),
                borderRadius:
                    pw.BorderRadius.circular(6),
              ),
              child: pw.Column(
                crossAxisAlignment:
                    pw.CrossAxisAlignment.start,
                children: [
                  pw.Row(
                    mainAxisAlignment:
                        pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Expanded(
                        child: pw.Text(task.name,
                            style: pw.TextStyle(
                                fontWeight:
                                    pw.FontWeight.bold)),
                      ),
                      pw.Text(
                        TimeUtils.formatDuration(
                            Duration(minutes: total)),
                        style: pw.TextStyle(
                            fontWeight:
                                pw.FontWeight.bold),
                      ),
                    ],
                  ),
                  if (task.division != null)
                    pw.Text(task.division!,
                        style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey600)),
                  // Show sessions if full mode
                  if (!condensed) ...[
                    pw.SizedBox(height: 4),
                    ...tSessions
                        .where((s) => !s.isActive)
                        .map((s) => pw.Padding(
                              padding:
                                  const pw.EdgeInsets
                                      .only(bottom: 2),
                              child: pw.Row(
                                mainAxisAlignment:
                                    pw.MainAxisAlignment
                                        .spaceBetween,
                                children: [
                                  pw.Text(
                                    '· ${TimeUtils.formatTime(s.startTime)} → ${TimeUtils.formatTime(s.endTime!)}',
                                    style:
                                        const pw.TextStyle(
                                            fontSize: 9,
                                            color: PdfColors
                                                .grey600),
                                  ),
                                  pw.Text(
                                    TimeUtils.formatDuration(
                                        s.durationRounded),
                                    style:
                                        const pw.TextStyle(
                                            fontSize: 9,
                                            color: PdfColors
                                                .grey600),
                                  ),
                                ],
                              ),
                            )),
                  ],
                  if (task.startLocation != null)
                    pw.Text('📍 ${task.startLocation}',
                        style: const pw.TextStyle(
                            fontSize: 9,
                            color: PdfColors.grey500)),
                  if (task.notes != null &&
                      task.notes!.isNotEmpty)
                    pw.Text('Notes: ${task.notes}',
                        style: const pw.TextStyle(
                            fontSize: 10,
                            color: PdfColors.grey700)),
                ],
              ),
            );
          }),

          pw.SizedBox(height: 16),
          pw.Divider(),
          pw.Align(
            alignment: pw.Alignment.centerRight,
            child: pw.Text('Generated by FieldClock',
                style: const pw.TextStyle(
                    fontSize: 9,
                    color: PdfColors.grey400)),
          ),
        ],
      ),
    );

    final dir =
        await getApplicationDocumentsDirectory();
    final fileName =
        'FieldClock_${day.date.toIso8601String().substring(0, 10)}${condensed ? '_condensed' : ''}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());
    await Share.shareXFiles(
      [XFile(file.path)],
      subject:
          'Work Summary — ${TimeUtils.formatDate(day.date)}',
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