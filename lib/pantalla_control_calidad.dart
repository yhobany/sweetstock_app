import 'package:flutter/material.dart';
import 'producto_modelo.dart';
import 'servicio_temporal.dart';

class PantallaControlCalidad extends StatefulWidget {
  const PantallaControlCalidad({super.key});

  @override
  State<PantallaControlCalidad> createState() => _PantallaControlCalidadState();
}

class _PantallaControlCalidadState extends State<PantallaControlCalidad> {
  final _servicio = ServicioTemporal();
  List<Producto> _riesgos = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  void _cargar() {
    setState(() {
      _riesgos = _servicio.obtenerProductosRiesgo();
    });
  }

  void _darDeBaja(String id) {
    // Aquí podrías implementar una lógica de "Salida por Merma"
    // Por ahora usamos eliminar físico
    _servicio.eliminarProducto(id);
    _cargar();
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Producto dado de baja del inventario")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Control de Calidad"), backgroundColor: Colors.white, foregroundColor: Colors.red),
      backgroundColor: Colors.red.shade50,
      body: _riesgos.isEmpty
          ? const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle, size: 60, color: Colors.green), SizedBox(height: 10), Text("Todo en orden. Nada vencido.")]))
          : ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: _riesgos.length,
        itemBuilder: (context, index) {
          final p = _riesgos[index];

          // Calcular estado
          final fecha = DateTime.parse(p.fechaVencimiento!);
          final hoy = DateTime.now();
          final dias = fecha.difference(hoy).inDays;
          final vencido = dias < 0;

          return Card(
            color: Colors.white,
            child: ListTile(
              leading: Icon(Icons.warning, color: vencido ? Colors.red : Colors.orange),
              title: Text(p.nombre, style: TextStyle(fontWeight: FontWeight.bold, decoration: vencido ? TextDecoration.lineThrough : null)),
              subtitle: Text(vencido ? "VENCIDO HACE ${dias.abs()} DÍAS" : "Vence en $dias días"),
              trailing: ElevatedButton(
                onPressed: () => _darDeBaja(p.id),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade100, foregroundColor: Colors.red),
                child: const Text("DAR BAJA"),
              ),
            ),
          );
        },
      ),
    );
  }
}