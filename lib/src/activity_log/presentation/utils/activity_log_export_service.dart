import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import '../../domain/entities/activity_log_entry.dart';
import '../widgets/activity_log_helper.dart';
import '../../../business/domain/business.dart';

class ExportResult {
  final bool success;
  final String? path;
  final String message;

  ExportResult({
    required this.success,
    this.path,
    required this.message,
  });
}

class ActivityLogExportService {
  static final _fmt = DateFormat('d MMM yyyy, hh:mm a');
  static const _prefKey = 'last_export_directory';

  static Future<String?> _getSavedDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKey);
  }

  static Future<void> _saveDirectory(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, path);
  }

  static Future<ExportResult> _saveFile({
    required String fileName,
    required Uint8List bytes,
  }) async {
    try {
      final savedDirPath = await _getSavedDirectory();
      if (savedDirPath != null) {
        final dir = Directory(savedDirPath);
        if (await dir.exists()) {
          try {
            final file = File('${dir.path}/$fileName');
            await file.writeAsBytes(bytes);
            return ExportResult(
              success: true,
              path: file.path,
              message: 'Activity log exported successfully',
            );
          } catch (e) {
            debugPrint('Failed to write to saved directory: $e');
          }
        }
      }

      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Select export location',
        fileName: fileName,
        bytes: bytes,
      );

      if (outputFile != null) {
        final lastSeparator = outputFile.lastIndexOf(Platform.pathSeparator);
        if (lastSeparator != -1) {
          final dirPath = outputFile.substring(0, lastSeparator);
          await _saveDirectory(dirPath);
        }

        return ExportResult(
          success: true,
          path: outputFile,
          message: 'Activity log exported successfully',
        );
      }

      return ExportResult(
        success: false,
        message: 'Export cancelled',
      );
    } catch (e) {
      try {
        final baseDir = await getApplicationDocumentsDirectory();
        final file = File('${baseDir.path}/$fileName');
        await file.writeAsBytes(bytes);

        return ExportResult(
          success: true,
          path: file.path,
          message: 'Saved to App Documents directory.',
        );
      } catch (fallbackError) {
        return ExportResult(
          success: false,
          message: 'Failed to save: $e',
        );
      }
    }
  }

  static Future<ExportResult> exportToPdf({
    required List<ActivityLogEntry> entries,
    Business? business,
  }) async {
    if (entries.isEmpty) {
      return ExportResult(success: false, message: 'No logs to export');
    }

    final pdf = pw.Document();

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        header: (context) => pw.Column(
          children: [
            if (business != null) ...[
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(business.businessName.toUpperCase(),
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 16)),
                      if (business.address != null)
                        pw.Text(business.address!, style: const pw.TextStyle(fontSize: 8)),
                    ],
                  ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text('ACTIVITY LOG REPORT',
                          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 14)),
                      pw.Text(DateFormat('dd MMM yyyy').format(DateTime.now()),
                          style: const pw.TextStyle(fontSize: 10)),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 8),
              pw.Divider(thickness: 0.5),
              pw.SizedBox(height: 16),
            ],
          ],
        ),
        footer: (context) => pw.Align(
          alignment: pw.Alignment.centerRight,
          child: pw.Text('Page ${context.pageNumber} of ${context.pagesCount}',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey)),
        ),
        build: (context) => [
          pw.Table(
            columnWidths: {
              0: const pw.FlexColumnWidth(2),
              1: const pw.FlexColumnWidth(3),
              2: const pw.FlexColumnWidth(2),
              3: const pw.FlexColumnWidth(3),
            },
            border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
            children: [
              pw.TableRow(
                decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                children: [
                  _headerCell('Timestamp'),
                  _headerCell('Action'),
                  _headerCell('Performed By'),
                  _headerCell('Details/Metadata'),
                ],
              ),
              ...entries.map((e) => pw.TableRow(
                    children: [
                      _cell(e.timestamp != null ? _fmt.format(e.timestamp!) : 'N/A'),
                      _cell(e.humanReadableAction, isBold: true),
                      _cell('${e.performedByName}\n(${e.performedByRole})'),
                      _cell(_formatMetadata(e)),
                    ],
                  )),
            ],
          ),
        ],
      ),
    );

    final bytes = await pdf.save();
    final fileName = 'TSP_ActivityLog_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';

    return await _saveFile(fileName: fileName, bytes: bytes);
  }

  static pw.Widget _headerCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text,
          style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
    );
  }

  static pw.Widget _cell(String text, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 8,
              fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
    );
  }

  static String _formatMetadata(ActivityLogEntry entry) {
    final buffer = StringBuffer();
    if (entry.targetType != null) {
      buffer.writeln('Target: ${entry.targetType}');
      if (entry.targetName != null) buffer.writeln('Name: ${entry.targetName}');
    }
    if (entry.metadata.isNotEmpty) {
      entry.metadata.forEach((key, value) {
        buffer.writeln('$key: $value');
      });
    }
    return buffer.toString().trim();
  }

  static Future<void> openFile(String path) async {
    await OpenFilex.open(path);
  }
}
