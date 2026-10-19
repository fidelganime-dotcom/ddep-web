import 'dart:js_interop';
import 'dart:typed_data';

import 'package:excel/excel.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:web/web.dart' as web;

import 'api.dart';

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

// ---------------------------------------------------------------------------
// RESUMEN KARDEX VALORADO - PDF + EXCEL
// Catalogos "PDF Items" / "Excel Items" abren en Java
// /reportes/resumen-kardex/pdf|excel?sucursalId=1&fechaHasta=hoy
// (ReporteService.generarResumenKardex, ReporteController.resumenKardex*)
// ---------------------------------------------------------------------------

class FilaKardexResumen {
  final int num;
  final String codigo;
  final String descripcion;
  final String unidad;
  final double pu;
  final int iniC;
  final double iniV;
  final int entC;
  final double entV;
  final int salC;
  final double salV;
  final int finC;
  final double finV;
  const FilaKardexResumen({
    required this.num,
    required this.codigo,
    required this.descripcion,
    required this.unidad,
    required this.pu,
    required this.iniC,
    required this.iniV,
    required this.entC,
    required this.entV,
    required this.salC,
    required this.salV,
    required this.finC,
    required this.finV,
  });
}

/// Réplica exacta de `ReporteService.generarResumenKardex(sucursalId, fechaHasta)`.
Future<List<FilaKardexResumen>> calcularResumenKardex(
    String fechaHastaIso) async {
  final items = await Api.raw('item_valorado',
      columns: 'id,codigo,descripcion,unidad_medida,precio_unitario_vigente',
      eqField: 'activo',
      eqVal: true,
      orderCol: 'id',
      asc: true);
  final movs = await Api.raw('movimiento_inventario',
      columns: '*', orderCol: 'id');
  final filtrados = movs.where((m) {
    final suc = ((m['sucursal_id'] as num?)?.toInt()) ?? 0;
    final f = '${m['fecha']}';
    return suc == 1 && f.compareTo(fechaHastaIso) <= 0;
  }).toList()
    ..sort((a, b) {
      final c = '${a['fecha']}'.compareTo('${b['fecha']}');
      if (c != 0) return c;
      return (((a['id'] as num?) ?? 0).toInt())
          .compareTo(((b['id'] as num?) ?? 0).toInt());
    });

  final out = <FilaKardexResumen>[];
  var n = 0;
  for (final it in items) {
    final iid = ((it['id'] as num?)?.toInt()) ?? -1;
    var iniC = 0, entC = 0, salC = 0;
    var iniV = 0.0, entV = 0.0, salV = 0.0;
    var firstEntry = true;
    for (final m in filtrados) {
      if ((((m['item_id'] as num?)?.toInt()) ?? -1) != iid) continue;
      final tipo = '${m['tipo']}';
      final cantE = ((m['cantidad_entradas'] as num?) ?? 0).toInt();
      final valE = ((m['valor_entradas'] as num?) ?? 0).toDouble();
      final cantS = ((m['cantidad_salidas'] as num?) ?? 0).toInt();
      final valS = ((m['valor_salidas'] as num?) ?? 0).toDouble();
      if (tipo == 'APERTURA' && firstEntry) {
        iniC = cantE > 0 ? cantE : (((m['saldo_cantidad'] as num?) ?? 0).toInt());
        iniV = valE > 0 ? valE : (((m['saldo_valor'] as num?) ?? 0).toDouble());
        firstEntry = false;
      } else if (tipo == 'ENTRADA' ||
          tipo == 'ENTRADA_INICIAL' ||
          tipo == 'ENTRADA_REPOSICION') {
        entC += cantE;
        entV += valE;
      } else {
        salC += cantS;
        salV += valS;
      }
    }
    n++;
    out.add(FilaKardexResumen(
      num: n,
      codigo: '${it['codigo'] ?? ''}',
      descripcion: '${it['descripcion'] ?? ''}',
      unidad: '${it['unidad_medida'] ?? ''}',
      pu: ((it['precio_unitario_vigente'] as num?) ?? 0).toDouble(),
      iniC: iniC,
      iniV: iniV,
      entC: entC,
      entV: entV,
      salC: salC,
      salV: salV,
      finC: iniC + entC - salC,
      finV: iniV + entV - salV,
    ));
  }
  return out;
}

