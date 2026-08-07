import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pelekapro_mobile/app/theme/app_spacing.dart';
import 'package:pelekapro_mobile/app/theme/app_theme.dart';
import 'package:pelekapro_mobile/features/auth/auth_composition.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_repository.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_user.dart';
import 'package:pelekapro_mobile/features/auth/presentation/login_controller.dart';
import 'package:pelekapro_mobile/features/auth/presentation/login_success_screen.dart';
import 'package:pelekapro_mobile/features/auth/presentation/widgets/login_error_banner.dart';
import 'package:pelekapro_mobile/shared/widgets/pelekapro_brand.dart';
import 'package:pelekapro_mobile/shared/widgets/primary_button.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.repository, this.onAuthenticated});

  final AuthRepository? repository;
  final ValueChanged<AuthUser>? onAuthenticated;

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();

  late final AuthRepository _repository;
  late final LoginController _loginController;
  late final bool _ownsRepository;

  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _ownsRepository = widget.repository == null;
    _repository = widget.repository ?? AuthComposition.createRepository();
    _loginController = LoginController(_repository)
      ..addListener(_handleControllerChanged);
  }

  @override
  void dispose() {
    _loginController
      ..removeListener(_handleControllerChanged)
      ..dispose();

    if (_ownsRepository) {
      _repository.close();
    }

    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _handleControllerChanged() {
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final session = await _loginController.submit(
      login: _identifierController.text,
      password: _passwordController.text,
    );

    if (!mounted || session == null) {
      return;
    }

    _passwordController.clear();
    TextInput.finishAutofillContext();

    if (widget.onAuthenticated case final onAuthenticated?) {
      onAuthenticated(session.user);
      return;
    }

    unawaited(
      Navigator.of(context).pushReplacement<void, void>(
        MaterialPageRoute<void>(
          builder: (_) => LoginSuccessScreen(user: session.user),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSubmitting = _loginController.isSubmitting;

    return Scaffold(
      key: const ValueKey('login-screen'),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.page,
              vertical: AppSpacing.xl,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Center(child: PelekaProBrand()),
                      const SizedBox(height: 54),
                      Text(
                        'Welcome back',
                        style: Theme.of(context).textTheme.headlineLarge,
                      ),
                      const SizedBox(height: AppSpacing.xs),
                      const Text(
                        'Sign in to continue',
                        style: TextStyle(
                          color: AppColors.mutedInk,
                          fontSize: 16,
                        ),
                      ),
                      if (_loginController.generalError case final error?) ...[
                        const SizedBox(height: AppSpacing.lg),
                        LoginErrorBanner(message: error),
                      ],
                      const SizedBox(height: AppSpacing.xxl),
                      TextFormField(
                        key: const ValueKey('login-identifier'),
                        controller: _identifierController,
                        enabled: !isSubmitting,
                        keyboardType: TextInputType.text,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.username],
                        autocorrect: false,
                        onChanged: (_) => _loginController.clearLoginError(),
                        decoration: InputDecoration(
                          labelText: 'Phone or email',
                          hintText: '+255 712 345 678',
                          prefixIcon: const Icon(Icons.person_outline_rounded),
                          errorText: _loginController.loginError,
                        ),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Enter your phone number or email.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.md),
                      TextFormField(
                        key: const ValueKey('login-password'),
                        controller: _passwordController,
                        enabled: !isSubmitting,
                        obscureText: _obscurePassword,
                        textInputAction: TextInputAction.done,
                        autofillHints: const [AutofillHints.password],
                        enableSuggestions: false,
                        autocorrect: false,
                        onChanged: (_) => _loginController.clearPasswordError(),
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(
                          labelText: 'Password',
                          prefixIcon: const Icon(Icons.lock_outline_rounded),
                          errorText: _loginController.passwordError,
                          suffixIcon: IconButton(
                            key: const ValueKey('password-visibility'),
                            tooltip: _obscurePassword
                                ? 'Show password'
                                : 'Hide password',
                            onPressed: isSubmitting
                                ? null
                                : () => setState(
                                    () => _obscurePassword = !_obscurePassword,
                                  ),
                            icon: Icon(
                              _obscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                            ),
                          ),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Enter your password.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: AppSpacing.xl),
                      PrimaryButton(
                        key: const ValueKey('login-submit'),
                        label: 'Sign in',
                        onPressed: _submit,
                        isLoading: isSubmitting,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      const Text(
                        'Driver access only',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.mutedInk,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
