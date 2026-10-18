import 'dart:js_interop';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:web/web.dart' as web;

/// Réplica de los reportes de Java:
///  - `ReporteController.ventaDiariaVentasPdf/Excel`
///  - `ModeloNegocioReporteController.reciboPdf`
///  - `imprimirRecibo()` (impresión del recibo)

const PdfColor _dark = PdfColor.fromInt(0xFF1E3A5F);
const PdfColor _darkText = PdfColor.fromInt(0xFF1E293B);
const PdfColor _alt = PdfColor.fromInt(0xFFF1F5F9);
const PdfColor _linea = PdfColor(0.78, 0.82, 0.86);
const PdfColor _green = PdfColor.fromInt(0xFF10B981);
const PdfColor _anulada = PdfColor.fromInt(0xFFFEE2E2);
const PdfColor _footerBg = PdfColor.fromInt(0xFFE2E8F0);

String fechaLarga(String fechaIso) {
  final p = fechaIso.split('-');
  if (p.length != 3) return fechaIso;
  return '${p[2]}/${p[1]}/${p[0]}';
}

String _dosDec(num v) => v.toStringAsFixed(2);

String _hora(String? hora) {
  final s = hora ?? '';
  final i = s.indexOf('T');
  final c = i >= 0 && s.length >= i + 6 ? s.substring(i + 1, i + 6) : s;
  return c.length >= 5 ? c.substring(0, 5) : c;
}

String _clienteSolo(Map<String, dynamic> v) {
  final c = v['cliente'];
  if (c is Map && '${c['nombre'] ?? ''}'.trim().isNotEmpty) {
    return '${c['nombre']}';
  }
  final alt = '${v['cliente_nombre'] ?? ''}'.trim();
  return alt.isEmpty ? 'N/A' : alt;
}

List<Map<String, dynamic>> _detalles(Map<String, dynamic> v) =>
    (v['detalles'] as List?)?.cast<Map<String, dynamic>>() ?? const [];

/// Exporta bytes en el navegador (reemplazo de dart:html).
void descargar(Uint8List bytes, String nombre, String mime) {
  final blob = web.Blob(<JSAny>[bytes.toJS].toJS, web.BlobPropertyBag(type: mime));
  final url = web.URL.createObjectURL(blob);
  final a = web.document.createElement('a') as web.HTMLAnchorElement;
  a.href = url;
  a.download = nombre;
  a.click();
  web.URL.revokeObjectURL(url);
}

// ---------------------------------------------------------------------------
// MODELO DE FILAS (compartido PDF/Excel)
// ---------------------------------------------------------------------------

class _ItemRow {
  final String codigo;
  final String detalle;
  final int cantidad;
  final double precio;
  const _ItemRow(this.codigo, this.detalle, this.cantidad, this.precio);
}

class _VentaRow {
  final int num;
  final String hora;
  final String cliente;
  final String codTramite;
  final String detTramite;
  final List<_ItemRow> items;
  final int cantVenta;
  final double totalVenta;
  final bool activa;
  const _VentaRow(
      {required this.num,
      required this.hora,
      required this.cliente,
      required this.codTramite,
      required this.detTramite,
      required this.items,
      required this.cantVenta,
      required this.totalVenta,
      required this.activa});
}

