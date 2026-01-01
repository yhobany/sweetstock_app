class Producto {
  String id;
  String nombre;
  String codigoBarras;
  double precio;
  double costo;
  int stock;
  String? fechaVencimiento;
  String? imagenUrl;

  Producto({
    required this.id,
    required this.nombre,
    required this.codigoBarras,
    required this.precio,
    required this.costo,
    required this.stock,
    this.fechaVencimiento,
    this.imagenUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'nombre': nombre,
      'codigoBarras': codigoBarras,
      'precio': precio,
      'costo': costo,
      'stock': stock,
      'fechaVencimiento': fechaVencimiento,
      'imagenUrl': imagenUrl,
    };
  }

  factory Producto.fromMap(Map<String, dynamic> map) {
    return Producto(
      id: map['id'] ?? '',
      nombre: map['nombre'] ?? '',
      codigoBarras: map['codigoBarras'] ?? '',
      precio: (map['precio'] ?? 0).toDouble(),
      costo: (map['costo'] ?? 0).toDouble(),
      stock: (map['stock'] ?? 0).toInt(),
      fechaVencimiento: map['fechaVencimiento'],
      imagenUrl: map['imagenUrl'],
    );
  }
}

// --- CLASE QUE FALTABA PARA QUE LA CAJA COMPILE ---
class ItemCarrito {
  final Producto producto;
  int cantidad;

  ItemCarrito({required this.producto, required this.cantidad});

  double get subtotal => producto.precio * cantidad;
}