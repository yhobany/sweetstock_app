import 'dart:io';
import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_cropper/image_cropper.dart';

class PantallaCamara extends StatefulWidget {
  final CameraDescription camera;
  final bool soloEvidencia;

  const PantallaCamara({
    super.key,
    required this.camera,
    this.soloEvidencia = false
  });

  @override
  State<PantallaCamara> createState() => _PantallaCamaraState();
}

class _PantallaCamaraState extends State<PantallaCamara> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  final TextRecognizer _textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);

  bool _isScanning = false;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.high,
      enableAudio: false,
    );
    _initializeControllerFuture = _controller.initialize();
  }

  @override
  void dispose() {
    _controller.dispose();
    _textRecognizer.close();
    super.dispose();
  }

  Future<void> _capturar() async {
    if (_isScanning) return;

    try {
      setState(() => _isScanning = true);
      await _initializeControllerFuture;

      final image = await _controller.takePicture();

      if (widget.soloEvidencia) {
        if (!mounted) return;
        Navigator.pop(context, image.path);
        return;
      }

      // --- SECCIÓN CORREGIDA: ELIMINAMOS aspectRatioPresets ---
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: image.path,
        // Eliminamos 'aspectRatioPresets' temporalmente para desbloquear la compilación.
        // El usuario podrá recortar libremente.
        uiSettings: [
          AndroidUiSettings(
              toolbarTitle: 'Recortar Imagen',
              toolbarColor: const Color(0xFFE91E63),
              toolbarWidgetColor: Colors.white,
              initAspectRatio: CropAspectRatioPreset.original,
              lockAspectRatio: false
          ),
          IOSUiSettings(
            title: 'Recortar Imagen',
          ),
        ],
      );
      // -------------------------------------------------------

      if (croppedFile == null) {
        setState(() => _isScanning = false);
        return;
      }

      final inputImage = InputImage.fromFilePath(croppedFile.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      if (!mounted) return;

      String textoCrudo = recognizedText.text;
      List<String> posiblesFechas = _buscarFechas(textoCrudo);

      _mostrarResultados(textoCrudo, posiblesFechas);

    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error al procesar la imagen.'))
        );
      }
    } finally {
      if (mounted && !widget.soloEvidencia) setState(() => _isScanning = false);
    }
  }

  List<String> _buscarFechas(String texto) {
    RegExp exp = RegExp(r'\b\d{2,4}[-./]\d{2}[-./]\d{2,4}\b');
    Iterable<RegExpMatch> matches = exp.allMatches(texto);
    return matches.map((m) => m.group(0)!).toList();
  }

  void _seleccionarDato(String dato) {
    Navigator.pop(context);
    Navigator.pop(context, dato);
  }

  void _mostrarResultados(String texto, List<String> fechas) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        height: MediaQuery.of(context).size.height * 0.6,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Resultado", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.pink)),
            const Divider(),
            if (fechas.isNotEmpty) ...[
              const Text("Fechas:", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),
              Wrap(
                spacing: 8,
                children: fechas.map((f) => ActionChip(
                  label: Text(f),
                  onPressed: () => _seleccionarDato(f),
                )).toList(),
              ),
              const SizedBox(height: 20),
            ],
            const Text("Texto:", style: TextStyle(fontWeight: FontWeight.bold)),
            Expanded(child: SingleChildScrollView(child: Text(texto))),
            ElevatedButton(
              onPressed: () => _seleccionarDato(texto),
              child: const Center(child: Text("Usar este texto")),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.soloEvidencia ? 'Evidencia' : 'Escanear'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      backgroundColor: Colors.black,
      body: Column(
        children: [
          Expanded(
            child: FutureBuilder<void>(
              future: _initializeControllerFuture,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.done) {
                  return CameraPreview(_controller);
                } else {
                  return const Center(child: CircularProgressIndicator());
                }
              },
            ),
          ),
          Container(
            color: Colors.black,
            padding: const EdgeInsets.all(20),
            child: Center(
              child: FloatingActionButton.extended(
                onPressed: _capturar,
                backgroundColor: const Color(0xFFE91E63),
                icon: Icon(widget.soloEvidencia ? Icons.camera_alt : Icons.crop),
                label: Text(_isScanning ? "Procesando..." : "Capturar"),
              ),
            ),
          )
        ],
      ),
    );
  }
}