List<_VentaRow> _filasDe(List<Map<String, dynamic>> ventas) {
  final lista = [...ventas]
    ..sort((a, b) => ((a['id'] as num?) ?? 0).compareTo((b['id'] as num?) ?? 0));
  final out = <_VentaRow>[];
  var nVenta = 0;
  for (final v in lista) {
    nVenta++;
    final activa = v['estado'] != 'ANULADA';
    final d = _detalles(v);
    var cant = 0;
    for (final x in d) {
      cant += ((x['cantidad'] as num?) ?? 0).toInt();
    }
    final t = v['tramite'];
    out.add(_VentaRow(
      num: nVenta,
      hora: _hora(v['hora']),
      cliente: _clienteSolo(v),
      codTramite: (t is Map && '${t['codigo'] ?? ''}'.trim().isNotEmpty)
          ? '${t['codigo']}'
          : '-',
      detTramite: (t is Map && t['nombre'] != null) ? '${t['nombre']}' : '-',
      items: [
        for (final x in d)
          _ItemRow(
              '${x['item']?['codigo'] ?? ''}',
              '${x['item']?['descripcion'] ?? 'Item'}',
              ((x['cantidad'] as num?) ?? 0).toInt(),
              ((x['precio_unitario_congelado'] as num?) ?? 0).toDouble()),
      ],
      cantVenta: cant,
      totalVenta: ((v['total'] as num?) ?? 0).toDouble(),
      activa: activa,
    ));
  }
  return out;
}

class _Totales {
  int cant = 0;
  double pu = 0;
  double general = 0;
  int ventas = 0;
}

_Totales _totales(List<_VentaRow> filas) {
  final t = _Totales();
  for (final f in filas) {
    if (!f.activa) continue;
    t.general += f.totalVenta;
    t.ventas++;
    t.cant += f.cantVenta;
    for (final i in f.items) {
      t.pu += i.precio;
    }
  }
  return t;
}

// ---------------------------------------------------------------------------
// VENTA DIARIA - PDF (landscape letter, 11 columnas)
// ---------------------------------------------------------------------------

