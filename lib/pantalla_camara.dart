import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

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
  bool _procesando = false;

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
    if (_procesando) return;

    try {
      setState(() => _procesando = true);
      await _initializeControllerFuture;

      final image = await _controller.takePicture();

      // CASO A: FOTO EVIDENCIA (Retorno directo)
      if (widget.soloEvidencia) {
        if (!mounted) return;
        Navigator.pop(context, image.path);
        return;
      }

      // CASO B: ESCÁNER INTELIGENTE
      final inputImage = InputImage.fromFilePath(image.path);
      final RecognizedText recognizedText = await _textRecognizer.processImage(inputImage);

      // 1. Extraemos todo el texto y buscamos solo secuencias numéricas
      String textoCompleto = recognizedText.text;

      // Expresión regular: Busca secuencias de números de 3 o más dígitos
      RegExp exp = RegExp(r'\b\d{3,}\b');
      Iterable<RegExpMatch> matches = exp.allMatches(textoCompleto);
      List<String> candidatos = matches.map((m) => m.group(0)!).toSet().toList(); // toSet para eliminar duplicados

      if (!mounted) return;

      if (candidatos.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('⚠️ No se detectaron números claros. Intenta acercar la cámara.'))
        );
        setState(() => _procesando = false);
        return;
      }

      // 2. LÓGICA DE SELECCIÓN AUTOMÁTICA O MANUAL
      // Si solo hay un número y parece un código de barras (8 a 14 dígitos), lo elegimos directo.
      String? seleccionAutomatico;
      for (var c in candidatos) {
        if (c.length >= 8 && c.length <= 14) {
          if (seleccionAutomatico == null) {
            seleccionAutomatico = c;
          } else {
            seleccionAutomatico = null; // Hay más de un código de barras posible, mejor preguntar
            break;
          }
        }
      }

      if (candidatos.length == 1) {
        // Solo un candidato, lo devolvemos directo
        Navigator.pop(context, candidatos.first);
      } else if (seleccionAutomatico != null) {
        // Varios números pero solo uno parece código de barras
        Navigator.pop(context, seleccionAutomatico);
      } else {
        // Ambigüedad (ej: Precio y Código), mostramos menú grande
        _mostrarSelector(candidatos);
      }

    } catch (e) {
      debugPrint('Error: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error al procesar.')));
        setState(() => _procesando = false);
      }
    }
  }

  // --- MENÚ INFERIOR CON BOTONES GRANDES ---
  void _mostrarSelector(List<String> candidatos) {
    showModalBottomSheet(
      context: context,
      isDismissible: false,
      enableDrag: false,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => Container(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Se detectaron varios números", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFFE91E63))),
            const Text("Selecciona el código de barras correcto:", style: TextStyle(color: Colors.grey)),
            const SizedBox(height: 15),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: candidatos.length,
                separatorBuilder: (_,__) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  final codigo = candidatos[index];
                  return SizedBox(
                    width: double.infinity,
                    height: 55, // BOTÓN GRANDE Y ACCESIBLE
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context); // Cierra modal
                        Navigator.pop(context, codigo); // Retorna valor a pantalla anterior
                      },
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: Colors.black87,
                          elevation: 2,
                          side: BorderSide(color: Colors.grey.shade300),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(codigo, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                          const Icon(Icons.touch_app, color: Color(0xFFE91E63))
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  setState(() => _procesando = false);
                },
                child: const Text("Cancelar y reintentar", style: TextStyle(color: Colors.red)),
              ),
            )
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(widget.soloEvidencia ? 'Evidencia' : 'Escanear'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Expanded(
            child: Stack(
              children: [
                // 1. VISTA DE CÁMARA
                FutureBuilder<void>(
                  future: _initializeControllerFuture,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.done) {
                      return Center(child: CameraPreview(_controller));
                    } else {
                      return const Center(child: CircularProgressIndicator(color: Color(0xFFE91E63)));
                    }
                  },
                ),

                // 2. GUIAS VISUALES (VISOR)
                if (!widget.soloEvidencia)
                  Center(
                    child: Container(
                      width: 280,
                      height: 150,
                      decoration: BoxDecoration(
                          border: Border.all(color: const Color(0xFFE91E63), width: 2),
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 100, spreadRadius: 100) // Efecto oscurecer alrededor
                          ]
                      ),
                      child: const Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: EdgeInsets.only(bottom: 8.0),
                          child: Text("Ubica el código aquí", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, shadows: [Shadow(blurRadius: 2, color: Colors.black)])),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ZONA DE CONTROLES
          Container(
            color: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: _procesando
                  ? const CircularProgressIndicator(color: Colors.white)
                  : GestureDetector(
                onTap: _capturar,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80, height: 80,
                      decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: const Color(0xFFE91E63), width: 6)
                      ),
                      child: const Icon(Icons.camera_alt, color: Color(0xFFE91E63), size: 35),
                    ),
                  ],
                ),
              ),
            ),
          )
        ],
      ),
    );
  }
}