import 'dart:convert';
import 'dart:typed_data';

/// نویسنده کوچک و بدون وابستگی فایل Excel (.xlsx) با شیت راست‌به‌چپ.
/// سبک‌ها: 0 معمولی ، 1 عنوان ، 2 سرستون ، 3 مبلغ ، 4 مقدار ، 5 جمع (متن) ، 6 جمع (مبلغ) ، 7 زیرعنوان
enum XStyle {
  normal,
  title,
  header,
  money,
  qty,
  totalText,
  totalMoney,
  subtitle,
}

class XCell {
  final String? text;
  final num? number;
  final XStyle style;
  const XCell.text(this.text, [this.style = XStyle.normal]) : number = null;
  const XCell.number(this.number, [this.style = XStyle.money]) : text = null;
  const XCell.empty([this.style = XStyle.normal]) : text = null, number = null;
}

class XSheet {
  final String name;
  final List<List<XCell>> rows;
  final List<double> columnWidths;
  final int freezeRows; // تعداد ردیف‌های بالای صفحه که ثابت می‌مانند
  const XSheet({
    required this.name,
    required this.rows,
    this.columnWidths = const [],
    this.freezeRows = 0,
  });
}

String _esc(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    if (r == 0x09 ||
        r == 0x0A ||
        r == 0x0D ||
        (r >= 0x20 && r <= 0xD7FF) ||
        (r >= 0xE000 && r <= 0xFFFD) ||
        r >= 0x10000) {
      switch (r) {
        case 0x26:
          b.write('&amp;');
        case 0x3C:
          b.write('&lt;');
        case 0x3E:
          b.write('&gt;');
        case 0x22:
          b.write('&quot;');
        default:
          b.writeCharCode(r);
      }
    }
  }
  return b.toString();
}

String colLetter(int index) {
  var n = index + 1;
  final s = StringBuffer();
  final chars = <String>[];
  while (n > 0) {
    final m = (n - 1) % 26;
    chars.add(String.fromCharCode(65 + m));
    n = (n - 1) ~/ 26;
  }
  for (final c in chars.reversed) {
    s.write(c);
  }
  return s.toString();
}

String _sheetName(String n) {
  final cleaned = n.replaceAll(RegExp(r'[\\/*?:\[\]]'), ' ').trim();
  return (cleaned.isEmpty ? 'Sheet1' : cleaned).substring(
    0,
    cleaned.length > 31 ? 31 : (cleaned.isEmpty ? 6 : cleaned.length),
  );
}

const _ns = 'http://schemas.openxmlformats.org/spreadsheetml/2006/main';

String _styles() =>
    '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<styleSheet xmlns="$_ns">
<numFmts count="1"><numFmt numFmtId="164" formatCode="#,##0.###"/></numFmts>
<fonts count="3">
<font><sz val="11"/><name val="Tahoma"/></font>
<font><b/><sz val="11"/><name val="Tahoma"/></font>
<font><b/><sz val="14"/><name val="Tahoma"/></font>
</fonts>
<fills count="3"><fill><patternFill patternType="none"/></fill><fill><patternFill patternType="gray125"/></fill>
<fill><patternFill patternType="solid"><fgColor rgb="FFE8ECF4"/><bgColor indexed="64"/></patternFill></fill></fills>
<borders count="2"><border><left/><right/><top/><bottom/><diagonal/></border>
<border><left style="thin"><color rgb="FFB0B7C3"/></left><right style="thin"><color rgb="FFB0B7C3"/></right><top style="thin"><color rgb="FFB0B7C3"/></top><bottom style="thin"><color rgb="FFB0B7C3"/></bottom><diagonal/></border></borders>
<cellStyleXfs count="1"><xf numFmtId="0" fontId="0" fillId="0" borderId="0"/></cellStyleXfs>
<cellXfs count="8">
<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
<xf numFmtId="0" fontId="2" fillId="0" borderId="0" xfId="0" applyFont="1"/>
<xf numFmtId="0" fontId="1" fillId="2" borderId="1" xfId="0" applyFont="1" applyFill="1" applyBorder="1" applyAlignment="1"><alignment horizontal="center" vertical="center" wrapText="1"/></xf>
<xf numFmtId="3" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>
<xf numFmtId="164" fontId="0" fillId="0" borderId="0" xfId="0" applyNumberFormat="1"/>
<xf numFmtId="0" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1"/>
<xf numFmtId="3" fontId="1" fillId="2" borderId="0" xfId="0" applyFont="1" applyFill="1" applyNumberFormat="1"/>
<xf numFmtId="0" fontId="0" fillId="0" borderId="0" xfId="0"/>
</cellXfs>
<cellStyles count="1"><cellStyle name="Normal" xfId="0" builtinId="0"/></cellStyles>
</styleSheet>''';

String _sheetXml(XSheet s) {
  final b = StringBuffer(
    '<?xml version="1.0" encoding="UTF-8" standalone="yes"?>\n<worksheet xmlns="$_ns">',
  );
  b.write('<sheetViews><sheetView rightToLeft="1" workbookViewId="0">');
  if (s.freezeRows > 0) {
    b.write(
      '<pane ySplit="${s.freezeRows}" topLeftCell="A${s.freezeRows + 1}" activePane="bottomRight" state="frozen"/>',
    );
  }
  b.write('</sheetView></sheetViews><sheetFormatPr defaultRowHeight="18"/>');
  if (s.columnWidths.isNotEmpty) {
    b.write('<cols>');
    for (var i = 0; i < s.columnWidths.length; i++) {
      b.write(
        '<col min="${i + 1}" max="${i + 1}" width="${s.columnWidths[i]}" customWidth="1"/>',
      );
    }
    b.write('</cols>');
  }
  b.write('<sheetData>');
  for (var r = 0; r < s.rows.length; r++) {
    b.write('<row r="${r + 1}">');
    for (var c = 0; c < s.rows[r].length; c++) {
      final cell = s.rows[r][c];
      final ref = '${colLetter(c)}${r + 1}';
      final st = cell.style.index; // ترتیب enum با cellXfs هم‌خوان است
      if (cell.number != null) {
        b.write('<c r="$ref" s="$st"><v>${cell.number}</v></c>');
      } else if (cell.text != null && cell.text!.isNotEmpty) {
        b.write(
          '<c r="$ref" s="$st" t="inlineStr"><is><t xml:space="preserve">${_esc(cell.text!)}</t></is></c>',
        );
      } else {
        b.write('<c r="$ref" s="$st"/>');
      }
    }
    b.write('</row>');
  }
  b.write('</sheetData><pageSetup orientation="landscape"/></worksheet>');
  return b.toString();
}

Uint8List buildXlsx(XSheet sheet) {
  final name = _sheetName(sheet.name);
  final files = <String, String>{
    '[Content_Types].xml':
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/><Default Extension="xml" ContentType="application/xml"/><Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/><Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/><Override PartName="/xl/styles.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.styles+xml"/></Types>''',
    '_rels/.rels': '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/></Relationships>''',
    'xl/workbook.xml':
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<workbook xmlns="$_ns" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><bookViews><workbookView/></bookViews><sheets><sheet name="${_esc(name)}" sheetId="1" r:id="rId1"/></sheets></workbook>''',
    'xl/_rels/workbook.xml.rels':
        '''<?xml version="1.0" encoding="UTF-8" standalone="yes"?>