Future<void> exportarVentasDiariasPdf(
    List<Map<String, dynamic>> ventas, String fechaIso) async {
  final filas = _filasDe(ventas);
  final tot = _totales(filas);

  pw.Widget cell(String txt,
      {required PdfColor bg,
      bool right = false,
      bool center = false,
      bool bold = false,
      double fontSize = 7,
      PdfColor? fg,
      double pad = 3,
      double border = 0.5}) {
    return pw.Container(
      padding: pw.EdgeInsets.all(pad),
      decoration: pw.BoxDecoration(
          color: bg, border: pw.Border.all(color: _linea, width: border)),
      alignment: right
          ? pw.Alignment.centerRight
          : center
              ? pw.Alignment.center
              : pw.Alignment.centerLeft,
      child: pw.Text(txt,
          style: pw.TextStyle(
              fontSize: fontSize,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: fg ?? _darkText)),
    );
  }

  const anchos = <int, pw.TableColumnWidth>{
    0: pw.FlexColumnWidth(3),
    1: pw.FlexColumnWidth(5),
    2: pw.FlexColumnWidth(11),
    3: pw.FlexColumnWidth(6),
    4: pw.FlexColumnWidth(12),
    5: pw.FlexColumnWidth(5),
    6: pw.FlexColumnWidth(14),
    7: pw.FlexColumnWidth(4),
    8: pw.FlexColumnWidth(6),
    9: pw.FlexColumnWidth(4.5),
    10: pw.FlexColumnWidth(7.5),
  };

  final headers = [
    'N°',
    'HORA',
    'CLIENTE',
    'COD. TRAMITE',
    'DETALLE TRAMITE',
    'CODIGO',
    'DETALLE',
    'CANT',
    'P/U',
    'CANT T.',
    'TOTAL Bs'
  ];

  final rows = <List<pw.Widget>>[];

  rows.add([
    for (final h in headers)
      pw.Container(
          padding: const pw.EdgeInsets.all(5),
          decoration: pw.BoxDecoration(color: _dark),
          alignment: pw.Alignment.center,
          child: pw.Text(h,
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                  fontSize: 8,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.white)))
  ]);

  for (final f in filas) {
    final bg = !f.activa ? _anulada : (f.num % 2 == 0 ? _alt : PdfColors.white);
    final n = f.items.length;
    for (var i = 0; i < (n == 0 ? 1 : n); i++) {
      if (n == 0) {
        rows.add([
          cell('${f.num}', bg: bg, center: true),
          cell(f.hora, bg: bg),
          cell(f.cliente, bg: bg),
          cell(f.codTramite, bg: bg),
          cell(f.detTramite, bg: bg),
          cell('Sin items', bg: bg),
          cell('', bg: bg),
          cell('', bg: bg),
          cell('', bg: bg),
          cell('0', bg: bg, right: true),
          cell('0.00', bg: bg, right: true),
        ]);
        break;
      }
      final it = f.items[i];
      final identidad = i == 0;
      rows.add([
        identidad ? cell('${f.num}', bg: bg, center: true) : cell('', bg: bg),
        identidad ? cell(f.hora, bg: bg) : cell('', bg: bg),
        identidad ? cell(f.cliente, bg: bg) : cell('', bg: bg),
        identidad ? cell(f.codTramite, bg: bg) : cell('', bg: bg),
        identidad ? cell(f.detTramite, bg: bg) : cell('', bg: bg),
        cell(it.codigo, bg: bg, bold: true),
        cell(it.detalle, bg: bg),
        cell('${it.cantidad}', bg: bg, right: true),
        cell(_dosDec(it.precio), bg: bg, right: true),
        i == 0 ? cell('${f.cantVenta}', bg: bg, right: true) : cell('', bg: bg),
        i == 0
            ? cell(_dosDec(f.totalVenta), bg: bg, right: true)
            : cell('', bg: bg),
      ]);
    }
  }

  rows.add([
    for (var i = 0; i < 5; i++)
      cell('', bg: _footerBg, border: 0.5),
    cell('TOTAL DEL DIA (${tot.ventas} ventas):',
        bg: _footerBg, right: true, bold: true, fontSize: 8),
    cell('', bg: _footerBg),
    cell('${tot.cant}', bg: _footerBg, center: true, bold: true, fontSize: 8),
    cell(_dosDec(tot.pu), bg: _footerBg, right: true, bold: true, fontSize: 8),
    cell('${tot.cant}', bg: _footerBg, center: true, bold: true, fontSize: 8),
    cell('${_dosDec(tot.general)} Bs',
        bg: _footerBg, right: true, bold: true, fontSize: 8),
  ]);

  final doc = pw.Document();
  doc.addPage(pw.Page(
    pageFormat: const PdfPageFormat(792, 612,
        marginTop: 40, marginBottom: 30, marginLeft: 30, marginRight: 30),
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: const pw.BoxDecoration(color: _dark),
            child: pw.Column(children: [
              pw.Text('DIRECCION DEPARTAMENTAL DE EDUCACION DE PANDO',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white)),
              pw.SizedBox(height: 2),
              pw.Text('Unidad de Asuntos Administrativos',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.white)),
            ])),
        pw.SizedBox(height: 8),
        pw.Text('VENTA DE FORMULARIOS, VALORADOS Y TRAMITES',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: _darkText)),
        pw.SizedBox(height: 2),
        pw.Text('Detalle por Venta - ${fechaLarga(fechaIso)}',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
                fontSize: 9, fontStyle: pw.FontStyle.italic, color: _darkText)),
        pw.SizedBox(height: 8),
        pw.Table(columnWidths: anchos, children: [
          for (final r in rows) pw.TableRow(children: r),
        ]),
        pw.SizedBox(height: 16),
        pw.Table(
            defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
            columnWidths: const {
              0: pw.FlexColumnWidth(33),
              1: pw.FlexColumnWidth(34),
              2: pw.FlexColumnWidth(33),
            },
            children: [
              pw.TableRow(children: [
                for (final s in ['Elaborado por', 'Revisado por', 'VoBo'])
                  pw.Container(
                      alignment: pw.Alignment.center,
                      child: pw.Text('\n\n_________________________\n$s',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: _darkText))),
              ]),
            ]),
      ],
    ),
  ));
  final bytes = await doc.save();
  descargar(bytes, 'venta_diaria_detalles_$fechaIso.pdf', 'application/pdf');
}

// ---------------------------------------------------------------------------
// VENTA DIARIA - EXCEL
// ---------------------------------------------------------------------------

