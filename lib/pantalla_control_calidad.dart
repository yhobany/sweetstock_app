import 'package:flutter/material.dart';
import 'producto_modelo.dart';
import 'servicio_firebase.dart';
import 'package:intl/intl.dart';

class PantallaControlCalidad extends StatefulWidget {
  const PantallaControlCalidad({super.key});

  @override
  State<PantallaControlCalidad> createState() => _PantallaControlCalidadState();
}

class _PantallaControlCalidadState extends State<PantallaControlCalidad> {
  final _servicio = ServicioFirebase();

  // Calcular días para vencer
  int _diasParaVencer(String? fechaStr) {
    if (fechaStr == null) return 999;
    try {
      final vencimiento = DateTime.parse(fechaStr);
      final hoy = DateTime.now();
      final fechaVenc = DateTime(vencimiento.year, vencimiento.month, vencimiento.day);
      final fechaHoy = DateTime(hoy.year, hoy.month, hoy.day);
      return fechaVenc.difference(fechaHoy).inDays;
    } catch (e) { return 999; }
  }

  void _eliminarProducto(Producto p) async {
    bool confirmar = await showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("¿Desechar Producto?"),
          content: Text("Estás a punto de eliminar '${p.nombre}' del inventario permanentemente.\n\nEsta acción no se puede deshacer."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancelar")),
            ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: const Text("ELIMINAR")
            )
          ],
        )
    ) ?? false;

    if (confirmar) {
      await _servicio.eliminarProducto(p.id); // <--- ESTO BORRA EN LA NUBE
      setState(() {}); // Recargamos la lista
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Producto eliminado correctamente")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(title: const Text("Control de Calidad"), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      body: StreamBuilder<List<Producto>>(
        stream: _servicio.obtenerProductosStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          // Filtramos solo los que tienen fecha de vencimiento
          final listaCompleta = snapshot.data!;
          final listaVencidos = listaCompleta.where((p) {
            if (p.fechaVencimiento == null) return false;
            return _diasParaVencer(p.fechaVencimiento) <= 30; // Muestra vencidos o próximos a vencer (30 días)
          }).toList();

          // Ordenamos: Primero los más urgentes (negativos o cercanos a 0)
          listaVencidos.sort((a, b) => _diasParaVencer(a.fechaVencimiento).compareTo(_diasParaVencer(b.fechaVencimiento)));

          if (listaVencidos.isEmpty) return const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.check_circle_outline, size: 80, color: Colors.green), SizedBox(height: 10), Text("¡Todo Fresco!", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green)), Text("No hay productos vencidos o por vencer")]));

          return ListView.separated(
            padding: const EdgeInsets.all(15),
            itemCount: listaVencidos.length,
            separatorBuilder: (_,__) => const SizedBox(height: 10),
            itemBuilder: (context, index) {
              final p = listaVencidos[index];
              final dias = _diasParaVencer(p.fechaVencimiento);
              final esVencido = dias < 0;
              final esUrgente = dias >= 0 && dias <= 7;

              Color colorBase = esVencido ? Colors.red : (esUrgente ? Colors.orange : Colors.yellow.shade800);
              String estadoTexto = esVencido ? "VENCIDO HACE ${dias.abs()} DÍAS" : (dias == 0 ? "VENCE HOY" : "VENCE EN $dias DÍAS");

              return Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: colorBase.withOpacity(0.3))),
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                  leading: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: colorBase.withOpacity(0.1), shape: BoxShape.circle),
                    child: Icon(Icons.warning_amber_rounded, color: colorBase),
                  ),
                  title: Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 5),
                      Text("Stock: ${p.stock} unidades"),
                      const SizedBox(height: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: colorBase.withOpacity(0.1), borderRadius: BorderRadius.circular(5)),
                        child: Text(estadoTexto, style: TextStyle(color: colorBase, fontWeight: FontWeight.bold, fontSize: 12)),
                      )
                    ],
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_forever, color: Colors.red),
                    onPressed: () => _eliminarProducto(p),
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}