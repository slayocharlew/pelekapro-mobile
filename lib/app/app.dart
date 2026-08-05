import 'package:flutter/material.dart';
import 'package:pelekapro_mobile/core/config/app_config.dart';

class PelekaProApp extends StatelessWidget {
  const PelekaProApp({super.key});

  @override
  Widget build(BuildContext context) {
    const brandGreen = Color(0xFF075E54);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PelekaPro Mobile',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: brandGreen,
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF4F8F6),
        useMaterial3: true,
      ),
      home: const _EnvironmentReadyScreen(),
    );
  }
}

class _EnvironmentReadyScreen extends StatelessWidget {
  const _EnvironmentReadyScreen();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final configured = AppConfig.isApiBaseUrlConfigured;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    margin: const EdgeInsets.only(bottom: 24),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: const Icon(
                      Icons.local_shipping_rounded,
                      color: Colors.white,
                      size: 38,
                      semanticLabel: 'PelekaPro delivery',
                    ),
                  ),
                  Text(
                    'PelekaPro Mobile',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: const Color(0xFF17352F),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Driver Delivery Application',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: const Color(0xFF527068),
                    ),
                  ),
                  const SizedBox(height: 32),
                  _StatusCard(
                    icon: Icons.android_rounded,
                    title: 'Android environment ready',
                    message: 'Backend integration is the next phase.',
                    color: theme.colorScheme.primary,
                  ),
                  const SizedBox(height: 16),
                  _StatusCard(
                    icon: configured
                        ? Icons.lan_rounded
                        : Icons.link_off_rounded,
                    title: 'API base URL',
                    message: AppConfig.apiHostLabel,
                    color: configured
                        ? theme.colorScheme.primary
                        : theme.colorScheme.secondary,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.title,
    required this.message,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String message;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Color(0xFFDCE9E4)),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 28),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: const Color(0xFF5B6F69),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
