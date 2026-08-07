import 'package:flutter/material.dart';
import 'package:pelekapro_mobile/app/theme/app_spacing.dart';
import 'package:pelekapro_mobile/app/theme/app_theme.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_repository.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_user.dart';
import 'package:pelekapro_mobile/features/auth/presentation/logout_controller.dart';
import 'package:pelekapro_mobile/shared/widgets/app_card.dart';
import 'package:pelekapro_mobile/shared/widgets/pelekapro_brand.dart';

class AccountPage extends StatefulWidget {
  const AccountPage({
    required this.user,
    required this.repository,
    required this.onRefresh,
    required this.onOpenHistory,
    required this.onLoggedOut,
    super.key,
  });

  final AuthUser user;
  final AuthRepository repository;
  final VoidCallback onRefresh;
  final VoidCallback onOpenHistory;
  final VoidCallback onLoggedOut;

  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  late final LogoutController _logoutController;

  @override
  void initState() {
    super.initState();
    _logoutController = LogoutController(widget.repository)
      ..addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    _logoutController
      ..removeListener(_handleControllerChanged)
      ..dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _requestLogout() async {
    _logoutController.clearError();
    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => const _LogoutConfirmationSheet(),
    );

    if (!mounted || confirmed != true) {
      return;
    }

    final succeeded = await _logoutController.submit();
    if (!mounted) {
      return;
    }

    if (succeeded) {
      widget.onLoggedOut();
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            _logoutController.errorMessage ??
                'Sign out could not be completed. Please try again.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    final profile = user.driverProfile!;
    return SafeArea(
      child: ListView(
        key: const ValueKey('account-page'),
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.page,
          AppSpacing.md,
          AppSpacing.page,
          AppSpacing.xl,
        ),
        children: [
          Row(
            children: [
              const PelekaProBrand(compact: true),
              const Spacer(),
              IconButton(
                key: const ValueKey('account-refresh'),
                onPressed: widget.onRefresh,
                tooltip: 'Refresh account',
                icon: const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.xl),
          Text('Account', style: Theme.of(context).textTheme.headlineMedium),
          const SizedBox(height: AppSpacing.lg),
          AppCard(
            child: Column(
              children: [
                _ProfileHeader(user: user),
                if (user.phone != null || user.email != null) ...[
                  const SizedBox(height: AppSpacing.lg),
                  const Divider(),
                  const SizedBox(height: AppSpacing.md),
                  if (user.phone case final phone?)
                    _ContactRow(icon: Icons.phone_outlined, value: phone),
                  if (user.phone != null && user.email != null)
                    const SizedBox(height: AppSpacing.sm),
                  if (user.email case final email?)
                    _ContactRow(icon: Icons.email_outlined, value: email),
                ],
                const SizedBox(height: AppSpacing.md),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    key: const ValueKey('account-availability'),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: profile.isAvailable
                          ? AppColors.successSoft
                          : AppColors.postmanOrangeSoft,
                      borderRadius: BorderRadius.circular(9),
                    ),
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      spacing: AppSpacing.xs,
                      children: [
                        Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: profile.isAvailable
                                ? AppColors.success
                                : AppColors.postmanOrangeDark,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Text(
                          profile.isAvailable
                              ? 'Available for deliveries'
                              : 'Not available',
                          style: TextStyle(
                            color: profile.isAvailable
                                ? AppColors.success
                                : AppColors.postmanOrangeDark,
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppCard(
            padding: EdgeInsets.zero,
            child: Column(
              children: [
                _AccountAction(
                  key: const ValueKey('account-delivery-history'),
                  icon: Icons.inventory_2_outlined,
                  label: 'Delivery history',
                  onTap: widget.onOpenHistory,
                ),
                const Divider(indent: 52),
                _AccountAction(
                  key: const ValueKey('logout-current-device'),
                  icon: Icons.logout_rounded,
                  label: 'Logout',
                  isLoading: _logoutController.isSubmitting,
                  onTap: _requestLogout,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.user});

  final AuthUser user;

  @override
  Widget build(BuildContext context) {
    final words = user.name.trim().split(RegExp(r'\s+'));
    final initials = words
        .where((word) => word.isNotEmpty)
        .take(2)
        .map((word) => word[0].toUpperCase())
        .join();

    return Row(
      children: [
        CircleAvatar(
          radius: 34,
          backgroundColor: AppColors.postmanOrangeSoft,
          foregroundColor: AppColors.postmanOrangeDark,
          child: Text(
            initials.isEmpty ? 'D' : initials,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
          ),
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                user.name,
                key: const ValueKey('account-driver-name'),
                style: const TextStyle(
                  color: AppColors.ink,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: AppSpacing.xxs),
              const Text(
                'Driver account',
                style: TextStyle(color: AppColors.mutedInk, fontSize: 13),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ContactRow extends StatelessWidget {
  const _ContactRow({required this.icon, required this.value});

  final IconData icon;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: AppColors.mutedInk, size: 19),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: AppColors.ink, fontSize: 14),
          ),
        ),
      ],
    );
  }
}

class _AccountAction extends StatelessWidget {
  const _AccountAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isLoading = false,
    super.key,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: isLoading ? null : onTap,
      minTileHeight: 58,
      leading: Icon(icon, color: AppColors.postmanOrangeDark),
      title: Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      trailing: isLoading
          ? const SizedBox.square(
              dimension: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right_rounded, color: AppColors.mutedInk),
    );
  }
}

class _LogoutConfirmationSheet extends StatelessWidget {
  const _LogoutConfirmationSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.xl,
          AppSpacing.xs,
          AppSpacing.xl,
          AppSpacing.xl,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Icon(
              Icons.logout_rounded,
              color: AppColors.postmanOrange,
              size: 38,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Sign out this phone?',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.xs),
            const Text(
              'Your secure session on this device will end.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.mutedInk, fontSize: 14),
            ),
            const SizedBox(height: AppSpacing.xl),
            FilledButton(
              key: const ValueKey('confirm-logout-current-device'),
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('Sign out'),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Stay signed in'),
            ),
          ],
        ),
      ),
    );
  }
}
