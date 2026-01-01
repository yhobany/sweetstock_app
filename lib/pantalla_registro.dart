import 'package:flutter/material.dart';
import 'pantalla_camara.dart';
import 'main.dart';
import 'producto_modelo.dart';
import 'movimiento_modelo.dart';
import 'servicio_firebase.dart';
import 'package:intl/intl.dart';

class PantallaRegistro extends StatefulWidget {
  const PantallaRegistro({super.key});

  @override
  State<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends State<PantallaRegistro> {
  final _servicio = ServicioFirebase();
  final _barrasController = TextEditingController();
  final _nombreController = TextEditingController();
  final _costoTotalController = TextEditingController();
  final _cantidadController = TextEditingController(text: "30");
  final _costoUnitarioController = TextEditingController();
  final _precioVentaController = TextEditingController();
  final _loteController = TextEditingController();
  final _vencimientoController = TextEditingController();
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _costoTotalController.addListener(_calcularMatematica);
    _cantidadController.addListener(_calcularMatematica);
  }

  @override
  void dispose() {
    _costoTotalController.removeListener(_calcularMatematica);
    _cantidadController.removeListener(_calcularMatematica);
    _nombreController.dispose();
    _barrasController.dispose();
    _costoTotalController.dispose();
    _cantidadController.dispose();
    _costoUnitarioController.dispose();
    _precioVentaController.dispose();
    _loteController.dispose();
    _vencimientoController.dispose();
    super.dispose();
  }

  void _calcularMatematica() {
    double totalFactura = double.tryParse(_costoTotalController.text) ?? 0;
    int cantidad = int.tryParse(_cantidadController.text) ?? 1;
    if (totalFactura > 0 && cantidad > 0) {
      double costoUnitario = totalFactura / cantidad;
      _costoUnitarioController.text = costoUnitario.toStringAsFixed(0);
      if (_precioVentaController.text.isEmpty) {
        double precioSugerido = costoUnitario * 1.30;
        precioSugerido = (precioSugerido / 50).ceil() * 50;
      }
    } else {
      _costoUnitarioController.text = "0";
    }
    setState(() {});
  }

