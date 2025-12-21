import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pantalla_dashboard.dart';
import 'pantalla_caja.dart';

class PantallaSeleccionRol extends StatelessWidget {
  const PantallaSeleccionRol({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Logo / Identidad
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                  color: const Color(0xFFE91E63),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(color: Colors.pink.withOpacity(0.3), blurRadius: 15, offset: const Offset(0, 10))
                  ]
              ),
              child: const Icon(Icons.inventory_2_rounded, size: 50, color: Colors.white),
            ),
            const SizedBox(height: 20),
            Text("SweetStock", style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
            const Text("Selecciona tu perfil", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 60),

            // BOTÓN 1: CAJA (Ventas)
            _botonRol(
                context,
                titulo: "Caja / Ventas",
                icono: Icons.shopping_cart_rounded,
                colorIcono: Colors.green,
                destino: const PantallaCaja()
            ),

            const SizedBox(height: 20),

            // BOTÓN 2: ADMIN (Gerente)
            _botonRol(
                context,
                titulo: "Administrador",
                icono: Icons.admin_panel_settings_rounded,
                colorIcono: Colors.indigo,
                destino: const PantallaDashboard()
            ),
          ],
        ),
      ),
    );
  }

  Widget _botonRol(BuildContext context, {required String titulo, required IconData icono, required Color colorIcono, required Widget destino}) {
    return InkWell(
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => destino)),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: Colors.grey.shade200),
            boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 10, offset: const Offset(0, 5))]
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: colorIcono.withOpacity(0.1), shape: BoxShape.circle),
              child: Icon(icono, color: colorIcono, size: 28),
            ),
            const SizedBox(width: 20),
            Text(titulo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.black87)),
            const Spacer(),
            Icon(Icons.arrow_forward_ios_rounded, size: 16, color: Colors.grey.shade400)
          ],
        ),
      ),
    );
  }
}