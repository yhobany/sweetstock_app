import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'producto_modelo.dart';
import 'movimiento_modelo.dart';
import 'usuario_modelo.dart';
import 'package:flutter/material.dart';

class ServicioFirebase {
  static final ServicioFirebase _instancia = ServicioFirebase._interno();
  factory ServicioFirebase() => _instancia;
  ServicioFirebase._interno();

  final FirebaseAuth _auth = FirebaseAuth.instance;
  final CollectionReference _productosRef = FirebaseFirestore.instance.collection('productos');
  final CollectionReference _movimientosRef = FirebaseFirestore.instance.collection('movimientos');
  final CollectionReference _usuariosRef = FirebaseFirestore.instance.collection('usuarios');

  // Referencia para el contador de facturas
  final DocumentReference _contadorRef = FirebaseFirestore.instance.collection('configuracion').doc('contadores');

  User? get usuarioActual => _auth.currentUser;
  String _rolEnMemoria = 'cajero';

  // --- SEGURIDAD ---
  Future<void> iniciarSesion(String email, String password) async {
    UserCredential credencial = await _auth.signInWithEmailAndPassword(email: email.trim(), password: password.trim());
    bool tienePermiso = await _verificarAcceso(credencial.user);
    if (!tienePermiso) {
      await _auth.signOut();
      throw FirebaseAuthException(code: 'user-disabled-by-admin', message: 'Tu cuenta está pendiente de aprobación o ha sido bloqueada.');
    }
  }

  Future<void> registrarUsuario(String email, String password) async {
    UserCredential credencial = await _auth.createUserWithEmailAndPassword(email: email.trim(), password: password.trim());
    User? user = credencial.user;
    if (user != null) {
      bool esMaster = email == 'admin@sweetstock.com';
      UsuarioSistema nuevoUsuario = UsuarioSistema(id: user.uid, email: email, rol: esMaster ? 'admin' : 'cajero', activo: esMaster ? true : false);
      await _usuariosRef.doc(user.uid).set(nuevoUsuario.toMap());
      if (!esMaster) { await _auth.signOut(); } else { _rolEnMemoria = 'admin'; }
    }
  }

  Future<void> recuperarContrasena(String email) async { await _auth.sendPasswordResetEmail(email: email.trim()); }

  Future<bool> _verificarAcceso(User? user) async {
    if (user == null) return false;
    DocumentSnapshot doc = await _usuariosRef.doc(user.uid).get();
    if (doc.exists) {
      Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
      _rolEnMemoria = data['rol'] ?? 'cajero';
      return data['activo'] ?? false;
    }
    return false;
  }

  Future<void> cerrarSesion() async { await _auth.signOut(); _rolEnMemoria = 'cajero'; }
  bool esAdmin() { return _rolEnMemoria == 'admin'; }

  // --- GESTIÓN ---
  Stream<List<UsuarioSistema>> obtenerUsuariosStream() { return _usuariosRef.snapshots().map((s) => s.docs.map((d) => UsuarioSistema.fromMap(d.data() as Map<String, dynamic>)).toList()); }
  Future<void> cambiarRolUsuario(String id, String nuevoRol) async { await _usuariosRef.doc(id).update({'rol': nuevoRol}); }
  Future<void> cambiarEstadoUsuario(String id, bool activo) async { await _usuariosRef.doc(id).update({'activo': activo}); }
  Future<void> eliminarUsuarioDb(String id) async { await _usuariosRef.doc(id).delete(); }

  // --- PRODUCTOS ---
  Stream<List<Producto>> obtenerProductosStream() { return _productosRef.snapshots().map((snapshot) => snapshot.docs.map((doc) => Producto.fromMap(doc.data() as Map<String, dynamic>)).toList()); }
  Future<void> guardarProducto(Producto p) async { await _productosRef.doc(p.id).set(p.toMap()); }
  Future<void> eliminarProducto(String id) async { await _productosRef.doc(id).delete(); }
  Future<void> registrarMovimiento(Movimiento m) async { await _movimientosRef.doc(m.id).set(m.toMap()); }

  Future<void> registrarGasto(double monto, String motivo) async {
    // Nota: Los gastos operativos (OPEX) no tienen "costo de inventario", por eso 'costo' se deja en 0 (default del modelo)
    final m = Movimiento(id: DateTime.now().millisecondsSinceEpoch.toString(), tipo: 'gasto', nombreProducto: 'GASTO OPERATIVO', cantidad: 1, total: monto, fecha: DateTime.now(), detalle: motivo);
    await registrarMovimiento(m);
  }

  // --- VENTA CON CONSECUTIVO Y COSTO ---
  Future<void> realizarVenta(List<ItemCarrito> carrito, String metodo, String? referencia) async {
    final batch = FirebaseFirestore.instance.batch();
    final fecha = DateTime.now();
    String detallePago = metodo;
    if (referencia != null && referencia.isNotEmpty) detallePago = "Ref: $referencia";

    // 1. Transacción para obtener consecutivo único (1, 2, 3...)
    int nroFactura = await FirebaseFirestore.instance.runTransaction((transaction) async {
      DocumentSnapshot snapshot = await transaction.get(_contadorRef);
      int nuevoConsecutivo = 1;
      if (snapshot.exists) {
        int actual = (snapshot.data() as Map<String, dynamic>)['ultimoNroVenta'] ?? 0;
        nuevoConsecutivo = actual + 1;
        transaction.update(_contadorRef, {'ultimoNroVenta': nuevoConsecutivo});
      } else {
        transaction.set(_contadorRef, {'ultimoNroVenta': 1});
      }
      return nuevoConsecutivo;
    });

    // 2. Guardar venta con el número Y EL COSTO
    for (var item in carrito) {
      final movId = "${fecha.millisecondsSinceEpoch}_${item.producto.id}";
      final movRef = _movimientosRef.doc(movId);

      // Calculamos el costo histórico de esta venta específica
      double costoTotalVenta = item.producto.costo * item.cantidad;

      final movimiento = Movimiento(
          id: movId,
          tipo: 'venta',
          nombreProducto: item.producto.nombre,
          cantidad: item.cantidad,
          total: item.subtotal, // Precio Venta
          costo: costoTotalVenta, // <--- NUEVO: Costo de Adquisición (COGS)
          fecha: fecha,
          detalle: detallePago,
          nroVenta: nroFactura
      );

      batch.set(movRef, movimiento.toMap());
      final prodRef = _productosRef.doc(item.producto.id);
      batch.update(prodRef, {'stock': FieldValue.increment(-item.cantidad)});
    }
    await batch.commit();
  }

