import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'servicio_temporal.dart';
import 'movimiento_modelo.dart';

class PantallaReportes extends StatefulWidget {
  final bool abrirCierreInmediato; // true = Modo Cierre Z, false = Modo Consulta

  const PantallaReportes({super.key, this.abrirCierreInmediato = false});

  @override
  State<PantallaReportes> createState() => _PantallaReportesState();
}

class _PantallaReportesState extends State<PantallaReportes> {
  final _servicio = ServicioTemporal();
  String _filtro = 'hoy';
  DateTimeRange? _rangoSeleccionado;
  List<Movimiento> _datos = [];

  double _ventasEfectivo = 0;
  double _ventasDigital = 0;
  double _gastos = 0;

  @override
  void initState() {
    super.initState();
    if (widget.abrirCierreInmediato) {
      _filtro = 'hoy';
    }
    _cargarReporte();
  }

  void _cargarReporte() {
    final movimientos = _servicio.obtenerReporte(_filtro, rangoPersonalizado: _rangoSeleccionado);

    double efectivo = 0;
    double digital = 0;
    double gastos = 0;

    for (var m in movimientos) {
      if (m.tipo == 'venta') {
        if (m.detalle != null && m.detalle!.startsWith('Ref:')) {
          digital += m.total;
        } else {
          efectivo += m.total;
        }
      } else if (m.tipo == 'gasto') {
        gastos += m.total;
      }
    }

    setState(() {
      _datos = movimientos.reversed.toList();
      _ventasEfectivo = efectivo;
      _ventasDigital = digital;
      _gastos = gastos;
    });
  }

  void _cambiarFiltro(String nuevoFiltro) {
    if (nuevoFiltro == 'rango') {
      _seleccionarRango();
    } else {
      setState(() {
        _filtro = nuevoFiltro;
        _rangoSeleccionado = null;
      });
      _cargarReporte();
    }
  }

