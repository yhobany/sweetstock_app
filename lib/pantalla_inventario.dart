import 'package:flutter/material.dart';
import 'producto_modelo.dart';
import 'servicio_temporal.dart';

class PantallaInventario extends StatefulWidget {
  const PantallaInventario({super.key});

  @override
  State<PantallaInventario> createState() => _PantallaInventarioState();
}

class _PantallaInventarioState extends State<PantallaInventario> {
  final _servicio = ServicioTemporal();
  List<Producto> _listaProductos = [];
  String _filtro = "";

  @override
  void initState() {
    super.initState();
    _recargar();
  }

  void _recargar() {
    setState(() {
      _listaProductos = _servicio.obtenerProductos();
    });
  }

  void _eliminar(String id) {
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("¿Eliminar producto?"),
          content: const Text("Esta acción no se puede deshacer."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
            TextButton(
              onPressed: () {
                _servicio.eliminarProducto(id);
                Navigator.pop(ctx);
                _recargar();
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Producto eliminado")));
              },
              child: const Text("ELIMINAR", style: TextStyle(color: Colors.red)),
            )
          ],
        )
    );
  }

  void _editar(Producto p) {
    final nombreCtrl = TextEditingController(text: p.nombre);
    final precioCtrl = TextEditingController(text: p.precio.toInt().toString());
    final stockCtrl = TextEditingController(text: p.stock.toString());
    final fechaCtrl = TextEditingController(text: p.fechaVencimiento ?? '');

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
              top: 20, left: 20, right: 20,
              bottom: MediaQuery.of(ctx).viewInsets.bottom + 20
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Editar Producto", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              TextField(controller: nombreCtrl, decoration: const InputDecoration(labelText: "Nombre")),
              Row(
                children: [
                  Expanded(child: TextField(controller: precioCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Precio"))),
                  const SizedBox(width: 15),
                  Expanded(child: TextField(controller: stockCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Stock"))),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: fechaCtrl,
                decoration: const InputDecoration(labelText: "Vence (YYYY-MM-DD)", suffixIcon: Icon(Icons.calendar_today)),
                readOnly: true,
                onTap: () async {
                  final picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2030)
                  );
                  if (picked != null) {
                    fechaCtrl.text = picked.toString().split(' ')[0];
                  }
                },
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    final nuevoProducto = Producto(
                        id: p.id,
                        codigoBarras: p.codigoBarras,
                        nombre: nombreCtrl.text,
                        precio: double.tryParse(precioCtrl.text) ?? p.precio,
                        costo: p.costo,
                        stock: int.tryParse(stockCtrl.text) ?? p.stock,
                        fechaVencimiento: fechaCtrl.text.isNotEmpty ? fechaCtrl.text : null
                    );
                    _servicio.actualizarProducto(nuevoProducto);
                    Navigator.pop(ctx);
                    _recargar();
                  },
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.indigo, foregroundColor: Colors.white),
                  child: const Text("GUARDAR CAMBIOS"),
                ),
              )
            ],
          ),
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtrados = _listaProductos.where((p) => p.nombre.toLowerCase().contains(_filtro.toLowerCase())).toList();

    return Scaffold(
      appBar: AppBar(title: const Text("Inventario"), backgroundColor: Colors.white, foregroundColor: Colors.indigo),
      backgroundColor: Colors.grey.shade50,
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(15),
            child: TextField(
              onChanged: (val) => setState(() => _filtro = val),
              decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, color: Colors.indigo),
                  hintText: "Buscar en bodega...",
                  filled: true, fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none)
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
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
                    subtitle: Text("Código: ${p.codigoBarras}\nVence: ${p.fechaVencimiento ?? 'N/A'}"),
                    isThreeLine: true,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text("\$${p.precio.toInt()}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.indigo)),
                            Text("Stock: ${p.stock}", style: TextStyle(color: p.stock < 5 ? Colors.red : Colors.green, fontSize: 12, fontWeight: FontWeight.bold)),
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
            ),
          )
        ],
      ),
    );
  }
}