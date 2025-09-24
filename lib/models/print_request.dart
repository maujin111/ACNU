// Modelo para representar los diferentes tipos de solicitudes de impresión
import 'dart:convert';

// Modelo para el nuevo formato JSON directamente con todos los campos
class DirectPrintRequest {
  final String piso;
  final String mesa;
  final String empleado;
  final List<DetalleDirecto> detalles;
  final String printerName;
  final String ip;
  final int copias;
  final String numeroFactura;
  final String sucursal;
  final String empresa;
  final String nombre;
  final String ruc;
  final String regimen;
  final String direccion;
  final String telefono;
  final String ambiente;
  final String cliente;
  final String fecha;
  final String rucCliente;
  final String direccionCliente;
  final String telefonoCliente;
  final String claveAcceso;
  final String subTotal0;
  final String subtotal15;
  final String subtotal12;
  final String subtotal5;
  final String subTotal8;
  final String subTotalSI;
  final String totalDescuento;
  final String iva8;
  final String iva15;
  final String iva0;
  final String iva2;
  final String iva05;
  final String iva12;
  final String total;
  final String ice;
  final List<FormaPagoDirecta> formaPago;
  final String valor;

  DirectPrintRequest({
    required this.piso,
    required this.mesa,
    required this.empleado,
    required this.detalles,
    required this.printerName,
    required this.ip,
    required this.copias,
    required this.numeroFactura,
    required this.sucursal,
    required this.empresa,
    required this.nombre,
    required this.ruc,
    required this.regimen,
    required this.direccion,
    required this.telefono,
    required this.ambiente,
    required this.cliente,
    required this.fecha,
    required this.rucCliente,
    required this.direccionCliente,
    required this.telefonoCliente,
    required this.claveAcceso,
    required this.subTotal0,
    required this.subtotal15,
    required this.subtotal12,
    required this.subtotal5,
    required this.subTotal8,
    required this.subTotalSI,
    required this.totalDescuento,
    required this.iva8,
    required this.iva15,
    required this.iva0,
    required this.iva2,
    required this.iva05,
    required this.iva12,
    required this.total,
    required this.ice,
    required this.formaPago,
    required this.valor,
  });

  factory DirectPrintRequest.fromJson(String jsonStr) {
    try {
      final Map<String, dynamic> json = jsonDecode(jsonStr);

      // Convertir la lista de detalles
      final List<dynamic> detallesList = json['detalles'] ?? [];
      final List<DetalleDirecto> detalles =
          detallesList
              .map((detalle) => DetalleDirecto.fromJson(detalle))
              .toList();

      // Convertir la lista de formas de pago
      final List<dynamic> formaPagoList = json['formaPago'] ?? [];
      final List<FormaPagoDirecta> formasPago =
          formaPagoList
              .map((formaPago) => FormaPagoDirecta.fromJson(formaPago))
              .toList();

      return DirectPrintRequest(
        piso: json['piso']?.toString() ?? '',
        mesa: json['mesa']?.toString() ?? '',
        empleado: json['empleado']?.toString() ?? '',
        detalles: detalles,
        printerName: json['printerName']?.toString() ?? '',
        ip: json['ip']?.toString() ?? '',
        copias:
            json['copias'] is int
                ? json['copias']
                : int.tryParse(json['copias']?.toString() ?? '1') ?? 1,
        numeroFactura: json['numeroFactura']?.toString() ?? '',
        sucursal: json['sucursal']?.toString() ?? '',
        empresa: json['empresa']?.toString() ?? '',
        nombre: json['nombre']?.toString() ?? '',
        ruc: json['ruc']?.toString() ?? '',
        regimen: json['regimen']?.toString() ?? '',
        direccion: json['direccion']?.toString() ?? '',
        telefono: json['telefono']?.toString() ?? '',
        ambiente: json['ambiente']?.toString() ?? '',
        cliente: json['cliente']?.toString() ?? '',
        fecha: json['fecha']?.toString() ?? '',
        rucCliente: json['rucCliente']?.toString() ?? '',
        direccionCliente: json['direccionCliente']?.toString() ?? '',
        telefonoCliente: json['telefonoCliente']?.toString() ?? '',
        claveAcceso: json['claveAcceso']?.toString() ?? '',
        subTotal0: json['subTotal0']?.toString() ?? '0.00',
        subtotal15: json['subtotal15']?.toString() ?? '0.00',
        subtotal12: json['subtotal12']?.toString() ?? '0.00',
        subtotal5: json['subtotal5']?.toString() ?? '0.00',
        subTotal8: json['subTotal8']?.toString() ?? '0.00',
        subTotalSI: json['subTotalSI']?.toString() ?? '0.00',
        totalDescuento: json['totalDescuento']?.toString() ?? '0.00',
        iva8: json['iva8']?.toString() ?? '0.00',
        iva15: json['iva15']?.toString() ?? '0.00',
        iva0: json['iva0']?.toString() ?? '0.00',
        iva2: json['iva2']?.toString() ?? '0.00',
        iva05: json['iva05']?.toString() ?? '0.00',
        iva12: json['iva12']?.toString() ?? '0.00',
        total: json['total']?.toString() ?? '0.00',
        ice: json['ice']?.toString() ?? '0.00',
        formaPago: formasPago,
        valor: json['valor']?.toString() ?? '',
      );
    } catch (e) {
      print('Error parseando JSON DirectPrintRequest: $e');
      throw FormatException('Error al parsear JSON: $e');
    }
  }
}