  Future<void> _seleccionarRango() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2023),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.light().copyWith(
            colorScheme: const ColorScheme.light(primary: Colors.indigo, onPrimary: Colors.white),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _filtro = 'rango';
        _rangoSeleccionado = picked;
      });
      _cargarReporte();
    }
  }

  // --- DESCARGA REAL DE CSV ---
  Future<void> _descargarReporteReal() async {
    try {
      String csvData = _servicio.generarReporteCSV(_filtro, rango: _rangoSeleccionado);

      // 1. Obtener carpeta temporal del sistema
      final directory = await getTemporaryDirectory();
      final fecha = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final path = '${directory.path}/Reporte_SweetStock_$fecha.csv';

      // 2. Escribir archivo
      final File file = File(path);
      await file.writeAsString(csvData);

      // 3. Abrir menú de compartir
      await Share.shareXFiles([XFile(path)], text: 'Reporte de Caja ($_filtro)');

    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error al exportar: $e"), backgroundColor: Colors.red)
      );
    }
  }

  void _confirmarCierre() {
    // Mensaje dinámico
    String mensaje = "Esto finalizará el turno actual (HOY).";
    if (_filtro != 'hoy') {
      mensaje = "Estás cerrando caja de un PERIODO PASADO ($_filtro). Asegúrate de que esto es correcto.";
    }

    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("¿Cerrar Caja Definitivamente?"),
          content: Text(mensaje),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
            ElevatedButton(
              onPressed: () {
                // Aquí se conectaría con Firebase 'closures'
                Navigator.pop(ctx);
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("🔒 Cierre Guardado Correctamente"), backgroundColor: Colors.green)
                );
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
              child: const Text("CONFIRMAR CIERRE"),
            )
          ],
        )
    );
  }

  @override
  Widget build(BuildContext context) {
    final currency = NumberFormat.currency(locale: 'es_CO', symbol: '\$', decimalDigits: 0);
    final efectivoEnCaja = _ventasEfectivo - _gastos;
    final totalVentas = _ventasEfectivo + _ventasDigital;
    final esModoCierre = widget.abrirCierreInmediato;

    String textoRango = "RANGO";
    if (_filtro == 'rango' && _rangoSeleccionado != null) {
      textoRango = "${DateFormat('dd/MM').format(_rangoSeleccionado!.start)} - ${DateFormat('dd/MM').format(_rangoSeleccionado!.end)}";
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
          title: Text(esModoCierre ? "Cierre de Caja (Z)" : "Reportes"),
          backgroundColor: esModoCierre ? Colors.red.shade50 : Colors.white,
          foregroundColor: esModoCierre ? Colors.red : Colors.black,
          elevation: 0
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. FILTROS (SIEMPRE VISIBLES)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey.shade200)),
              child: Row(
                  children: [
                    _tabFiltro("HOY", 'hoy'),
                    _tabFiltro("SEMANA", 'semana'),
                    _tabFiltro("MES", 'mes'),
                    _tabFiltro(textoRango, 'rango'),
                  ]
              ),
            ),

            const SizedBox(height: 20),

            // 2. TARJETA DE BALANCE (Roja si es cierre, Negra si es reporte)
            if (esModoCierre)
              _tarjetaCierre(currency, totalVentas, efectivoEnCaja)
            else
              _tarjetaReporte(currency, efectivoEnCaja),

            const SizedBox(height: 20),

            // 3. BOTONES DE ACCIÓN (Solo visibles en Modo Cierre Z)
            if (esModoCierre) ...[
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _descargarReporteReal,
                  icon: const Icon(Icons.download),
                  label: const Text("Descargar Archivo (CSV)"),
                  style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      side: const BorderSide(color: Colors.blue),
                      foregroundColor: Colors.blue,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                ),
              ),
              const SizedBox(height: 15),
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton.icon(
                  onPressed: _confirmarCierre,
                  icon: const Icon(Icons.lock),
                  label: const Text("CERRAR CAJA"),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                ),
              ),
            ],

            const SizedBox(height: 20),

            // 4. LISTA
            Text("Detalle de Movimientos", style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey)),
            const SizedBox(height: 10),

            Container(
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200)),
              child: _datos.isEmpty
                  ? const Padding(padding: EdgeInsets.all(20), child: Center(child: Text("Sin movimientos", style: TextStyle(color: Colors.grey))))
                  : ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _datos.length,
                separatorBuilder: (_,__) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final m = _datos[index];
                  Color color = m.tipo == 'venta' ? Colors.green : m.tipo == 'gasto' ? Colors.red : Colors.blue;
                  return ListTile(
                    dense: true,
                    title: Text(m.nombreProducto, style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(DateFormat('HH:mm').format(m.fecha) + (m.detalle != null ? " • ${m.detalle}" : "")),
                    trailing: Text(
                        m.tipo == 'gasto' ? "-${currency.format(m.total)}" : currency.format(m.total),
                        style: TextStyle(fontWeight: FontWeight.bold, color: color)
                    ),
                  );
                },
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _tarjetaReporte(NumberFormat currency, double efectivoEnCaja) {
    String titulo = "Balance ($_filtro)";
    if (_filtro == 'rango' && _rangoSeleccionado != null) titulo = "Rango Personalizado";

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: const Color(0xFF1a1a1a), borderRadius: BorderRadius.circular(20), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]),
      child: Column(children: [
        Row(children: [const Icon(Icons.pie_chart, color: Colors.white70, size: 20), const SizedBox(width: 10), Text(titulo, style: const TextStyle(color: Colors.white70, fontWeight: FontWeight.bold))]),
        const SizedBox(height: 20),
        _filaBalance("Efectivo", currency.format(efectivoEnCaja), Colors.greenAccent),
        _filaBalance("Digital", currency.format(_ventasDigital), Colors.purpleAccent),
        const Divider(color: Colors.white24),
        _filaBalance("Gastos", "- ${currency.format(_gastos)}", Colors.redAccent, esSmall: true),
      ]),
    );
  }

  Widget _tarjetaCierre(NumberFormat currency, double totalVentas, double efectivoEnCaja) {
    String periodoCierre = _filtro.toUpperCase();
    if (_filtro == 'rango') periodoCierre = "RANGO";

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.red.shade100), boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.05), blurRadius: 10)]),
      child: Column(
        children: [
          Text("CIERRE DE CAJA ($periodoCierre)", style: const TextStyle(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold, letterSpacing: 1)),
          const SizedBox(height: 15),
          _filaResumen("Ventas Totales", currency.format(totalVentas), esBold: true, tamano: 20),
          const Divider(),
          _filaResumen("(+) Efectivo Entrante", currency.format(_ventasEfectivo), color: Colors.green),
          _filaResumen("(-) Gastos Registrados", "- ${currency.format(_gastos)}", color: Colors.red),
          const Divider(),
          _filaResumen("= EFECTIVO EN CAJÓN", currency.format(efectivoEnCaja), esBold: true, color: Colors.black, tamano: 18),
          const SizedBox(height: 15),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(10)),
            child: _filaResumen("Bancos / Digital", currency.format(_ventasDigital), color: Colors.purple),
          ),
        ],
      ),
    );
  }

  Widget _tabFiltro(String titulo, String valor) {
    bool activo = _filtro == valor;
    return Expanded(child: GestureDetector(onTap: () => _cambiarFiltro(valor), child: Container(padding: const EdgeInsets.symmetric(vertical: 10), decoration: BoxDecoration(color: activo ? Colors.indigo : Colors.transparent, borderRadius: BorderRadius.circular(8)), child: Text(titulo, textAlign: TextAlign.center, style: TextStyle(color: activo ? Colors.white : Colors.grey, fontWeight: FontWeight.bold, fontSize: 10)))));
  }
  Widget _filaBalance(String label, String valor, Color color, {bool esSmall = false}) { return Padding(padding: const EdgeInsets.only(bottom: 8), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Row(children: [Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)), const SizedBox(width: 10), Text(label, style: const TextStyle(color: Colors.white70))]), Text(valor, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: esSmall ? 14 : 18))])); }
  Widget _filaResumen(String label, String valor, {bool esBold = false, Color? color, double tamano = 14}) { return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(color: Colors.grey.shade700, fontSize: 14)), Text(valor, style: TextStyle(fontWeight: esBold ? FontWeight.bold : FontWeight.normal, color: color ?? Colors.black, fontSize: tamano))])); }
}