Future<void> exportarResumenKardexPdf(
    List<FilaKardexResumen> filas, String fechaIso) async {
  final fmt = DateFormat("d 'de' MMMM 'de' yyyy", 'es_BO');
  final fecha = fmt.format(DateTime.parse(fechaIso));

  pw.Widget cell(String txt,
      {required PdfColor bg,
      bool right = false,
      bool center = false,
      double fontSize = 7}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(3),
      decoration: pw.BoxDecoration(
          color: bg, border: pw.Border.all(color: _linea, width: 0.5)),
      alignment: right
          ? pw.Alignment.centerRight
          : center
              ? pw.Alignment.center
              : pw.Alignment.centerLeft,
      child: pw.Text(txt,
          style: pw.TextStyle(fontSize: fontSize, color: _darkText)),
    );
  }

  const headers = [
    'N°',
    'Codigo',
    'Descripcion',
    'Unid.',
    'P/U',
    'Saldo Ini C',
    'Saldo Ini V',
    'Ent C',
    'Ent V',
    'Sal C',
    'Sal V',
    'Saldo Fin C',
    'Saldo Fin V',
  ];
  const anchos = <int, pw.TableColumnWidth>{
    0: pw.FlexColumnWidth(2.5),
    1: pw.FlexColumnWidth(6),
    2: pw.FlexColumnWidth(13),
    3: pw.FlexColumnWidth(4.5),
    4: pw.FlexColumnWidth(5.5),
    5: pw.FlexColumnWidth(5.5),
    6: pw.FlexColumnWidth(6),
    7: pw.FlexColumnWidth(4.5),
    8: pw.FlexColumnWidth(6),
    9: pw.FlexColumnWidth(4.5),
    10: pw.FlexColumnWidth(6),
    11: pw.FlexColumnWidth(6),
    12: pw.FlexColumnWidth(6.5),
  };

  final rows = <List<pw.Widget>>[
    [
      for (final h in headers)
        pw.Container(
            padding: const pw.EdgeInsets.all(5),
            decoration: const pw.BoxDecoration(color: _dark),
            alignment: pw.Alignment.center,
            child: pw.Text(h,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)))
    ],
  ];

  for (final f in filas) {
    final bg = f.num % 2 == 0 ? _alt : PdfColors.white;
    rows.add([
      cell('${f.num}', bg: bg, center: true),
      cell(f.codigo, bg: bg),
      cell(f.descripcion, bg: bg),
      cell(f.unidad, bg: bg, center: true),
      cell(_dosDec(f.pu), bg: bg, right: true),
      cell('${f.iniC}', bg: bg, right: true),
      cell(_dosDec(f.iniV), bg: bg, right: true),
      cell('${f.entC}', bg: bg, right: true),
      cell(_dosDec(f.entV), bg: bg, right: true),
      cell('${f.salC}', bg: bg, right: true),
      cell(_dosDec(f.salV), bg: bg, right: true),
      cell('${f.finC}', bg: bg, right: true),
      cell(_dosDec(f.finV), bg: bg, right: true),
    ]);
  }

  pw.Widget firma(String label) => pw.Container(
      alignment: pw.Alignment.center,
      child: pw.Text('\n\n_________________________\n$label',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: _darkText)));

  // Java reparte las filas en varias paginas (iText); aca hacemos lo mismo
  // porque una sola pw.Page deja de pintar al desbordar.
  double alturaFila(FilaKardexResumen f) {
    var lineas = (f.descripcion.length / 33).ceil();
    final lc = (f.codigo.length / 14).ceil();
    final lu = (f.unidad.length / 10).ceil();
    if (lc > lineas) lineas = lc;
    if (lu > lineas) lineas = lu;
    if (lineas < 1) lineas = 1;
    return 16 + 9 * (lineas - 1);
  }

  const altoContenido = 526.0; // 612 - margenSup 50 - margenInf 36
  const altoCabeceraTabla = 22.0;
  const altoFirmas = 75.0;
  const prePrimera = 123.0; // banner + titulos + fecha + linea
  const preSiguientes = 43.0; // titulo repetido + linea
  final altos = filas.map(alturaFila).toList();
  final tramos = <List<int>>[];
  var idx = 0;
  while (idx < filas.length) {
    final base = (tramos.isEmpty
            ? altoContenido - prePrimera
            : altoContenido - preSiguientes) -
        altoCabeceraTabla;
    var resto = 0.0;
    for (var k = idx; k < filas.length; k++) {
      resto += altos[k];
    }
    if (resto <= base - altoFirmas) {
      tramos.add([idx, filas.length]);
      break;
    }
    var j = idx, s = 0.0;
    while (j < filas.length && s + altos[j] <= base) {
      s += altos[j];
      j++;
    }
    if (j == idx) j = idx + 1;
    tramos.add([idx, j]);
    idx = j;
  }

  const formato = PdfPageFormat(792, 612,
      marginTop: 50, marginBottom: 36, marginLeft: 36, marginRight: 36);
  final doc = pw.Document();
  for (var p = 0; p < tramos.length; p++) {
    final a = tramos[p][0];
    final b = tramos[p][1];
    final esUltimo = p == tramos.length - 1;
    doc.addPage(pw.Page(
      pageFormat: formato,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          if (p == 0) ...[
            pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            pw.Text('REPORTE DE KARDEX POR ITEM - VALORADO',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: _darkText)),
            pw.SizedBox(height: 2),
            pw.Text('Al $fecha (Expresado en Bolivianos)',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                    fontSize: 9,
                    fontStyle: pw.FontStyle.italic,
                    color: _darkText)),
            pw.SizedBox(height: 4),
            pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text('Fecha de emision: $fecha',
                    style:
                        const pw.TextStyle(fontSize: 9, color: _darkText))),
            pw.SizedBox(height: 4),
            pw.Container(height: 2, color: _linea),
            pw.SizedBox(height: 10),
          ] else ...[
            pw.Text('REPORTE DE KARDEX POR ITEM - VALORADO',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: _darkText)),
            pw.SizedBox(height: 2),
            pw.Text('Al $fecha (Expresado en Bolivianos)',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                    fontSize: 8,
                    fontStyle: pw.FontStyle.italic,
                    color: _darkText)),
            pw.SizedBox(height: 4),
            pw.Container(height: 2, color: _linea),
            pw.SizedBox(height: 8),
          ],
          pw.Table(columnWidths: anchos, children: [
            pw.TableRow(children: rows[0]),
            for (var k = a; k < b; k++) pw.TableRow(children: rows[k + 1]),
          ]),
          if (esUltimo) ...[
            pw.SizedBox(height: 24),
            pw.Table(
                defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
                columnWidths: const {
                  0: pw.FlexColumnWidth(50),
                  1: pw.FlexColumnWidth(50),
                },
                children: [
                  pw.TableRow(children: [
                    firma('Resp. Ventanilla de Valores'),
                    firma('Visto Bueno'),
                  ]),
                ]),
          ],
        ],
      ),
    ));
  }
  final bytes = await doc.save();
  descargar(bytes, 'resumen_kardex.pdf', 'application/pdf');
}