Future<void> exportarVentasDiariasXlsx(
    List<Map<String, dynamic>> ventas, String fechaIso) async {
  final filas = _filasDe(ventas);
  final tot = _totales(filas);

  final book = Excel.createExcel();
  final sheetName = 'Venta Diaria Detalle';
  final sheet = book[sheetName];
  for (final name in List<String>.from(book.sheets.keys)) {
    if (name != sheetName) book.delete(name);
  }

  final borde = Border(
      borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.black);
  final headerStyle = CellStyle(
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromInt(0xFF1E3A5F),
      bold: true,
      fontSize: 9,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      leftBorder: borde,
      rightBorder: borde,
      topBorder: borde,
      bottomBorder: borde);
  final dataStyle = CellStyle(
      verticalAlign: VerticalAlign.Center,
      leftBorder: borde,
      rightBorder: borde,
      topBorder: borde,
      bottomBorder: borde);
  final numStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      leftBorder: borde,
      rightBorder: borde,
      topBorder: borde,
      bottomBorder: borde);
  final rightStyle = CellStyle(
      horizontalAlign: HorizontalAlign.Right,
      verticalAlign: VerticalAlign.Center,
      leftBorder: borde,
      rightBorder: borde,
      topBorder: borde,
      bottomBorder: borde);
  final darkStyle = CellStyle(
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromInt(0xFF1E293B),
      bold: true,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      leftBorder: borde,
      rightBorder: borde,
      topBorder: borde,
      bottomBorder: borde);
  final titleStyle = CellStyle(
      bold: true, fontSize: 14, horizontalAlign: HorizontalAlign.Center);

  void put(int col, int row, CellValue? value, CellStyle style) {
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
      ..value = value
      ..cellStyle = style;
  }

  put(0, 0, TextCellValue(
      'DDEP - VENTA DE FORMULARIOS, VALORADOS Y TRAMITES - Detalle por Venta'),
      titleStyle);
  sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      CellIndex.indexByColumnRow(columnIndex: 10, rowIndex: 0));
  put(0, 1,
      TextCellValue('Fecha: ${fechaLarga(fechaIso)}'), CellStyle());

  const headers = [
    'N°',
    'HORA',
    'CLIENTE',
    'COD. TRAMITE',
    'DETALLE TRAMITE',
    'CODIGO',
    'DETALLE',
    'CANT',
    'P/U',
    'CANT T.',
    'TOTAL Bs'
  ];
  for (var i = 0; i < headers.length; i++) {
    put(i, 3, TextCellValue(headers[i]), headerStyle);
  }

  var row = 4;
  for (final f in filas) {
    final n = f.items.length;
    for (var i = 0; i < (n == 0 ? 1 : n); i++) {
      if (n == 0) {
        put(0, row, IntCellValue(f.num), numStyle);
        put(1, row, TextCellValue(f.hora), dataStyle);
        put(2, row, TextCellValue(f.cliente), dataStyle);
        put(3, row, TextCellValue(f.codTramite), dataStyle);
        put(4, row, TextCellValue(f.detTramite), dataStyle);
        put(5, row, null, dataStyle);
        put(6, row, TextCellValue('Sin items'), dataStyle);
        put(7, row, IntCellValue(0), numStyle);
        put(8, row, IntCellValue(0), rightStyle);
        put(9, row, IntCellValue(0), numStyle);
        put(10, row, IntCellValue(0), rightStyle);
        row++;
        break;
      }
      final it = f.items[i];
      final first = i == 0;
      put(0, row, first ? IntCellValue(f.num) : null, first ? numStyle : dataStyle);
      put(1, row, first ? TextCellValue(f.hora) : null, dataStyle);
      put(2, row, first ? TextCellValue(f.cliente) : null, dataStyle);
      put(3, row, first ? TextCellValue(f.codTramite) : null, dataStyle);
      put(4, row, first ? TextCellValue(f.detTramite) : null, dataStyle);
      put(5, row, TextCellValue(it.codigo), dataStyle);
      put(6, row, TextCellValue(it.detalle), dataStyle);
      put(7, row, IntCellValue(it.cantidad), numStyle);
      put(8, row, DoubleCellValue(it.precio), rightStyle);
      put(9, row, first ? IntCellValue(f.cantVenta) : null, numStyle);
      put(10, row, first ? DoubleCellValue(f.totalVenta) : null, rightStyle);
      row++;
    }
  }

  final totalRow = row + 1;
  for (var i = 0; i < 9; i++) {
    put(i, totalRow, null, darkStyle);
  }
  put(9, totalRow, TextCellValue('TOTAL (${tot.ventas} ventas):'), darkStyle);

  final valRow = row + 2;
  for (var i = 0; i < 7; i++) {
    put(i, valRow, null, darkStyle);
  }
  put(7, valRow, IntCellValue(tot.cant), darkStyle);
  put(8, valRow, DoubleCellValue(tot.pu), darkStyle);
  put(9, valRow, IntCellValue(tot.cant), darkStyle);
  put(10, valRow, DoubleCellValue(tot.general), darkStyle);

  for (var i = 0; i < headers.length; i++) {
    sheet.setColumnAutoFit(i);
  }

  final bytes = book.encode();
  if (bytes == null) return;
  descargar(Uint8List.fromList(bytes), 'venta_diaria_detalles_$fechaIso.xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
}

