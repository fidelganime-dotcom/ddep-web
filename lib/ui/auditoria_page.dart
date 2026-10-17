import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api.dart';
import 'tema.dart';

class AuditoriaPage extends StatefulWidget {
  const AuditoriaPage({super.key});
  @override
  State<AuditoriaPage> createState() => _AuditoriaPageState();
}

class _AuditoriaPageState extends State<AuditoriaPage> {
  List<Map<String, dynamic>> _logs = [];
  String _filtro = '';
  final _buscador = TextEditingController();
  DateTime? _desde;
  DateTime? _hasta;

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _buscador.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    _logs = await Api.raw('auditoria_log',
        columns: '*, usuario:usuario_sistema(nombre,usuario)', orderCol: 'id');
    if (mounted) setState(() {});
  }

  String _iso(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  String _fecha10(dynamic v) {
    final s = '${v ?? ''}';
    return s.length >= 10 ? s.substring(0, 10) : s;
  }

  void _buscar() {
    FocusScope.of(context).unfocus();
    setState(() {});
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(t,
            style: TextStyle(
                fontSize: 12.5,
                fontWeight: FontWeight.w600,
                color: T.texto2(context))),
      );

  Widget _campoFecha(String etiqueta, DateTime? valor,
      ValueChanged<DateTime> onSel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _label(etiqueta),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () async {
            final d = await showDatePicker(
                context: context,
                initialDate: valor ?? DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2100));
            if (d != null) onSel(d);
          },
          child: InputDecorator(
            decoration: InputDecoration(
              hintText: 'dd/mm/aaaa',
              suffixIcon: Icon(Icons.calendar_today,
                  size: 16, color: T.texto2(context)),
            ),
            child: Text(
                valor == null
                    ? ''
                    : '${valor.day.toString().padLeft(2, '0')}/${valor.month.toString().padLeft(2, '0')}/${valor.year}',
                style: TextStyle(fontSize: 13, color: T.texto(context))),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final f = DateFormat('dd/MM/yyyy HH:mm:ss');
    final filtrados = _logs.where((l) {
      final fh = _fecha10(l['fecha_hora']);
      if (_desde != null && fh.compareTo(_iso(_desde!)) < 0) return false;
      if (_hasta != null && fh.compareTo(_iso(_hasta!)) > 0) return false;
      if (_filtro.isEmpty) return true;
      final s =
          '${l['tabla_afectada']} ${l['accion']} ${l['usuario']?['nombre']} ${l['usuario']?['usuario']}'
              .toLowerCase();
      return s.contains(_filtro.toLowerCase());
    }).toList().reversed.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.verified_user, color: T.purple1, size: 26),
            const SizedBox(width: 10),
            Text('Auditoría',
                style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: T.texto(context))),
          ],
        ),
        const SizedBox(height: 4),
        Text('Registro de acciones del sistema',
            style: TextStyle(fontSize: 14, color: T.texto2(context))),
        const SizedBox(height: 16),
        SoftCard(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const CardHeaderSection(
                  icon: Icons.verified_user, titulo: 'Filtros de Búsqueda'),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                crossAxisAlignment: WrapCrossAlignment.end,
                children: [
                  SizedBox(
                    width: 200,
                    child: _campoFecha('Fecha Desde', _desde,
                        (d) => setState(() => _desde = d)),
                  ),
                  SizedBox(
                    width: 200,
                    child: _campoFecha('Fecha Hasta', _hasta,
                        (d) => setState(() => _hasta = d)),
                  ),
                  SizedBox(
                    width: 240,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _label('Usuario'),
                        TextField(
                          controller: _buscador,
                          decoration:
                              const InputDecoration(hintText: 'Nombre'),
                          onChanged: (v) => _filtro = v,
                        ),
                      ],
                    ),
                  ),
                  SizedBox(
                    width: 150,
                    child: BtnPrimario('Buscar',
                        icon: Icons.search, onPressed: _buscar),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              TablaModerna(
                anchoTotal: 820,
                columnas: const [
                  'Fecha/Hora',
                  'Usuario',
                  'Acción',
                  'Tabla',
                  'Detalle'
                ],
                filas: _logs.isEmpty
                    ? [
                        const DataRow(cells: [
                          DataCell(Text('Use los filtros para buscar')),
                          DataCell(Text('')),
                          DataCell(Text('')),
                          DataCell(Text('')),
                          DataCell(Text('')),
                        ]),
                      ]
                    : filtrados.isEmpty
                        ? [
                            const DataRow(cells: [
                              DataCell(Text('Sin registros')),
                              DataCell(Text('')),
                              DataCell(Text('')),
                              DataCell(Text('')),
                              DataCell(Text('')),
                            ]),
                          ]
                        : [
                            for (final l in filtrados.take(300))
                              DataRow(cells: [
                                DataCell(Text(l['fecha_hora'] != null
                                    ? f.format(DateTime.parse(l['fecha_hora']
                                        .toString()
                                        .replaceAll(' ', 'T')))
                                    : '—')),
                                DataCell(Text(
                                    '${l['usuario']?['nombre'] ?? l['usuario_id'] ?? 'sistema'}')),
                                DataCell(Text('${l['accion']}')),
                                DataCell(Text('${l['tabla_afectada']}')),
                                DataCell(Text('${l['registro_id'] ?? '—'}')),
                              ]),
                          ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
