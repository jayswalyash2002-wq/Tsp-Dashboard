import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;

class MenuQrCard extends StatefulWidget {
  final String businessId;
  final String businessName;
  final String hostingUrl;

  const MenuQrCard({
    super.key,
    required this.businessId,
    required this.businessName,
    required this.hostingUrl,
  });

  @override
  State<MenuQrCard> createState() => _MenuQrCardState();
}

class _MenuQrCardState extends State<MenuQrCard> {
  final GlobalKey _qrBoundaryKey = GlobalKey();

  String _buildUrl({int? table}) {
    // Phase 2: Add table support here
    final baseUrl = '${widget.hostingUrl}/menu/business/${widget.businessId}';
    if (table != null) {
      return '$baseUrl?table=$table';
    }
    return baseUrl;
  }

  Future<void> _saveAsPng() async {
    try {
      final boundary = _qrBoundaryKey.currentContext?.findRenderObject() as RenderRepaintBoundary?;
      if (boundary == null) return;

      // Capture high resolution image
      final ui.Image image = await boundary.toImage(pixelRatio: 3.0);
      final ByteData? byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final Uint8List pngBytes = byteData!.buffer.asUint8List();

      if (kIsWeb) {
        // Trigger web download via printing package (works well for bytes)
        await Printing.sharePdf(
          bytes: pngBytes,
          filename: 'menu_qr_${widget.businessId}.png',
        );
      } else {
        final directory = await getTemporaryDirectory();
        final imagePath = '${directory.path}/menu_qr_${widget.businessId}.png';
        final imageFile = File(imagePath);
        await imageFile.writeAsBytes(pngBytes);

        await Share.shareXFiles(
          [XFile(imagePath)],
          text: 'Menu QR Code for ${widget.businessName}',
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving PNG: $e')),
        );
      }
    }
  }

  Future<void> _saveAsPdf() async {
    try {
      final doc = pw.Document();
      final url = _buildUrl();

      // Generate QR for PDF
      final qrPainter = QrPainter(
        data: url,
        version: QrVersions.auto,
        errorCorrectionLevel: QrErrorCorrectLevel.L,
      );
      final qrImage = await qrPainter.toImageData(1024);
      final qrImageWidget = pw.MemoryImage(qrImage!.buffer.asUint8List());

      doc.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          build: (pw.Context context) {
            return pw.Center(
              child: pw.Column(
                mainAxisAlignment: pw.MainAxisAlignment.center,
                children: [
                  pw.Text(
                    widget.businessName,
                    style: pw.TextStyle(
                      fontSize: 40,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.SizedBox(height: 20),
                  pw.Text(
                    'Scan to view our digital menu',
                    style: pw.TextStyle(fontSize: 20),
                  ),
                  pw.SizedBox(height: 40),
                  pw.Container(
                    width: 400,
                    height: 400,
                    child: pw.Image(qrImageWidget),
                  ),
                  pw.SizedBox(height: 40),
                  pw.Text(
                    url,
                    style: pw.TextStyle(
                      fontSize: 14,
                      color: PdfColors.grey700,
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      );

      await Printing.layoutPdf(
        onLayout: (PdfPageFormat format) async => doc.save(),
        name: 'Menu_QR_${widget.businessName}.pdf',
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error generating PDF: $e')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final url = _buildUrl();
    final cs = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          RepaintBoundary(
            key: _qrBoundaryKey,
            child: Container(
              color: Colors.white,
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.businessName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  QrImageView(
                    data: url,
                    version: QrVersions.auto,
                    size: 200.0,
                    backgroundColor: Colors.white,
                    eyeStyle: const QrEyeStyle(
                      eyeShape: QrEyeShape.square,
                      color: Colors.black,
                    ),
                    dataModuleStyle: const QrDataModuleStyle(
                      dataModuleShape: QrDataModuleShape.square,
                      color: Colors.black,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    url,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade700,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Divider(height: 1, color: cs.outlineVariant),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(
                  child: TextButton.icon(
                    onPressed: _saveAsPng,
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Save PNG'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextButton.icon(
                    onPressed: _saveAsPdf,
                    icon: const Icon(Icons.picture_as_pdf_outlined),
                    label: const Text('Save PDF'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
