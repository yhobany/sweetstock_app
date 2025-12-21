import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'pantalla_registro.dart';
import 'pantalla_inventario.dart' hide ServicioTemporal; // Evita conflictos
import 'pantalla_reportes.dart';
import 'pantalla_control_calidad.dart';
import 'servicio_temporal.dart';
import 'movimiento_modelo.dart';

class PantallaDashboard extends StatefulWidget {
  const PantallaDashboard({super.key});

  @override
  State<PantallaDashboard> createState() => _PantallaDashboardState();
}

class _PantallaDashboardState extends State<PantallaDashboard> {
  final _servicio = ServicioTemporal();
  double _valorBodega = 0;
  double _valorVencido = 0;
  double _ventasHoy = 0;
  List<Movimiento> _ultimosMovimientos = [];

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  void _cargarDatos() {
    final metricas = _servicio.obtenerMetricas();
    setState(() {
      _valorBodega = metricas['valorBodega']!;
      _valorVencido = metricas['valorVencido']!;
      _ventasHoy = metricas['ventasHoy']!;
      _ultimosMovimientos = _servicio.obtenerUltimosMovimientos();
    });
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Admin Dashboard"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.indigo,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _cargarDatos)
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _cardResumen("Valor Bodega (Activo)", currency.format(_valorBodega), Colors.indigo, width: 160),
                  const SizedBox(width: 10),
                  _cardResumen("Ventas Hoy", currency.format(_ventasHoy), Colors.blue, width: 160),
                  const SizedBox(width: 10),
                  _cardResumen("Stock Vencido (Merma)", currency.format(_valorVencido), Colors.red, width: 160),
                ],
              ),
            ),
            const SizedBox(height: 30),

            const Text("Acciones Rápidas", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 15,
              mainAxisSpacing: 15,
              childAspectRatio: 1.4,
              children: [
                _botonAccion(context, "Nuevo Ingreso", Icons.add_box_rounded, Colors.pink, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaRegistro())).then((_) => _cargarDatos())),
                _botonAccion(context, "Ver Inventario", Icons.list_alt_rounded, Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaInventario())).then((_) => _cargarDatos())),
                _botonAccion(context, "Control Calidad", Icons.health_and_safety, Colors.redAccent, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaControlCalidad())).then((_) => _cargarDatos())),

                // AQUÍ SEPARADOS Y DIFERENCIADOS
                _botonAccion(context, "Reportes", Icons.bar_chart_rounded, Colors.purple,
                        () => Navigator.push(context, MaterialPageRoute(
                        builder: (context) => const PantallaReportes(abrirCierreInmediato: false)
                    )).then((_) => _cargarDatos())
                ),

                // BOTÓN DE CIERRE (ABRE EN MODO CIERRE)
                _botonAccion(context, "Cierre Z", Icons.lock_clock, Colors.red,
                        () => Navigator.push(context, MaterialPageRoute(
                        builder: (context) => const PantallaReportes(abrirCierreInmediato: true)
                    )).then((_) => _cargarDatos())
                ),
              ],
            ),

            const SizedBox(height: 30),

            // LISTA... (Resto del código igual)
            const Text("Últimos Movimientos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
              child: _ultimosMovimientos.isEmpty
                  ? const Padding(padding: EdgeInsets.all(20), child: Center(child: Text("Sin movimientos", style: TextStyle(color: Colors.grey))))
                  : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _ultimosMovimientos.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final mov = _ultimosMovimientos[index];
                  Color colorBase = mov.tipo == 'venta' ? Colors.green : mov.tipo == 'gasto' ? Colors.red : Colors.blue;
                  IconData icono = mov.tipo == 'venta' ? Icons.shopping_bag : mov.tipo == 'gasto' ? Icons.trending_down : Icons.add_shopping_cart;

                  return ListTile(
                    leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: colorBase.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icono, color: colorBase, size: 20)),
                    title: Text(mov.nombreProducto, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                    subtitle: Text("${DateFormat('HH:mm').format(mov.fecha)} • ${mov.detalle ?? ''}", style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                    trailing: Text(currency.format(mov.total), style: TextStyle(fontWeight: FontWeight.bold, color: colorBase, fontSize: 14)),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _cardResumen(String titulo, String valor, Color color, {double width = 150}) {
    return Container(width: width, padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border(left: BorderSide(color: color, width: 4)), boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 5)]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(titulo, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)), const SizedBox(height: 5), Text(valor, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold))]));
  }

  Widget _botonAccion(BuildContext context, String titulo, IconData icono, Color color, VoidCallback onTap) {
    return InkWell(onTap: onTap, child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 5)]), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icono, color: color, size: 30)), const SizedBox(height: 10), Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))])));
  }
}