Future<void> exportarResumenKardexXlsx(
    List<FilaKardexResumen> filas, String fechaIso) async {
  final book = Excel.createExcel();
  const sheetName = 'Resumen Kardex';
  final sheet = book[sheetName];
  for (final name in List<String>.from(book.sheets.keys)) {
    if (name != sheetName) book.delete(name);
  }

  final borde =
      Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.black);
  final headerStyle = CellStyle(
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromInt(0xFF1E3A5F),
      bold: true,
      fontSize: 10,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      leftBorder: borde,
      rightBorder: borde,
      topBorder: borde,
      bottomBorder: borde);
  CellStyle estiloData(bool alt, {HorizontalAlign align = HorizontalAlign.Left}) {
    return CellStyle(
        backgroundColorHex:
            alt ? ExcelColor.fromInt(0xFFF1F5F9) : ExcelColor.white,
        fontSize: 10,
        horizontalAlign: align,
        verticalAlign: VerticalAlign.Center,
        leftBorder: borde,
        rightBorder: borde,
        topBorder: borde,
        bottomBorder: borde);
  }

  void put(int col, int row, CellValue? value, CellStyle style) {
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
      ..value = value
      ..cellStyle = style;
  }

  put(
      0,
      0,
      TextCellValue('REPORTE DE KARDEX POR ITEM - VALORADO'),
      CellStyle(
          fontColorHex: ExcelColor.white,
          backgroundColorHex: ExcelColor.fromInt(0xFF1E3A5F),
          bold: true,
          fontSize: 14,
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
          leftBorder: borde,
          rightBorder: borde,
          topBorder: borde,
          bottomBorder: borde));
  sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: 0));
  put(
      0,
      1,
      TextCellValue('Al $fechaIso (Expresado en Bolivianos)'),
      CellStyle(
          fontColorHex: ExcelColor.white,
          backgroundColorHex: ExcelColor.fromInt(0xFF3B82F6),
          fontSize: 11,
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
          leftBorder: borde,
          rightBorder: borde,
          topBorder: borde,
          bottomBorder: borde));
  sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
      CellIndex.indexByColumnRow(columnIndex: 12, rowIndex: 1));

  const headers = [
    'N°',
    'Codigo',
    'Descripcion',
    'Unid.',
    'P/U',
    'Saldo Ini C',
    'Saldo Ini V',
    'Ent C',
    'Ent V',
    'Sal C',
    'Sal V',
    'Saldo Fin C',
    'Saldo Fin V',
  ];
  for (var i = 0; i < headers.length; i++) {
    put(i, 2, TextCellValue(headers[i]), headerStyle);
  }

  var row = 3;
  for (final f in filas) {
    // Java: alt = rowNum % 2 == 1 con datos desde la fila 3 (1a fila sombreada)
    final alt = f.num % 2 == 1;
    put(0, row, IntCellValue(f.num), estiloData(alt, align: HorizontalAlign.Center));
    put(1, row, TextCellValue(f.codigo), estiloData(alt));
    put(2, row, TextCellValue(f.descripcion), estiloData(alt));
    put(3, row, TextCellValue(f.unidad), estiloData(alt, align: HorizontalAlign.Center));
    put(4, row, DoubleCellValue(f.pu), estiloData(alt, align: HorizontalAlign.Right));
    put(5, row, IntCellValue(f.iniC), estiloData(alt, align: HorizontalAlign.Right));
    put(6, row, DoubleCellValue(f.iniV), estiloData(alt, align: HorizontalAlign.Right));
    put(7, row, IntCellValue(f.entC), estiloData(alt, align: HorizontalAlign.Right));
    put(8, row, DoubleCellValue(f.entV), estiloData(alt, align: HorizontalAlign.Right));
    put(9, row, IntCellValue(f.salC), estiloData(alt, align: HorizontalAlign.Right));
    put(10, row, DoubleCellValue(f.salV), estiloData(alt, align: HorizontalAlign.Right));
    put(11, row, IntCellValue(f.finC), estiloData(alt, align: HorizontalAlign.Right));
    put(12, row, DoubleCellValue(f.finV), estiloData(alt, align: HorizontalAlign.Right));
    row++;
  }

  for (var i = 0; i < headers.length; i++) {
    sheet.setColumnAutoFit(i);
  }

  final bytes = book.encode();
  if (bytes == null) return;
  descargar(Uint8List.fromList(bytes), 'resumen_kardex.xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
}

// ---------------------------------------------------------------------------
// KARDEX POR ITEM (Formulario 2) - PDF + EXCEL
// Java: ReporteService.generarKardexItem,
//       ReporteController.kardexPdf (L667) / kardexExcel (L737)
// ---------------------------------------------------------------------------

class FilaKardexItem {
  final int num;
  final String fecha; // dd/MM/yyyy
  final String descripcion;
  final String numeroDoc;
  final String unidad;
  final double pu;
  final int iniC;
  final double iniV;
  final int entC;
  final double entV;
  final int salC;
  final double salV;
  final int finC;
  final double finV;
  const FilaKardexItem({
    required this.num,
    required this.fecha,
    required this.descripcion,
    required this.numeroDoc,
    required this.unidad,
    required this.pu,
    required this.iniC,
    required this.iniV,
    required this.entC,
    required this.entV,
    required this.salC,
    required this.salV,
    required this.finC,
    required this.finV,
  });
}

/// Réplica de `ReporteService.generarKardexItem` (saldo corrido desde 0,
/// fecha asc / id asc, sucursal 1, fecha <= fechaHasta).
///
/// DESVIACION DEL BUG JAVA (unica, documentada en el reporte de pruebas):
/// la fila APERTURA tiene `cantidad_entradas = 0` en BD, y Java usa ese valor
/// crudo dejando el saldo del PDF/Excel en 0/negativo. Aqui se aplica el guard
/// de `ReporteService.generarResumenKardex` (`cant > 0 ? cant : saldo_cantidad`)
/// para que la exportacion sea coherente con la tabla de la pantalla.
List<FilaKardexItem> filasKardexItem(
    List<Map<String, dynamic>> movs, String fechaIso,
    {String unidad = ''}) {
  final filtrados = movs.where((m) {
    final suc = ((m['sucursal_id'] as num?)?.toInt()) ?? 0;
    return suc == 1 && '${m['fecha']}'.compareTo(fechaIso) <= 0;
  }).toList()
    ..sort((a, b) {
      final c = '${a['fecha']}'.compareTo('${b['fecha']}');
      if (c != 0) return c;
      return (((a['id'] as num?) ?? 0).toInt())
          .compareTo(((b['id'] as num?) ?? 0).toInt());
    });

  final out = <FilaKardexItem>[];
  var saldoC = 0;
  var saldoV = 0.0;
  var n = 0;
  for (final m in filtrados) {
    final tipo = '${m['tipo'] ?? ''}';
    final esEntrada = tipo == 'ENTRADA' ||
        tipo == 'APERTURA' ||
        tipo == 'ENTRADA_INICIAL' ||
        tipo == 'ENTRADA_REPOSICION';
    var entC = 0, entV = 0.0, salC = 0, salV = 0.0;
    String desc;
    if (esEntrada) {
      var c = ((m['cantidad_entradas'] as num?) ?? 0).toInt();
      var v = ((m['valor_entradas'] as num?) ?? 0).toDouble();
      if (tipo == 'APERTURA') {
        final sc = ((m['saldo_cantidad'] as num?) ?? 0).toInt();
        final sv = ((m['saldo_valor'] as num?) ?? 0).toDouble();
        if (c <= 0) c = sc;
        if (v <= 0) v = sv;
      }
      entC = c;
      entV = v;
      desc = tipo == 'APERTURA' ? 'SALDO ANTERIOR' : tipo;
    } else {
      salC = ((m['cantidad_salidas'] as num?) ?? 0).toInt();
      salV = ((m['valor_salidas'] as num?) ?? 0).toDouble();
      desc = tipo == 'VENTA' ? 'VENTAS - CAJA' : tipo;
    }
    final iniC = saldoC;
    final iniV = saldoV;
    saldoC += entC - salC;
    saldoV += entV - salV;
    final ref = m['referencia_venta_id'];
    final fec = '${m['fecha'] ?? ''}';
    out.add(FilaKardexItem(
      num: ++n,
      fecha: fec.length >= 10 ? fechaLarga(fec.substring(0, 10)) : fec,
      descripcion: desc,
      numeroDoc: (ref != null && '$ref'.isNotEmpty) ? 'VTA-$ref' : '',
      unidad: unidad.isNotEmpty
          ? unidad
          : '${m['unidad_medida'] ?? ''}',
      pu: ((m['precio_unitario'] as num?) ?? 0).toDouble(),
      iniC: iniC,
      iniV: iniV,
      entC: entC,
      entV: entV,
      salC: salC,
      salV: salV,
      finC: saldoC,
      finV: saldoV,
    ));
  }
  return out;
}

