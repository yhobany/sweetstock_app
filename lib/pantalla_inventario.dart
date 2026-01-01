import 'package:flutter/material.dart';
import 'producto_modelo.dart';
import 'servicio_firebase.dart'; // <--- CONEXIÓN REAL

class PantallaInventario extends StatefulWidget {
  const PantallaInventario({super.key});

  @override
  State<PantallaInventario> createState() => _PantallaInventarioState();
}

class _PantallaInventarioState extends State<PantallaInventario> {
  final _servicio = ServicioFirebase(); // <--- INSTANCIA NUBE
  String _filtro = "";

  void _eliminar(String id) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("¿Eliminar de Nube?"),
          content: const Text("Esta acción es irreversible y borrará el producto de la base de datos."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
            TextButton(
              onPressed: () {
                _servicio.eliminarProducto(id);
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Producto eliminado")));
              },
              child: const Text("ELIMINAR", style: TextStyle(color: Colors.red)),
            )
          ],
        )
    );
  }

  void _editar(Producto p) {
    // Por ahora solo mostramos mensaje, la edición completa vendrá en una actualización futura
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Edición en la nube disponible en próxima actualización")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Inventario (En Nube)"), backgroundColor: Colors.white, foregroundColor: Colors.indigo),
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: TextField(
              onChanged: (val) => setState(() => _filtro = val),
              decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, color: Colors.indigo),
                  hintText: "Buscar en Firestore...",
                  filled: true, fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)
              ),
            ),
          ),
          Expanded(
            // STREAMBUILDER: La magia del tiempo real
            child: StreamBuilder<List<Producto>>(
              stream: _servicio.obtenerProductosStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text("Error al cargar datos"));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                final listaTotal = snapshot.data ?? [];

                // Filtro local
                final filtrados = listaTotal.where((p) => p.nombre.toLowerCase().contains(_filtro.toLowerCase())).toList();

                if (filtrados.isEmpty) return const Center(child: Text("Inventario vacío en la Nube"));

                return ListView.builder(
                  itemCount: filtrados.length,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  itemBuilder: (context, index) {
                    final p = filtrados[index];
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      elevation: 0,
                      shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey.shade200), borderRadius: BorderRadius.circular(10)),
                      child: ListTile(
                        title: Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text("Código: ${p.codigoBarras}\nStock: ${p.stock}"),
                        isThreeLine: true,
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text("\$${p.precio.toInt()}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                                if (p.fechaVencimiento != null)
                                  Text("Vence: ${p.fechaVencimiento}", style: const TextStyle(fontSize: 10, color: Colors.grey)),
                              ],
                            ),
                            const SizedBox(width: 10),
                            PopupMenuButton(
                              onSelected: (value) {
                                if (value == 'edit') _editar(p);
                                if (value == 'delete') _eliminar(p.id);
                              },
                              itemBuilder: (context) => [
                                const PopupMenuItem(value: 'edit', child: Row(children: [Icon(Icons.edit, size: 18, color: Colors.blue), SizedBox(width: 10), Text("Editar")])),
                                const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, size: 18, color: Colors.red), SizedBox(width: 10), Text("Eliminar")])),
                              ],
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          )
        ],
      ),
    );
  }
}