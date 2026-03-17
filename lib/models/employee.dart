import 'package:json_annotation/json_annotation.dart';

part 'employee.g.dart';

@JsonSerializable(fieldRename: FieldRename.snake)
class Employee {
  final int emplId;
  final String persNombres;
  final String persApellidos;
  final String persDocumento;
  final String? persImagen; // Base64 encoded image, if applicable

  Employee({
    required this.emplId,
    required this.persNombres,
    required this.persApellidos,
    required this.persDocumento,
    this.persImagen,
  });

  factory Employee.fromJson(Map<String, dynamic> json) =>
      _$EmployeeFromJson(json);
  Map<String, dynamic> toJson() => _$EmployeeToJson(this);
}