// ---------------------------------------------------------------------------
// RECIBO DE PAGO - PDF + impresion
// ---------------------------------------------------------------------------

Future<Uint8List> _reciboPdfBytes(
    Map<String, dynamic> venta, Map<String, dynamic> recibo) async {
  final doc = pw.Document();
  final numero = '${recibo['numero'] ?? '-'}';
  final anulado = '${recibo['estado'] ?? ''}' == 'ANULADO';
  final detalles = _detalles(venta);

  String? isoFechaEmision = recibo['fecha_emision']?.toString();
  String emitido = '';
  if (isoFechaEmision != null && isoFechaEmision.isNotEmpty) {
    final d = isoFechaEmision.split('T');
    var hora = '';
    if (d.length > 1) {
      hora = d[1].substring(0, d[1].length > 5 ? 5 : d[1].length);
    }
    emitido = '${fechaLarga(d[0])} $hora';
  }

  final emisor = recibo['emisor'];
  final emitidoPor = emisor is Map && '${emisor['nombre'] ?? ''}'.isNotEmpty
      ? '${emisor['nombre']}'
      : 'Usuario ${recibo['emisor_usuario_id'] ?? ''}';

  final tramite = venta['tramite'];
  final textoTramite = (tramite is Map && tramite['nombre'] != null)
      ? '${(tramite['codigo'] != null && '${tramite['codigo']}'.trim().isNotEmpty ? '${tramite['codigo']} - ' : '')}${tramite['nombre']}'
      : 'Venta manual';

  final cliente = venta['cliente'];
  final clienteTexto = cliente is Map
      ? '${cliente['nombre'] ?? 'CLIENTE'}${'${cliente['ci'] ?? ''}'.trim().isEmpty ? '' : '  (CI: ${cliente['ci']})'}'
      : 'CLIENTE';

  final fechaVenta = '${venta['fecha'] ?? ''}';
  final fechaVentaTxt = fechaVenta.isEmpty
      ? '-'
      : '${fechaLarga(fechaVenta)} ${_hora(venta['hora'])}';

  pw.Widget hCell(String t) => pw.Container(
      padding: const pw.EdgeInsets.all(4),
      decoration: const pw.BoxDecoration(color: _dark),
      alignment: pw.Alignment.center,
      child: pw.Text(t,
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.white)));

  pw.Widget dCell(String t, {required bool label}) => pw.Container(
      padding: const pw.EdgeInsets.all(3),
      decoration: pw.BoxDecoration(
          color: label ? _alt : PdfColors.white,
          border: pw.Border.all(color: _linea, width: 0.5)),
      child: pw.Text(t,
          style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: label ? pw.FontWeight.normal : pw.FontWeight.bold,
              color: _darkText)));

  num total = 0;
  for (final d in detalles) {
    total += ((d['subtotal'] as num?) ?? 0);
  }

  doc.addPage(pw.Page(
    pageFormat: const PdfPageFormat(612, 792,
        marginTop: 50, marginBottom: 40, marginLeft: 50, marginRight: 50),
    build: (ctx) => pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.stretch,
      children: [
        pw.Container(
            padding: const pw.EdgeInsets.all(10),
            decoration: const pw.BoxDecoration(color: _dark),
            child: pw.Column(children: [
              pw.Text('DIRECCION DEPARTAMENTAL DE EDUCACION DE PANDO',
                  textAlign: pw.TextAlign.center,
                  style: pw.TextStyle(
                      fontSize: 15,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white)),
              pw.SizedBox(height: 2),
              pw.Text('Unidad de Asuntos Administrativos',
                  textAlign: pw.TextAlign.center,
                  style: const pw.TextStyle(
                      fontSize: 9, color: PdfColors.white)),
            ])),
        pw.SizedBox(height: 8),
        pw.Text('RECIBO DE PAGO',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
                fontSize: 13,
                fontWeight: pw.FontWeight.bold,
                color: _darkText)),
        pw.SizedBox(height: 2),
        pw.Text(
            'N° $numero${emitido.isEmpty ? '' : '  |  Emitido: $emitido'}',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
                fontSize: 9, fontStyle: pw.FontStyle.italic, color: _darkText)),
        pw.SizedBox(height: 6),
        if (anulado) ...[
          pw.Text(
              'RECIBO ANULADO - ${recibo['motivo_anulacion'] ?? ''}',
              textAlign: pw.TextAlign.center,
              style: pw.TextStyle(
                  fontSize: 11,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.red)),
          pw.SizedBox(height: 6),
        ],
        pw.SizedBox(height: 6),
        pw.Table(
            columnWidths: const {
              0: pw.FlexColumnWidth(30),
              1: pw.FlexColumnWidth(70),
            },
            children: [
              pw.TableRow(children: [hCell('DATO'), hCell('DETALLE')]),
              pw.TableRow(children: [
                dCell('Venta N°', label: true),
                dCell('${venta['numero_recibo'] ?? venta['id']}', label: false),
              ]),
              pw.TableRow(children: [
                dCell('Fecha de venta', label: true),
                dCell(fechaVentaTxt, label: false),
              ]),
              pw.TableRow(children: [
                dCell('Cliente', label: true),
                dCell(clienteTexto, label: false),
              ]),
              pw.TableRow(children: [
                dCell('Tramite', label: true),
                dCell(textoTramite, label: false),
              ]),
              pw.TableRow(children: [
                dCell('Forma de pago', label: true),
                dCell('${venta['forma_pago'] ?? '-'}', label: false),
              ]),
              pw.TableRow(children: [
                dCell('Emitido por', label: true),
                dCell(emitidoPor, label: false),
              ]),
            ]),
        pw.SizedBox(height: 10),
        pw.Table(
            columnWidths: const {
              0: pw.FlexColumnWidth(14),
              1: pw.FlexColumnWidth(34),
              2: pw.FlexColumnWidth(18),
              3: pw.FlexColumnWidth(10),
              4: pw.FlexColumnWidth(12),
              5: pw.FlexColumnWidth(12),
            },
            children: [
              pw.TableRow(children: [
                hCell('CODIGO'),
                hCell('DETALLE'),
                hCell('SERIE'),
                hCell('CANT'),
                hCell('P/U'),
                hCell('SUBTOTAL'),
              ]),
              for (var i = 0; i < detalles.length; i++)
                pw.TableRow(children: [
                  _dCellRecibo('${detalles[i]['item']?['codigo'] ?? ''}',
                      bg: i.isEven ? _alt : PdfColors.white),
                  _dCellRecibo('${detalles[i]['item']?['descripcion'] ?? ''}',
                      bg: i.isEven ? _alt : PdfColors.white),
                  _dCellRecibo(
                      (detalles[i]['serie_del'] != null &&
                              detalles[i]['serie_al'] != null)
                          ? '${detalles[i]['serie_del']} al ${detalles[i]['serie_al']}'
                          : '-',
                      bg: i.isEven ? _alt : PdfColors.white,
                      center: true),
                  _dCellRecibo('${detalles[i]['cantidad'] ?? 0}',
                      bg: i.isEven ? _alt : PdfColors.white, right: true),
                  _dCellRecibo(_dosDec(detalles[i]['precio_unitario_congelado']),
                      bg: i.isEven ? _alt : PdfColors.white, right: true),
                  _dCellRecibo(_dosDec(detalles[i]['subtotal']),
                      bg: i.isEven ? _alt : PdfColors.white,
                      right: true,
                      bold: true),
                ]),
              pw.TableRow(children: [
                for (var i = 0; i < 5; i++)
                  pw.Container(
                      padding: const pw.EdgeInsets.all(6),
                      decoration: const pw.BoxDecoration(color: _green)),
                pw.Container(
                    padding: const pw.EdgeInsets.all(6),
                    decoration: const pw.BoxDecoration(color: _green),
                    alignment: pw.Alignment.centerRight,
                    child: pw.Text('TOTAL: Bs ${_dosDec(total)}',
                        textAlign: pw.TextAlign.right,
                        style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white))),
              ]),
            ]),
        pw.SizedBox(height: 10),
        pw.Text('Documento de control interno. No es un comprobante fiscal.',
            textAlign: pw.TextAlign.center,
            style: pw.TextStyle(
                fontSize: 7,
                fontStyle: pw.FontStyle.italic,
                color: PdfColors.grey)),
        pw.Spacer(),
        pw.Table(
            defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
            columnWidths: const {
              0: pw.FlexColumnWidth(50),
              1: pw.FlexColumnWidth(50),
            },
            children: [
              pw.TableRow(children: [
                for (final s in ['Responsable de Ventanilla', 'Visto Bueno'])
                  pw.Container(
                      alignment: pw.Alignment.center,
                      child: pw.Text('\n_________________________\n$s',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: _darkText))),
              ]),
            ]),
      ],
    ),
  ));
  return doc.save();
}

