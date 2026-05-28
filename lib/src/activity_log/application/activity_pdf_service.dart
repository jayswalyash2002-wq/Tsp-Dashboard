import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import '../domain/entities/activity_log_entry.dart';
import '../presentation/widgets/activity_log_helper.dart';

class ActivityPdfService {
  static Future<void> exportActivityLog(List<ActivityLogEntry> entries) async {
    final pdf = pw.Document();
    final dateFormat = DateFormat('dd MMM yyyy, hh:mm a');

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            pw.Header(
              level: 0,
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Business Activity Log',
                      style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold)),
                  pw.Text(DateFormat('dd/MM/yyyy').format(DateTime.now())),
                ],
              ),
            ),
            pw.SizedBox(height: 20),
            pw.TableHelper.fromTextArray(
              headers: ['Action', 'User', 'Time', 'Details'],
              data: entries.map((e) {
                return [
                  e.humanReadableAction,
                  e.performedByName,
                  e.timestamp != null
                      ? dateFormat.format(e.timestamp!)
                      : 'Unknown Time',
                  _formatMetadata(e.metadata),
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey300),
              cellHeight: 30,
              cellAlignments: {
                0: pw.Alignment.centerLeft,
                1: pw.Alignment.centerLeft,
                2: pw.Alignment.centerLeft,
                3: pw.Alignment.centerLeft,
              },
            ),
          ];
        },
      ),
    );

    await Printing.sharePdf(
      bytes: await pdf.save(),
      filename: 'activity_log_${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf',
    );
  }

  static String _formatMetadata(Map<String, dynamic> metadata) {
    if (metadata.isEmpty) return '-';
    return metadata.entries
        .where((e) => e.key != 'appVersion' && e.key != 'platform')
        .map((e) => '${e.key}: ${e.value}')
        .join(', ');
  }
}
