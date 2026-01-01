class Movimiento {
  String id;
  String tipo; // 'entrada', 'venta', 'gasto'
  String nombreProducto;
  int cantidad;
  double total; // Precio de Venta Total (lo que pagó el cliente)
  double costo; // <--- NUEVO CAMPO: Costo Total (lo que te costó a ti)
  DateTime fecha;
  String? detalle;
  int? nroVenta;

  Movimiento({
    required this.id,
    required this.tipo,
    required this.nombreProducto,
    required this.cantidad,
    required this.total,
    this.costo = 0.0, // <--- Inicializamos en 0 por defecto
    required this.fecha,
    this.detalle,
    this.nroVenta,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tipo': tipo,
      'nombreProducto': nombreProducto,
      'cantidad': cantidad,
      'total': total,
      'costo': costo, // <--- Guardamos el costo histórico
      'fecha': fecha.millisecondsSinceEpoch,
      'detalle': detalle,
      'nroVenta': nroVenta,
    };
  }

  factory Movimiento.fromMap(Map<String, dynamic> map) {
    return Movimiento(
      id: map['id'] ?? '',
      tipo: map['tipo'] ?? '',
      nombreProducto: map['nombreProducto'] ?? '',
      cantidad: map['cantidad'] ?? 0,
      total: (map['total'] ?? 0).toDouble(),
      costo: (map['costo'] ?? 0).toDouble(), // <--- Leemos, si no existe (antiguos) será 0
      fecha: DateTime.fromMillisecondsSinceEpoch(map['fecha'] ?? 0),
      detalle: map['detalle'],
      nroVenta: map['nroVenta'],
    );
  }
}