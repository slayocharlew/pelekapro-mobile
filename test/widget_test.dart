import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelekapro_mobile/app/app.dart';
import 'package:pelekapro_mobile/app/theme/app_theme.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_failure.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_repository.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_session.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_user.dart';
import 'package:pelekapro_mobile/features/auth/domain/driver_profile.dart';
import 'package:pelekapro_mobile/features/auth/domain/session_restore_result.dart';
import 'package:pelekapro_mobile/features/onboarding/onboarding_screen.dart';

void main() {
  testWidgets('starts with the branded first onboarding page', (tester) async {
    await _pumpApp(tester);

    expect(find.text('PelekaPro'), findsOneWidget);
    expect(find.text('Deliveries made simple'), findsOneWidget);
    expect(find.text('Skip'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('onboarding-indicator-0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('onboarding-indicator-1')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('onboarding-indicator-2')),
      findsOneWidget,
    );

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme?.colorScheme.primary, AppColors.postmanOrange);
    expect(materialApp.theme?.scaffoldBackgroundColor, AppColors.whiteSmoke);
  });

  testWidgets('Next advances through all three onboarding pages', (
    tester,
  ) async {
    await _pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Live tracking with privacy'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Complete with confidence'), findsOneWidget);
    expect(find.text('Get Started'), findsOneWidget);
  });

  testWidgets('onboarding supports swipe navigation', (tester) async {
    await _pumpApp(tester);

    await tester.drag(
      find.byKey(const ValueKey('onboarding-page-view')),
      const Offset(-500, 0),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Live tracking with privacy'), findsOneWidget);
  });

  testWidgets('Skip opens the login screen', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Phone number or email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Deliveries made simple'), findsNothing);
  });

  testWidgets('Get Started opens login from the final page', (tester) async {
    await _pumpApp(tester);

    for (var index = 0; index < 2; index++) {
      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
    }

    await tester.tap(find.byKey(const ValueKey('onboarding-next')));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('login form validates required credentials', (tester) async {
    await _openLogin(tester);

    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pump();

    expect(find.text('Enter your phone number or email.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
  });

  testWidgets('password visibility can be toggled', (tester) async {
    await _openLogin(tester);

    final visibilityButton = find.byKey(const ValueKey('password-visibility'));

    expect(
      find.descendant(
        of: visibilityButton,
        matching: find.byIcon(Icons.visibility_outlined),
      ),
      findsOneWidget,
    );

    await tester.tap(visibilityButton);
    await tester.pump();

    expect(
      find.descendant(
        of: visibilityButton,
        matching: find.byIcon(Icons.visibility_off_outlined),
      ),
      findsOneWidget,
    );
  });

  testWidgets('valid credentials open the verified driver profile', (
    tester,
  ) async {
    final repository = _FakeAuthRepository();
    await _openLogin(tester, repository: repository);

    await tester.enterText(
      find.byKey(const ValueKey('login-identifier')),
      '+255700000000',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password')),
      'safe-test-password',
    );
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('driver-profile-screen')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('driver-session-verified')),
      findsOneWidget,
    );
    expect(find.text('Welcome, Test Driver'), findsOneWidget);
    expect(repository.lastLogin, '+255700000000');
    expect(repository.lastPassword, 'safe-test-password');
  });

  testWidgets('API validation errors appear beside the login fields', (
    tester,
  ) async {
    final repository = _FakeAuthRepository(
      failure: AuthFailure(
        message: 'Validation failed',
        statusCode: 422,
        fieldErrors: const {
          'login': ['Use a valid phone number or email.'],
          'password': ['The password is incorrect.'],
        },
      ),
    );
    await _openLogin(tester, repository: repository);

    await tester.enterText(
      find.byKey(const ValueKey('login-identifier')),
      'invalid-driver',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password')),
      'wrong-password',
    );
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('login-error-banner')), findsOneWidget);
    expect(find.text('Validation failed'), findsOneWidget);
    expect(find.text('Use a valid phone number or email.'), findsOneWidget);
    expect(find.text('The password is incorrect.'), findsOneWidget);
  });

  testWidgets('restores a stored driver session on startup', (tester) async {
    final repository = _FakeAuthRepository(
      restoreResult: const RestoredSession(_testDriver),
    );

    await _pumpApp(tester, repository: repository);

    expect(find.byKey(const ValueKey('driver-profile-screen')), findsOneWidget);
    expect(find.text('Welcome, Test Driver'), findsOneWidget);
    expect(find.text('Available'), findsNWidgets(2));
    expect(find.text('Deliveries made simple'), findsNothing);
    expect(repository.restoreCalls, 1);
  });

  testWidgets('a rejected stored session opens login', (tester) async {
    final repository = _FakeAuthRepository(
      restoreResult: const UnavailableSession(hadStoredSession: true),
    );

    await _pumpApp(tester, repository: repository);

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Deliveries made simple'), findsNothing);
  });

  testWidgets('session restore failure can be retried safely', (tester) async {
    final repository = _FakeAuthRepository(
      restoreFailure: AuthFailure(
        message: 'Unable to reach PelekaPro. Check your connection.',
      ),
    );

    await _pumpApp(tester, repository: repository);

    expect(find.byKey(const ValueKey('session-error-screen')), findsOneWidget);
    expect(find.text('Unable to restore session'), findsOneWidget);
    expect(repository.restoreCalls, 1);

    repository.restoreFailure = null;
    await tester.tap(find.byKey(const ValueKey('session-retry')));
    await tester.pump();
    await tester.pump();

    expect(find.text('Deliveries made simple'), findsOneWidget);
    expect(repository.restoreCalls, 2);
  });

  testWidgets('refresh verifies the current driver again', (tester) async {
    final repository = _FakeAuthRepository(
      restoreResult: const RestoredSession(_testDriver),
    );
    await _pumpApp(tester, repository: repository);

    await tester.tap(find.byKey(const ValueKey('profile-refresh')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('driver-profile-screen')), findsOneWidget);
    expect(repository.restoreCalls, 2);
  });

  testWidgets('illustration remains still when reduced motion is requested', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: OnboardingScreen(),
        ),
      ),
    );
    await tester.pump();

    final illustration = find.byKey(
      const ValueKey('onboarding-illustration-deliveries'),
    );
    final before = List<double>.of(
      tester.widget<Transform>(illustration).transform.storage,
    );

    await tester.pump(const Duration(seconds: 3));

    final after = List<double>.of(
      tester.widget<Transform>(illustration).transform.storage,
    );
    expect(after, before);
  });
}

