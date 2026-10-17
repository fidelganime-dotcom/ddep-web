class Perfil {
  final int id;
  final String nombre;
  final String usuario;
  final String rol;
  final bool debeCambiarPassword;

  Perfil({
    required this.id,
    required this.nombre,
    required this.usuario,
    required this.rol,
    required this.debeCambiarPassword,
  });

  factory Perfil.fromMap(Map<String, dynamic> m) => Perfil(
        id: (m['id'] as num).toInt(),
        nombre: (m['nombre'] ?? '') as String,
        usuario: (m['usuario'] ?? '') as String,
        rol: ((m['rol']?['nombre'] ?? m['rol_nombre'] ?? '') as String).toUpperCase(),
        debeCambiarPassword: (m['debe_cambiar_password'] ?? false) as bool,
      );
}
