import 'dart:io';
import 'package:csv/csv.dart';
import 'package:excel/excel.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import '../../domain/entities/activity_log_entry.dart';
import '../widgets/activity_log_helper.dart';
import '../../../business/domain/business.dart';

class ActivityLogExportService {
  static final _fmt = DateFormat('d MMM yyyy, hh:mm a');

  static Future<void> exportToPdf({
    required List<ActivityLogEntry> entries,
    Business? business,
  }) async {
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
    await Printing.sharePdf(
      bytes: bytes,
      filename: 'activity_log_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf',
    );
  }

  static Future<void> exportToCsv({
    required List<ActivityLogEntry> entries,
  }) async {
    final List<List<dynamic>> rows = [
      ['Timestamp', 'Action', 'User Name', 'User Role', 'Details'],
      ...entries.map((e) => [
            e.timestamp != null ? _fmt.format(e.timestamp!) : 'N/A',
            e.humanReadableAction,
            e.performedByName,
            e.performedByRole,
            _formatMetadata(e).replaceAll('\n', '; '),
          ]),
    ];

    final String csvData = const ListToCsvConverter().convert(rows);
    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/activity_log_${DateTime.now().millisecondsSinceEpoch}.csv';
    final file = File(path);
    await file.writeAsString(csvData);

    await Share.shareXFiles([XFile(path)], subject: 'Activity Log CSV');
  }

  static Future<void> exportToXlsx({
    required List<ActivityLogEntry> entries,
  }) async {
    final excel = Excel.createExcel();
    final Sheet sheet = excel[excel.getDefaultSheet()!];

    // Header
    sheet.appendRow([
      TextCellValue('Timestamp'),
      TextCellValue('Action'),
      TextCellValue('User Name'),
      TextCellValue('User Role'),
      TextCellValue('Details'),
    ]);

    // Data
    for (final e in entries) {
      sheet.appendRow([
        TextCellValue(e.timestamp != null ? _fmt.format(e.timestamp!) : 'N/A'),
        TextCellValue(e.humanReadableAction),
        TextCellValue(e.performedByName),
        TextCellValue(e.performedByRole),
        TextCellValue(_formatMetadata(e).replaceAll('\n', '; ')),
      ]);
    }

    final bytes = excel.encode();
    if (bytes == null) return;

    final directory = await getTemporaryDirectory();
    final path = '${directory.path}/activity_log_${DateTime.now().millisecondsSinceEpoch}.xlsx';
    final file = File(path);
    await file.writeAsBytes(bytes);

    await Share.shareXFiles([XFile(path)], subject: 'Activity Log XLSX');
  }

  static pw.Widget _headerCell(String text) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text, style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 9)),
    );
  }

  static pw.Widget _cell(String text, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.all(6),
      child: pw.Text(text,
          style: pw.TextStyle(
              fontSize: 8, fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
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
}
