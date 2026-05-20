class Employee {
  final int emplId;
  final String persNombres;
  final String persApellidos;
  final String persDocumento;
  final String? persImagen;

  Employee({
    required this.emplId,
    required this.persNombres,
    required this.persApellidos,
    required this.persDocumento,
    this.persImagen,
  });

  factory Employee.fromJson(Map<String, dynamic> json) {
    return Employee(
      emplId:
          json['empl_id'] is int
              ? json['empl_id']
              : int.tryParse(json['empl_id']?.toString() ?? '0') ?? 0,
      persNombres: json['pers_nombres']?.toString().trim() ?? '',
      persApellidos: json['pers_apellidos']?.toString().trim() ?? '',
      persDocumento: json['pers_documento']?.toString().trim() ?? '',
      persImagen: json['pers_imagen']?.toString(),
    );
  }

  String get nombreCompleto => '$persNombres $persApellidos'.trim();

  bool get isNameMissing => nombreCompleto.isEmpty;
  bool get isDocMissing => persDocumento.isEmpty;

  String get displayNombre =>
      isNameMissing ? 'Nombre no registrado' : nombreCompleto;
  String get displayDocumento =>
      isDocMissing ? 'Documento no registrado' : persDocumento;

  Map<String, dynamic> toJson() {
    return {
      'empl_id': emplId,
      'pers_nombres': persNombres,
      'pers_apellidos': persApellidos,
      'pers_documento': persDocumento,
      'pers_imagen': persImagen,
    };
  }
}