class DetalleDirecto {
  final double cant;
  final String umd;
  final String valUnitario;
  final String valTotal;
  final String descripcion;
  final String observacion;

  DetalleDirecto({
    required this.cant,
    required this.umd,
    required this.valUnitario,
    required this.valTotal,
    required this.descripcion,
    required this.observacion,
  });

  factory DetalleDirecto.fromJson(Map<String, dynamic> json) {
    return DetalleDirecto(
      cant:
          json['cant'] is double
              ? json['cant']
              : double.tryParse(json['cant'].toString()) ?? 0.0,
      umd: json['umd']?.toString() ?? '',
      valUnitario: json['valUnitario']?.toString() ?? '0.00',
      valTotal: json['valTotal']?.toString() ?? '0.00',
      descripcion: json['descripcion']?.toString() ?? '',
      observacion: json['observacion']?.toString() ?? '',
    );
  }
}

class FormaPagoDirecta {
  final String detalle;
  final double importe;

  FormaPagoDirecta({required this.detalle, required this.importe});

  factory FormaPagoDirecta.fromJson(Map<String, dynamic> json) {
    return FormaPagoDirecta(
      detalle: json['detalle']?.toString() ?? '',
      importe:
          json['importe'] is double
              ? json['importe']
              : double.tryParse(json['importe'].toString()) ?? 0.0,
    );
  }
}

class PrintRequest {
  final String tipo;
  final String id;
  final String copias;
  final String orden;
  final String printerName;
  final dynamic data;

  PrintRequest({
    required this.tipo,
    required this.id,
    required this.copias,
    required this.orden,
    this.printerName = '',
    this.data,
  });
  factory PrintRequest.fromJson(String jsonStr) {
    Map<String, dynamic> jsonVerificado;
    try {
      // Validar y convertir a JSON si es necesario
      String validJsonStr = jsonStr.trim();
      if (!validJsonStr.startsWith('{') && !validJsonStr.startsWith('[')) {
        // Si no parece ser JSON, intentar parsearlo como string simple
        try {
          // Verificar si es una cadena que necesita ser envuelta en JSON
          validJsonStr = '{"data": "$validJsonStr"}';
          print('📝 Convirtiendo string a JSON: $validJsonStr');
          jsonVerificado = {'data': validJsonStr};
        } catch (e) {
          print('❌ Error al convertir string a JSON: $e');
          throw FormatException(
            'El string proporcionado no es un JSON válido: $jsonStr',
          );
        }
      } else {
        // Validar que sea JSON válido
        try {
          jsonVerificado = jsonDecode(validJsonStr);
        } catch (e) {
          print('❌ JSON inválido proporcionado: $e');
          jsonVerificado = {'data': validJsonStr};
          throw FormatException('JSON inválido: $e');
        }
      }

      final Map<String, dynamic> json =
          jsonVerificado; // Si es un formato de venta directa y no tiene ID, generamos uno
      String id = json['id']?.toString() ?? '';
      if (id.isEmpty &&
          json['tipo']?.toString().toUpperCase() == 'VENTA' &&
          (json['numeroFactura'] != null || json['detalles'] != null)) {
        // Usar el número de factura o un timestamp como ID en caso de venta directa
        id =
            json['numeroFactura']?.toString() ??
            DateTime.now().millisecondsSinceEpoch.toString();
        print('📝 Generando ID automático para venta directa: $id');
      }

      return PrintRequest(
        tipo: json['tipo']?.toString() ?? '',
        id: id,
        copias: json['copias']?.toString() ?? '1',
        orden: json['orden']?.toString() ?? '1',
        printerName: json['printerName']?.toString() ?? '',
        data: json, // Guardar todo el JSON como data para procesarlo después
      );
    } catch (e) {
      print('Error parseando JSON de solicitud de impresión: $e');
      return PrintRequest(tipo: 'DESCONOCIDO', id: '', copias: '1', orden: '1');
    }
  }

