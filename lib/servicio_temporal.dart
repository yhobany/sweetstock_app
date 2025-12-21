import 'package:flutter/material.dart';
import 'producto_modelo.dart';
import 'movimiento_modelo.dart';
import 'package:intl/intl.dart';

class ServicioTemporal {
  static final ServicioTemporal _instancia = ServicioTemporal._interno();
  factory ServicioTemporal() => _instancia;
  ServicioTemporal._interno();

  // INVENTARIO INICIAL
  final List<Producto> _inventario = [
    Producto(id: '1', nombre: 'Chocolatina Jet Leche', codigoBarras: '7702007001', precio: 600, costo: 450, stock: 24, fechaVencimiento: '2025-12-01'),
    Producto(id: '2', nombre: 'Gomitas Trululu Aros', codigoBarras: '7702007002', precio: 2500, costo: 1800, stock: 15, fechaVencimiento: '2024-06-15'),
    Producto(id: '3', nombre: 'Papas Margarita Pollo', codigoBarras: '7702007003', precio: 1800, costo: 1400, stock: 10, fechaVencimiento: '2024-02-28'),
    Producto(id: '4', nombre: 'Coca Cola 400ml', codigoBarras: '7702007004', precio: 3000, costo: 2400, stock: 50, fechaVencimiento: '2025-01-01'),
    Producto(id: '5', nombre: 'Galletas Festival', codigoBarras: '7702007005', precio: 1200, costo: 900, stock: 5, fechaVencimiento: '2023-12-01'),
    // Producto vencido para pruebas
    Producto(id: '99', nombre: 'Leche Vencida (Prueba)', codigoBarras: '000000', precio: 2000, costo: 1500, stock: 5, fechaVencimiento: '2023-01-01'),
  ];

  final List<Movimiento> _historial = [];

  List<Producto> obtenerProductos() => _inventario;

  List<Producto> obtenerProductosRiesgo() {
    final hoy = DateTime.now();
    final limiteAlerta = hoy.add(const Duration(days: 7));
    return _inventario.where((p) {
      if (p.fechaVencimiento == null) return false;
      try {
        final fecha = DateTime.parse(p.fechaVencimiento!);
        return fecha.isBefore(limiteAlerta);
      } catch (e) { return false; }
    }).toList();
  }

  List<Movimiento> obtenerReporte(String periodo, {DateTimeRange? rangoPersonalizado}) {
    final now = DateTime.now();
    DateTime inicio = DateTime(now.year, now.month, now.day);
    DateTime fin = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);

    if (periodo == 'rango' && rangoPersonalizado != null) {
      inicio = rangoPersonalizado.start;
      fin = DateTime(rangoPersonalizado.end.year, rangoPersonalizado.end.month, rangoPersonalizado.end.day, 23, 59, 59, 999);
    } else if (periodo == 'semana') {
      inicio = inicio.subtract(Duration(days: now.weekday - 1));
    } else if (periodo == 'mes') {
      inicio = DateTime(now.year, now.month, 1);
    }

