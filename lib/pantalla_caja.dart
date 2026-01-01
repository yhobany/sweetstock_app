import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'producto_modelo.dart';
import 'servicio_firebase.dart';
import 'pantalla_camara.dart'; // <--- IMPORTANTE: Acceso a la cámara
import 'main.dart'; // <--- IMPORTANTE: Acceso a variable global cameras

class PantallaCaja extends StatefulWidget {
  const PantallaCaja({super.key});

  @override
  State<PantallaCaja> createState() => _PantallaCajaState();
}

class _PantallaCajaState extends State<PantallaCaja> {
  final List<ItemCarrito> _carrito = [];
  String _busqueda = "";
  final _servicio = ServicioFirebase();

  // Controlador para manipular el texto del buscador
  final TextEditingController _searchCtrl = TextEditingController();

  // Lógica de Vencimiento
  String _calcularEstadoVencimiento(String? fechaStr) {
    if (fechaStr == null) return 'good';
    try {
      final vencimiento = DateTime.parse(fechaStr);
      final hoy = DateTime.now();
      final fechaVenc = DateTime(vencimiento.year, vencimiento.month, vencimiento.day);
      final fechaHoy = DateTime(hoy.year, hoy.month, hoy.day);

      final diferencia = fechaVenc.difference(fechaHoy).inDays;
      if (diferencia < 0) return 'expired';
      if (diferencia <= 30) return 'warning';
      return 'good';
    } catch (e) { return 'good'; }
  }