Future<void> exportarKardexItemPdf(Map<String, dynamic> item,
    List<FilaKardexItem> filas, String fechaIso) async {
  final fmt = DateFormat("d 'de' MMMM 'de' yyyy", 'es_BO');
  final alFecha = fmt.format(DateTime.parse(fechaIso));
  final hoy = fmt.format(DateTime.now());
  final desc = '${item['descripcion'] ?? ''}';
  final codigo = '${item['codigo'] ?? ''}';
  final itemId = ((item['id'] as num?)?.toInt()) ?? 0;
  final subtitulo =
      'ITEM: $desc | CODIGO: $codigo | Al $alFecha (Expresado en Bolivianos)';

  pw.Widget cell(String txt,
      {required PdfColor bg,
      bool right = false,
      bool center = false,
      double fontSize = 7}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(3),
      decoration: pw.BoxDecoration(
          color: bg, border: pw.Border.all(color: _linea, width: 0.5)),
      alignment: right
          ? pw.Alignment.centerRight
          : center
              ? pw.Alignment.center
              : pw.Alignment.centerLeft,
      child: pw.Text(txt,
          style: pw.TextStyle(fontSize: fontSize, color: _darkText)),
    );
  }

  const headers = [
    'N°',
    'Fecha',
    'Descripcion',
    'N°Doc',
    'Unid.',
    'P/U',
    'Saldo Ini C',
    'Saldo Ini V',
    'Ent C',
    'Ent V',
    'Sal C',
    'Sal V',
    'Saldo Fin C',
    'Saldo Fin V',
  ];
  // ReporteController.kardexPdf: new PdfPTable(14) + setWidths
  // Ancho disponible = 792 (letter horizontal) - 36 - 36 = 720 pt, repartido
  // en 14 columnas con la misma proporcion relativa que en Java/iText.
  const pesos = [4, 8, 10, 7, 5, 5, 7, 7, 7, 7, 7, 7, 7, 7];
  final total = pesos.fold<int>(0, (a, b) => a + b);
  const anchoDisponible = 720.0;
  final anchos = <int, pw.TableColumnWidth>{
    for (var i = 0; i < pesos.length; i++)
      i: pw.FixedColumnWidth(anchoDisponible * pesos[i] / total),
  };

  final rows = <List<pw.Widget>>[
    [
      for (final h in headers)
        pw.Container(
            padding: const pw.EdgeInsets.all(5),
            decoration: const pw.BoxDecoration(color: _dark),
            alignment: pw.Alignment.center,
            child: pw.Text(h,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                    fontSize: 7.5,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)))
    ],
  ];

  for (final f in filas) {
    final bg = f.num % 2 == 0 ? _alt : PdfColors.white;
    rows.add([
      cell('${f.num}', bg: bg),
      cell(f.fecha, bg: bg),
      cell(f.descripcion, bg: bg),
      cell(f.numeroDoc, bg: bg),
      cell(f.unidad, bg: bg),
      cell(_dosDec(f.pu), bg: bg, right: true),
      cell('${f.iniC}', bg: bg, right: true),
      cell(_dosDec(f.iniV), bg: bg, right: true),
      cell('${f.entC}', bg: bg, right: true),
      cell(_dosDec(f.entV), bg: bg, right: true),
      cell('${f.salC}', bg: bg, right: true),
      cell(_dosDec(f.salV), bg: bg, right: true),
      cell('${f.finC}', bg: bg, right: true),
      cell(_dosDec(f.finV), bg: bg, right: true),
    ]);
  }

  pw.Widget firma(String label) => pw.Container(
      alignment: pw.Alignment.center,
      child: pw.Text('\n\n_________________________\n$label',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: _darkText)));

  double alturaFila(FilaKardexItem f) {
    var lineas = (f.descripcion.length / 19).ceil();
    final lf = (f.fecha.length / 9).ceil();
    if (lf > lineas) lineas = lf;
    if (lineas < 1) lineas = 1;
    return 15 + 8 * (lineas - 1);
  }

  const altoContenido = 526.0; // 612 - margenSup 50 - margenInf 36
  const altoCabeceraTabla = 22.0;
  const altoFirmas = 75.0;
  const prePrimera = 137.0; // banner + titulo + subtitulo + fecha + linea
  const preSiguientes = 54.0; // titulo + subtitulo + linea
  const altoNota = 34.0;
  final altos = filas.map(alturaFila).toList();
  final tramos = <List<int>>[];
  var idx = 0;
  while (idx < filas.length) {
    final base = (tramos.isEmpty
            ? altoContenido - prePrimera
            : altoContenido - preSiguientes) -
        altoCabeceraTabla;
    var resto = 0.0;
    for (var k = idx; k < filas.length; k++) {
      resto += altos[k];
    }
    if (resto <= base - altoFirmas - altoNota) {
      tramos.add([idx, filas.length]);
      break;
    }
    var j = idx, s = 0.0;
    while (j < filas.length && s + altos[j] <= base) {
      s += altos[j];
      j++;
    }
    if (j == idx) j = idx + 1;
    tramos.add([idx, j]);
    idx = j;
  }

  const formato = PdfPageFormat(792, 612,
      marginTop: 50, marginBottom: 36, marginLeft: 36, marginRight: 36);
  final doc = pw.Document();
  for (var p = 0; p < tramos.length; p++) {
    final a = tramos[p][0];
    final b = tramos[p][1];
    final esUltimo = p == tramos.length - 1;
    doc.addPage(pw.Page(
      pageFormat: formato,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          if (p == 0) ...[
            pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            pw.Text('KARDEX POR ITEM',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: _darkText)),
            pw.SizedBox(height: 2),
            pw.Text(subtitulo,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                    fontSize: 9,
                    fontStyle: pw.FontStyle.italic,
                    color: _darkText)),
            pw.SizedBox(height: 4),
            pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text('Fecha de emision: $hoy',
                    style:
                        const pw.TextStyle(fontSize: 9, color: _darkText))),
            pw.SizedBox(height: 4),
            pw.Container(height: 2, color: _linea),
            pw.SizedBox(height: 10),
          ] else ...[
            pw.Text('KARDEX POR ITEM',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: _darkText)),
            pw.SizedBox(height: 2),
            pw.Text(subtitulo,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                    fontSize: 8,
                    fontStyle: pw.FontStyle.italic,
                    color: _darkText)),
            pw.SizedBox(height: 4),
            pw.Container(height: 2, color: _linea),
            pw.SizedBox(height: 8),
          ],
          pw.Table(columnWidths: anchos, children: [
            pw.TableRow(children: rows[0]),
            for (var k = a; k < b; k++) pw.TableRow(children: rows[k + 1]),
          ]),
          if (esUltimo) ...[
            pw.SizedBox(height: 8),
            pw.Text(
                'La informacion expuesta en el presente cuadro cuenta con la documentacion de soporte correspondiente, en el marco de las Normas Basicas del Sistema de Contabilidad Integrada.',
                style: const pw.TextStyle(fontSize: 7, color: _darkText)),
            pw.SizedBox(height: 16),
            pw.Table(
                defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
                columnWidths: const {
                  0: pw.FlexColumnWidth(50),
                  1: pw.FlexColumnWidth(50),
                },
                children: [
                  pw.TableRow(children: [
                    firma('Resp. Ventanilla de Valores'),
                    firma('Visto Bueno'),
                  ]),
                ]),
          ],
        ],
      ),
    ));
  }
  final bytes = await doc.save();
  descargar(bytes, 'kardex_$itemId.pdf', 'application/pdf');
}