  bool get isValid {
    return tipo.isNotEmpty && id.isNotEmpty;
  }
}

// Modelos para representar los datos de las comandas
class ComandaData {
  final String? hameName;
  final String? pisoName;
  final List<DetalleComanda> detalles;
  final String? empleado;
  final String? fecha;
  final String? hora;

  ComandaData({
    this.hameName,
    this.pisoName,
    required this.detalles,
    this.empleado,
    this.fecha,
    this.hora,
  });
  factory ComandaData.fromJson(Map<String, dynamic> json) {
    final List<dynamic> detallesList =
        json['detalles'] ?? json['detalle'] ?? [];

    // Compatibilidad con ambos formatos
    final hameName = json['mesa'] ?? json['hame_nombre'];
    final pisoName = json['piso'].toString();
    final empleado = json['empleado'] ?? json['emp_nombre'];
    final fecha =
        json['fecha']?.toString() ?? DateTime.now().toString().substring(0, 10);
    final hora =
        json['hora']?.toString() ?? DateTime.now().toString().substring(11, 19);
    print(
      'Procesando comanda: Mesa: $hameName, Piso: $pisoName, Detalles: ${detallesList.length}',
    );

    return ComandaData(
      hameName: hameName,
      pisoName: pisoName,
      detalles:
          detallesList
              .map((detalle) => DetalleComanda.fromJson(detalle))
              .toList(),
      empleado: empleado,
      fecha: fecha,
      hora: hora,
    );
  }
}

class DetalleComanda {
  final double cant;
  final String? umedNombre;
  final String? descripcion;
  final String? observacion;

  DetalleComanda({
    required this.cant,
    this.umedNombre,
    this.descripcion,
    this.observacion,
  });
  factory DetalleComanda.fromJson(Map<String, dynamic> json) {
    // Cantidad puede venir en múltiples formatos
    double cantidad = 0.0;
    if (json.containsKey('cant') && json['cant'] != null) {
      cantidad =
          json['cant'] is double
              ? json['cant']
              : double.tryParse(json['cant'].toString()) ?? 0.0;
    } else if (json.containsKey('ddin_cantidad') &&
        json['ddin_cantidad'] != null) {
      cantidad = double.tryParse(json['ddin_cantidad'].toString()) ?? 0.0;
    }

    // Unidad de medida
    final umedNombre = json['umd'] ?? json['umd'];

    // Descripción del producto
    final descripcion = json['descripcion'] ?? json['prod_descripcion'];

    // Observación
    final observacion = json['observacion'] ?? json['ddin_observacion'];

    return DetalleComanda(
      cant: cantidad,
      umedNombre: umedNombre,
      descripcion: descripcion,
      observacion: observacion,
    );
  }
}

// Modelos para representar los datos de las prefacturas
class PrefacturaData {
  final int numero;
  final String? hameName;
  final String? pisoName;
  final double sinIva;
  final double conIva;
  final double iva;
  final double servicio;
  final double total;
  final List<DetallePrefactura> detalles;
  final String? empleado;

