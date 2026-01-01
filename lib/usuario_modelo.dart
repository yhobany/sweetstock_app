class UsuarioSistema {
  String id;
  String email;
  String rol; // 'admin' o 'cajero'
  bool activo;

  UsuarioSistema({
    required this.id,
    required this.email,
    required this.rol,
    required this.activo,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'rol': rol,
      'activo': activo,
    };
  }

  factory UsuarioSistema.fromMap(Map<String, dynamic> map) {
    return UsuarioSistema(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      rol: map['rol'] ?? 'cajero',
      activo: map['activo'] ?? true,
    );
  }
}