  // --- FUNCIÓN CORREGIDA: ABRIR ESCÁNER CON FILTRO NUMÉRICO ---
  void _abrirEscaner() async {
    if (cameras.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No se detectó cámara")));
      return;
    }

    // Navegamos a la cámara
    final result = await Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => PantallaCamara(camera: cameras.first))
    );

    if (result != null && result is String) {
      setState(() {
        // 1. Limpiamos saltos de línea
        String codigoLimpio = result.replaceAll("\n", " ");

        // 2. APLICAMOS EL FILTRO: Solo dejamos números (0-9)
        codigoLimpio = codigoLimpio.replaceAll(RegExp(r'[^0-9]'), '');

        if (codigoLimpio.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠️ El código escaneado no contiene números válidos"), backgroundColor: Colors.orange));
          return;
        }

        // 3. Ponemos el código numérico limpio en el buscador
        _searchCtrl.text = codigoLimpio;
        _busqueda = codigoLimpio;
      });
    }
  }

  void _abrirModalGasto() {
    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (context) => ModalGasto(
            onRegistrar: (monto, motivo) {
              _servicio.registrarGasto(monto, motivo);
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("📉 Gasto registrado en Nube"), backgroundColor: Colors.orange));
            }
        )
    );
  }

  void _abrirModalCantidad(Producto p) {
    final estado = _calcularEstadoVencimiento(p.fechaVencimiento);
    if (estado == 'expired') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⛔ PROHIBIDO: Producto vencido"), backgroundColor: Colors.red));
      return;
    }

    int enCarrito = 0;
    final index = _carrito.indexWhere((item) => item.producto.id == p.id);
    if (index != -1) enCarrito = _carrito[index].cantidad;

    int disponible = p.stock - enCarrito;

    if (disponible <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("¡Sin stock disponible!"), backgroundColor: Colors.red));
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => ModalCantidad(
        producto: p,
        maximoDisponible: disponible,
        onConfirmar: (cantidad) => _agregarAlCarrito(p, cantidad),
      ),
    );
  }

  void _agregarAlCarrito(Producto p, int cantidad) {
    setState(() {
      final indice = _carrito.indexWhere((item) => item.producto.id == p.id);
      if (indice != -1) {
        _carrito[indice].cantidad += cantidad;
      } else {
        _carrito.add(ItemCarrito(producto: p, cantidad: cantidad));
      }
      // Limpiamos búsqueda tras agregar para seguir vendiendo
      _busqueda = "";
      _searchCtrl.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Se agregaron $cantidad unidades")));
  }

  double get _totalVenta => _carrito.fold(0, (sum, item) => sum + item.subtotal);

  void _abrirModalPago() {
    if (_carrito.isEmpty) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => ModalPago(
        total: _totalVenta,
        onFinalizar: (metodo, referencia) => _finalizarVenta(metodo, referencia),
      ),
    );
  }

  void _finalizarVenta(String metodo, String? referencia) async {
    showDialog(context: context, barrierDismissible: false, builder: (ctx) => const Center(child: CircularProgressIndicator()));

    try {
      await _servicio.realizarVenta(_carrito, metodo, referencia);

      Navigator.pop(context); // Cierra carga

      setState(() {
        _carrito.clear();
      });
      Navigator.pop(context); // Cierra Modal Pago

      showDialog(context: context, builder: (ctx) => AlertDialog(
          icon: const Icon(Icons.check_circle, color: Colors.green, size: 50),
          title: const Text("¡Venta Exitosa!"),
          content: Text("Pago registrado con $metodo"),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))]
      ));

    } catch (e) {
      Navigator.pop(context); // Cierra carga
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error al vender: $e"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        title: const Text("Punto de Venta (Nube)"),
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        elevation: 0,
        actions: [
          Center(child: Padding(padding: const EdgeInsets.only(right: 20), child: Badge(label: Text("${_carrito.length}"), isLabelVisible: _carrito.isNotEmpty, child: const Icon(Icons.shopping_cart, color: Color(0xFFE91E63)))))
        ],
      ),
      body: Column(
        children: [
          // Botón Gasto
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 5),
            child: SizedBox(
              width: double.infinity,
              height: 40,
              child: OutlinedButton.icon(
                onPressed: _abrirModalGasto,
                icon: const Icon(Icons.trending_down, color: Colors.red, size: 18),
                label: const Text("REGISTRAR GASTO", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                style: OutlinedButton.styleFrom(side: BorderSide(color: Colors.red.shade200), backgroundColor: Colors.red.shade50),
              ),
            ),
          ),

          // Buscador con Escáner
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: TextField(
              controller: _searchCtrl, // Conectamos el controlador
              onChanged: (val) => setState(() => _busqueda = val),
              decoration: InputDecoration(
                  hintText: "Buscar producto o escanear...",
                  prefixIcon: const Icon(Icons.search),
                  // BOTÓN DE ESCÁNER AQUÍ
                  suffixIcon: IconButton(
                    icon: const Icon(Icons.qr_code_scanner, color: Color(0xFFE91E63)),
                    onPressed: _abrirEscaner,
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none)),
            ),
          ),

          // Lista Filtrada
          Expanded(
            child: StreamBuilder<List<Producto>>(
              stream: _servicio.obtenerProductosStream(),
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text("Error de conexión"));
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator());

                final listaTotal = snapshot.data ?? [];

                // FILTRO MEJORADO: Busca por Nombre O por Código de Barras
                final listaFiltrada = listaTotal.where((p) {
                  final busquedaLower = _busqueda.toLowerCase();
                  final nombreMatch = p.nombre.toLowerCase().contains(busquedaLower);
                  // La búsqueda ya está limpia y es solo números, así que la coincidencia será exacta
                  final codigoMatch = p.codigoBarras == _busqueda;
                  return nombreMatch || codigoMatch;
                }).toList();

                if (listaFiltrada.isEmpty) return const Center(child: Text("No se encontraron productos"));

                return ListView.builder(
                  itemCount: listaFiltrada.length,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  itemBuilder: (context, index) {
                    final producto = listaFiltrada[index];
                    final estado = _calcularEstadoVencimiento(producto.fechaVencimiento);
                    final esVencido = estado == 'expired';

                    return Opacity(
                      opacity: esVencido ? 0.6 : 1.0,
                      child: Card(
                        elevation: 0,
                        margin: const EdgeInsets.only(bottom: 10),
                        color: esVencido ? Colors.red.shade50 : Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: BorderSide(color: esVencido ? Colors.red.shade200 : Colors.grey.shade200)),
                        child: ListTile(
                          leading: Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(color: esVencido ? Colors.red.shade100 : Colors.pink.shade50, borderRadius: BorderRadius.circular(10)),
                            child: Icon(Icons.inventory_2, color: esVencido ? Colors.red : const Color(0xFFE91E63)),
                          ),
                          title: Text(producto.nombre, style: TextStyle(fontWeight: FontWeight.bold, decoration: esVencido ? TextDecoration.lineThrough : null)),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Stock: ${producto.stock} unds"),
                              if (producto.fechaVencimiento != null)
                                Text("Vence: ${producto.fechaVencimiento}", style: TextStyle(fontSize: 12, color: esVencido ? Colors.red : Colors.grey.shade700, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text("\$${producto.precio.toInt()}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              const SizedBox(width: 10),
                              IconButton(
                                icon: Icon(esVencido ? Icons.block : Icons.add_circle, color: esVencido ? Colors.grey : Colors.green),
                                onPressed: () => _abrirModalCantidad(producto),
                              )
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),

          // CARRITO
          if (_carrito.isNotEmpty)
            Container(
              padding: const EdgeInsets.only(left: 20, right: 20, top: 20, bottom: 60),
              decoration: BoxDecoration(color: Colors.white, boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))], borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
              child: SafeArea(
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("${_carrito.length} Items", style: const TextStyle(color: Colors.grey)),
                        Text("Total: \$${_totalVenta.toInt()}", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.black)),
                      ],
                    ),
                    const SizedBox(height: 15),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _abrirModalPago,
                        style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE91E63), foregroundColor: Colors.white),
                        child: const Text("COBRAR", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      ),
                    )
                  ],
                ),
              ),
            )
        ],
      ),
    );
  }
}