  void _abrirEscaner(TextEditingController controller) async {
    if (cameras.isEmpty) return;
    // Usamos PantallaCamara que ya tiene recorte integrado
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => PantallaCamara(camera: cameras.first, soloEvidencia: false)));

    if (result != null && result is String) {
      // Limpieza extra por seguridad
      String procesado = result.replaceAll("\n", " ").replaceAll(RegExp(r'[^0-9]'), '');
      setState(() => controller.text = procesado);
    }
  }

  void _intentarGuardar() {
    if (_barrasController.text.isEmpty || _nombreController.text.isEmpty || _precioVentaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠️ Faltan datos obligatorios"), backgroundColor: Colors.orange));
      return;
    }
    if (_vencimientoController.text.isNotEmpty) {
      try {
        final fechaInput = DateTime.parse(_vencimientoController.text);
        final hoy = DateTime.now();
        final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);
        if (fechaInput.isBefore(hoySinHora)) {
          showDialog(context: context, builder: (ctx) => AlertDialog(title: const Row(children: [Icon(Icons.dangerous, color: Colors.red), SizedBox(width: 10), Text("PRODUCTO VENCIDO")]), content: const Text("Estás intentando ingresar inventario con fecha pasada.\n\nEsto se marcará como PÉRDIDA/MERMA.\n\n¿Confirmas el ingreso?"), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Corregir")), ElevatedButton(onPressed: () { Navigator.pop(ctx); _procesarGuardado(); }, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: const Text("CONFIRMAR MERMA", style: TextStyle(color: Colors.white))) ])); return;
        }
      } catch (e) { ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Formato de fecha inválido"), backgroundColor: Colors.red)); return; }
    }
    _procesarGuardado();
  }

  void _procesarGuardado() async {
    setState(() => _guardando = true);
    try {
      double costoU = double.tryParse(_costoUnitarioController.text) ?? 0;
      double precio = double.tryParse(_precioVentaController.text) ?? 0;
      int cantidad = int.tryParse(_cantidadController.text) ?? 0;

      final nuevoProducto = Producto(id: DateTime.now().millisecondsSinceEpoch.toString(), codigoBarras: _barrasController.text, nombre: _nombreController.text, precio: precio, costo: costoU, stock: cantidad, fechaVencimiento: _vencimientoController.text.isNotEmpty ? _vencimientoController.text : null);
      await _servicio.guardarProducto(nuevoProducto);

      final movimiento = Movimiento(id: DateTime.now().millisecondsSinceEpoch.toString(), tipo: 'entrada', nombreProducto: nuevoProducto.nombre, cantidad: cantidad, total: costoU * cantidad, fecha: DateTime.now(), detalle: 'Ingreso Inicial (App)');
      await _servicio.registrarMovimiento(movimiento);

      if (mounted) {
        await showDialog(context: context, barrierDismissible: false, builder: (ctx) => AlertDialog(icon: const Icon(Icons.check_circle, color: Colors.green, size: 60), title: const Text("¡Registro Exitoso!"), content: const Text("El producto se guardó correctamente en la nube."), actions: [FilledButton(onPressed: () { Navigator.pop(ctx); Navigator.pop(context); }, child: const Text("Entendido"))]));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red));
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    double costoU = double.tryParse(_costoUnitarioController.text) ?? 0;
    double sugerido = (costoU * 1.30 / 50).ceil() * 50;

    return Scaffold(
      appBar: AppBar(title: const Text("Nuevo Ingreso (Nube)"), elevation: 0, backgroundColor: Colors.white, foregroundColor: Colors.black),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Ficha Técnica", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFE91E63))),
            const SizedBox(height: 20),
            _crearCampoInput("Código de Barras *", Icons.qr_code, _barrasController, esNumerico: true, usarScanner: true),
            _crearCampoInput("Nombre del Producto *", Icons.label, _nombreController),
            const SizedBox(height: 20),
            Container(padding: const EdgeInsets.all(15), decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.green.shade200)), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Row(children: [Icon(Icons.calculate, size: 16, color: Colors.green), SizedBox(width: 5), Text("CALCULADORA DE COSTOS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 12))]), const SizedBox(height: 15), const Text("Costo Total Factura (\$)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)), const SizedBox(height: 5), TextField(controller: _costoTotalController, keyboardType: TextInputType.number, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87), decoration: InputDecoration(hintText: "Ej: 30000", fillColor: Colors.white, filled: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none))), const SizedBox(height: 15), Row(children: [Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Cantidad", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)), const SizedBox(height: 5), TextField(controller: _cantidadController, keyboardType: TextInputType.number, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), decoration: InputDecoration(fillColor: Colors.white, filled: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)))])), const SizedBox(width: 15), Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Costo Unitario", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)), const SizedBox(height: 5), Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10), decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)), child: Text("\$${_costoUnitarioController.text}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black54)))])), ])])),
            const SizedBox(height: 20),
            const Text("Precio al Público", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            TextField(controller: _precioVentaController, keyboardType: TextInputType.number, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.indigo), decoration: InputDecoration(prefixIcon: const Icon(Icons.attach_money, color: Colors.indigo), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
            if (costoU > 0) Padding(padding: const EdgeInsets.only(top: 5, left: 10), child: Text("Sugerido (30%): \$$sugerido", style: const TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic))),
            const SizedBox(height: 20),
            Row(children: [Expanded(child: _crearCampoInput("Lote", Icons.layers, _loteController)), const SizedBox(width: 15), Expanded(child: GestureDetector(onTap: () async { DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030)); if (picked != null) _vencimientoController.text = picked.toString().split(' ')[0]; }, child: AbsorbPointer(child: _crearCampoInput("Vencimiento", Icons.calendar_today, _vencimientoController, esFecha: true)))),]),
            const SizedBox(height: 30),
            SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: _guardando ? null : _intentarGuardar, style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE91E63), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _guardando ? const CircularProgressIndicator(color: Colors.white) : const Text("CONFIRMAR INGRESO", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _crearCampoInput(String label, IconData icono, TextEditingController controller, {bool esNumerico = false, bool esFecha = false, bool usarScanner = false}) {
    return Padding(padding: const EdgeInsets.only(bottom: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 8), Row(children: [Expanded(child: TextField(controller: controller, keyboardType: esNumerico ? TextInputType.number : TextInputType.text, decoration: InputDecoration(prefixIcon: Icon(icono, color: Colors.grey), hintText: esFecha ? "YYYY-MM-DD" : "...", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300))))), if(usarScanner || (!esNumerico && !esFecha)) ...[const SizedBox(width: 10), InkWell(onTap: () => _abrirEscaner(controller), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.pink.shade50, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.qr_code_scanner, color: Color(0xFFE91E63))))]])]));
  }
}