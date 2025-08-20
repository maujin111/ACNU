import 'dart:convert';

class PrintHistoryItem {
  final String id;
  final String tipo;
  final DateTime timestamp;
  final String rawJson;

  PrintHistoryItem({
    required this.id,
    required this.tipo,
    required this.timestamp,
    required this.rawJson,
  });

  // Método de fábrica para crear un elemento del historial desde un mensaje JSON
  factory PrintHistoryItem.fromMessage(String message, {DateTime? timestamp}) {
    try {
      // Validar si el mensaje ya es un JSON válido
      if (!message.trim().startsWith('{') && !message.trim().startsWith('[')) {
        // Si no es JSON, convertirlo a un objeto JSON básico
        message = jsonEncode({
          'tipo': 'Mensaje de texto',
          'contenido': message,
          'timestamp': DateTime.now().millisecondsSinceEpoch,
        });
      }

      final Map<String, dynamic> json = jsonDecode(message);

      // Extraer ID y tipo
      String id = json['id']?.toString() ?? '';
      String tipo = json['tipo']?.toString() ?? 'Desconocido';

      // Si no hay ID pero es un documento de venta con número de factura, usamos ese
      if (id.isEmpty && json['numeroFactura'] != null) {
        id = json['numeroFactura'].toString();
      } else if (id.isEmpty && json['numero'] != null) {
        // Para prefacturas o comandas que tienen campo 'numero'
        id = json['numero'].toString();
      } else if (id.isEmpty) {
        // Si no hay ningún ID reconocible, usar timestamp como ID
        id = DateTime.now().millisecondsSinceEpoch.toString();
      }

      return PrintHistoryItem(
        id: id,
        tipo: tipo,
        timestamp: timestamp ?? DateTime.now(),
        rawJson: message,
      );
    } catch (e) {
      // Si hay un error al parsear, crear un elemento con datos mínimos
      print('Error al parsear mensaje del historial: $e');
      return PrintHistoryItem(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        tipo: 'Desconocido',
        timestamp: timestamp ?? DateTime.now(),
        rawJson: message,
      );
    }
  }

  // Obtener una representación string formateada de la fecha y hora
  String get formattedTimestamp {
    // Formatear como: DD/MM/YYYY HH:MM:SS
    return '${timestamp.day.toString().padLeft(2, '0')}/${timestamp.month.toString().padLeft(2, '0')}/${timestamp.year} ${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}:${timestamp.second.toString().padLeft(2, '0')}';
  }

  // Convertir a JSON para almacenamiento
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'tipo': tipo,
      'timestamp': timestamp.millisecondsSinceEpoch,
      'rawJson': rawJson,
    };
  }

  // Crear desde JSON almacenado
  factory PrintHistoryItem.fromJson(Map<String, dynamic> json) {
    return PrintHistoryItem(
      id: json['id'],
      tipo: json['tipo'],
      timestamp: DateTime.fromMillisecondsSinceEpoch(json['timestamp']),
      rawJson: json['rawJson'],
    );
  }
}
