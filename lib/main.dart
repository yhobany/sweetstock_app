import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'pantalla_seleccion_rol.dart'; // <--- IMPORTANTE

// Variable global para cámaras
List<CameraDescription> cameras = [];

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    cameras = await availableCameras();
  } on CameraException catch (e) {
    debugPrint('Error cámara: $e');
    cameras = [];
  }
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
    // Simular carga de 2 segundos y pasar a selección de rol
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const PantallaSeleccionRol())
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.inventory_2_rounded, size: 80, color: Color(0xFFE91E63)),
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: Color(0xFFE91E63)),
          ],
        ),
      ),
    );
  }
}