Future<void> exportarKardexItemXlsx(Map<String, dynamic> item,
    List<FilaKardexItem> filas, String fechaIso) async {
  final book = Excel.createExcel();
  const sheetName = 'Kardex';
  final sheet = book[sheetName];
  for (final name in List<String>.from(book.sheets.keys)) {
    if (name != sheetName) book.delete(name);
  }

  final borde =
      Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.black);
  final headerStyle = CellStyle(
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromInt(0xFF1E3A5F),
      bold: true,
      fontSize: 10,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      leftBorder: borde,
      rightBorder: borde,
      topBorder: borde,
      bottomBorder: borde);
  CellStyle estiloData(bool alt, {HorizontalAlign align = HorizontalAlign.Left}) {
    return CellStyle(
        backgroundColorHex:
            alt ? ExcelColor.fromInt(0xFFF1F5F9) : ExcelColor.white,
        fontSize: 10,
        horizontalAlign: align,
        verticalAlign: VerticalAlign.Center,
        leftBorder: borde,
        rightBorder: borde,
        topBorder: borde,
        bottomBorder: borde);
  }

  void put(int col, int row, CellValue? value, CellStyle style) {
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
      ..value = value
      ..cellStyle = style;
  }

  final desc = '${item['descripcion'] ?? ''}';
  final codigo = '${item['codigo'] ?? ''}';
  final itemId = ((item['id'] as num?)?.toInt()) ?? 0;

  put(
      0,
      0,
      TextCellValue('KARDEX: $desc ($codigo)'),
      CellStyle(
          fontColorHex: ExcelColor.white,
          backgroundColorHex: ExcelColor.fromInt(0xFF1E3A5F),
          bold: true,
          fontSize: 14,
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
          leftBorder: borde,
          rightBorder: borde,
          topBorder: borde,
          bottomBorder: borde));
  sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: 0));
  put(
      0,
      1,
      TextCellValue('Al ${fechaLarga(fechaIso)} (Expresado en Bolivianos)'),
      CellStyle(
          fontColorHex: ExcelColor.white,
          backgroundColorHex: ExcelColor.fromInt(0xFF3B82F6),
          fontSize: 11,
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
          leftBorder: borde,
          rightBorder: borde,
          topBorder: borde,
          bottomBorder: borde));
  sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
      CellIndex.indexByColumnRow(columnIndex: 13, rowIndex: 1));

  const headers = [
    'N°',
    'Fecha',
    'Descripcion',
    'N°Doc',
    'Unid.',
    'P/U',
    'Saldo Ini C',
    'Saldo Ini V',
    'Ent C',
    'Ent V',
    'Sal C',
    'Sal V',
    'Saldo Fin C',
    'Saldo Fin V',
  ];
  for (var i = 0; i < headers.length; i++) {
    put(i, 2, TextCellValue(headers[i]), headerStyle);
  }

  var row = 3;
  for (final f in filas) {
    // Java kardexExcel: alt = rowNum % 2 == 1 con datos desde la fila 3
    final alt = f.num % 2 == 1;
    put(0, row, IntCellValue(f.num), estiloData(alt, align: HorizontalAlign.Center));
    put(1, row, TextCellValue(f.fecha), estiloData(alt));
    put(2, row, TextCellValue(f.descripcion), estiloData(alt));
    put(3, row, TextCellValue(f.numeroDoc), estiloData(alt));
    put(4, row, TextCellValue(f.unidad), estiloData(alt, align: HorizontalAlign.Center));
    put(5, row, DoubleCellValue(f.pu), estiloData(alt, align: HorizontalAlign.Right));
    put(6, row, IntCellValue(f.iniC), estiloData(alt, align: HorizontalAlign.Right));
    put(7, row, DoubleCellValue(f.iniV), estiloData(alt, align: HorizontalAlign.Right));
    put(8, row, IntCellValue(f.entC), estiloData(alt, align: HorizontalAlign.Right));
    put(9, row, DoubleCellValue(f.entV), estiloData(alt, align: HorizontalAlign.Right));
    put(10, row, IntCellValue(f.salC), estiloData(alt, align: HorizontalAlign.Right));
    put(11, row, DoubleCellValue(f.salV), estiloData(alt, align: HorizontalAlign.Right));
    put(12, row, IntCellValue(f.finC), estiloData(alt, align: HorizontalAlign.Right));
    put(13, row, DoubleCellValue(f.finV), estiloData(alt, align: HorizontalAlign.Right));
    row++;
  }

  for (var i = 0; i < headers.length; i++) {
    sheet.setColumnAutoFit(i);
  }

  final bytes = book.encode();
  if (bytes == null) return;
  descargar(Uint8List.fromList(bytes), 'kardex_$itemId.xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
}

