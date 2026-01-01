import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'servicio_firebase.dart';
import 'pantalla_seleccion_rol.dart';

class PantallaLogin extends StatefulWidget {
  const PantallaLogin({super.key});

  @override
  State<PantallaLogin> createState() => _PantallaLoginState();
}

class _PantallaLoginState extends State<PantallaLogin> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _servicio = ServicioFirebase();

  bool _cargando = false;
  bool _ocultarPassword = true;
  bool _esRegistro = false;

  void _submit() async {
    if (_emailCtrl.text.isEmpty || (_passCtrl.text.isEmpty && !_esRegistro)) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Completa los campos"), backgroundColor: Colors.orange));
      return;
    }

    setState(() => _cargando = true);

    try {
      if (_esRegistro) {
        // REGISTRO
        if (_passCtrl.text.length < 6) throw Exception("La contraseña debe tener al menos 6 caracteres");
        await _servicio.registrarUsuario(_emailCtrl.text, _passCtrl.text);

        if (mounted) {
          // Volvemos a modo Login y mostramos alerta de espera
          setState(() {
            _esRegistro = false;
            _passCtrl.clear();
          });

          showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                icon: const Icon(Icons.mark_email_read, size: 50, color: Colors.indigo),
                title: const Text("Solicitud Enviada"),
                content: const Text("Tu cuenta ha sido creada exitosamente.\n\n🔒 Por seguridad, el Administrador debe APROBAR tu acceso antes de que puedas ingresar."),
                actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text("Entendido"))],
              )
          );
        }
      } else {
        // LOGIN
        await _servicio.iniciarSesion(_emailCtrl.text, _passCtrl.text);
        if (mounted) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const PantallaSeleccionRol()));
        }
      }
    } catch (e) {
      if (mounted) {
        String mensaje = "Error de conexión";
        if (e.toString().contains('user-disabled-by-admin')) mensaje = "🔒 Acceso pendiente de aprobación o bloqueado.";
        if (e.toString().contains('user-not-found')) mensaje = "Usuario no encontrado";
        if (e.toString().contains('wrong-password')) mensaje = "Contraseña incorrecta";
        if (e.toString().contains('email-already-in-use')) mensaje = "El correo ya está registrado";

        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(mensaje), backgroundColor: Colors.red));
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  void _olvideContrasena() async {
    if (_emailCtrl.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Escribe tu correo arriba para recuperar la clave"), backgroundColor: Colors.orange));
      return;
    }
    try {
      await _servicio.recuperarContrasena(_emailCtrl.text);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("📧 Se envió un correo para restablecer tu contraseña"), backgroundColor: Colors.green));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error al enviar correo"), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(30),
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 500),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(color: (_esRegistro ? Colors.indigo : const Color(0xFFE91E63)).withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(_esRegistro ? Icons.person_add : Icons.lock_person_rounded, size: 60, color: _esRegistro ? Colors.indigo : const Color(0xFFE91E63)),
              ),
              const SizedBox(height: 20),
              Text(_esRegistro ? "Solicitar Acceso" : "Bienvenido", style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.grey.shade800)),
              Text(_esRegistro ? "Regístrate y espera aprobación" : "Inicia sesión para continuar", style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 40),

              TextField(controller: _emailCtrl, keyboardType: TextInputType.emailAddress, decoration: InputDecoration(labelText: "Correo Electrónico", prefixIcon: const Icon(Icons.email_outlined), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50)),
              const SizedBox(height: 20),

              TextField(controller: _passCtrl, obscureText: _ocultarPassword, decoration: InputDecoration(labelText: "Contraseña", prefixIcon: const Icon(Icons.key_outlined), suffixIcon: IconButton(icon: Icon(_ocultarPassword ? Icons.visibility : Icons.visibility_off), onPressed: () => setState(() => _ocultarPassword = !_ocultarPassword)), border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)), filled: true, fillColor: Colors.grey.shade50)),

              if (!_esRegistro)
                Align(alignment: Alignment.centerRight, child: TextButton(onPressed: _olvideContrasena, child: const Text("¿Olvidaste tu contraseña?", style: TextStyle(color: Colors.grey)))),

              const SizedBox(height: 20),

              SizedBox(width: double.infinity, height: 55, child: ElevatedButton(onPressed: _cargando ? null : _submit, style: ElevatedButton.styleFrom(backgroundColor: _esRegistro ? Colors.indigo : const Color(0xFFE91E63), foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: _cargando ? const CircularProgressIndicator(color: Colors.white) : Text(_esRegistro ? "SOLICITAR REGISTRO" : "INGRESAR", style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)))),

              const SizedBox(height: 20),
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text(_esRegistro ? "¿Ya tienes cuenta?" : "¿Nuevo empleado?"), TextButton(onPressed: () => setState(() => _esRegistro = !_esRegistro), child: Text(_esRegistro ? "Inicia Sesión" : "Regístrate aquí", style: TextStyle(fontWeight: FontWeight.bold, color: _esRegistro ? Colors.indigo : const Color(0xFFE91E63))))])
            ],
          ),
        ),
      ),
    );
  }
}