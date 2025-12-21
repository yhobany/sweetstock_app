import 'dart:io';
import 'package:flutter/material.dart';
import 'pantalla_camara.dart';
import 'main.dart';
import 'producto_modelo.dart';
import 'servicio_temporal.dart';
import 'package:intl/intl.dart';

class PantallaRegistro extends StatefulWidget {
  const PantallaRegistro({super.key});

  @override
  State<PantallaRegistro> createState() => _PantallaRegistroState();
}

class _PantallaRegistroState extends State<PantallaRegistro> {
  final _servicio = ServicioTemporal();

  // Controladores
  final _barrasController = TextEditingController();
  final _nombreController = TextEditingController();

  // FINANCIEROS
  final _costoTotalController = TextEditingController(); // Input: Costo Factura
  final _cantidadController = TextEditingController(text: "30"); // Input: Cantidad
  final _costoUnitarioController = TextEditingController(); // Calculado
  final _precioVentaController = TextEditingController(); // Input: Precio Final

  final _loteController = TextEditingController();
  final _vencimientoController = TextEditingController();

  String? _rutaEvidencia;

  @override
  void initState() {
    super.initState();
    // Escuchamos cambios para calcular en tiempo real
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

  // --- LÓGICA DE CÁLCULO FINANCIERO ---
  void _calcularMatematica() {
    double totalFactura = double.tryParse(_costoTotalController.text) ?? 0;
    int cantidad = int.tryParse(_cantidadController.text) ?? 1;

    if (totalFactura > 0 && cantidad > 0) {
      // 1. Costo Unitario
      double costoUnitario = totalFactura / cantidad;
      _costoUnitarioController.text = costoUnitario.toStringAsFixed(0);

      // 2. Sugerencia de Precio (+30%)
      if (_precioVentaController.text.isEmpty) {
        // Ganancia del 30%, redondeado a la centena más cercana (ej 1230 -> 1300)
        double precioSugerido = costoUnitario * 1.30;
        precioSugerido = (precioSugerido / 50).ceil() * 50; // Redondeo a 50 pesos
        // Nota: No llenamos el campo automáticamente para no invadir,
        // pero podrías hacerlo descomentando la siguiente línea:
        // _precioVentaController.text = precioSugerido.toStringAsFixed(0);
      }
    } else {
      _costoUnitarioController.text = "0";
    }
    setState(() {}); // Refrescar para mostrar la sugerencia en texto
  }

  void _abrirEscaner(TextEditingController controller, String tipoDato) async {
    if (cameras.isEmpty) return;
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => PantallaCamara(camera: cameras.first, soloEvidencia: false)));
    if (result != null && result is String) setState(() => controller.text = result.replaceAll("\n", " "));
  }

  void _tomarEvidencia() async {
    if (cameras.isEmpty) return;
    final result = await Navigator.push(context, MaterialPageRoute(builder: (context) => PantallaCamara(camera: cameras.first, soloEvidencia: true)));
    if (result != null && result is String) setState(() => _rutaEvidencia = result);
  }

  // --- VALIDACIÓN DE SEGURIDAD ---
  void _intentarGuardar() {
    if (_barrasController.text.isEmpty || _nombreController.text.isEmpty || _precioVentaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⚠️ Faltan datos obligatorios"), backgroundColor: Colors.orange));
      return;
    }

    // Validar Fechas estrictamente
    if (_vencimientoController.text.isNotEmpty) {
      try {
        final fechaInput = DateTime.parse(_vencimientoController.text);
        final hoy = DateTime.now();
        final hoySinHora = DateTime(hoy.year, hoy.month, hoy.day);

        if (fechaInput.isBefore(hoySinHora)) {
          // ALERTA BLOQUEANTE
          showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                title: const Row(children: [Icon(Icons.dangerous, color: Colors.red), SizedBox(width: 10), Text("PRODUCTO VENCIDO")]),
                content: const Text("Estás intentando ingresar inventario con fecha pasada.\n\nEsto se marcará como PÉRDIDA/MERMA y el sistema NO permitirá venderlo en caja.\n\n¿Confirmas que es una merma?"),
                actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Corregir Fecha")),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _procesarGuardado(); // Guarda, pero la lógica de caja lo bloqueará
                    },
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    child: const Text("CONFIRMAR MERMA", style: TextStyle(color: Colors.white)),
                  )
                ],
              )
          );
          return;
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Formato de fecha inválido (Use YYYY-MM-DD)"), backgroundColor: Colors.red));
        return;
      }
    }
    _procesarGuardado();
  }

  void _procesarGuardado() {
    double costoU = double.tryParse(_costoUnitarioController.text) ?? 0;
    double precio = double.tryParse(_precioVentaController.text) ?? 0;
    int cantidad = int.tryParse(_cantidadController.text) ?? 0;

    final nuevoProducto = Producto(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      codigoBarras: _barrasController.text,
      nombre: _nombreController.text,
      precio: precio,
      costo: costoU, // Guardamos el costo real calculado
      stock: 0, // Se actualizará en registrarEntrada
      fechaVencimiento: _vencimientoController.text.isNotEmpty ? _vencimientoController.text : null,
    );

    _servicio.registrarEntrada(nuevoProducto, cantidad);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("✅ Producto Ingresado"), backgroundColor: Colors.green));
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    // Calculamos sugerencia para mostrarla visualmente
    double costoU = double.tryParse(_costoUnitarioController.text) ?? 0;
    double sugerido = (costoU * 1.30 / 50).ceil() * 50;

    return Scaffold(
      appBar: AppBar(title: const Text("Nuevo Ingreso"), elevation: 0, backgroundColor: Colors.white, foregroundColor: Colors.black),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Ficha Técnica", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFE91E63))),
            const SizedBox(height: 20),

            _crearCampoInput("Código de Barras *", Icons.qr_code, _barrasController, esNumerico: true),
            _crearCampoInput("Nombre del Producto *", Icons.label, _nombreController),

            const SizedBox(height: 20),

            // --- TARJETA DE CALCULADORA (RESTAURADA) ---
            Container(
              padding: const EdgeInsets.all(15),
              decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.green.shade200)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(children: [Icon(Icons.calculate, size: 16, color: Colors.green), SizedBox(width: 5), Text("CALCULADORA DE COSTOS", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green, fontSize: 12))]),
                  const SizedBox(height: 15),
                  const Text("Costo Total Factura (\$)", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)),
                  const SizedBox(height: 5),
                  TextField(
                    controller: _costoTotalController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black87),
                    decoration: InputDecoration(hintText: "Ej: 30000", fillColor: Colors.white, filled: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Cantidad", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)), const SizedBox(height: 5), TextField(controller: _cantidadController, keyboardType: TextInputType.number, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18), decoration: InputDecoration(fillColor: Colors.white, filled: true, contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)))])),
                      const SizedBox(width: 15),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [const Text("Costo Unitario", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.black54)), const SizedBox(height: 5), Container(width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10), decoration: BoxDecoration(color: Colors.black12, borderRadius: BorderRadius.circular(8)), child: Text("\$${_costoUnitarioController.text}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.black54)))])),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Precio Venta con Sugerencia
            const Text("Precio al Público", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 5),
            TextField(
              controller: _precioVentaController,
              keyboardType: TextInputType.number,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.indigo),
              decoration: InputDecoration(prefixIcon: const Icon(Icons.attach_money, color: Colors.indigo), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10))),
            ),
            if (costoU > 0)
              Padding(padding: const EdgeInsets.only(top: 5, left: 10), child: Text("Sugerido (30%): \$$sugerido", style: const TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic))),

            const SizedBox(height: 20),

            Row(children: [
              Expanded(child: _crearCampoInput("Lote", Icons.layers, _loteController)),
              const SizedBox(width: 15),
              // Aquí agregamos la fecha con selector
              Expanded(child: GestureDetector(
                onTap: () async {
                  DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2030));
                  if (picked != null) _vencimientoController.text = picked.toString().split(' ')[0];
                },
                child: AbsorbPointer(child: _crearCampoInput("Vencimiento", Icons.calendar_today, _vencimientoController, esFecha: true)),
              )),
            ]),

            const Divider(),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Evidencia", style: TextStyle(fontWeight: FontWeight.bold)), IconButton(icon: const Icon(Icons.camera_alt, color: Color(0xFFE91E63)), onPressed: _tomarEvidencia)]),
            if (_rutaEvidencia != null) Container(height: 100, width: double.infinity, margin: const EdgeInsets.only(bottom: 20), decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), image: DecorationImage(image: FileImage(File(_rutaEvidencia!)), fit: BoxFit.cover))),

            SizedBox(
              width: double.infinity,
              height: 55,
              child: ElevatedButton(
                onPressed: _intentarGuardar, // Usamos la validación segura
                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFFE91E63), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                child: const Text("CONFIRMAR INGRESO", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _crearCampoInput(String label, IconData icono, TextEditingController controller, {bool esNumerico = false, bool esFecha = false}) {
    return Padding(padding: const EdgeInsets.only(bottom: 20), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: const TextStyle(fontWeight: FontWeight.w600)), const SizedBox(height: 8), Row(children: [Expanded(child: TextField(controller: controller, keyboardType: esNumerico ? TextInputType.number : TextInputType.text, decoration: InputDecoration(prefixIcon: Icon(icono, color: Colors.grey), hintText: esFecha ? "YYYY-MM-DD" : "...", border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: Colors.grey.shade300))))), if(!esNumerico && !esFecha) ...[const SizedBox(width: 10), InkWell(onTap: () => _abrirEscaner(controller, label), child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: Colors.pink.shade50, borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.document_scanner, color: Color(0xFFE91E63))))]])]));
  }
}