  PrefacturaData({
    required this.numero,
    this.hameName,
    this.pisoName,
    required this.sinIva,
    required this.conIva,
    required this.iva,
    required this.servicio,
    required this.total,
    required this.detalles,
    this.empleado,
  });
  factory PrefacturaData.fromJson(Map<String, dynamic> json) {
    try {
      // Compatibilidad con ambos formatos: nuevo formato directo y formato anterior
      final List<dynamic> detallesList =
          json['detalles'] ?? json['detalle'] ?? [];

      // Número de prefactura (puede venir como 'numero' o 'doin_numero')
      // Detección y conversión del campo numero que está causando el error
      var numeroRaw = json['numero'] ?? json['doin_numero'] ?? 0;
      int numero;
      if (numeroRaw is String) {
        print(
          '⚠️ Campo numero es String ("$numeroRaw"), intentando convertir a int',
        );
        numero = int.tryParse(numeroRaw) ?? 0;
      } else if (numeroRaw is int) {
        numero = numeroRaw;
      } else {
        print(
          '⚠️ Campo numero es de tipo ${numeroRaw.runtimeType}: $numeroRaw',
        );
        numero = 0;
      }

      // Nombres de mesa y piso (formato nuevo o antiguo)
      final hameName = json['mesa'] ?? json['hame_nombre'];
      final pisoName = json['piso'].toString();

      // Valores con IVA, sin IVA, etc.
      final sinIva = _parseDoubleFromJson(json, ['subTotal0', 'doin_siniva']);
      final conIva = _parseDoubleFromJson(json, ['subtotal15', 'doin_coniva']);
      final iva = _parseDoubleFromJson(json, ['iva15', 'doin_iva']);
      final servicio = _parseDoubleFromJson(json, [
        'servicio',
        'doin_servicio',
      ]);
      final total = _parseDoubleFromJson(json, ['total', 'doin_total']);
      final empleado = json['empleado'] ?? json['empl_nombre'];

      print(
        'Procesando prefactura: $numero, Mesa: $hameName, Piso: $pisoName, Detalles: ${detallesList.length}',
      );

      return PrefacturaData(
        numero: numero,
        hameName: hameName,
        pisoName: pisoName,
        sinIva: sinIva,
        conIva: conIva,
        iva: iva,
        servicio: servicio,
        total: total,
        detalles:
            detallesList
                .map((detalle) => DetallePrefactura.fromJson(detalle))
                .toList(),
        empleado: empleado,
      );
    } catch (e) {
      print('❌ Error al parsear PrefacturaData: $e');
      // Retornar una prefactura con valores por defecto
      return PrefacturaData(
        numero: 0,
        sinIva: 0.0,
        conIva: 0.0,
        iva: 0.0,
        servicio: 0.0,
        total: 0.0,
        detalles: [],
        empleado: '',
      );
    }
  }
}

class DetallePrefactura {
  final double cantidad;
  final String? umedNombre;
  final String? descripcion;
  final String? observacion;
  final double valorUnitario;
  final double total;

  DetallePrefactura({
    required this.cantidad,
    this.umedNombre,
    this.descripcion,
    this.observacion,
    required this.valorUnitario,
    required this.total,
  });
  factory DetallePrefactura.fromJson(Map<String, dynamic> json) {
    // Cantidad puede venir en múltiples formatos
    double cantidad = 0.0;
    if (json.containsKey('cantidad') && json['cantidad'] != null) {
      cantidad =
          json['cantidad'] is double
              ? json['cantidad']
              : double.tryParse(json['cantidad'].toString()) ?? 0.0;
    } else if (json.containsKey('ddin_cantidad') &&
        json['ddin_cantidad'] != null) {
      cantidad = double.tryParse(json['ddin_cantidad'].toString()) ?? 0.0;
    }

    // Unidad de medida
    final umedNombre = json['umedNombre'] ?? json['umed_nombre'];

    // Descripción del producto
    final descripcion = json['descripcion'] ?? json['prod_descripcion'];

    // Observación
    final observacion = json['observacion'] ?? json['ddin_observacion'];

    // Valor unitario
    double valorUnitario = 0.0;
    if (json.containsKey('valorUnitario') && json['valorUnitario'] != null) {
      valorUnitario =
          json['valorUnitario'] is double
              ? json['valorUnitario']
              : double.tryParse(json['valorUnitario'].toString()) ?? 0.0;
    } else if (json.containsKey('ddin_valor_unitario') &&
        json['ddin_valor_unitario'] != null) {
      valorUnitario =
          double.tryParse(json['ddin_valor_unitario'].toString()) ?? 0.0;
    }

    // Total
    double total = 0.0;
    if (json.containsKey('total') && json['total'] != null) {
      total =
          json['total'] is double
              ? json['total']
              : double.tryParse(json['total'].toString()) ?? 0.0;
    } else if (json.containsKey('ddin_total') && json['ddin_total'] != null) {
      total = double.tryParse(json['ddin_total'].toString()) ?? 0.0;
    }

    return DetallePrefactura(
      cantidad: cantidad,
      umedNombre: umedNombre,
      descripcion: descripcion,
      observacion: observacion,
      valorUnitario: valorUnitario,
      total: total,
    );
  }
}

