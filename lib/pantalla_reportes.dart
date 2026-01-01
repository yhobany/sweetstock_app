import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'movimiento_modelo.dart';
import 'servicio_firebase.dart';
import 'package:share_plus/share_plus.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';

class PantallaReportes extends StatefulWidget {
  final bool abrirCierreInmediato;
  const PantallaReportes({super.key, required this.abrirCierreInmediato});

  @override
  State<PantallaReportes> createState() => _PantallaReportesState();
}

class _PantallaReportesState extends State<PantallaReportes> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _servicio = ServicioFirebase();
  DateTimeRange? _rangoSeleccionado;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    if (widget.abrirCierreInmediato) {
      _tabController.animateTo(0); // Pestaña "Hoy"
    }
  }

  void _exportarCSV(String periodo) async {
    try {
      String csvData = await _servicio.generarReporteCSV(periodo, rango: _rangoSeleccionado);
      final directory = await getTemporaryDirectory();
      final file = File('${directory.path}/reporte_$periodo.csv');
      await file.writeAsString(csvData);
      await Share.shareXFiles([XFile(file.path)], text: 'Reporte SweetStock ($periodo)');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al exportar: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade100,
      appBar: AppBar(
        title: Text(
          widget.abrirCierreInmediato ? "Cierre de Caja (Z)" : "Reportes Financieros",
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFFE91E63),
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFFE91E63),
          labelStyle: const TextStyle(fontWeight: FontWeight.bold),
          unselectedLabelColor: Colors.grey,
          indicatorColor: const Color(0xFFE91E63),
          indicatorWeight: 3,
          tabs: const [Tab(text: "Hoy"), Tab(text: "Semana"), Tab(text: "Mes"), Tab(text: "Rango")],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _VistaReporte(servicio: _servicio, periodo: 'hoy'),
          _VistaReporte(servicio: _servicio, periodo: 'semana'),
          _VistaReporte(servicio: _servicio, periodo: 'mes'),
          _VistaReporte(servicio: _servicio, periodo: 'rango', onRangoSeleccionado: (r) => setState(() => _rangoSeleccionado = r)),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          String periodo = ['hoy', 'semana', 'mes', 'rango'][_tabController.index];
          _exportarCSV(periodo);
        },
        label: const Text("Exportar CSV", style: TextStyle(fontWeight: FontWeight.bold)),
        icon: const Icon(Icons.download),
        backgroundColor: const Color(0xFFE91E63),
      ),
    );
  }
}

class _VistaReporte extends StatefulWidget {
  final ServicioFirebase servicio;
  final String periodo;
  final Function(DateTimeRange)? onRangoSeleccionado;

  const _VistaReporte({required this.servicio, required this.periodo, this.onRangoSeleccionado});

  @override
  State<_VistaReporte> createState() => _VistaReporteState();
}

class _VistaReporteState extends State<_VistaReporte> {
  DateTimeRange? _rango;

