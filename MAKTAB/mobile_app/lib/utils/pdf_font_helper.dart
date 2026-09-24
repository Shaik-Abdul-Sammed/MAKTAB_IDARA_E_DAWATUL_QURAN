import 'package:flutter/services.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class PdfFontHelper {
  /// Loads fonts appropriate for [languageCode], falling back gracefully to standard Helvetica.
  static Future<pw.ThemeData> getTheme({String languageCode = 'en'}) async {
    pw.Font? regular;
    pw.Font? bold;

    try {
      if (languageCode == 'ur') {
        // Try local asset first
        try {
          final fontData = await rootBundle.load('assets/fonts/Amiri-Regular.ttf');
          regular = pw.Font.ttf(fontData);
          final boldData = await rootBundle.load('assets/fonts/Amiri-Bold.ttf');
          bold = pw.Font.ttf(boldData);
        } catch (_) {
          try {
            regular = await PdfGoogleFonts.amiriRegular();
            bold = await PdfGoogleFonts.amiriBold();
          } catch (_) {}
        }
      } else if (languageCode == 'hi') {
        try {
          final fontData = await rootBundle.load('assets/fonts/NotoSansDevanagari-Regular.ttf');
          regular = pw.Font.ttf(fontData);
          final boldData = await rootBundle.load('assets/fonts/NotoSansDevanagari-Bold.ttf');
          bold = pw.Font.ttf(boldData);
        } catch (_) {
          try {
            regular = await PdfGoogleFonts.notoSansDevanagariRegular();
            bold = await PdfGoogleFonts.notoSansDevanagariBold();
          } catch (_) {}
        }
      } else if (languageCode == 'te') {
        try {
          final fontData = await rootBundle.load('assets/fonts/NotoSansTelugu-Regular.ttf');
          regular = pw.Font.ttf(fontData);
          final boldData = await rootBundle.load('assets/fonts/NotoSansTelugu-Bold.ttf');
          bold = pw.Font.ttf(boldData);
        } catch (_) {
          try {
            regular = await PdfGoogleFonts.notoSansTeluguRegular();
            bold = await PdfGoogleFonts.notoSansTeluguBold();
          } catch (_) {}
        }
      }
    } catch (_) {
      // Safe fallback
    }

    regular ??= pw.Font.helvetica();
    bold ??= pw.Font.helveticaBold();

    return pw.ThemeData.withFont(
      base: regular,
      bold: bold,
    );
  }
}
