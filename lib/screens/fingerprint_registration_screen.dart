import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:anfibius_uwu/services/fingerprint_reader_service.dart';

class FingerprintRegistrationScreen extends StatefulWidget {
  final int employeeId;
  final String employeeName;

  const FingerprintRegistrationScreen({
    super.key,
    required this.employeeId,
    required this.employeeName,
  });

  @override
  State<FingerprintRegistrationScreen> createState() =>
      _FingerprintRegistrationScreenState();
}

enum RegistrationStatus {
  idle,
  waitingForFinger,
  reading,
  liftFinger,
  success,
  error,
}

class _FingerprintRegistrationScreenState
    extends State<FingerprintRegistrationScreen> {
  RegistrationStatus _status = RegistrationStatus.idle;
  String _statusMessage = 'Presione el botón para iniciar el registro';
  String? _errorMessage;
  FingerprintReaderService? _fingerprintService;
  int _currentCapture = 0;
  final int _totalCaptures =
      3; // SDK Hikvision en modo 0 requiere 3 colocaciones
  bool _isProcessing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Guardar referencia al servicio de forma segura
    if (_fingerprintService == null) {
      _fingerprintService = Provider.of<FingerprintReaderService>(
        context,
        listen: false,
      );
    }
  }

  @override
  void initState() {
    super.initState();
    // NO iniciar automáticamente, esperar que el usuario presione el botón
  }

  void _startRegistration() async {
    if (_fingerprintService == null) return;
    if (_isProcessing) return; // Prevenir doble inicio

    setState(() {
      _isProcessing = true;
      _status = RegistrationStatus.waitingForFinger;
      _statusMessage = '👇 Coloque su dedo en el lector';
      _errorMessage = null;
      _currentCapture = 0;
    });

    // Cuando el SDK detecta el dedo por primera vez, iniciar simulación del progreso
    _fingerprintService!.onFingerDetected = () {
      if (!mounted || _currentCapture > 0) return; // Solo la primera vez

      // Simular el progreso de las 3 capturas mientras FpEnroll trabaja
      _simulateThreeCaptures();
    };

    // Callback de errores
    _fingerprintService!.onRegistrationStatusChange = (
      bool isReading,
      String? error,
    ) {
      if (!mounted) return;

      if (error != null) {
        setState(() {
          _status = RegistrationStatus.error;
          _statusMessage = 'Error al registrar huella';
          _errorMessage = error;
          _isProcessing = false;
        });
      }
    };

    // Callback de éxito
    _fingerprintService!.onRegistrationSuccess = () {
      if (!mounted) return;

      setState(() {
        _status = RegistrationStatus.success;
        _statusMessage = '¡Huella registrada correctamente!';
        _errorMessage = null;
        _currentCapture = 3; // SDK requiere 3 colocaciones
        _isProcessing = false;
      });
    };

    // Iniciar el proceso de registro
    _fingerprintService!.startFingerprintRegistration(widget.employeeId);
  }

  // Simular las 3 capturas mientras FpEnroll está ejecutándose
  void _simulateThreeCaptures() async {
    // Primera captura
    setState(() {
      _currentCapture = 1;
      _status = RegistrationStatus.reading;
      _statusMessage = '📸 Captura 1/3 - Mantenga el dedo quieto';
    });

    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted ||
        _status == RegistrationStatus.success ||
        _status == RegistrationStatus.error)
      return;

    setState(() {
      _status = RegistrationStatus.liftFinger;
      _statusMessage = '⬆️ Levante el dedo del lector';
    });

    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted ||
        _status == RegistrationStatus.success ||
        _status == RegistrationStatus.error)
      return;

    setState(() {
      _status = RegistrationStatus.waitingForFinger;
      _statusMessage = '👇 Coloque el dedo nuevamente (2/3)';
    });

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted ||
        _status == RegistrationStatus.success ||
        _status == RegistrationStatus.error)
      return;

    // Segunda captura
    setState(() {
      _currentCapture = 2;
      _status = RegistrationStatus.reading;
      _statusMessage = '📸 Captura 2/3 - Mantenga el dedo quieto';
    });

    await Future.delayed(const Duration(milliseconds: 1500));
    if (!mounted ||
        _status == RegistrationStatus.success ||
        _status == RegistrationStatus.error)
      return;

    setState(() {
      _status = RegistrationStatus.liftFinger;
      _statusMessage = '⬆️ Levante el dedo del lector';
    });

    await Future.delayed(const Duration(milliseconds: 1000));
    if (!mounted ||
        _status == RegistrationStatus.success ||
        _status == RegistrationStatus.error)
      return;

    setState(() {
      _status = RegistrationStatus.waitingForFinger;
      _statusMessage = '👇 Coloque el dedo nuevamente (3/3)';
    });

    await Future.delayed(const Duration(milliseconds: 800));
    if (!mounted ||
        _status == RegistrationStatus.success ||
        _status == RegistrationStatus.error)
      return;

    // Tercera captura
    setState(() {
      _currentCapture = 3;
      _status = RegistrationStatus.reading;
      _statusMessage = '📸 Captura 3/3 - Procesando...';
    });
  }

  void _resetRegistration() {
    if (_fingerprintService != null) {
      _fingerprintService!.stopFingerprintRegistration();
    }

    setState(() {
      _status = RegistrationStatus.idle;
      _statusMessage = 'Presione el botón para iniciar el registro';
      _errorMessage = null;
      _currentCapture = 0;
      _isProcessing = false;
    });
  }

  @override
  void dispose() {
    // Detener el registro si está en proceso
    if (_isProcessing && _fingerprintService != null) {
      _fingerprintService!.stopFingerprintRegistration();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fingerprintService = Provider.of<FingerprintReaderService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Registrar Huella'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              // Información del empleado
              Text(
                'Registrar huella para:',
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(color: Colors.grey.shade600),
              ),
              const SizedBox(height: 8.0),
              Text(
                widget.employeeName,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 48.0),

              // Icono de huella que se va llenando
              _buildFingerprintIcon(),

              const SizedBox(height: 32.0),

              // Mensaje de estado
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: _getStatusColor().withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: _getStatusColor().withOpacity(0.3),
                    width: 2,
                  ),
                ),
                child: Text(
                  _statusMessage,
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: _getStatusColor(),
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),

              if (_errorMessage != null) ...[
                const SizedBox(height: 16.0),
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade700),
                      const SizedBox(width: 8.0),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(color: Colors.red.shade700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              const SizedBox(height: 32.0),

              // Indicador de progreso con círculos
              _buildProgressIndicator(),

              const SizedBox(height: 32.0),

              // Botones de acción
              _buildActionButtons(),

              const SizedBox(height: 24.0),

              // Info de conexión
              if (!fingerprintService.isConnected)
                Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8.0),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber, color: Colors.orange.shade700),
                      const SizedBox(width: 8.0),
                      const Expanded(
                        child: Text(
                          'Lector desconectado. Por favor, conecte el lector desde Configuraciones.',
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  // Icono de huella que se va llenando
  Widget _buildFingerprintIcon() {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Fondo del icono
        Container(
          width: 180,
          height: 180,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _getStatusBackgroundColor(),
            boxShadow: [
              BoxShadow(
                color: _getStatusColor().withOpacity(0.3),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Icon(Icons.fingerprint, size: 120, color: _getStatusColor()),
        ),

        // Indicador de progreso circular
        if (_status != RegistrationStatus.idle &&
            _status != RegistrationStatus.error)
          SizedBox(
            width: 200,
            height: 200,
            child: CircularProgressIndicator(
              value: _currentCapture / _totalCaptures,
              strokeWidth: 8,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(
                _status == RegistrationStatus.success
                    ? Colors.green
                    : Colors.blue,
              ),
            ),
          ),
      ],
    );
  }

  // Indicador de progreso con círculos numerados
  Widget _buildProgressIndicator() {
    if (_status == RegistrationStatus.idle) {
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(_totalCaptures, (index) {
            final isCompleted = index < _currentCapture;
            final isCurrent =
                index == _currentCapture &&
                _status != RegistrationStatus.success;

            return AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 6.0),
              width: 50,
              height: 50,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color:
                    isCompleted
                        ? Colors.green
                        : isCurrent
                        ? Colors.blue.shade100
                        : Colors.grey.shade200,
                border: Border.all(
                  color:
                      isCompleted
                          ? Colors.green.shade700
                          : isCurrent
                          ? Colors.blue
                          : Colors.grey.shade400,
                  width: isCurrent ? 3 : 2,
                ),
              ),
              child: Center(
                child:
                    isCompleted
                        ? const Icon(Icons.check, color: Colors.white, size: 24)
                        : Text(
                          '${index + 1}',
                          style: TextStyle(
                            color:
                                isCurrent ? Colors.blue : Colors.grey.shade600,
                            fontWeight: FontWeight.bold,
                            fontSize: 18,
                          ),
                        ),
              ),
            );
          }),
        ),
        const SizedBox(height: 12.0),
        Text(
          _status == RegistrationStatus.success
              ? '✅ Completado'
              : 'Progreso: $_currentCapture de $_totalCaptures capturas',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
            color:
                _status == RegistrationStatus.success
                    ? Colors.green.shade700
                    : Colors.grey.shade700,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  // Botones de acción
  Widget _buildActionButtons() {
    if (_status == RegistrationStatus.idle) {
      return ElevatedButton.icon(
        onPressed: _startRegistration,
        icon: const Icon(Icons.fingerprint, size: 28),
        label: const Text('Iniciar Registro'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          textStyle: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
      );
    } else if (_status == RegistrationStatus.success) {
      return Column(
        children: [
          ElevatedButton.icon(
            onPressed: _resetRegistration,
            icon: const Icon(Icons.refresh, size: 28),
            label: const Text('Registrar Otra Huella'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.check_circle),
            label: const Text('Finalizar'),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.green,
              side: const BorderSide(color: Colors.green, width: 2),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              textStyle: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      );
    } else if (_status == RegistrationStatus.error) {
      return ElevatedButton.icon(
        onPressed: _resetRegistration,
        icon: const Icon(Icons.refresh),
        label: const Text('Reintentar'),
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.orange,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
      );
    } else {
      // En proceso
      return const SizedBox.shrink();
    }
  }

  Color _getStatusColor() {
    switch (_status) {
      case RegistrationStatus.idle:
        return Colors.grey.shade600;
      case RegistrationStatus.waitingForFinger:
        return Colors.blue;
      case RegistrationStatus.reading:
        return Colors.orange;
      case RegistrationStatus.liftFinger:
        return Colors.purple;
      case RegistrationStatus.success:
        return Colors.green;
      case RegistrationStatus.error:
        return Colors.red;
    }
  }

  Color _getStatusBackgroundColor() {
    switch (_status) {
      case RegistrationStatus.idle:
        return Colors.grey.shade100;
      case RegistrationStatus.waitingForFinger:
        return Colors.blue.shade50;
      case RegistrationStatus.reading:
        return Colors.orange.shade50;
      case RegistrationStatus.liftFinger:
        return Colors.purple.shade50;
      case RegistrationStatus.success:
        return Colors.green.shade50;
      case RegistrationStatus.error:
        return Colors.red.shade50;
    }
  }
}
