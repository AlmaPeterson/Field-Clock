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

class ShareUtils {
  /// Build plain text summary
  static String buildTextSummary({
    required WorkDay day,
    required List<Task> tasks,
    required List<Session> sessions,
    required String workerName,
  }) {
    final buffer = StringBuffer();
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

    final taskTotal = tasks.fold(
        0, (s, t) => s + t.durationMinutesRounded);
    buffer.writeln(
        '⏱  Task Hours: ${TimeUtils.formatDuration(Duration(minutes: taskTotal))}');
    buffer.writeln('');
    buffer.writeln('─────────────────────────');
    buffer.writeln('TASKS');
    buffer.writeln('─────────────────────────');

    for (int i = 0; i < tasks.length; i++) {
      final t = tasks[i];
      buffer.writeln('');
      buffer.writeln('${i + 1}. ${t.name}');
      if (t.division != null)
        buffer.writeln('   Division: ${t.division}');
      buffer.writeln(
          '   ${TimeUtils.formatTime(t.startTime)} → ${t.endTime != null ? TimeUtils.formatTime(t.endTime!) : 'In progress'}');
      buffer.writeln(
          '   Duration: ${TimeUtils.formatDuration(t.durationRounded)}');
      if (t.startLocation != null)
        buffer.writeln('   📍 ${t.startLocation}');
      if (t.notes != null && t.notes!.isNotEmpty)
        buffer.writeln('   Notes: ${t.notes}');
    }

    buffer.writeln('');
    buffer.writeln('─────────────────────────');
    buffer.writeln('Sent via FieldClock');
    return buffer.toString();
  }

  /// Share text only
  static Future<void> shareText({
    required WorkDay day,
    required List<Task> tasks,
    required List<Session> sessions,
    required String workerName,
  }) async {
    final text = buildTextSummary(
      day: day,
      tasks: tasks,
      sessions: sessions,
      workerName: workerName,
    );
    await Share.share(text,
        subject:
            'Work Summary — ${TimeUtils.formatDate(day.date)}');
  }

  /// Share text + all photos including task_photos table
  static Future<void> shareWithPhotos({
    required WorkDay day,
    required List<Task> tasks,
    required List<Session> sessions,
    required String workerName,
    required BuildContext context,
  }) async {
    final text = buildTextSummary(
      day: day,
      tasks: tasks,
      sessions: sessions,
      workerName: workerName,
    );

    final List<XFile> files = [];

    // Session photos
    for (final s in sessions) {
      for (final path in
          [s.clockInPhoto, s.clockOutPhoto]) {
        if (path != null && File(path).existsSync()) {
          files.add(XFile(path));
        }
      }
    }

    // Task primary photos + task_photos table
    for (final task in tasks) {
      // Primary before/after
      for (final path in
          [task.startPhoto, task.endPhoto]) {
        if (path != null && File(path).existsSync()) {
          files.add(XFile(path));
        }
      }
      // Additional photos from task_photos table
      if (task.id != null) {
        final extras =
            await TaskPhotoDao().getByTask(task.id!);
        for (final photo in extras) {
          if (File(photo.photoPath).existsSync()) {
            files.add(XFile(photo.photoPath));
          }
        }
      }
    }

    // Deduplicate paths
    final seen = <String>{};
    final unique = files
        .where((f) => seen.add(f.path))
        .toList();

    if (unique.isEmpty) {
      await Share.share(text,
          subject:
              'Work Summary — ${TimeUtils.formatDate(day.date)}');
    } else {
      await Share.shareXFiles(
        unique,
        text: text,
        subject:
            'Work Summary — ${TimeUtils.formatDate(day.date)}',
      );
    }
  }

  /// Generate and share PDF
  static Future<void> sharePdf({
    required WorkDay day,
    required List<Task> tasks,
    required List<Session> sessions,
    required String workerName,
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
                pw.Text('DAILY WORK SUMMARY',
                    style: pw.TextStyle(
                        fontSize: 20,
                        fontWeight:
                            pw.FontWeight.bold)),
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

          pw.SizedBox(height: 24),

          // Tasks
          pw.Text('TASKS',
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.grey700)),
          pw.Divider(),

          ...tasks.map((task) => pw.Container(
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
                          pw.MainAxisAlignment
                              .spaceBetween,
                      children: [
                        pw.Expanded(
                          child: pw.Text(task.name,
                              style: pw.TextStyle(
                                  fontWeight:
                                      pw.FontWeight
                                          .bold)),
                        ),
                        pw.Text(
                            TimeUtils.formatDuration(
                                task.durationRounded),
                            style: pw.TextStyle(
                                fontWeight:
                                    pw.FontWeight
                                        .bold)),
                      ],
                    ),
                    if (task.division != null) ...[
                      pw.SizedBox(height: 2),
                      pw.Text(
                        task.division!,
                        style: const pw.TextStyle(
                            fontSize: 9,
                            color:
                                PdfColors.grey600),
                      ),
                    ],
                    pw.SizedBox(height: 4),
                    pw.Text(
                        '${TimeUtils.formatTime(task.startTime)} → ${task.endTime != null ? TimeUtils.formatTime(task.endTime!) : 'In progress'}',
                        style: const pw.TextStyle(
                            fontSize: 10,
                            color:
                                PdfColors.grey600)),
                    if (task.startLocation != null)
                      pw.Text(
                          '📍 ${task.startLocation}',
                          style: const pw.TextStyle(
                              fontSize: 9,
                              color:
                                  PdfColors.grey500)),
                    if (task.notes != null &&
                        task.notes!.isNotEmpty)
                      pw.Text('Notes: ${task.notes}',
                          style: const pw.TextStyle(
                              fontSize: 10,
                              color:
                                  PdfColors.grey700)),
                  ],
                ),
              )),

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
        'FieldClock_${day.date.toIso8601String().substring(0, 10)}.pdf';
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles(
      [XFile(file.path)],
      subject:
          'Work Summary — ${TimeUtils.formatDate(day.date)}',
    );
  }

  /// Share a single task summary
  static Future<void> shareTask(
      {required Task task}) async {
    final buffer = StringBuffer();
    buffer.writeln('🔨 TASK SUMMARY');
    buffer.writeln('Task:     ${task.name}');
    if (task.division != null)
      buffer.writeln('Division: ${task.division}');
    buffer.writeln(
        'Start:    ${TimeUtils.formatTime(task.startTime)}');
    if (task.endTime != null)
      buffer.writeln(
          'End:      ${TimeUtils.formatTime(task.endTime!)}');
    buffer.writeln(
        'Duration: ${TimeUtils.formatDuration(task.durationRounded)}');
    if (task.startLocation != null)
      buffer.writeln('📍 ${task.startLocation}');
    if (task.notes != null && task.notes!.isNotEmpty)
      buffer.writeln('Notes: ${task.notes}');
    buffer.writeln('');
    buffer.writeln('Sent via FieldClock');

    final List<XFile> files = [];

    // Primary photos
    for (final path in
        [task.startPhoto, task.endPhoto]) {
      if (path != null && File(path).existsSync()) {
        files.add(XFile(path));
      }
    }

    // Additional task photos
    if (task.id != null) {
      final extras =
          await TaskPhotoDao().getByTask(task.id!);
      for (final photo in extras) {
        if (File(photo.photoPath).existsSync()) {
          files.add(XFile(photo.photoPath));
        }
      }
    }

    // Deduplicate
    final seen = <String>{};
    final unique = files
        .where((f) => seen.add(f.path))
        .toList();

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