import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter_svg/flutter_svg.dart';

class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Acerca de ACNU'),
        surfaceTintColor: Colors.lightGreen,
        centerTitle: true,
      ),
      body: FutureBuilder<PackageInfo>(
        future: PackageInfo.fromPlatform(),
        builder: (context, snapshot) {
          // Mientras carga la información del sistema
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: Colors.lightGreen),
            );
          }

          // Si ocurre un error (muy raro)
          if (snapshot.hasError) {
            return Center(child: Text('Error al cargar la información: ${snapshot.error}'));
          }

          // Datos cargados exitosamente
          final packageInfo = snapshot.data!;
          
          return Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(32.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [

                  // LOGO DE LA EMPRESA

                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white, // Fondo blanco para que el logo PNG resalte
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: SvgPicture.asset(
                        'assets/icon/logo.svg', 
                        width: 110,
                        height: 110,
                        fit: BoxFit.contain,
                        placeholderBuilder: (BuildContext context) => const Icon(
                          Icons.business, 
                          size: 80, 
                          color: Colors.lightGreen,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 28),
                  

                  // NOMBRE DE LA APLICACIÓN

                  Text(
                    'Anfibius Connect Nexus Utility', 
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      letterSpacing: 0.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),

                  // VERSIÓN Y BUILD (Etiqueta destacada)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(30),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
                      ),
                    ),
                    child: Text(
                      // 🛡️ Lógica condicional: Solo muestra el "(Build X)" si realmente existe
                      packageInfo.buildNumber.isNotEmpty
                          ? 'Versión ${packageInfo.version}+ ${packageInfo.buildNumber}'
                          : 'Versión ${packageInfo.version}',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 20),

                  // DESCRIPCIÓN 
                 
                  const SizedBox(height: 12),
                  Text(
                    'Gestor de hardware en segundo plano\n(WebSockets, Lectores NFC y POS)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      height: 1.5,
                      color: Theme.of(context).textTheme.bodyMedium?.color?.withOpacity(0.7),
                    ),
                  ),
                  const SizedBox(height: 40),
                  
                  Text(
                    'Copyright © ${DateTime.now().year} Corporación Anfibius.\nTodos los derechos reservados.',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.grey,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}