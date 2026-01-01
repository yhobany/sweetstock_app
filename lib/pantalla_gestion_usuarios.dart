import 'package:flutter/material.dart';
import 'servicio_firebase.dart';
import 'usuario_modelo.dart';

class PantallaGestionUsuarios extends StatefulWidget {
  const PantallaGestionUsuarios({super.key});

  @override
  State<PantallaGestionUsuarios> createState() => _PantallaGestionUsuariosState();
}

class _PantallaGestionUsuariosState extends State<PantallaGestionUsuarios> {
  final _servicio = ServicioFirebase();
  final String _miId = ServicioFirebase().usuarioActual?.uid ?? "";

  // Cambiar Rol (Cajero <-> Admin)
  void _toggleRol(UsuarioSistema usuario) async {
    if (usuario.id == _miId) { _alerta("No puedes cambiar tu propio rol"); return; }
    String nuevoRol = (usuario.rol == 'admin') ? 'cajero' : 'admin';
    await _servicio.cambiarRolUsuario(usuario.id, nuevoRol);
  }

  // Aprobar / Bloquear Acceso
  void _toggleAcceso(UsuarioSistema usuario) async {
    if (usuario.id == _miId) { _alerta("No puedes bloquearte a ti mismo"); return; }
    bool nuevoEstado = !usuario.activo;
    await _servicio.cambiarEstadoUsuario(usuario.id, nuevoEstado);
    String msj = nuevoEstado ? "Usuario ACTIVADO ✅" : "Usuario BLOQUEADO ⛔";
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msj), backgroundColor: nuevoEstado ? Colors.green : Colors.red));
  }

  // Eliminar Usuario
  void _eliminarUsuario(UsuarioSistema usuario) {
    if (usuario.id == _miId) { _alerta("No puedes eliminarte a ti mismo"); return; }
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text("¿Eliminar Usuario?"),
          content: Text("Estás a punto de borrar a ${usuario.email}.\n\nEsta acción quitará sus permisos y lo borrará de la lista."),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancelar")),
            ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  _servicio.eliminarUsuarioDb(usuario.id);
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white),
                child: const Text("ELIMINAR")
            )
          ],
        )
    );
  }

  void _alerta(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg), backgroundColor: Colors.orange));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade50,
      appBar: AppBar(title: const Text("Gestión de Equipo"), backgroundColor: Colors.white, foregroundColor: Colors.black, elevation: 0),
      body: StreamBuilder<List<UsuarioSistema>>(
        stream: _servicio.obtenerUsuariosStream(),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final usuarios = snapshot.data!;
          if (usuarios.isEmpty) return const Center(child: Text("No hay usuarios"));

          return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: usuarios.length,
            separatorBuilder: (_,__) => const SizedBox(height: 15),
            itemBuilder: (context, index) {
              final u = usuarios[index];
              final esAdmin = u.rol == 'admin';
              final estaActivo = u.activo;

              return Container(
                decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(15),
                    border: Border.all(color: estaActivo ? (esAdmin ? Colors.indigo.shade100 : Colors.grey.shade200) : Colors.red.shade100, width: estaActivo ? 1 : 2),
                    boxShadow: [BoxShadow(color: Colors.grey.shade100, blurRadius: 5, offset: const Offset(0, 3))]
                ),
                child: Column(
                  children: [
                    ListTile(
                      contentPadding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                      leading: CircleAvatar(
                        backgroundColor: estaActivo ? (esAdmin ? Colors.indigo : const Color(0xFFE91E63)) : Colors.grey,
                        child: Icon(estaActivo ? (esAdmin ? Icons.shield : Icons.person) : Icons.block, color: Colors.white),
                      ),
                      title: Text(u.email, style: TextStyle(fontWeight: FontWeight.bold, decoration: estaActivo ? null : TextDecoration.lineThrough, color: estaActivo ? Colors.black : Colors.grey)),
                      subtitle: Text(
                          estaActivo ? (esAdmin ? "ADMINISTRADOR" : "CAJERO") : "PENDIENTE / BLOQUEADO",
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: estaActivo ? (esAdmin ? Colors.indigo : const Color(0xFFE91E63)) : Colors.red)
                      ),
                      trailing: u.id == _miId ? const Chip(label: Text("TÚ"), backgroundColor: Colors.indigo, labelStyle: TextStyle(color: Colors.white)) : IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red), onPressed: () => _eliminarUsuario(u)),
                    ),
                    if (u.id != _miId)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                        child: Row(
                          children: [
                            const SizedBox(width: 10),
                            Text("Acceso:", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                            Switch(value: estaActivo, activeColor: Colors.green, onChanged: (v) => _toggleAcceso(u)),
                            const Spacer(),
                            if (estaActivo) ...[
                              Text("Es Admin:", style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                              Switch(value: esAdmin, activeColor: Colors.indigo, onChanged: (v) => _toggleRol(u)),
                            ]
                          ],
                        ),
                      )
                  ],
                ),
              );
            },
          );
        },
      ),
    );
  }
}