class Vendedor {
  final int empleadoId;
  final String? nombre;
  final String? apellido;
  final String? cargo;

  Vendedor({required this.empleadoId, this.nombre, this.apellido, this.cargo});
  factory Vendedor.fromJson(Map<String, dynamic> json) {
    try {
      // El ID puede venir en diferentes formatos
      var idRaw = json['id'] ?? json['empl_id'] ?? 0;
      int empleadoId;

      if (idRaw is String) {
        print(
          '⚠️ Campo empleadoId es String ("$idRaw"), intentando convertir a int',
        );
        empleadoId = int.tryParse(idRaw) ?? 0;
      } else if (idRaw is int) {
        empleadoId = idRaw;
      } else {
        print('⚠️ Campo empleadoId es de tipo ${idRaw.runtimeType}: $idRaw');
        empleadoId = 0;
      }

      // El nombre puede venir en diferentes formatos
      final nombre = json['nombre'] ?? json['pers_nombres'];

      // El apellido puede venir en diferentes formatos
      final apellido = json['apellido'] ?? json['pers_apellidos'];

      // El cargo puede venir en diferentes formatos
      final cargo = json['cargo'] ?? json['carg_nombre'] ?? json['empl_cargo'];

      return Vendedor(
        empleadoId: empleadoId,
        nombre: nombre,
        apellido: apellido,
        cargo: cargo,
      );
    } catch (e) {
      print('❌ Error al parsear Vendedor: $e');
      return Vendedor(empleadoId: 0, nombre: "Error", apellido: "", cargo: "");
    }
  }

  String get nombreCompleto => '${nombre ?? ''} ${apellido ?? ''}'.trim();
}

// Modelos para representar los datos de las ventas/facturas
class VentaData {
  final String? numeroFactura;
  final String? cliente;
  final String? rucCliente;
  final String? fechaVenta;
  final String? direccionCliente;
  final String? telefonoCliente;
  final String? claveAcceso;
  final double base0;
  final double subtotal15;
  final double subtotal12;
  final double subtotal5;
  final double subtotal8;
  final double totalDescuento;
  final double recargo;
  final double iva15;
  final double iva12;
  final double iva5;
  final double iva8;
  final double total;
  final double ice;
  final List<DetalleVenta> detalles;
  final List<FormaPago> formasPago;
  final String? sucursal;
  final String? empresa;
  final String? razonSocial;
  final String? ruc;
  final String? regimen;
  final String? direccion;
  final String? telefono;
  final String? ambiente;
  final String? empleadoNombre;

  VentaData({
    this.numeroFactura,
    this.cliente,
    this.rucCliente,
    this.fechaVenta,
    this.direccionCliente,
    this.telefonoCliente,
    this.claveAcceso,
    required this.base0,
    required this.subtotal15,
    required this.subtotal12,
    required this.subtotal5,
    required this.subtotal8,
    required this.totalDescuento,
    required this.recargo,
    required this.iva15,
    required this.iva12,
    required this.iva5,
    required this.iva8,
    required this.total,
    required this.ice,
    required this.detalles,
    required this.formasPago,
    this.sucursal,
    this.empresa,
    this.razonSocial,
    this.ruc,
    this.regimen,
    this.direccion,
    this.telefono,
    this.ambiente,
    this.empleadoNombre,
  });

  double get subtotalSinImpuestos =>
      base0 + subtotal15 + subtotal12 + subtotal5 + subtotal8;