// ---------------------------------------------------------------------------
// INVENTARIO MENSUAL / ARQUEO (Formulario 4) - PDF + EXCEL
// Java: ReporteService.generarInventarioMensual,
//       ReporteController.inventarioMensualPdf (L969) / inventarioMensualExcel (L1021)
// ---------------------------------------------------------------------------

class FilaInventarioMensual {
  final int num;
  final String codigo;
  final String detalle;
  final double pu;
  final int saldoInicial;
  final List<int> entradas; // 12 meses
  final int totalEntradas;
  final List<int> salidas; // 12 meses
  final int totalSalidas;
  final int saldoInventario;
  final int toma;
  final int diferencia;
  const FilaInventarioMensual({
    required this.num,
    required this.codigo,
    required this.detalle,
    required this.pu,
    required this.saldoInicial,
    required this.entradas,
    required this.totalEntradas,
    required this.salidas,
    required this.totalSalidas,
    required this.saldoInventario,
    required this.toma,
    required this.diferencia,
  });
}

/// Réplica de `ReporteService.generarInventarioMensual(sucursalId, anio, fechaToma)`
/// con `anio = año(fecha)` y `fechaToma = fecha` (parametros del JS de Java:
/// `exportarInventarioMensual('pdf'|'excel')` lee la fecha de corte actual).
Future<List<FilaInventarioMensual>> calcularInventarioMensual(
    String fechaIso) async {
  final anio = int.parse(fechaIso.substring(0, 4));
  final ini = '$anio-01-01';
  final fin = '$anio-12-31';

  final items = await Api.raw('item_valorado',
      columns: 'id,codigo,descripcion,precio_unitario_vigente',
      eqField: 'activo',
      eqVal: true,
      orderCol: 'id',
      asc: true);
  final movs = await Api.raw('movimiento_inventario',
      columns: '*', orderCol: 'id');
  final filtrados = movs.where((m) {
    final suc = ((m['sucursal_id'] as num?)?.toInt()) ?? 0;
    final f = '${m['fecha']}';
    return suc == 1 && f.compareTo(ini) >= 0 && f.compareTo(fin) <= 0;
  }).toList()
    ..sort((a, b) {
      final c = '${a['fecha']}'.compareTo('${b['fecha']}');
      if (c != 0) return c;
      return (((a['id'] as num?) ?? 0).toInt())
          .compareTo(((b['id'] as num?) ?? 0).toInt());
    });

  final tomas = await Api.raw('toma_inventario_fisico', columns: '*');
  final tomasPorItem = <int, Map<String, dynamic>>{};
  for (final t in tomas) {
    if ('${t['fecha']}' != fechaIso) continue;
    final iid = ((t['item_id'] as num?)?.toInt()) ?? -1;
    // findByItemIdAndFecha(...).get(0): primera por id
    final prev = tomasPorItem[iid];
    if (prev == null ||
        (((t['id'] as num?) ?? 0).toInt()) <
            (((prev['id'] as num?) ?? 0).toInt())) {
      tomasPorItem[iid] = t;
    }
  }

  final out = <FilaInventarioMensual>[];
  var n = 0;
  for (final it in items) {
    final iid = ((it['id'] as num?)?.toInt()) ?? -1;
    var saldoIni = 0;
    final entradas = List<int>.filled(12, 0);
    final salidas = List<int>.filled(12, 0);
    for (final m in filtrados) {
      if ((((m['item_id'] as num?)?.toInt()) ?? -1) != iid) continue;
      final mes = int.parse('${m['fecha']}'.substring(5, 7)) - 1;
      final tipo = '${m['tipo']}';
      if (tipo == 'APERTURA') {
        final cant = ((m['cantidad_entradas'] as num?) ?? 0).toInt();
        saldoIni = cant > 0
            ? cant
            : (((m['saldo_cantidad'] as num?) ?? 0).toInt());
      } else if (tipo == 'ENTRADA' ||
          tipo == 'ENTRADA_INICIAL' ||
          tipo == 'ENTRADA_REPOSICION') {
        entradas[mes] += ((m['cantidad_entradas'] as num?) ?? 0).toInt();
      } else {
        salidas[mes] += ((m['cantidad_salidas'] as num?) ?? 0).toInt();
      }
    }
    final totalE = entradas.fold<int>(0, (a, b) => a + b);
    final totalS = salidas.fold<int>(0, (a, b) => a + b);
    final saldoInv = saldoIni + totalE - totalS;
    final t = tomasPorItem[iid];
    final toma = t == null
        ? 0
        : (((t['cantidad_fisica'] as num?) ?? 0).toInt());
    n++;
    out.add(FilaInventarioMensual(
      num: n,
      codigo: '${it['codigo'] ?? ''}',
      detalle: '${it['descripcion'] ?? ''}',
      pu: ((it['precio_unitario_vigente'] as num?) ?? 0).toDouble(),
      saldoInicial: saldoIni,
      entradas: entradas,
      totalEntradas: totalE,
      salidas: salidas,
      totalSalidas: totalS,
      saldoInventario: saldoInv,
      toma: toma,
      diferencia: saldoInv - toma,
    ));
  }
  return out;
}