<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/styles" Target="styles.xml"/></Relationships>''',
    'xl/styles.xml': _styles(),
    'xl/worksheets/sheet1.xml': _sheetXml(sheet),
  };
  return zipStore({
    for (final e in files.entries)
      e.key: Uint8List.fromList(utf8.encode(e.value)),
  });
}

// ---------- ZIP (بدون فشرده‌سازی، با CRC32) ----------
List<int>? _crcTable;
int crc32(List<int> data) {
  _crcTable ??= List<int>.generate(256, (n) {
    var c = n;
    for (var k = 0; k < 8; k++) {
      c = (c & 1) != 0 ? (0xEDB88320 ^ (c >> 1)) : (c >> 1);
    }
    return c;
  });
  var c = 0xFFFFFFFF;
  for (final b in data) {
    c = _crcTable![(c ^ b) & 0xFF] ^ (c >> 8);
  }
  return (c ^ 0xFFFFFFFF) & 0xFFFFFFFF;
}

Uint8List zipStore(Map<String, Uint8List> files) {
  final out = BytesBuilder(copy: false);
  final central = BytesBuilder(copy: false);
  final now = DateTime.now();
  final dosTime = (now.hour << 11) | (now.minute << 5) | (now.second ~/ 2);
  final dosDate =
      (((now.year - 1980).clamp(0, 127)) << 9) | (now.month << 5) | now.day;
  var offset = 0;

  void u16(BytesBuilder b, int v) => b.add([v & 0xFF, (v >> 8) & 0xFF]);
  void u32(BytesBuilder b, int v) =>
      b.add([v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF]);

  files.forEach((name, data) {
    final nameBytes = utf8.encode(name);
    final crc = crc32(data);
    // local header
    u32(out, 0x04034b50);
    u16(out, 20);
    u16(out, 0x0800); // UTF-8
    u16(out, 0);
    u16(out, dosTime);
    u16(out, dosDate);
    u32(out, crc);
    u32(out, data.length);
    u32(out, data.length);
    u16(out, nameBytes.length);
    u16(out, 0);
    out.add(nameBytes);
    out.add(data);
    // central directory
    u32(central, 0x02014b50);
    u16(central, 20);
    u16(central, 20);
    u16(central, 0x0800);
    u16(central, 0);
    u16(central, dosTime);
    u16(central, dosDate);
    u32(central, crc);
    u32(central, data.length);
    u32(central, data.length);
    u16(central, nameBytes.length);
    u16(central, 0);
    u16(central, 0);
    u16(central, 0);
    u16(central, 0);
    u32(central, 0);
    u32(central, offset);
    central.add(nameBytes);
    offset += 30 + nameBytes.length + data.length;
  });
  final cd = central.toBytes();
  out.add(cd);
  u32(out, 0x06054b50);
  u16(out, 0);
  u16(out, 0);
  u16(out, files.length);
  u16(out, files.length);
  u32(out, cd.length);
  u32(out, offset);
  u16(out, 0);
  return out.toBytes();
}