  factory VentaData.fromJson(Map<String, dynamic> json) {
    String formatoNumeroFactura(
      String? almacen,
      String? puntoEmision,
      int? serie,
    ) {
      if (almacen == null || puntoEmision == null || serie == null) {
        return '';
      }
      return '$almacen-$puntoEmision-$serie';
    }

    final List<dynamic> detallesList = json['detalles'] ?? [];
    final List<dynamic> formasPagoList = json['formas_pago'] ?? [];

    return VentaData(
      numeroFactura: formatoNumeroFactura(
        json['talo_almacen'],
        json['talo_punto_emision'],
        json['vent_serie3'],
      ),
      cliente:
          '${json['pers_apellidos'] ?? ''} ${json['pers_nombres'] ?? ''}'
              .trim(),
      rucCliente: json['pers_documento'],
      fechaVenta: json['vent_fecha'],
      direccionCliente: json['pers_direccion_domicilio'],
      telefonoCliente: json['pers_telefono_personal'],
      claveAcceso: json['vent_clave_acceso'],
      base0:
          json['vent_base0'] != null
              ? double.tryParse(json['vent_base0'].toString()) ?? 0.0
              : 0.0,
      subtotal15:
          json['subtotal_iva_15'] != null
              ? double.tryParse(json['subtotal_iva_15'].toString()) ?? 0.0
              : 0.0,
      subtotal12:
          json['subtotal_iva_12'] != null
              ? double.tryParse(json['subtotal_iva_12'].toString()) ?? 0.0
              : 0.0,
      subtotal5:
          json['subtotal_iva_5'] != null
              ? double.tryParse(json['subtotal_iva_5'].toString()) ?? 0.0
              : 0.0,
      subtotal8:
          json['subtotal_iva_8'] != null
              ? double.tryParse(json['subtotal_iva_8'].toString()) ?? 0.0
              : 0.0,
      totalDescuento:
          json['vent_descuento'] != null
              ? double.tryParse(json['vent_descuento'].toString()) ?? 0.0
              : 0.0,
      recargo:
          json['vent_recargo'] != null
              ? double.tryParse(json['vent_recargo'].toString()) ?? 0.0
              : 0.0,
      iva15:
          json['sum_iva_15'] != null
              ? double.tryParse(json['sum_iva_15'].toString()) ?? 0.0
              : 0.0,
      iva12:
          json['sum_iva_12'] != null
              ? double.tryParse(json['sum_iva_12'].toString()) ?? 0.0
              : 0.0,
      iva5:
          json['sum_iva_5'] != null
              ? double.tryParse(json['sum_iva_5'].toString()) ?? 0.0
              : 0.0,
      iva8:
          json['sum_iva_8'] != null
              ? double.tryParse(json['sum_iva_8'].toString()) ?? 0.0
              : 0.0,
      total:
          json['vent_total'] != null
              ? double.tryParse(json['vent_total'].toString()) ?? 0.0
              : 0.0,
      ice:
          json['vent_ice'] != null
              ? double.tryParse(json['vent_ice'].toString()) ?? 0.0
              : 0.0,
      detalles:
          detallesList
              .map((detalle) => DetalleVenta.fromJson(detalle))
              .toList(),
      formasPago:
          formasPagoList
              .map((formaPago) => FormaPago.fromJson(formaPago))
              .toList(),
      sucursal: json['sucu_nombre'],
      empresa: json['representante'],
      razonSocial: json['razon_social'],
      ruc: json['ruc'],
      regimen: json['regimen_rimpe'],
      direccion: json['sucu_direccion'],
      telefono: json['telefonos'],
      ambiente: json['vent_tipo_ambiente'],
      empleadoNombre: json['empl_nombre'],
    );
  }
}

class DetalleVenta {
  final double cantidad;
  final String? umedNombre;
  final String? descripcion;
  final String? observacion;
  final double valorUnitario;
  final double total;
  final List<Lote>? lotes;
  final List<Serie>? series;

  DetalleVenta({
    required this.cantidad,
    this.umedNombre,
    this.descripcion,
    this.observacion,
    required this.valorUnitario,
    required this.total,
    this.lotes,
    this.series,
  });

  factory DetalleVenta.fromJson(Map<String, dynamic> json) {
    final List<dynamic>? lotesList = json['lotes'];
    final List<dynamic>? seriesList = json['series'];

    return DetalleVenta(
      cantidad:
          json['dven_cantidad'] != null
              ? double.tryParse(json['dven_cantidad'].toString()) ?? 0.0
              : 0.0,
      umedNombre: json['umed_nombre'],
      descripcion: json['prod_descripcion'],
      observacion: json['prod_observacion'],
      valorUnitario:
          json['dven_valor_unitario'] != null
              ? double.tryParse(json['dven_valor_unitario'].toString()) ?? 0.0
              : 0.0,
      total:
          json['dven_cantidad'] != null && json['dven_valor_unitario'] != null
              ? (double.tryParse(json['dven_cantidad'].toString()) ?? 0.0) *
                  (double.tryParse(json['dven_valor_unitario'].toString()) ??
                      0.0)
              : 0.0,
      lotes: lotesList?.map((lote) => Lote.fromJson(lote)).toList(),
      series: seriesList?.map((serie) => Serie.fromJson(serie)).toList(),
    );
  }