pw.Widget _dCellRecibo(String t,
    {required PdfColor bg,
    bool right = false,
    bool center = false,
    bool bold = false}) {
  return pw.Container(
      padding: const pw.EdgeInsets.all(3),
      decoration: pw.BoxDecoration(
          color: bg, border: pw.Border.all(color: _linea, width: 0.5)),
      alignment: right
          ? pw.Alignment.centerRight
          : center
              ? pw.Alignment.center
              : pw.Alignment.centerLeft,
      child: pw.Text(t,
          style: pw.TextStyle(
              fontSize: 7.5,
              fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: _darkText)));
}

/// `imprimirRecibo()` de Java (window.print) → diálogo de impresión.
Future<void> imprimirReciboPdf(
    Map<String, dynamic> venta, Map<String, dynamic> recibo) async {
  final bytes = await _reciboPdfBytes(venta, recibo);
  await Printing.layoutPdf(
      onLayout: (_) async => bytes,
      name: 'recibo_${recibo['numero'] ?? 'recibo'}.pdf');
}

/// `exportarReciboPDF()` de Java (/reportes/recibo/pdf/{id}).
Future<void> exportarReciboPdf(
    Map<String, dynamic> venta, Map<String, dynamic> recibo) async {
  final bytes = await _reciboPdfBytes(venta, recibo);
  descargar(bytes, 'recibo_${recibo['numero'] ?? 'recibo'}.pdf',
      'application/pdf');
}