// --- MODALES COMPLETOS CON MARGEN CORREGIDO ---

class ModalGasto extends StatefulWidget {
  final Function(double monto, String motivo) onRegistrar;
  const ModalGasto({super.key, required this.onRegistrar});
  @override
  State<ModalGasto> createState() => _ModalGastoState();
}
class _ModalGastoState extends State<ModalGasto> {
  final _montoCtrl = TextEditingController();
  final _motivoCtrl = TextEditingController();
  @override
  Widget build(BuildContext context) {
    // YA TENÍA EL MARGEN CORRECTO
    return Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20), child: Column(mainAxisSize: MainAxisSize.min, children: [const Text("Registrar Gasto", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: Colors.red)), const SizedBox(height: 20), TextField(controller: _montoCtrl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Monto (Efectivo)", prefixIcon: Icon(Icons.attach_money), border: OutlineInputBorder())), const SizedBox(height: 15), TextField(controller: _motivoCtrl, decoration: const InputDecoration(labelText: "Motivo (Ej: Hielo, Bolsas...)", prefixIcon: Icon(Icons.edit), border: OutlineInputBorder())), const SizedBox(height: 20), SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: () { double monto = double.tryParse(_montoCtrl.text) ?? 0; if (monto <= 0 || _motivoCtrl.text.isEmpty) return; widget.onRegistrar(monto, _motivoCtrl.text); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), child: const Text("REGISTRAR SALIDA")))]));
  }
}

class ModalPago extends StatefulWidget {
  final double total;
  final Function(String metodo, String? referencia) onFinalizar;
  const ModalPago({super.key, required this.total, required this.onFinalizar});
  @override
  State<ModalPago> createState() => _ModalPagoState();
}
class _ModalPagoState extends State<ModalPago> {
  String paso = 'seleccion';
  String metodoSeleccionado = '';
  final TextEditingController referenciaController = TextEditingController();
  @override
  Widget build(BuildContext context) {
    // CORRECCIÓN: Agregado + 20 al bottom padding
    return Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20), child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
      Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(paso == 'seleccion' ? "Medio de Pago" : "Validar Transferencia", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))]), const Divider(), const SizedBox(height: 10), Text("Total a Pagar", style: TextStyle(color: Colors.grey.shade600)), Text("\$${NumberFormat.currency(locale: 'es_CO', symbol: '').format(widget.total)}", style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.green)), const SizedBox(height: 30),
      if (paso == 'seleccion') ...[ _botonPago(icono: Icons.attach_money, color: Colors.green, texto: "Efectivo", onTap: () => widget.onFinalizar("Efectivo", null)), const SizedBox(height: 10), _botonPago(icono: Icons.smartphone, color: Colors.purple, texto: "Nequi", onTap: () { setState(() { paso = 'referencia'; metodoSeleccionado = 'Nequi'; }); }), const SizedBox(height: 10), _botonPago(icono: Icons.credit_card, color: Colors.blue, texto: "Tarjeta / Datáfono", onTap: () { setState(() { paso = 'referencia'; metodoSeleccionado = 'Tarjeta'; }); }), ],
      if (paso == 'referencia') ...[ Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.grey.shade50, borderRadius: BorderRadius.circular(10)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text("Código de Aprobación ($metodoSeleccionado)", style: const TextStyle(fontWeight: FontWeight.bold)), TextField(controller: referenciaController, autofocus: true, keyboardType: TextInputType.number, decoration: const InputDecoration(hintText: "Ej: 1593...", border: InputBorder.none), onChanged: (val) => setState(() {}))])), const SizedBox(height: 20), Row(children: [TextButton(onPressed: () => setState(() => paso = 'seleccion'), child: const Text("Atrás")), Expanded(child: ElevatedButton(onPressed: referenciaController.text.length < 4 ? null : () => widget.onFinalizar(metodoSeleccionado, referenciaController.text), style: ElevatedButton.styleFrom(backgroundColor: metodoSeleccionado == 'Nequi' ? Colors.purple : Colors.blue, foregroundColor: Colors.white), child: const Text("CONFIRMAR PAGO")))])], const SizedBox(height: 30)])));
  }
  Widget _botonPago({required IconData icono, required Color color, required String texto, required VoidCallback onTap}) { return InkWell(onTap: onTap, child: Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: color.withOpacity(0.1), border: Border.all(color: color.withOpacity(0.3)), borderRadius: BorderRadius.circular(12)), child: Row(children: [Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: color, shape: BoxShape.circle), child: Icon(icono, color: Colors.white, size: 20)), const SizedBox(width: 15), Text(texto, style: TextStyle(color: color.withOpacity(0.8), fontWeight: FontWeight.bold, fontSize: 16)), const Spacer(), Icon(Icons.arrow_forward_ios, size: 14, color: color.withOpacity(0.5))]))); }
}