  String formatoDescripcion(int maxLength) {
    if (descripcion == null) return '';
    if (descripcion!.length <= maxLength) {
      return descripcion!.padRight(maxLength);
    }
    return descripcion!.substring(0, maxLength);
  }

  String getObservacionFormateada() {
    StringBuffer buffer = StringBuffer();

    if (lotes != null && lotes!.isNotEmpty) {
      for (var lote in lotes!) {
        buffer.write(
          'Lote: ${lote.numero} - Elaboración: ${lote.fechaElaboracion}\n',
        );
        buffer.write('Caducidad: ${lote.fechaCaducidad}\n');
      }
    }

    if (series != null && series!.isNotEmpty) {
      for (var serie in series!) {
        if (serie.propiedades != null) {
          for (var prop in serie.propiedades!) {
            buffer.write('${prop.detalle}: ${prop.valor}\n');
          }
        }
      }
    }

    return buffer.toString();
  }
}

class Lote {
  final String? numero;
  final String? fechaElaboracion;
  final String? fechaCaducidad;

  Lote({this.numero, this.fechaElaboracion, this.fechaCaducidad});

  factory Lote.fromJson(Map<String, dynamic> json) {
    return Lote(
      numero: json['lote_numero'],
      fechaElaboracion: json['lote_fecha_elaboracion'],
      fechaCaducidad: json['lote_fecha_caducidad'],
    );
  }
}

class Serie {
  final List<PropiedadSerie>? propiedades;

  Serie({this.propiedades});

  factory Serie.fromJson(Map<String, dynamic> json) {
    final List<dynamic>? propiedadesList = json['propiedades_series'];

    return Serie(
      propiedades:
          propiedadesList
              ?.map((prop) => PropiedadSerie.fromJson(prop))
              .toList(),
    );
  }
}

class PropiedadSerie {
  final String? detalle;
  final String? valor;

  PropiedadSerie({this.detalle, this.valor});

  factory PropiedadSerie.fromJson(Map<String, dynamic> json) {
    return PropiedadSerie(
      detalle: json['prpi_detalle'],
      valor: json['dser_valor'],
    );
  }
}

class FormaPago {
  final String? detalle;
  final double importe;

  FormaPago({this.detalle, required this.importe});

  factory FormaPago.fromJson(Map<String, dynamic> json) {
    return FormaPago(
      detalle: json['frmp_sri'],
      importe:
          json['dtco_importe'] != null
              ? double.tryParse(json['dtco_importe'].toString()) ?? 0.0
              : 0.0,
    );
  }
}

// Modelos para representar los datos de los sorteos
class SorteoData {
  final String fecha;
  final String hora;
  final String evento;
  final String nombres;
  final String apellidos;
  final String cedula;
  final String telefono;
  final String numeroSorteo;
  final String mensaje;
  final String pie;

  SorteoData({
    required this.fecha,
    required this.hora,
    required this.evento,
    required this.nombres,
    required this.apellidos,
    required this.cedula,
    required this.telefono,
    required this.numeroSorteo,
    required this.mensaje,
    required this.pie,
  });
  factory SorteoData.fromJson(Map<String, dynamic> json) {
    return SorteoData(
      fecha: json['fecha']?.toString() ?? '',
      hora: json['hora']?.toString() ?? '',
      evento: json['evento']?.toString() ?? '',
      nombres: json['nombres']?.toString() ?? '',
      apellidos: json['apellidos']?.toString() ?? '',
      cedula: json['cedula']?.toString() ?? '',
      telefono: json['telefono']?.toString() ?? '',
      numeroSorteo: json['numeroSorteo']?.toString() ?? '',
      mensaje: json['mensaje']?.toString() ?? '',
      pie: json['pie']?.toString() ?? '',
    );
  }

  String get nombreCompleto => '$nombres $apellidos'.trim();
}

// Función utilitaria para parsear valores double de un JSON usando múltiples posibles keys
double _parseDoubleFromJson(
  Map<String, dynamic> json,
  List<String> possibleKeys,
) {
  for (final key in possibleKeys) {
    if (json.containsKey(key) && json[key] != null) {
      return double.tryParse(json[key].toString()) ?? 0.0;
    }
  }
  return 0.0;
}