Future<void> exportarInventarioMensualPdf(
    List<FilaInventarioMensual> filas, String fechaIso) async {
  final anio = fechaIso.substring(0, 4);
  final fmt = DateFormat("d 'de' MMMM 'de' yyyy", 'es_BO');
  final hoy = fmt.format(DateTime.now());
  final tomaFecha = fechaLarga(fechaIso);

  pw.Widget cell(String txt,
      {required PdfColor bg,
      bool right = false,
      bool center = false,
      double fontSize = 7}) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(3),
      decoration: pw.BoxDecoration(
          color: bg, border: pw.Border.all(color: _linea, width: 0.5)),
      alignment: right
          ? pw.Alignment.centerRight
          : center
              ? pw.Alignment.center
              : pw.Alignment.centerLeft,
      child: pw.Text(txt,
          style: pw.TextStyle(fontSize: fontSize, color: _darkText)),
    );
  }

  // ReporteController.inventarioMensualPdf: 22 columnas, anchos iguales,
  // DEL/AL siempre vacios (serieDel/serieAl nunca se setean en Java).
  const headers = [
    'N°', 'CODIGO', 'DETALLE', 'DEL', 'AL', 'P/U', 'SALDO INI',
    'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'TOTAL E',
    'ENE', 'FEB', 'MAR', 'ABR', 'TOTAL S', 'SALDO INV',
  ];
  const anchos = <int, pw.TableColumnWidth>{
    0: pw.FlexColumnWidth(1),
    1: pw.FlexColumnWidth(1),
    2: pw.FlexColumnWidth(1),
    3: pw.FlexColumnWidth(1),
    4: pw.FlexColumnWidth(1),
    5: pw.FlexColumnWidth(1),
    6: pw.FlexColumnWidth(1),
    7: pw.FlexColumnWidth(1),
    8: pw.FlexColumnWidth(1),
    9: pw.FlexColumnWidth(1),
    10: pw.FlexColumnWidth(1),
    11: pw.FlexColumnWidth(1),
    12: pw.FlexColumnWidth(1),
    13: pw.FlexColumnWidth(1),
    14: pw.FlexColumnWidth(1),
    15: pw.FlexColumnWidth(1),
    16: pw.FlexColumnWidth(1),
    17: pw.FlexColumnWidth(1),
    18: pw.FlexColumnWidth(1),
    19: pw.FlexColumnWidth(1),
    20: pw.FlexColumnWidth(1),
    21: pw.FlexColumnWidth(1),
  };

  final rows = <List<pw.Widget>>[
    [
      for (final h in headers)
        pw.Container(
            padding: const pw.EdgeInsets.all(5),
            decoration: const pw.BoxDecoration(color: _dark),
            alignment: pw.Alignment.center,
            child: pw.Text(h,
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                    fontSize: 7,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.white)))
    ],
  ];

  for (final f in filas) {
    final bg = f.num % 2 == 0 ? _alt : PdfColors.white;
    rows.add([
      cell('${f.num}', bg: bg),
      cell(f.codigo, bg: bg),
      cell(f.detalle, bg: bg),
      cell('', bg: bg, right: true),
      cell('', bg: bg, right: true),
      cell(_dosDec(f.pu), bg: bg, right: true),
      cell('${f.saldoInicial}', bg: bg, right: true),
      for (var i = 0; i < 8; i++)
        cell('${f.entradas[i]}', bg: bg, right: true),
      cell('${f.totalEntradas}', bg: bg, right: true),
      for (var i = 0; i < 4; i++)
        cell('${f.salidas[i]}', bg: bg, right: true),
      cell('${f.totalSalidas}', bg: bg, right: true),
      cell('${f.saldoInventario}', bg: bg, right: true),
    ]);
  }

  pw.Widget firma(String label) => pw.Container(
      alignment: pw.Alignment.center,
      child: pw.Text('\n\n_________________________\n$label',
          textAlign: pw.TextAlign.center,
          style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: _darkText)));

  double alturaFila(FilaInventarioMensual f) {
    var lineas = (f.detalle.length / 11).ceil();
    final lc = (f.codigo.length / 11).ceil();
    if (lc > lineas) lineas = lc;
    if (lineas < 1) lineas = 1;
    return 15 + 8 * (lineas - 1);
  }

  const altoContenido = 548.0; // 612 - margenSup 40 - margenInf 24
  const altoCabeceraTabla = 22.0;
  const altoFirmas = 75.0;
  const prePrimera = 137.0;
  const preSiguientes = 54.0;
  final altos = filas.map(alturaFila).toList();
  final tramos = <List<int>>[];
  var idx = 0;
  while (idx < filas.length) {
    final base = (tramos.isEmpty
            ? altoContenido - prePrimera
            : altoContenido - preSiguientes) -
        altoCabeceraTabla;
    var resto = 0.0;
    for (var k = idx; k < filas.length; k++) {
      resto += altos[k];
    }
    if (resto <= base - altoFirmas) {
      tramos.add([idx, filas.length]);
      break;
    }
    var j = idx, s = 0.0;
    while (j < filas.length && s + altos[j] <= base) {
      s += altos[j];
      j++;
    }
    if (j == idx) j = idx + 1;
    tramos.add([idx, j]);
    idx = j;
  }

  const formato = PdfPageFormat(1008, 612,
      marginTop: 40, marginBottom: 24, marginLeft: 24, marginRight: 24);
  final doc = pw.Document();
  for (var p = 0; p < tramos.length; p++) {
    final a = tramos[p][0];
    final b = tramos[p][1];
    final esUltimo = p == tramos.length - 1;
    doc.addPage(pw.Page(
      pageFormat: formato,
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.stretch,
        children: [
          if (p == 0) ...[
            pw.Container(
                padding:
                    const pw.EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
            pw.Text('REPORTE DE ENTRADAS Y SALIDAS - INVENTARIO CAJA VALORES',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: _darkText)),
            pw.SizedBox(height: 2),
            pw.Text(
                'Gestion $anio | Toma de Inventario: $tomaFecha',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                    fontSize: 9,
                    fontStyle: pw.FontStyle.italic,
                    color: _darkText)),
            pw.SizedBox(height: 4),
            pw.Align(
                alignment: pw.Alignment.centerRight,
                child: pw.Text('Fecha de emision: $hoy',
                    style:
                        const pw.TextStyle(fontSize: 9, color: _darkText))),
            pw.SizedBox(height: 4),
            pw.Container(height: 2, color: _linea),
            pw.SizedBox(height: 10),
          ] else ...[
            pw.Text('REPORTE DE ENTRADAS Y SALIDAS - INVENTARIO CAJA VALORES',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                    fontSize: 11,
                    fontWeight: pw.FontWeight.bold,
                    color: _darkText)),
            pw.SizedBox(height: 2),
            pw.Text(
                'Gestion $anio | Toma de Inventario: $tomaFecha',
                textAlign: pw.TextAlign.center,
                style: pw.TextStyle(
                    fontSize: 8,
                    fontStyle: pw.FontStyle.italic,
                    color: _darkText)),
            pw.SizedBox(height: 4),
            pw.Container(height: 2, color: _linea),
            pw.SizedBox(height: 8),
          ],
          pw.Table(columnWidths: anchos, children: [
            pw.TableRow(children: rows[0]),
            for (var k = a; k < b; k++) pw.TableRow(children: rows[k + 1]),
          ]),
          if (esUltimo) ...[
            pw.SizedBox(height: 24),
            pw.Table(
                defaultVerticalAlignment: pw.TableCellVerticalAlignment.middle,
                columnWidths: const {
                  0: pw.FlexColumnWidth(50),
                  1: pw.FlexColumnWidth(50),
                },
                children: [
                  pw.TableRow(children: [
                    firma('Resp. Ventanilla de Valores'),
                    firma('Visto Bueno'),
                  ]),
                ]),
          ],
        ],
      ),
    ));
  }
  final bytes = await doc.save();
  descargar(bytes, 'inventario_mensual_$anio.pdf', 'application/pdf');
}

