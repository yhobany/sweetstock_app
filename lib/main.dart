import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart'; // <--- Importante
import 'firebase_options.dart';
import 'pantalla_seleccion_rol.dart';
import 'pantalla_login.dart'; // <--- Importante

List<CameraDescription> cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  try { cameras = await availableCameras(); }
  on CameraException catch (e) { debugPrint('Error cámara: $e'); cameras = []; }

  runApp(const SweetStockApp());
}

class SweetStockApp extends StatelessWidget {
  const SweetStockApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SweetStock',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFFE91E63)),
        textTheme: GoogleFonts.interTextTheme(),
      ),
      home: const PantallaCarga(),
    );
  }
}

class PantallaCarga extends StatefulWidget {
  const PantallaCarga({super.key});
  @override
  State<PantallaCarga> createState() => _PantallaCargaState();
}

class _PantallaCargaState extends State<PantallaCarga> {
  @override
  void initState() {
    super.initState();
    _verificarSesion();
  }

  void _verificarSesion() async {
    await Future.delayed(const Duration(seconds: 2)); // Efecto visual

    // Verificamos si hay usuario guardado
    User? usuario = FirebaseAuth.instance.currentUser;

    if (mounted) {
      if (usuario != null) {
        // Si ya entró antes, vamos directo al menú
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const PantallaSeleccionRol()));
      } else {
        // Si no, al login
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => const PantallaLogin()));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.cloud_done, size: 80, color: Color(0xFFE91E63)),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: Color(0xFFE91E63)),
            const SizedBox(height: 10),
            const Text("Conectando SweetStock...", style: TextStyle(color: Colors.grey))
          ],
        ),
      ),
    );
  }
}