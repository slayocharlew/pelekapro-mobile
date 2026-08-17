import 'dart:async';

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
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_failure.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/delivery_repository.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery.dart';
import 'package:pelekapro_mobile/features/deliveries/domain/driver_delivery_details.dart';
import 'package:pelekapro_mobile/features/deliveries/presentation/active_navigation_screen.dart';
import 'package:pelekapro_mobile/features/onboarding/onboarding_screen.dart';
import 'package:pelekapro_mobile/shared/widgets/pelekapro_brand.dart';

import 'helpers/driver_delivery_fixture.dart';

void main() {
  testWidgets('startup shows the simple brand while checking the session', (
    tester,
  ) async {
    _usePhoneSurface(tester);
    final completer = Completer<SessionRestoreResult>();
    final repository = _FakeAuthRepository(restoreCompleter: completer);

    await tester.pumpWidget(PelekaProApp(authRepository: repository));
    await tester.pump();

    expect(find.byKey(const ValueKey('session-check-screen')), findsOneWidget);
    expect(find.byType(PelekaProBrand), findsOneWidget);
    expect(
      find.byKey(const ValueKey('session-check-progress')),
      findsOneWidget,
    );
    expect(find.text('Next'), findsNothing);
    expect(find.text('Skip'), findsNothing);

    completer.complete(const UnavailableSession(hadStoredSession: false));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('login-screen')), findsOneWidget);
  });

  testWidgets('no session opens the restrained login screen directly', (
    tester,
  ) async {
    await _pumpApp(tester);

    expect(find.byKey(const ValueKey('login-screen')), findsOneWidget);
    expect(find.byType(PelekaProBrand), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Sign in to continue'), findsOneWidget);
    expect(find.text('Phone or email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Driver access only'), findsOneWidget);
    expect(find.text('Forgot password?'), findsNothing);
    expect(find.textContaining('Google'), findsNothing);

    final materialApp = tester.widget<MaterialApp>(find.byType(MaterialApp));
    expect(materialApp.theme?.colorScheme.primary, AppColors.postmanOrange);
    expect(materialApp.theme?.scaffoldBackgroundColor, AppColors.whiteSmoke);
  });

  testWidgets('login form validates required credentials', (tester) async {
    await _pumpApp(tester);

    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pump();

    expect(find.text('Enter your phone number or email.'), findsOneWidget);
    expect(find.text('Enter your password.'), findsOneWidget);
  });

  testWidgets('password visibility can be toggled', (tester) async {
    await _pumpApp(tester);

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

  testWidgets('working login opens assigned deliveries', (tester) async {
    final repository = _FakeAuthRepository();
    await _pumpApp(tester, repository: repository);

    await tester.enterText(
      find.byKey(const ValueKey('login-identifier')),
      '+255712345678',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password')),
      'safe-test-password',
    );
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('driver-shell')), findsOneWidget);
    expect(find.byKey(const ValueKey('deliveries-page')), findsOneWidget);
    expect(find.text('Assigned deliveries'), findsOneWidget);
    expect(repository.loginCalls, 1);
    expect(repository.lastLogin, '+255712345678');
    expect(repository.lastPassword, 'safe-test-password');
  });

  testWidgets('API validation errors remain attached to login fields', (
    tester,
  ) async {
    final repository = _FakeAuthRepository(
      loginFailure: AuthFailure(
        message: 'Validation failed',
        statusCode: 422,
        fieldErrors: const {
          'login': ['Use a valid phone number or email.'],
          'password': ['The password is incorrect.'],
        },
      ),
    );
    await _pumpApp(tester, repository: repository);

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

  testWidgets('stored driver session restores into deliveries', (tester) async {
    final repository = _authenticatedRepository();
    final deliveryRepository = _FakeDeliveryRepository();
    await _pumpApp(
      tester,
      repository: repository,
      deliveryRepository: deliveryRepository,
    );

    expect(find.byKey(const ValueKey('driver-shell')), findsOneWidget);
    expect(find.byKey(const ValueKey('deliveries-page')), findsOneWidget);
    expect(find.text('Asha Juma'), findsOneWidget);
    expect(find.text('Kariakoo, Dar es Salaam'), findsOneWidget);
    expect(repository.restoreCalls, 1);
    expect(deliveryRepository.fetchCalls, 1);

    await tester.tap(find.byKey(const ValueKey('refresh-assigned-deliveries')));
    await tester.pumpAndSettle();
    expect(deliveryRepository.fetchCalls, 2);
  });

  testWidgets('assigned deliveries shows a lightweight loading state', (
    tester,
  ) async {
    _usePhoneSurface(tester);
    final completer = Completer<List<DriverDelivery>>();
    final deliveryRepository = _FakeDeliveryRepository(completer: completer);

    await tester.pumpWidget(
      PelekaProApp(
        authRepository: _authenticatedRepository(),
        deliveryRepository: deliveryRepository,
      ),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('driver-shell')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('assigned-deliveries-loading')),
      findsOneWidget,
    );

    completer.complete(assignedDeliveriesFixture());
    await tester.pumpAndSettle();
    expect(find.text('Asha Juma'), findsOneWidget);
  });

  testWidgets('assigned deliveries supports an empty response', (tester) async {
    final emptyRepository = _FakeDeliveryRepository(deliveries: const []);
    await _pumpApp(
      tester,
      repository: _authenticatedRepository(),
      deliveryRepository: emptyRepository,
    );
    expect(find.text('No deliveries assigned'), findsOneWidget);
  });

  testWidgets('assigned deliveries supports error and retry states', (
    tester,
  ) async {
    final failedRepository = _FakeDeliveryRepository(
      failure: const DeliveryFailure(
        message: 'Unable to reach PelekaPro. Check your connection.',
      ),
    );
    await _pumpApp(
      tester,
      repository: _authenticatedRepository(),
      deliveryRepository: failedRepository,
    );
    expect(find.text('Something went wrong'), findsOneWidget);
    expect(
      find.text('Unable to reach PelekaPro. Check your connection.'),
      findsOneWidget,
    );

    failedRepository.failure = null;
    await tester.tap(find.byKey(const ValueKey('retry-assigned-deliveries')));
    await tester.pumpAndSettle();
    expect(find.text('Asha Juma'), findsOneWidget);
    expect(failedRepository.fetchCalls, 2);
  });

  testWidgets('an expired delivery-list session returns to login', (
    tester,
  ) async {
    final deliveryRepository = _FakeDeliveryRepository(
      failure: const DeliveryFailure(
        message: 'Your session has expired. Sign in again.',
        statusCode: 401,
      ),
    );
    await _pumpApp(
      tester,
      repository: _authenticatedRepository(),
      deliveryRepository: deliveryRepository,
    );

    expect(find.byKey(const ValueKey('login-screen')), findsOneWidget);
  });

  testWidgets('rejected stored session returns to login', (tester) async {
    final repository = _FakeAuthRepository(
      restoreResult: const UnavailableSession(hadStoredSession: true),
    );
    await _pumpApp(tester, repository: repository);

    expect(find.byKey(const ValueKey('login-screen')), findsOneWidget);
    expect(find.text('Welcome back'), findsOneWidget);
  });

  testWidgets('session restore failure can be retried safely', (tester) async {
    final repository = _FakeAuthRepository(
      restoreFailure: AuthFailure(
        message: 'Unable to reach PelekaPro. Check your connection.',
      ),
    );
    await _pumpApp(tester, repository: repository);

    expect(find.byKey(const ValueKey('session-error-screen')), findsOneWidget);
    expect(find.text('Something went wrong'), findsOneWidget);
    expect(repository.restoreCalls, 1);

    repository.restoreFailure = null;
    await tester.tap(find.byKey(const ValueKey('session-retry')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('login-screen')), findsOneWidget);
    expect(repository.restoreCalls, 2);
  });

  testWidgets('bottom navigation contains exactly the approved three tabs', (
    tester,
  ) async {
    await _pumpApp(tester, repository: _authenticatedRepository());

    final navigation = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(navigation.destinations, hasLength(3));
    expect(
      navigation.destinations.whereType<NavigationDestination>().map(
        (destination) => destination.label,
      ),
      ['Deliveries', 'Active', 'Account'],
    );
    expect(find.text('Home'), findsNothing);
  });

  testWidgets('assigned API delivery opens the concise detail screen', (
    tester,
  ) async {
    final deliveryRepository = _FakeDeliveryRepository(
      details: driverDeliveryDetailsFixture(),
    );
    await _pumpApp(
      tester,
      repository: _authenticatedRepository(),
      deliveryRepository: deliveryRepository,
    );

    await tester.tap(find.byKey(const ValueKey('view-delivery-101')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const ValueKey('delivery-details-screen')),
      findsOneWidget,
    );
    expect(find.text('PP-24031'), findsOneWidget);
    expect(find.textContaining('Uhuru Street, Kariakoo'), findsOneWidget);
    expect(find.textContaining('Mwai Kibaki Road, Mikocheni'), findsOneWidget);
    expect(find.text('Asha Juma'), findsOneWidget);
    expect(find.text('TZS 25,000'), findsOneWidget);
    expect(find.text('Call on arrival'), findsOneWidget);
    expect(find.text('Accept delivery'), findsNothing);
    expect(find.text('Mark arrived'), findsNothing);
    expect(find.text('Cancel delivery'), findsNothing);
    expect(deliveryRepository.detailFetchCalls, 1);
    expect(deliveryRepository.lastDetailId, 101);
  });

  testWidgets('delivery details supports loading and retry states', (
    tester,
  ) async {
    final detailCompleter = Completer<DriverDeliveryDetails>();
    final deliveryRepository = _FakeDeliveryRepository(
      detailCompleter: detailCompleter,
    );
    await _pumpApp(
      tester,
      repository: _authenticatedRepository(),
      deliveryRepository: deliveryRepository,
    );

    await tester.tap(find.byKey(const ValueKey('view-delivery-101')));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      find.byKey(const ValueKey('delivery-details-loading')),
      findsOneWidget,
    );

    detailCompleter.complete(driverDeliveryDetailsFixture());
    await tester.pumpAndSettle();
    expect(find.text('Asha Juma'), findsOneWidget);

    await tester.pageBack();
    await tester.pumpAndSettle();
    deliveryRepository.detailFailure = const DeliveryFailure(
      message: 'Unable to load this delivery.',
    );
    await tester.tap(find.byKey(const ValueKey('view-delivery-101')));
    await tester.pumpAndSettle();
    expect(find.text('Unable to load this delivery.'), findsOneWidget);

    deliveryRepository.detailFailure = null;
    await tester.tap(find.byKey(const ValueKey('retry-delivery-details')));
    await tester.pumpAndSettle();
    expect(find.text('Asha Juma'), findsOneWidget);
  });

  testWidgets('an expired delivery-detail session returns to login', (
    tester,
  ) async {
    final deliveryRepository = _FakeDeliveryRepository(
      detailFailure: const DeliveryFailure(
        message: 'Your session has expired. Sign in again.',
        statusCode: 401,
      ),
    );
    await _pumpApp(
      tester,
      repository: _authenticatedRepository(),
      deliveryRepository: deliveryRepository,
    );

    await tester.tap(find.byKey(const ValueKey('view-delivery-101')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('login-screen')), findsOneWidget);
    expect(deliveryRepository.detailFetchCalls, 1);
  });

  testWidgets('Start delivery opens motorcycle navigation locally only', (
    tester,
  ) async {
    final repository = _authenticatedRepository();
    final deliveryRepository = _FakeDeliveryRepository();
    await _pumpApp(
      tester,
      repository: repository,
      deliveryRepository: deliveryRepository,
    );
    await _openFirstNavigation(tester);

    expect(
      find.byKey(const ValueKey('active-navigation-screen')),
      findsOneWidget,
    );
    expect(find.byType(MotorcycleMarker), findsOneWidget);
    expect(find.text('Turn right'), findsOneWidget);
    expect(find.text('Ali Hassan Mwinyi Rd'), findsWidgets);
    expect(find.textContaining('OpenStreetMap'), findsOneWidget);
    expect(repository.restoreCalls, 1);
    expect(repository.loginCalls, 0);
    expect(repository.logoutCalls, 0);
    expect(deliveryRepository.fetchCalls, 1);
    expect(deliveryRepository.detailFetchCalls, 1);
  });

  testWidgets(
    'local delivered journey returns to deliveries without API calls',
    (tester) async {
      final repository = _authenticatedRepository();
      final deliveryRepository = _FakeDeliveryRepository();
      await _pumpApp(
        tester,
        repository: repository,
        deliveryRepository: deliveryRepository,
      );
      await _openFirstNavigation(tester);

      await tester.tap(find.byKey(const ValueKey('mark-delivered-local')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('mark-delivered-screen')),
        findsOneWidget,
      );
      expect(find.text('Proof of delivery'), findsOneWidget);
      expect(find.text('Cash on delivery'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('confirm-delivered-local')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('delivered-result-screen')),
        findsOneWidget,
      );
      expect(find.text('Delivery completed successfully'), findsOneWidget);

      await tester.tap(find.byKey(const ValueKey('back-to-deliveries')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('deliveries-page')), findsOneWidget);
      expect(repository.restoreCalls, 1);
      expect(repository.loginCalls, 0);
      expect(repository.logoutCalls, 0);
      expect(deliveryRepository.fetchCalls, 1);
      expect(deliveryRepository.detailFetchCalls, 1);
    },
  );

  testWidgets('local failed journey returns to deliveries without API calls', (
    tester,
  ) async {
    final repository = _authenticatedRepository();
    final deliveryRepository = _FakeDeliveryRepository();
    await _pumpApp(
      tester,
      repository: repository,
      deliveryRepository: deliveryRepository,
    );

    await tester.tap(find.byKey(const ValueKey('nav-active')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('active-deliveries-page')),
      findsOneWidget,
    );
    expect(find.text('Assigned deliveries'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('open-active-navigation')));
    await tester.pumpAndSettle();
    expect(
      find.bySemanticsLabel(
        'OpenStreetMap style navigation preview in Oysterbay, Dar es Salaam',
      ),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('report-issue-local')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('report-issue-screen')), findsOneWidget);
    expect(find.text('Customer unavailable'), findsOneWidget);
    expect(find.text('Wrong address'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('issue-reason-customer-unavailable')),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('submit-issue-local')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('failed-result-screen')), findsOneWidget);
    expect(find.text('Delivery marked as failed'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('back-to-deliveries')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('deliveries-page')), findsOneWidget);
    expect(repository.restoreCalls, 1);
    expect(repository.loginCalls, 0);
    expect(repository.logoutCalls, 0);
    expect(deliveryRepository.fetchCalls, 1);
    expect(deliveryRepository.detailFetchCalls, 1);
  });

  testWidgets('Account renders only real me data and useful actions', (
    tester,
  ) async {
    final repository = _authenticatedRepository();
    await _pumpApp(tester, repository: repository);

    await tester.tap(find.byKey(const ValueKey('nav-account')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('account-page')), findsOneWidget);
    expect(find.text('Emmanuel Mushi'), findsOneWidget);
    expect(find.text('+255 712 345 678'), findsOneWidget);
    expect(find.text('Available for deliveries'), findsOneWidget);
    expect(find.text('Delivery history'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
    expect(find.text('Rating'), findsNothing);
    expect(find.text('Earnings'), findsNothing);
    expect(find.text('Wallet'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('account-delivery-history')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('deliveries-page')), findsOneWidget);
    expect(find.text('Rehema Kweka'), findsOneWidget);
  });

  testWidgets('account refresh still validates the current me session', (
    tester,
  ) async {
    final repository = _authenticatedRepository();
    await _pumpApp(tester, repository: repository);

    await tester.tap(find.byKey(const ValueKey('nav-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('account-refresh')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('driver-shell')), findsOneWidget);
    expect(repository.restoreCalls, 2);
  });

  testWidgets('current-device logout keeps its existing secure behavior', (
    tester,
  ) async {
    final repository = _authenticatedRepository();
    await _pumpApp(tester, repository: repository);

    await tester.tap(find.byKey(const ValueKey('nav-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('logout-current-device')));
    await tester.pumpAndSettle();
    expect(find.text('Sign out this phone?'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('confirm-logout-current-device')),
    );
    await tester.pumpAndSettle();

    expect(repository.logoutCalls, 1);
    expect(find.byKey(const ValueKey('login-screen')), findsOneWidget);
  });

  testWidgets('failed logout keeps the account visible', (tester) async {
    final repository = _FakeAuthRepository(
      restoreResult: const RestoredSession(_testDriver),
      logoutFailure: AuthFailure(
        message: 'PelekaPro is temporarily unavailable. Please try again.',
        statusCode: 503,
      ),
    );
    await _pumpApp(tester, repository: repository);

    await tester.tap(find.byKey(const ValueKey('nav-account')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('logout-current-device')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('confirm-logout-current-device')),
    );
    await tester.pumpAndSettle();

    expect(repository.logoutCalls, 1);
    expect(find.byKey(const ValueKey('account-page')), findsOneWidget);
    expect(
      find.text('PelekaPro is temporarily unavailable. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('main layouts remain overflow-free at common Android widths', (
    tester,
  ) async {
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    for (final width in [360.0, 375.0, 390.0, 480.0]) {
      tester.view.physicalSize = Size(width, 844);
      tester.view.devicePixelRatio = 1;
      await tester.pumpWidget(
        PelekaProApp(
          authRepository: _authenticatedRepository(),
          deliveryRepository: _FakeDeliveryRepository(),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'Unexpected layout exception at ${width.toInt()} px',
      );
      expect(find.byKey(const ValueKey('deliveries-page')), findsOneWidget);
    }
  });

  testWidgets('delivery workflow stays usable at 360 px with larger text', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    tester.platformDispatcher.textScaleFactorTestValue = 1.2;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
      tester.platformDispatcher.clearTextScaleFactorTestValue();
    });

    await tester.pumpWidget(
      PelekaProApp(
        authRepository: _authenticatedRepository(),
        deliveryRepository: _FakeDeliveryRepository(),
      ),
    );
    await tester.pumpAndSettle();
    final initialException = tester.takeException();
    expect(
      initialException,
      isNull,
      reason: initialException is FlutterError
          ? initialException.toStringDeep()
          : null,
    );

    await tester.tap(find.byKey(const ValueKey('nav-active')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('active-deliveries-page')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('nav-account')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('account-page')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('nav-deliveries')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('deliveries-page')), findsOneWidget);
    expect(tester.takeException(), isNull);

    final viewDelivery = find.byKey(const ValueKey('view-delivery-101'));
    await tester.ensureVisible(viewDelivery);
    await tester.pumpAndSettle();
    await tester.tap(viewDelivery);
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('delivery-details-screen')),
      findsOneWidget,
    );
    expect(tester.takeException(), isNull);

    await tester.tap(find.byKey(const ValueKey('start-delivery-local')));
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('active-navigation-screen')),
      findsOneWidget,
    );
    final navigationException = tester.takeException();
    expect(
      navigationException,
      isNull,
      reason: navigationException is FlutterError
          ? navigationException.toStringDeep()
          : null,
    );

    final markDelivered = find.byKey(const ValueKey('mark-delivered-local'));
    final navigationSheet = find.byKey(
      const ValueKey('active-navigation-sheet-list'),
    );
    await tester.scrollUntilVisible(
      markDelivered,
      160,
      scrollable: find.descendant(
        of: navigationSheet,
        matching: find.byType(Scrollable),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(markDelivered);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('mark-delivered-screen')), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pageBack();
    await tester.pumpAndSettle();
    final reportIssue = find.byKey(const ValueKey('report-issue-local'));
    if (reportIssue.evaluate().isEmpty) {
      await tester.scrollUntilVisible(
        reportIssue,
        160,
        scrollable: find.descendant(
          of: navigationSheet,
          matching: find.byType(Scrollable),
        ),
      );
      await tester.pumpAndSettle();
    } else {
      await tester.ensureVisible(reportIssue);
    }
    await tester.tap(reportIssue);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('report-issue-screen')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('legacy illustration remains still with reduced motion', (
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

Future<void> _openFirstNavigation(WidgetTester tester) async {
  await tester.tap(find.byKey(const ValueKey('view-delivery-101')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const ValueKey('start-delivery-local')));
  await tester.pumpAndSettle();
}

Future<void> _pumpApp(
  WidgetTester tester, {
  AuthRepository? repository,
  DeliveryRepository? deliveryRepository,
}) async {
  _usePhoneSurface(tester);
  await tester.pumpWidget(
    PelekaProApp(
      authRepository: repository ?? _FakeAuthRepository(),
      deliveryRepository: deliveryRepository ?? _FakeDeliveryRepository(),
    ),
  );
  await tester.pumpAndSettle();
}

void _usePhoneSurface(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(() {
    tester.view.resetPhysicalSize();
    tester.view.resetDevicePixelRatio();
  });
}

_FakeAuthRepository _authenticatedRepository() {
  return _FakeAuthRepository(restoreResult: const RestoredSession(_testDriver));
}

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({
    this.loginFailure,
    this.restoreResult = const UnavailableSession(hadStoredSession: false),
    this.restoreFailure,
    this.logoutFailure,
    this.restoreCompleter,
  });

  final AuthFailure? loginFailure;
  final SessionRestoreResult restoreResult;
  AuthFailure? restoreFailure;
  final AuthFailure? logoutFailure;
  final Completer<SessionRestoreResult>? restoreCompleter;
  String? lastLogin;
  String? lastPassword;
  int restoreCalls = 0;
  int loginCalls = 0;
  int logoutCalls = 0;

  @override
  Future<SessionRestoreResult> restoreSession() async {
    restoreCalls += 1;
    if (restoreCompleter case final completer?) {
      return completer.future;
    }
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
    loginCalls += 1;
    lastLogin = login;
    lastPassword = password;
    if (loginFailure case final failure?) {
      throw failure;
    }
    return const AuthSession(
      accessToken: 'test-access-token',
      tokenType: 'Bearer',
      user: _testDriver,
    );
  }

  @override
  Future<void> logout() async {
    logoutCalls += 1;
    if (logoutFailure case final failure?) {
      throw failure;
    }
  }

  @override
  void close() {}
}

class _FakeDeliveryRepository implements DeliveryRepository {
  _FakeDeliveryRepository({
    List<DriverDelivery>? deliveries,
    this.failure,
    this.completer,
    this.details,
    this.detailFailure,
    this.detailCompleter,
  }) : deliveries = deliveries ?? assignedDeliveriesFixture();

  final List<DriverDelivery> deliveries;
  DeliveryFailure? failure;
  final Completer<List<DriverDelivery>>? completer;
  final DriverDeliveryDetails? details;
  DeliveryFailure? detailFailure;
  final Completer<DriverDeliveryDetails>? detailCompleter;
  int fetchCalls = 0;
  int detailFetchCalls = 0;
  int? lastDetailId;

  @override
  Future<List<DriverDelivery>> fetchAssignedDeliveries() async {
    fetchCalls += 1;
    if (completer case final pending?) {
      return pending.future;
    }
    if (failure case final deliveryFailure?) {
      throw deliveryFailure;
    }
    return deliveries;
  }

  @override
  Future<DriverDeliveryDetails> fetchDeliveryDetails(int deliveryId) async {
    detailFetchCalls += 1;
    lastDetailId = deliveryId;
    if (detailFailure case final deliveryFailure?) {
      throw deliveryFailure;
    }
    if (detailCompleter case final pending?) {
      return pending.future;
    }
    if (details case final configuredDetails?) {
      return configuredDetails;
    }
    return driverDeliveryDetailsFixture(
      delivery: deliveries.firstWhere((delivery) => delivery.id == deliveryId),
    );
  }

  @override
  void close() {}
}

const _testDriver = AuthUser(
  id: 42,
  businessId: 7,
  branchId: 3,
  name: 'Emmanuel Mushi',
  phone: '+255 712 345 678',
  email: 'emmanuel.mushi@example.com',
  status: 'active',
  role: 'driver',
  driverProfile: DriverProfile(
    id: 9,
    isAvailable: true,
    currentStatus: 'available',
  ),
);