    return _historial.where((m) =>
    m.fecha.isAfter(inicio.subtract(const Duration(seconds: 1))) &&
        m.fecha.isBefore(fin.add(const Duration(seconds: 1)))
    ).toList();
  }

  // --- GENERADOR CSV CON TOTALES FINANCIEROS ---
  String generarReporteCSV(String periodo, {DateTimeRange? rango}) {
    final movimientos = obtenerReporte(periodo, rangoPersonalizado: rango);

    double totalEfectivo = 0;
    double totalDigital = 0;
    double totalGastos = 0;

    StringBuffer csv = StringBuffer();

    csv.writeln("REPORTE SWEETSTOCK");
    csv.writeln("Periodo: $periodo");
    csv.writeln("Generado: ${DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())}");
    csv.writeln(""); // Espacio

    csv.writeln("Fecha,Tipo,Producto,Cantidad,Total,Detalle");

    for (var h in movimientos) {
      // Cálculos de acumulados
      if (h.tipo == 'venta') {
        if (h.detalle != null && h.detalle!.startsWith('Ref:')) {
          totalDigital += h.total;
        } else {
          totalEfectivo += h.total;
        }
      } else if (h.tipo == 'gasto') {
        totalGastos += h.total;
      }

      String fecha = DateFormat('yyyy-MM-dd HH:mm').format(h.fecha);
      String prod = h.nombreProducto.replaceAll(',', '');
      String detalle = (h.detalle ?? '').replaceAll(',', '');

      csv.writeln("$fecha,${h.tipo},$prod,${h.cantidad},${h.total},$detalle");
    }

    // BLOQUE DE TOTALES AL FINAL
    csv.writeln("");
    csv.writeln("--- RESUMEN FINANCIERO ---");
    csv.writeln("Ventas Efectivo,${totalEfectivo}");
    csv.writeln("Ventas Digital,${totalDigital}");
    csv.writeln("(-) Gastos Operativos,${totalGastos}");
    csv.writeln("TOTAL NETO EN CAJA,${totalEfectivo - totalGastos}");
    csv.writeln("Ventas Brutas Totales,${totalEfectivo + totalDigital}");

    return csv.toString();
  }

  Map<String, double> obtenerMetricas() {
    final now = DateTime.now();
    final hoy = DateTime(now.year, now.month, now.day);
    double valorBodega = 0;
    double valorVencido = 0;

    for (var item in _inventario) {
      bool vencido = false;
      if (item.fechaVencimiento != null) {
        try {
          final fechaVenc = DateTime.parse(item.fechaVencimiento!);
          if (fechaVenc.isBefore(hoy)) vencido = true;
        } catch (e) {}
      }
      double valorTotalItem = item.precio * item.stock;
      if (vencido) valorVencido += valorTotalItem;
      else valorBodega += valorTotalItem;
    }

    final inicioDia = DateTime(now.year, now.month, now.day);
    double ventasHoy = _historial
        .where((m) => m.tipo == 'venta' && m.fecha.isAfter(inicioDia.subtract(const Duration(seconds: 1))))
        .fold(0, (sum, m) => sum + m.total);

    return { "valorBodega": valorBodega, "ventasHoy": ventasHoy, "valorVencido": valorVencido };
  }

  void realizarVenta(List<ItemCarrito> carrito, String metodoPago, String? referencia) {
    for (var item in carrito) {
      var productoReal = _inventario.firstWhere((p) => p.id == item.producto.id);
      if (productoReal.stock >= item.cantidad) {
        productoReal.stock -= item.cantidad;
      }
      _historial.add(Movimiento(
          id: DateTime.now().millisecondsSinceEpoch.toString() + item.producto.id,
          tipo: 'venta',
          nombreProducto: item.producto.nombre,
          cantidad: item.cantidad,
          total: item.subtotal,
          fecha: DateTime.now(),
          detalle: referencia != null ? 'Ref: $referencia' : metodoPago
      ));
    }
  }

  void registrarGasto(double monto, String motivo) {
    _historial.add(Movimiento(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        tipo: 'gasto',
        nombreProducto: 'GASTO OPERATIVO',
        cantidad: 1,
        total: monto,
        fecha: DateTime.now(),
        detalle: motivo
    ));
  }

  void registrarEntrada(Producto p, int cantidadAgregada) {
    final index = _inventario.indexWhere((existe) => existe.codigoBarras == p.codigoBarras);
    if (index == -1) {
      p.stock = cantidadAgregada;
      _inventario.add(p);
    } else {
      _inventario[index].stock += cantidadAgregada;
    }

    _historial.add(Movimiento(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        tipo: 'entrada',
        nombreProducto: p.nombre,
        cantidad: cantidadAgregada,
        total: p.costo * cantidadAgregada,
        fecha: DateTime.now(),
        detalle: 'Compra Inventario'
    ));
  }

  List<Movimiento> obtenerUltimosMovimientos() {
    _historial.sort((a, b) => b.fecha.compareTo(a.fecha));
    return _historial.take(10).toList();
  }

  void eliminarProducto(String id) => _inventario.removeWhere((p) => p.id == id);

  void actualizarProducto(Producto p) {
    final index = _inventario.indexWhere((prod) => prod.id == p.id);
    if (index != -1) _inventario[index] = p;
  }
}