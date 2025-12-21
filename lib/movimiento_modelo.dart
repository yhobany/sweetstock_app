class Movimiento {
  final String id;
  final String tipo; // 'venta', 'gasto', 'entrada'
  final String nombreProducto;
  final double total; // Dinero involucrado
  final int cantidad;
  final DateTime fecha;
  final String? detalle; // 'Efectivo', 'Ref: 1234', 'Pago Proveedor'

  Movimiento({
    required this.id,
    required this.tipo,
    required this.nombreProducto,
    required this.total,
    required this.cantidad,
    required this.fecha,
    this.detalle,
  });
}