Future<void> _openLogin(
  WidgetTester tester, {
  AuthRepository? repository,
}) async {
  await _pumpApp(tester, repository: repository ?? _FakeAuthRepository());
  await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
  await tester.pumpAndSettle();
}

Future<void> _pumpApp(WidgetTester tester, {AuthRepository? repository}) async {
  await tester.pumpWidget(
    PelekaProApp(authRepository: repository ?? _FakeAuthRepository()),
  );
  await tester.pump();
  await tester.pump();
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    this.failure,
    this.restoreResult = const UnavailableSession(hadStoredSession: false),
    this.restoreFailure,
  });

  final AuthFailure? failure;
  final SessionRestoreResult restoreResult;
  AuthFailure? restoreFailure;
  String? lastLogin;
  String? lastPassword;
  int restoreCalls = 0;

  @override
  Future<SessionRestoreResult> restoreSession() async {
    restoreCalls += 1;

    if (restoreFailure case final failure?) {
      throw failure;
    }

    return restoreResult;
  }

  @override
  Future<AuthSession> login({
    required String login,
    required String password,
  }) async {
    lastLogin = login;
    lastPassword = password;

    if (failure case final failure?) {
      throw failure;
    }

    return const AuthSession(
      accessToken: 'test-access-token',
      tokenType: 'Bearer',
      user: _testDriver,
    );
  }

  @override
  void close() {}
}

const _testDriver = AuthUser(
  id: 42,
  businessId: 7,
  branchId: 3,
  name: 'Test Driver',
  phone: '+255700000000',
  email: 'driver@example.com',
  status: 'active',
  role: 'driver',
  driverProfile: DriverProfile(
    id: 9,
    isAvailable: true,
    currentStatus: 'available',
  ),
);
