import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'pantalla_registro.dart';
import 'pantalla_inventario.dart';
import 'pantalla_reportes.dart';
import 'pantalla_control_calidad.dart';
import 'servicio_firebase.dart';
import 'movimiento_modelo.dart';
import 'pantalla_gestion_usuarios.dart';

class PantallaDashboard extends StatefulWidget {
  const PantallaDashboard({super.key});

  @override
  State<PantallaDashboard> createState() => _PantallaDashboardState();
}

class _PantallaDashboardState extends State<PantallaDashboard> {
  final _servicio = ServicioFirebase();
  double _valorBodega = 0;
  double _valorVencido = 0;
  double _ventasHoy = 0;
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarDatosNube();
  }

  void _cargarDatosNube() async {
    setState(() { _cargando = true; _error = null; });
    try {
      final metricas = await _servicio.obtenerMetricas();
      if (mounted) {
        setState(() {
          _valorBodega = metricas['valorBodega']!;
          _valorVencido = metricas['valorVencido']!;
          _ventasHoy = metricas['ventasHoy']!;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() { _cargando = false; _error = "Error de conexión: $e"; });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(title: const Text("Admin Dashboard (Nube)"), backgroundColor: Colors.white, foregroundColor: Colors.indigo, elevation: 0, actions: [IconButton(icon: const Icon(Icons.refresh), onPressed: _cargarDatosNube)]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_error != null) Container(padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 20), color: Colors.red.shade100, child: Row(children: [const Icon(Icons.error, color: Colors.red), const SizedBox(width: 10), Expanded(child: Text(_error!))])),
            if (_cargando) const Center(child: LinearProgressIndicator())
            else SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [_cardResumen("Valor Bodega", currency.format(_valorBodega), Colors.indigo, width: 160), const SizedBox(width: 10), _cardResumen("Ventas Hoy", currency.format(_ventasHoy), Colors.blue, width: 160), const SizedBox(width: 10), _cardResumen("Stock Vencido", currency.format(_valorVencido), Colors.red, width: 160)])),
            const SizedBox(height: 30),
            const Text("Acciones Rápidas", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 15),
            GridView.count(
              shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), crossAxisCount: 2, crossAxisSpacing: 15, mainAxisSpacing: 15, childAspectRatio: 1.4,
              children: [
                _botonAccion(context, "Nuevo Ingreso", Icons.add_box_rounded, Colors.pink, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaRegistro())).then((_) => _cargarDatosNube())),
                _botonAccion(context, "Ver Inventario", Icons.list_alt_rounded, Colors.orange, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaInventario())).then((_) => _cargarDatosNube())),
                _botonAccion(context, "Control Calidad", Icons.health_and_safety, Colors.redAccent, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaControlCalidad())).then((_) => _cargarDatosNube())),
                _botonAccion(context, "Reportes", Icons.bar_chart_rounded, Colors.purple, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaReportes(abrirCierreInmediato: false))).then((_) => _cargarDatosNube())),
                _botonAccion(context, "Cierre Z", Icons.lock_clock, Colors.red, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaReportes(abrirCierreInmediato: true))).then((_) => _cargarDatosNube())),
                _botonAccion(context, "Equipo y Roles", Icons.people_alt_rounded, Colors.teal, () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaGestionUsuarios()))),
              ],
            ),
            const SizedBox(height: 30),
            const Text("Últimos Movimientos", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
              child: StreamBuilder<List<Movimiento>>(
                stream: _servicio.obtenerUltimosMovimientosStream(),
                builder: (context, snapshot) {
                  if (snapshot.hasError) return Padding(padding: const EdgeInsets.all(20), child: Text("Error: ${snapshot.error}"));
                  if (!snapshot.hasData) return const Padding(padding: EdgeInsets.all(20), child: Center(child: CircularProgressIndicator()));
                  final movs = snapshot.data!;
                  if (movs.isEmpty) return const Padding(padding: EdgeInsets.all(20), child: Center(child: Text("Sin actividad reciente")));

                  return ListView.separated(
                    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(), itemCount: movs.length, separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final mov = movs[index];
                      Color colorBase = mov.tipo == 'venta' ? Colors.green : mov.tipo == 'gasto' ? Colors.red : Colors.blue;
                      IconData icono = mov.tipo == 'venta' ? Icons.shopping_bag : mov.tipo == 'gasto' ? Icons.trending_down : Icons.add_shopping_cart;

                      // AQUÍ SE MUESTRA EL NÚMERO
                      String titulo = mov.tipo == 'venta' && mov.nroVenta != null
                          ? "Venta #${mov.nroVenta} - ${mov.nombreProducto}"
                          : mov.nombreProducto;

                      return ListTile(
                        leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: colorBase.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(icono, color: colorBase, size: 20)),
                        title: Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Text("${DateFormat('HH:mm').format(mov.fecha)} • ${mov.detalle ?? ''}", style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
                        trailing: Text(currency.format(mov.total), style: TextStyle(fontWeight: FontWeight.bold, color: colorBase, fontSize: 14)),
                      );
                    },
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
  Widget _cardResumen(String titulo, String valor, Color color, {double width = 150}) { return Container(width: width, padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border(left: BorderSide(color: color, width: 4)), boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 5)]), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(titulo, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)), const SizedBox(height: 5), Text(valor, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold))])); }
  Widget _botonAccion(BuildContext context, String titulo, IconData icono, Color color, VoidCallback onTap) { return InkWell(onTap: onTap, child: Container(decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 5)]), child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: color.withOpacity(0.1), shape: BoxShape.circle), child: Icon(icono, color: color, size: 30)), const SizedBox(height: 10), Text(titulo, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))]))); }
}