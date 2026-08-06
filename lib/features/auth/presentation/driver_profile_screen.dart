import 'package:flutter/material.dart';
import 'package:pelekapro_mobile/app/theme/app_theme.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_user.dart';

class DriverProfileScreen extends StatelessWidget {
  const DriverProfileScreen({
    required this.user,
    required this.onRefresh,
    super.key,
  });

  final AuthUser user;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context) {
    final profile = user.driverProfile!;

    return Scaffold(
      key: const ValueKey('driver-profile-screen'),
      appBar: AppBar(
        title: const Text(
          'PelekaPro',
          style: TextStyle(fontWeight: FontWeight.w900),
        ),
        actions: [
          IconButton(
            key: const ValueKey('profile-refresh'),
            onPressed: onRefresh,
            tooltip: 'Refresh driver profile',
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Container(
                    padding: const EdgeInsets.all(22),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(22),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          decoration: const BoxDecoration(
                            color: AppColors.postmanOrangeSoft,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.person_rounded,
                            color: AppColors.postmanOrangeDark,
                            size: 42,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Text(
                          'Welcome, ${user.name}',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(
                                color: AppColors.ink,
                                fontWeight: FontWeight.w900,
                              ),
                        ),
                        const SizedBox(height: 8),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.verified_rounded,
                              color: AppColors.success,
                              size: 20,
                            ),
                            SizedBox(width: 7),
                            Text(
                              'Driver session verified',
                              key: ValueKey('driver-session-verified'),
                              style: TextStyle(
                                color: AppColors.success,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                  _ProfileDetailsCard(
                    phone: user.phone,
                    email: user.email,
                    currentStatus: profile.currentStatus,
                    isAvailable: profile.isAvailable,
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Your authenticated profile is current. Assigned '
                    'deliveries can be connected next.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.mutedInk,
                      height: 1.5,
                    ),
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

class _ProfileDetailsCard extends StatelessWidget {
  const _ProfileDetailsCard({
    required this.phone,
    required this.email,
    required this.currentStatus,
    required this.isAvailable,
  });

  final String? phone;
  final String? email;
  final String currentStatus;
  final bool isAvailable;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          if (phone case final phone?)
            _ProfileRow(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: phone,
            ),
          if (phone != null && email != null) const Divider(height: 28),
          if (email case final email?)
            _ProfileRow(
              icon: Icons.email_outlined,
              label: 'Email',
              value: email,
            ),
          if (phone != null || email != null) const Divider(height: 28),
          _ProfileRow(
            icon: Icons.local_shipping_outlined,
            label: 'Driver status',
            value: _readable(currentStatus),
          ),
          const Divider(height: 28),
          _ProfileRow(
            icon: isAvailable
                ? Icons.check_circle_outline_rounded
                : Icons.pause_circle_outline_rounded,
            label: 'Availability',
            value: isAvailable ? 'Available' : 'Unavailable',
          ),
        ],
      ),
    );
  }

  String _readable(String value) {
    if (value.isEmpty) {
      return 'Unknown';
    }

    final words = value.replaceAll('_', ' ').split(' ');
    return words
        .map(
          (word) => word.isEmpty
              ? word
              : '${word[0].toUpperCase()}${word.substring(1)}',
        )
        .join(' ');
  }
}

class _ProfileRow extends StatelessWidget {
  const _ProfileRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: AppColors.postmanOrangeDark, size: 22),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(
                  color: AppColors.mutedInk,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                value,
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
