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

class _FingerprintRegistrationScreenState
    extends State<FingerprintRegistrationScreen> {
  String _statusMessage = 'Coloque su huella en el lector';
  bool _isRegistering = false;

  @override
  void initState() {
    super.initState();
    _startRegistration();
  }

  void _startRegistration() async {
    setState(() {
      _isRegistering = true;
      _statusMessage = 'Esperando huella...';
    });

    final fingerprintService = Provider.of<FingerprintReaderService>(
      context,
      listen: false,
    );

    // Set up a listener for successful registration (optional, as API call handles success)
    // fingerprintService.onFingerprintRead = (data) {
    //   // This callback is for general fingerprint reads, not specific API registration success
    // };

    // Start the registration process in the service
    fingerprintService.startFingerprintRegistration(widget.employeeId);

    // You might want a mechanism to know when the API call succeeds/fails
    // For now, we rely on the service's internal print statements.
    // A more robust solution would involve a Stream or Future from the service.
  }

  @override
  void dispose() {
    Provider.of<FingerprintReaderService>(
      context,
      listen: false,
    ).stopFingerprintRegistration();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fingerprintService = Provider.of<FingerprintReaderService>(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Registrar Huella')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'Registrar huella para:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                widget.employeeName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 32.0),

              const Icon(Icons.fingerprint, size: 100, color: Colors.grey),
              const SizedBox(height: 32.0),
              Text(
                fingerprintService.isConnected
                    ? (_isRegistering
                        ? 'Esperando huella...'
                        : 'Lector conectado.')
                    : 'Lector desconectado. Por favor, reconectar.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24.0),
              if (_isRegistering)
                const CircularProgressIndicator()
              else
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Listo'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