  Stream<List<Movimiento>> obtenerUltimosMovimientosStream() {
    return _movimientosRef.orderBy('fecha', descending: true).limit(20).snapshots().map((s) => s.docs.map((d) => Movimiento.fromMap(d.data() as Map<String, dynamic>)).toList());
  }

  // --- CORRECCIÓN FECHAS VENCIDAS (Normalización) ---
  Future<Map<String, double>> obtenerMetricas() async {
    final prodSnap = await _productosRef.get();
    final productos = prodSnap.docs.map((d) => Producto.fromMap(d.data() as Map<String, dynamic>)).toList();
    double valorBodega = 0, valorVencido = 0, ventasHoy = 0;

    // Normalizamos "Hoy" a medianoche para comparar manzanas con manzanas
    final ahora = DateTime.now();
    final hoySinHora = DateTime(ahora.year, ahora.month, ahora.day);

    for (var p in productos) {
      bool vencido = false;
      if (p.fechaVencimiento != null) {
        try {
          DateTime fVenc = DateTime.parse(p.fechaVencimiento!);
          DateTime fVencSinHora = DateTime(fVenc.year, fVenc.month, fVenc.day);
          // Si la fecha de vencimiento es ANTES de hoy (ayer o antes), está vencido
          if (fVencSinHora.isBefore(hoySinHora)) vencido = true;
        } catch (_) {}
      }
      if (vencido) valorVencido += (p.precio * p.stock); else valorBodega += (p.precio * p.stock);
    }

    final inicioDia = hoySinHora.millisecondsSinceEpoch;
    final movSnap = await _movimientosRef.where('fecha', isGreaterThanOrEqualTo: inicioDia).get();
    for (var doc in movSnap.docs) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['tipo'] == 'venta') ventasHoy += (data['total'] ?? 0);
    }
    return { "valorBodega": valorBodega, "ventasHoy": ventasHoy, "valorVencido": valorVencido };
  }

  Future<List<Movimiento>> obtenerReporte(String periodo, {DateTimeRange? rangoPersonalizado}) async {
    final now = DateTime.now();
    DateTime inicio = DateTime(now.year, now.month, now.day, 0, 0, 0);
    DateTime fin = DateTime(now.year, now.month, now.day, 23, 59, 59);

    if (periodo == 'rango' && rangoPersonalizado != null) {
      inicio = DateTime(rangoPersonalizado.start.year, rangoPersonalizado.start.month, rangoPersonalizado.start.day, 0, 0, 0);
      fin = DateTime(rangoPersonalizado.end.year, rangoPersonalizado.end.month, rangoPersonalizado.end.day, 23, 59, 59);
    } else if (periodo == 'semana') {
      inicio = inicio.subtract(Duration(days: now.weekday - 1));
      inicio = DateTime(inicio.year, inicio.month, inicio.day, 0, 0, 0);
    } else if (periodo == 'mes') {
      inicio = DateTime(now.year, now.month, 1);
    }

    Query query = _movimientosRef
        .where('fecha', isGreaterThanOrEqualTo: inicio.millisecondsSinceEpoch)
        .where('fecha', isLessThanOrEqualTo: fin.millisecondsSinceEpoch);

    final snapshot = await query.get();
    final lista = snapshot.docs.map((d) => Movimiento.fromMap(d.data() as Map<String, dynamic>)).toList();
    lista.sort((a, b) => b.fecha.compareTo(a.fecha));
    return lista;
  }

  Future<String> generarReporteCSV(String periodo, {DateTimeRange? rango}) async {
    final movimientos = await obtenerReporte(periodo, rangoPersonalizado: rango);
    double totalEfectivo = 0, totalDigital = 0, totalGastos = 0;
    StringBuffer csv = StringBuffer();
    csv.writeln("Fecha,Factura,Tipo,Producto,Cantidad,Total,Costo,Detalle"); // <-- Agregamos columna Costo
    for (var h in movimientos) {
      if (h.tipo == 'venta') {
        if (h.detalle != null && (h.detalle!.startsWith('Ref:') || h.detalle == 'Nequi' || h.detalle == 'Tarjeta')) totalDigital += h.total;
        else totalEfectivo += h.total;
      } else if (h.tipo == 'gasto') totalGastos += h.total;
      String fecha = DateFormat('yyyy-MM-dd HH:mm').format(h.fecha);
      String factura = h.nroVenta != null ? "#${h.nroVenta}" : "-";
      // Exportamos también el costo
      csv.writeln("$fecha,$factura,${h.tipo},${h.nombreProducto},${h.cantidad},${h.total},${h.costo},${h.detalle ?? ''}");
    }
    csv.writeln("\nRESUMEN: Efectivo=$totalEfectivo | Digital=$totalDigital | Gastos=$totalGastos");
    return csv.toString();
  }
}