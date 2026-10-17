import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/api.dart';

class AuditoriaPage extends StatefulWidget {
  const AuditoriaPage({super.key});
  @override
  State<AuditoriaPage> createState() => _AuditoriaPageState();
}

class _AuditoriaPageState extends State<AuditoriaPage> {
  List<Map<String, dynamic>> _logs = [];
  String _filtro = '';
  final _buscador = TextEditingController();

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    _logs = await Api.raw('auditoria_log',
        columns: '*, usuario:usuario_sistema(nombre,usuario)', orderCol: 'id');
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final f = DateFormat('dd/MM/yyyy HH:mm:ss');
    final filtrados = _logs.where((l) {
      if (_filtro.isEmpty) return true;
      final s =
          '${l['tabla_afectada']} ${l['accion']} ${l['usuario']?['nombre']} ${l['usuario']?['usuario']}'
              .toLowerCase();
      return s.contains(_filtro.toLowerCase());
    }).toList().reversed.toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              controller: _buscador,
              decoration: const InputDecoration(
                labelText: 'Buscar (tabla, acción, usuario)',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _filtro = v),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns: const [
                    DataColumn(label: Text('Fecha/Hora')),
                    DataColumn(label: Text('Usuario')),
                    DataColumn(label: Text('Acción')),
                    DataColumn(label: Text('Tabla')),
                    DataColumn(label: Text('Registro')),
                  ],
                  rows: [
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
              ),
            ),
          ],
        ),
      ),
    );
  }
}