class ModalCantidad extends StatefulWidget {
  final Producto producto;
  final int maximoDisponible;
  final Function(int) onConfirmar;
  const ModalCantidad({super.key, required this.producto, required this.maximoDisponible, required this.onConfirmar});
  @override
  State<ModalCantidad> createState() => _ModalCantidadState();
}
class _ModalCantidadState extends State<ModalCantidad> {
  final TextEditingController _qtyController = TextEditingController(text: "1");
  int _cantidadActual = 1;
  bool _excedeStock = false;
  @override
  void dispose() { _qtyController.dispose(); super.dispose(); }
  void _actualizarCantidad(int nuevaCantidad) { if (nuevaCantidad < 1) nuevaCantidad = 1; setState(() { _cantidadActual = nuevaCantidad; _qtyController.text = _cantidadActual.toString(); _validarStock(); }); }
  void _onInputChanged(String valor) { int? numero = int.tryParse(valor); if (numero != null) { setState(() { _cantidadActual = numero; _validarStock(); }); } }
  void _validarStock() { setState(() { _excedeStock = _cantidadActual > widget.maximoDisponible; }); }
  @override
  Widget build(BuildContext context) {
    // CORRECCIÓN: Agregado + 20 al bottom padding
    return Padding(padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom + 20, left: 20, right: 20, top: 20), child: Column(mainAxisSize: MainAxisSize.min, children: [Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Agregar Producto", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context))]), const Divider(), const SizedBox(height: 10), Text(widget.producto.nombre, style: const TextStyle(fontSize: 16, color: Colors.grey)), Text("Disponible: ${widget.maximoDisponible}", style: TextStyle(fontSize: 12, color: Colors.grey.shade500)), const SizedBox(height: 20), Row(mainAxisAlignment: MainAxisAlignment.center, children: [IconButton.filledTonal(onPressed: () => _actualizarCantidad(_cantidadActual - 1), icon: const Icon(Icons.remove)), const SizedBox(width: 20), SizedBox(width: 100, child: TextField(controller: _qtyController, keyboardType: TextInputType.number, textAlign: TextAlign.center, style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: _excedeStock ? Colors.red : const Color(0xFFE91E63)), decoration: const InputDecoration(border: InputBorder.none), onChanged: _onInputChanged)), const SizedBox(width: 20), IconButton.filledTonal(onPressed: () => _actualizarCantidad(_cantidadActual + 1), icon: const Icon(Icons.add))]), if (_excedeStock) Padding(padding: const EdgeInsets.only(top: 10), child: Text("¡Solo hay ${widget.maximoDisponible} unidades disponibles!", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))), const SizedBox(height: 30), SizedBox(width: double.infinity, height: 50, child: ElevatedButton(onPressed: _excedeStock ? null : () { int qtyFinal = int.tryParse(_qtyController.text) ?? 1; if (qtyFinal < 1) qtyFinal = 1; Navigator.pop(context); widget.onConfirmar(qtyFinal); }, style: ElevatedButton.styleFrom(backgroundColor: _excedeStock ? Colors.grey : const Color(0xFFE91E63), foregroundColor: Colors.white), child: const Text("AGREGAR AL CARRITO", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))), const SizedBox(height: 20)])); }
}