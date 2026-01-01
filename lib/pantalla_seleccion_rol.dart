import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pantalla_dashboard.dart';
import 'pantalla_caja.dart';
import 'servicio_firebase.dart';
import 'pantalla_login.dart';

class PantallaSeleccionRol extends StatelessWidget {
  const PantallaSeleccionRol({super.key});

  @override
  Widget build(BuildContext context) {
    final servicio = ServicioFirebase();
    final usuario = servicio.usuarioActual;
    final esAdmin = servicio.esAdmin(); // Verificamos si tiene permisos

    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        actions: [
          TextButton.icon(
            icon: const Icon(Icons.logout, color: Colors.grey),
            label: const Text("Salir", style: TextStyle(color: Colors.grey)),
            onPressed: () {
              servicio.cerrarSesion();
              Navigator.pushReplacement(context, MaterialPageRoute(builder: (ctx) => const PantallaLogin()));
            },
          )
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Identidad Usuario
            Container(width: 80, height: 80, decoration: BoxDecoration(color: const Color(0xFFE91E63), borderRadius: BorderRadius.circular(20)), child: const Icon(Icons.person, size: 40, color: Colors.white)),
            const SizedBox(height: 20),
            Text(usuario?.email ?? "Usuario", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
            Text(esAdmin ? "Rol: ADMINISTRADOR" : "Rol: CAJERO", style: TextStyle(color: esAdmin ? Colors.indigo : Colors.grey, fontWeight: FontWeight.bold)),
            const SizedBox(height: 50),

            // BOTÓN 1: CAJA (Acceso Universal)
            _botonRol(
                context,
                titulo: "Caja / Ventas",
                subtitulo: "Facturación y Gastos",
                icono: Icons.shopping_cart_rounded,
                colorIcono: Colors.green,
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaCaja()))
            ),

            const SizedBox(height: 20),

            // BOTÓN 2: ADMIN (Protegido)
            _botonRol(
                context,
                titulo: "Administrador",
                subtitulo: "Inventario y Reportes",
                icono: Icons.admin_panel_settings_rounded,
                colorIcono: esAdmin ? Colors.indigo : Colors.grey,
                bloqueado: !esAdmin, // <--- CANDADO AQUÍ
                onTap: () {
                  if (esAdmin) {
                    Navigator.push(context, MaterialPageRoute(builder: (context) => const PantallaDashboard()));
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("⛔ Acceso Denegado: Requiere permisos de Administrador"), backgroundColor: Colors.red));
                  }
                }
            ),
          ],
        ),
      ),
    );
  }

  Widget _botonRol(BuildContext context, {required String titulo, String? subtitulo, required IconData icono, required Color colorIcono, required VoidCallback onTap, bool bloqueado = false}) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade200), boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 10, offset: const Offset(0, 5))]),
        child: Row(
          children: [
            Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(color: bloqueado ? Colors.grey.shade100 : colorIcono.withOpacity(0.1), shape: BoxShape.circle), child: Icon(bloqueado ? Icons.lock : icono, color: bloqueado ? Colors.grey : colorIcono, size: 28)),
            const SizedBox(width: 20),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(titulo, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: bloqueado ? Colors.grey : Colors.black87)),
              if(subtitulo != null) Text(subtitulo, style: const TextStyle(fontSize: 12, color: Colors.grey))
            ]),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade400)
          ],
        ),
      ),
    );
  }
}