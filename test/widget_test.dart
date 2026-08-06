import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pelekapro_mobile/app/app.dart';
import 'package:pelekapro_mobile/app/theme/app_theme.dart';
import 'package:pelekapro_mobile/features/onboarding/onboarding_screen.dart';

void main() {
  testWidgets('starts with the branded first onboarding page', (tester) async {
    await tester.pumpWidget(const PelekaProApp());
    await tester.pump();

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
    await tester.pumpWidget(const PelekaProApp());
    await tester.pump();

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
    await tester.pumpWidget(const PelekaProApp());
    await tester.pump();

    await tester.drag(
      find.byKey(const ValueKey('onboarding-page-view')),
      const Offset(-500, 0),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Live tracking with privacy'), findsOneWidget);
  });

  testWidgets('Skip opens the login screen', (tester) async {
    await tester.pumpWidget(const PelekaProApp());
    await tester.pump();

    await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
    await tester.pumpAndSettle();

    expect(find.text('Welcome back'), findsOneWidget);
    expect(find.text('Phone number or email'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
    expect(find.text('Deliveries made simple'), findsNothing);
  });

  testWidgets('Get Started opens login from the final page', (tester) async {
    await tester.pumpWidget(const PelekaProApp());
    await tester.pump();

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

  testWidgets('valid local form reports the next integration phase', (
    tester,
  ) async {
    await _openLogin(tester);

    await tester.enterText(
      find.byKey(const ValueKey('login-identifier')),
      '+255700000000',
    );
    await tester.enterText(
      find.byKey(const ValueKey('login-password')),
      'safe-test-password',
    );
    await tester.tap(find.byKey(const ValueKey('login-submit')));
    await tester.pump();

    expect(
      find.text('Secure login will be connected in the next phase.'),
      findsOneWidget,
    );
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

Future<void> _openLogin(WidgetTester tester) async {
  await tester.pumpWidget(const PelekaProApp());
  await tester.pump();
  await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
  await tester.pumpAndSettle();
}
