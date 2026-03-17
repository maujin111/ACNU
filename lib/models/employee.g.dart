// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'employee.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Employee _$EmployeeFromJson(Map<String, dynamic> json) => Employee(
  emplId: (json['empl_id'] as num).toInt(),
  persNombres: json['pers_nombres'] as String,
  persApellidos: json['pers_apellidos'] as String,
  persDocumento: json['pers_documento'] as String,
  persImagen: json['pers_imagen'] as String?,
);

Map<String, dynamic> _$EmployeeToJson(Employee instance) => <String, dynamic>{
  'empl_id': instance.emplId,
  'pers_nombres': instance.persNombres,
  'pers_apellidos': instance.persApellidos,
  'pers_documento': instance.persDocumento,
  'pers_imagen': instance.persImagen,
};
