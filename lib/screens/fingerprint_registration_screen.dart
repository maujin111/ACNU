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
  String _statusMessage = 'Place finger on reader...';
  bool _isRegistering = false;

  @override
  void initState() {
    super.initState();
    _startRegistration();
  }

  void _startRegistration() async {
    setState(() {
      _isRegistering = true;
      _statusMessage = 'Waiting for fingerprint...';
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

    // Listen for connection changes to update UI
    fingerprintService.onConnectionChanged = (isConnected) {
      if (!mounted) return; // Add mounted check here
      if (!isConnected) {
        setState(() {
          _statusMessage = 'Reader disconnected. Please reconnect.';
          _isRegistering = false;
        });
      } else if (_isRegistering) {
        setState(() {
          _statusMessage = 'Reader connected. Waiting for fingerprint...';
        });
      }
    };

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
      appBar: AppBar(title: const Text('Register Fingerprint')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Text(
                'Registering fingerprint for:',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                widget.employeeName,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 32.0),
              if (fingerprintService.lastFingerprintImage != null)
                Image.memory(
                  fingerprintService.lastFingerprintImage!,
                  width: 150,
                  height: 150,
                  fit: BoxFit.contain,
                )
              else
                const Icon(Icons.fingerprint, size: 100, color: Colors.grey),
              const SizedBox(height: 32.0),
              Text(
                _statusMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24.0),
              if (_isRegistering)
                const CircularProgressIndicator()
              else
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('Done'),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
