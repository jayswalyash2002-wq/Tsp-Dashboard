import 'dart:io';
import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/report_models.dart';
import '../../core/format/money.dart';
import '../../business/domain/business.dart';

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

class ReportExportService {
  static final _fmt = DateFormat('d MMM yyyy');
  static const _prefKey = 'last_export_directory';

  static Future<String?> _getSavedDirectory() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_prefKey);
  }

  static Future<void> _saveDirectory(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefKey, path);
  }

  /// Modern way to save a file using Storage Access Framework on Android.
  /// If [forcePicker] is true, it always shows the system dialog.
  /// If false, it tries to use the [rememberedDirectory].
  static Future<ExportResult> _saveReportFile({
    required String fileName,
    required Uint8List bytes,
    bool forcePicker = false,
  }) async {
    try {
      if (!forcePicker) {
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
                message: 'Report exported successfully',
              );
            } catch (e) {
              // If writing to saved directory fails (e.g. Scoped Storage restriction)
              // we proceed to the picker or fallback.
              print('Failed to write to saved directory: $e');
            }
          }
        }
      }

      // Use FilePicker.platform.saveFile for modern SAF behavior
      final String? outputFile = await FilePicker.platform.saveFile(
        dialogTitle: 'Select export location',
        fileName: fileName,
        bytes: bytes,
      );

      if (outputFile != null) {
        // Save the directory for future use
        final lastSeparator = outputFile.lastIndexOf(Platform.pathSeparator);
        if (lastSeparator != -1) {
          final dirPath = outputFile.substring(0, lastSeparator);
          await _saveDirectory(dirPath);
        }

        return ExportResult(
          success: true,
          path: outputFile,
          message: 'Report exported successfully',
        );
      }

      // If user cancelled, try fallback to App Documents as a safety measure
      // or just return cancelled status.
      return ExportResult(
        success: false,
        message: 'Export cancelled by user',
      );
    } catch (e) {
      // Fallback to application documents directory
      try {
        final baseDir = await getApplicationDocumentsDirectory();
        final tspDir = Directory('${baseDir.path}/TSP_Reports');
        if (!await tspDir.exists()) {
          await tspDir.create(recursive: true);
        }
        final file = File('${tspDir.path}/$fileName');
        await file.writeAsBytes(bytes);

        return ExportResult(
          success: true,
          path: file.path,
          message: 'Unable to save to selected folder. Saved to App Documents instead.',
        );
      } catch (fallbackError) {
        return ExportResult(
          success: false,
          message: 'Failed to save report: $e',
        );
      }
    }
  }

  static Future<ExportResult> exportToExcel({
    required String period,
    required DateTime start,
    required DateTime end,
    required SalesReportData data,
    Business? business,
    bool forcePicker = false,
  }) async {
    final excel = Excel.createExcel();
    final sheet = excel['Sheet1'];

    if (business != null) {
      sheet.appendRow([TextCellValue(business.businessName.toUpperCase())]);
      if (business.address != null) {
        sheet.appendRow([TextCellValue(business.address!)]);
      }
      if (business.isGstRegistered) {
        sheet.appendRow([TextCellValue('GSTIN: ${business.gstNumber}')]);
      }
      sheet.appendRow([TextCellValue('')]);
    }

    sheet.appendRow([TextCellValue('TSP ${period.toUpperCase()} SALES REPORT')]);
    sheet.appendRow([TextCellValue('Period: ${_fmt.format(start)} - ${_fmt.format(end)}')]);
    sheet.appendRow([TextCellValue('')]);

    sheet.appendRow([TextCellValue('Metric'), TextCellValue('Value')]);
    sheet.appendRow([TextCellValue('Total Sales'), TextCellValue('Rs. ${formatRupeesFromPaise(data.totalSalesPaise)}')]);
    sheet.appendRow([TextCellValue('Total Orders'), IntCellValue(data.totalOrders)]);
    sheet.appendRow([TextCellValue('Cash Sales'), TextCellValue('Rs. ${formatRupeesFromPaise(data.cashSalesPaise)}')]);
    sheet.appendRow([TextCellValue('Bank Sales'), TextCellValue('Rs. ${formatRupeesFromPaise(data.bankSalesPaise)}')]);
    sheet.appendRow([TextCellValue('Split Payments'), TextCellValue('Rs. ${formatRupeesFromPaise(data.splitSalesPaise)}')]);
    sheet.appendRow([TextCellValue('Discounts'), TextCellValue('Rs. ${formatRupeesFromPaise(data.totalDiscountsPaise)}')]);
    sheet.appendRow([TextCellValue('Pending Payments'), TextCellValue('Rs. ${formatRupeesFromPaise(data.pendingSalesPaise)}')]);
    sheet.appendRow([TextCellValue('')]);

    sheet.appendRow([TextCellValue('Top Selling Items')]);
    sheet.appendRow([TextCellValue('Item Name'), TextCellValue('Units Sold')]);
    for (final item in data.topSellingItems) {
      sheet.appendRow([TextCellValue(item.name), IntCellValue(item.qty)]);
    }

    final bytes = excel.encode();
    if (bytes == null) return ExportResult(success: false, message: 'Failed to generate Excel data');

    final fileName = 'TSP_${period.toLowerCase().capitalize()}_Report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.xlsx';
    
    return await _saveReportFile(
      fileName: fileName,
      bytes: Uint8List.fromList(bytes),
      forcePicker: forcePicker,
    );
  }

  static Future<ExportResult> exportToPdf({
    required String period,
    required DateTime start,
    required DateTime end,
    required SalesReportData data,
    Business? business,
    bool forcePicker = false,
  }) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (business != null) ...[
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(business.businessName,
                            style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 18)),
                        if (business.address != null)
                          pw.Text(business.address!, style: const pw.TextStyle(fontSize: 10)),
                        if (business.isGstRegistered)
                          pw.Padding(
                            padding: const pw.EdgeInsets.only(top: 4),
                            child: pw.Text('GSTIN: ${business.gstNumber}',
                                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)),
                          ),
                      ],
                    ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(business.officialEmail, style: const pw.TextStyle(fontSize: 10)),
                        pw.Text(business.phoneNumber, style: const pw.TextStyle(fontSize: 10)),
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 20),
                pw.Divider(),
              ],
              pw.Header(
                level: 0,
                child: pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('TSP ${period.toUpperCase()} REPORT',
                        style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 24)),
                    pw.Text(_fmt.format(DateTime.now())),
                  ],
                ),
              ),
              pw.SizedBox(height: 10),
              pw.Text('Period: ${_fmt.format(start)} to ${_fmt.format(end)}', style: pw.TextStyle(fontSize: 14)),
              pw.Divider(),
              pw.SizedBox(height: 20),

              pw.Text('Financial Summary', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              _pdfRow('Total Sales', 'Rs. ${formatRupeesFromPaise(data.totalSalesPaise)}', isBold: true),
              _pdfRow('Total Orders', '${data.totalOrders}'),
              _pdfRow('Cash Sales', 'Rs. ${formatRupeesFromPaise(data.cashSalesPaise)}'),
              _pdfRow('Bank Sales', 'Rs. ${formatRupeesFromPaise(data.bankSalesPaise)}'),
              _pdfRow('Split Payments', 'Rs. ${formatRupeesFromPaise(data.splitSalesPaise)}'),
              _pdfRow('Discounts', 'Rs. ${formatRupeesFromPaise(data.totalDiscountsPaise)}'),
              _pdfRow('Pending Payments', 'Rs. ${formatRupeesFromPaise(data.pendingSalesPaise)}'),

              pw.SizedBox(height: 30),
              pw.Text('Top Selling Items', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
              pw.SizedBox(height: 10),
              pw.Table(
                border: pw.TableBorder.all(),
                children: [
                  pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Item Name', style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('Units Sold', textAlign: pw.TextAlign.right, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
                    ],
                  ),
                  ...data.topSellingItems.map((item) => pw.TableRow(
                    children: [
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text(item.name)),
                      pw.Padding(padding: const pw.EdgeInsets.all(4), child: pw.Text('${item.qty}', textAlign: pw.TextAlign.right)),
                    ],
                  )),
                ],
              ),
              if (data.topSellingItems.isEmpty)
                pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('No sales data recorded.')),
              
              pw.Spacer(),
              pw.Divider(),
              pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text('Generated by TSP Dashboard', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey)),
              ),
            ],
          );
        },
      ),
    );

    final bytes = await pdf.save();
    final fileName = 'TSP_${period.toLowerCase().capitalize()}_Report_${DateFormat('yyyyMMdd_HHmmss').format(DateTime.now())}.pdf';

    return await _saveReportFile(
      fileName: fileName,
      bytes: bytes,
      forcePicker: forcePicker,
    );
  }

  static pw.Widget _pdfRow(String label, String value, {bool isBold = false}) {
    return pw.Padding(
      padding: const pw.EdgeInsets.symmetric(vertical: 2),
      child: pw.Row(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(label),
          pw.Text(value, style: pw.TextStyle(fontWeight: isBold ? pw.FontWeight.bold : pw.FontWeight.normal)),
        ],
      ),
    );
  }

  static Future<void> openFile(String path) async {
    await OpenFilex.open(path);
  }
}

extension StringExtension on String {
  String capitalize() {
    if (isEmpty) return this;
    return '${this[0].toUpperCase()}${substring(1)}';
  }
}