  @override
  Widget build(BuildContext context) {
    if (widget.periodo == 'rango' && _rango == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.date_range, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: () async {
                final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2023),
                    lastDate: DateTime.now(),
                    builder: (context, child) {
                      return Theme(
                        data: Theme.of(context).copyWith(
                          colorScheme: const ColorScheme.light(primary: Color(0xFFE91E63), onPrimary: Colors.white),
                        ),
                        child: child!,
                      );
                    }
                );
                if (picked != null) {
                  setState(() => _rango = picked);
                  if (widget.onRangoSeleccionado != null) widget.onRangoSeleccionado!(picked);
                }
              },
              icon: const Icon(Icons.calendar_month),
              label: const Text("Seleccionar Fechas"),
              style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE91E63), foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
            ),
          ],
        ),
      );
    }

    return FutureBuilder<List<Movimiento>>(
      future: widget.servicio.obtenerReporte(widget.periodo, rangoPersonalizado: _rango),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)));
        final lista = snapshot.data!;

        if (lista.isEmpty) {
          return Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.inbox, size: 60, color: Colors.grey.shade300), const SizedBox(height: 10), Text("Sin movimientos", style: TextStyle(color: Colors.grey.shade500))]));
        }

        double totalVenta = 0;
        double totalCosto = 0;
        double totalGastoOperativo = 0;

        for (var m in lista) {
          if (m.tipo == 'venta') {
            totalVenta += m.total;
            totalCosto += m.costo;
          } else if (m.tipo == 'gasto') {
            totalGastoOperativo += m.total;
          }
          // Nota: m.tipo == 'entrada' NO se suma aquí porque es movimiento de Activo (Inventario), no de PyG.
        }

        double utilidadBruta = totalVenta - totalCosto;
        double utilidadNeta = utilidadBruta - totalGastoOperativo;

        return Column(
          children: [
            // --- ESTADO DE RESULTADOS ---
            Container(
              padding: const EdgeInsets.all(15),
              margin: const EdgeInsets.all(15),
              decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: [BoxShadow(color: Colors.grey.shade200, blurRadius: 10, offset: const Offset(0,5))]
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      _cardResumen("Ventas Totales", totalVenta, Colors.blue, Icons.attach_money),
                      Container(width: 1, height: 50, color: Colors.grey.shade200),
                      _cardResumen("Utilidad Bruta", utilidadBruta, Colors.green, Icons.monetization_on),
                    ],
                  ),
                  const Divider(height: 20),
                  Row(
                    children: [
                      _cardResumen("Gastos Operativos", totalGastoOperativo, Colors.orange, Icons.money_off),
                      Container(width: 1, height: 50, color: Colors.grey.shade200),
                      _cardResumen("Utilidad Neta", utilidadNeta, utilidadNeta >= 0 ? const Color(0xFFE91E63) : Colors.red, Icons.account_balance),
                    ],
                  ),
                ],
              ),
            ),

            // --- LISTA DE MOVIMIENTOS MEJORADA VISUALMENTE ---
            Expanded(
              child: ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
                itemCount: lista.length,
                itemBuilder: (context, index) {
                  final m = lista[index];

                  // --- LÓGICA VISUAL MEJORADA ---
                  bool esVenta = m.tipo == 'venta';
                  bool esEntrada = m.tipo == 'entrada'; // Nuevo caso
                  bool esGasto = m.tipo == 'gasto';

                  Color colorBase;
                  IconData icono;
                  String etiqueta;

                  if (esVenta) {
                    colorBase = Colors.green;
                    icono = Icons.shopping_bag;
                    etiqueta = m.nroVenta != null ? "#${m.nroVenta}" : "Venta";
                  } else if (esEntrada) {
                    colorBase = Colors.blue; // Azul para inventario (Activo)
                    icono = Icons.inventory_2;
                    etiqueta = "COMPRA";
                  } else {
                    colorBase = Colors.orange; // Naranja para gastos (Pérdida)
                    icono = Icons.trending_down;
                    etiqueta = "GASTO";
                  }

                  return Container(
                    margin: const EdgeInsets.only(bottom: 10),
                    decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border(left: BorderSide(color: colorBase, width: 4)),
                        boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 4, offset: const Offset(0,2))]
                    ),
                    child: ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      leading: Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                            color: colorBase.withOpacity(0.1),
                            shape: BoxShape.circle
                        ),
                        child: Text(etiqueta, style: TextStyle(color: colorBase, fontWeight: FontWeight.bold, fontSize: 10)),
                      ),
                      title: Text(m.nombreProducto, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 4),
                          Text(DateFormat('hh:mm a').format(m.fecha), style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                          if(m.detalle != null) Text(m.detalle!, style: TextStyle(color: Colors.grey.shade400, fontSize: 11))
                        ],
                      ),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(
                            "\$${NumberFormat.currency(locale: 'es_CO', symbol: '', decimalDigits: 0).format(m.total)}",
                            style: TextStyle(color: colorBase, fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                          if (esVenta && m.costo > 0)
                            Text(
                              "Ganancia: \$${(m.total - m.costo).toStringAsFixed(0)}",
                              style: TextStyle(fontSize: 10, color: Colors.green.shade300),
                            )
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _cardResumen(String label, double valor, Color color, IconData icon) {
    return Expanded(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Text(label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 4),
          Text(
              NumberFormat.compact().format(valor),
              style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)
          )
        ],
      ),
    );
  }
}