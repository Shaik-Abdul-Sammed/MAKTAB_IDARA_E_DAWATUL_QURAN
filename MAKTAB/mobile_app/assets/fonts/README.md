# Custom Fonts for Multi-Language PDF Generation

Place TTF/OTF fonts in this directory to support multilingual PDF generation offline:
- `Amiri-Regular.ttf` / `Amiri-Bold.ttf` (Arabic / Urdu)
- `NotoSansDevanagari-Regular.ttf` / `NotoSansDevanagari-Bold.ttf` (Hindi)
- `NotoSansTelugu-Regular.ttf` / `NotoSansTelugu-Bold.ttf` (Telugu)

If a font file is not found, the PDF generator gracefully falls back to `PdfGoogleFonts` (when online) or standard `pw.Font.helvetica()` so generation never crashes.
