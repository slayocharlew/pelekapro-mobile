import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:pelekapro_mobile/app/theme/app_theme.dart';
import 'package:pelekapro_mobile/features/auth/auth_composition.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_repository.dart';
import 'package:pelekapro_mobile/features/auth/presentation/login_controller.dart';
import 'package:pelekapro_mobile/features/auth/presentation/login_success_screen.dart';
import 'package:pelekapro_mobile/features/auth/presentation/widgets/login_error_banner.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key, this.repository});

  final AuthRepository? repository;

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
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: AutofillGroup(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Container(
                          width: 66,
                          height: 66,
                          decoration: BoxDecoration(
                            color: AppColors.postmanOrange,
                            borderRadius: BorderRadius.circular(21),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.postmanOrangeDark.withValues(
                                  alpha: 0.24,
                                ),
                                blurRadius: 22,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.local_shipping_rounded,
                            color: Colors.white,
                            size: 35,
                            semanticLabel: 'PelekaPro',
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      Text(
                        'Welcome back',
                        style: Theme.of(context).textTheme.headlineMedium
                            ?.copyWith(
                              color: AppColors.ink,
                              fontWeight: FontWeight.w900,
                              letterSpacing: -0.7,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Sign in to view and manage your assigned deliveries.',
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          color: AppColors.mutedInk,
                          height: 1.45,
                        ),
                      ),
                      if (_loginController.generalError case final error?) ...[
                        const SizedBox(height: 22),
                        LoginErrorBanner(message: error),
                      ],
                      const SizedBox(height: 34),
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
                          labelText: 'Phone number or email',
                          hintText: '+255… or driver@example.com',
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
                      const SizedBox(height: 18),
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
                                : () {
                                    setState(
                                      () =>
                                          _obscurePassword = !_obscurePassword,
                                    );
                                  },
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
                      const SizedBox(height: 26),
                      FilledButton(
                        key: const ValueKey('login-submit'),
                        onPressed: isSubmitting ? null : _submit,
                        child: isSubmitting
                            ? const SizedBox.square(
                                dimension: 22,
                                child: CircularProgressIndicator(
                                  key: ValueKey('login-progress'),
                                  strokeWidth: 2.5,
                                ),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text('Sign In'),
                                  SizedBox(width: 9),
                                  Icon(Icons.arrow_forward_rounded, size: 21),
                                ],
                              ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'Your session is encrypted and stored securely on this device.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: AppColors.mutedInk,
                          fontSize: 13,
                          height: 1.4,
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