Future<void> exportarInventarioMensualXlsx(
    List<FilaInventarioMensual> filas, String fechaIso) async {
  final anio = fechaIso.substring(0, 4);
  final book = Excel.createExcel();
  const sheetName = 'Inventario Mensual';
  final sheet = book[sheetName];
  for (final name in List<String>.from(book.sheets.keys)) {
    if (name != sheetName) book.delete(name);
  }

  final borde =
      Border(borderStyle: BorderStyle.Thin, borderColorHex: ExcelColor.black);
  final headerStyle = CellStyle(
      fontColorHex: ExcelColor.white,
      backgroundColorHex: ExcelColor.fromInt(0xFF1E3A5F),
      bold: true,
      fontSize: 10,
      horizontalAlign: HorizontalAlign.Center,
      verticalAlign: VerticalAlign.Center,
      leftBorder: borde,
      rightBorder: borde,
      topBorder: borde,
      bottomBorder: borde);
  CellStyle estiloData(bool alt, {HorizontalAlign align = HorizontalAlign.Left}) {
    return CellStyle(
        backgroundColorHex:
            alt ? ExcelColor.fromInt(0xFFF1F5F9) : ExcelColor.white,
        fontSize: 10,
        horizontalAlign: align,
        verticalAlign: VerticalAlign.Center,
        leftBorder: borde,
        rightBorder: borde,
        topBorder: borde,
        bottomBorder: borde);
  }

  void put(int col, int row, CellValue? value, CellStyle style) {
    sheet.cell(CellIndex.indexByColumnRow(columnIndex: col, rowIndex: row))
      ..value = value
      ..cellStyle = style;
  }

  put(
      0,
      0,
      TextCellValue('REPORTE DE ENTRADAS Y SALIDAS - INVENTARIO CAJA VALORES'),
      CellStyle(
          fontColorHex: ExcelColor.white,
          backgroundColorHex: ExcelColor.fromInt(0xFF1E3A5F),
          bold: true,
          fontSize: 14,
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
          leftBorder: borde,
          rightBorder: borde,
          topBorder: borde,
          bottomBorder: borde));
  sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 0),
      CellIndex.indexByColumnRow(columnIndex: 21, rowIndex: 0));
  put(
      0,
      1,
      TextCellValue(
          'Gestion $anio | Toma de Inventario: ${fechaLarga(fechaIso)}'),
      CellStyle(
          fontColorHex: ExcelColor.white,
          backgroundColorHex: ExcelColor.fromInt(0xFF3B82F6),
          fontSize: 11,
          horizontalAlign: HorizontalAlign.Center,
          verticalAlign: VerticalAlign.Center,
          leftBorder: borde,
          rightBorder: borde,
          topBorder: borde,
          bottomBorder: borde));
  sheet.merge(CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: 1),
      CellIndex.indexByColumnRow(columnIndex: 21, rowIndex: 1));

  const headers = [
    'N°', 'CODIGO', 'DETALLE', 'P/U', 'SALDO INI',
    'ENE', 'FEB', 'MAR', 'ABR', 'MAY', 'JUN', 'JUL', 'AGO', 'TOTAL E',
    'ENE', 'FEB', 'MAR', 'ABR', 'TOTAL S', 'SALDO INV',
    'TOMA FISICA', 'DIFERENCIA',
  ];
  for (var i = 0; i < headers.length; i++) {
    put(i, 2, TextCellValue(headers[i]), headerStyle);
  }

  var row = 3;
  for (final f in filas) {
    // Java inventarioMensualExcel: alt = rowNum % 2 == 1 (fila 3 => true)
    final alt = f.num % 2 == 1;
    put(0, row, IntCellValue(f.num), estiloData(alt, align: HorizontalAlign.Center));
    put(1, row, TextCellValue(f.codigo), estiloData(alt));
    put(2, row, TextCellValue(f.detalle), estiloData(alt));
    put(3, row, DoubleCellValue(f.pu), estiloData(alt, align: HorizontalAlign.Right));
    put(4, row, IntCellValue(f.saldoInicial), estiloData(alt, align: HorizontalAlign.Right));
    for (var i = 0; i < 8; i++) {
      put(5 + i, row, IntCellValue(f.entradas[i]),
          estiloData(alt, align: HorizontalAlign.Right));
    }
    put(13, row, IntCellValue(f.totalEntradas),
        estiloData(alt, align: HorizontalAlign.Right));
    for (var i = 0; i < 4; i++) {
      put(14 + i, row, IntCellValue(f.salidas[i]),
          estiloData(alt, align: HorizontalAlign.Right));
    }
    put(18, row, IntCellValue(f.totalSalidas),
        estiloData(alt, align: HorizontalAlign.Right));
    put(19, row, IntCellValue(f.saldoInventario),
        estiloData(alt, align: HorizontalAlign.Right));
    put(20, row, IntCellValue(f.toma),
        estiloData(alt, align: HorizontalAlign.Right));
    put(21, row, IntCellValue(f.diferencia),
        estiloData(alt, align: HorizontalAlign.Right));
    row++;
  }

  for (var i = 0; i < headers.length; i++) {
    sheet.setColumnAutoFit(i);
  }

  final bytes = book.encode();
  if (bytes == null) return;
  descargar(Uint8List.fromList(bytes), 'inventario_mensual_$anio.xlsx',
      'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
}
