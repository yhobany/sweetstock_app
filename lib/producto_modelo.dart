class Producto {
  final String id;
  final String nombre;
  final String codigoBarras;
  final double precio; // Precio de Venta al público
  final double costo;  // NUEVO: Costo de adquisición unitario
  int stock;
  final String? fechaVencimiento;

  Producto({
    required this.id,
    required this.nombre,
    required this.codigoBarras,
    required this.precio,
    this.costo = 0, // Por defecto 0 si es antiguo
    required this.stock,
    this.fechaVencimiento,
  });
}

class ItemCarrito {
  final Producto producto;
  int cantidad;

  ItemCarrito({required this.producto, this.cantidad = 1});

  double get subtotal => producto.precio * cantidad;
}