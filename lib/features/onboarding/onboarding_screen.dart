import 'package:flutter/material.dart';
import 'package:pelekapro_mobile/app/theme/app_theme.dart';
import 'package:pelekapro_mobile/features/auth/domain/auth_repository.dart';
import 'package:pelekapro_mobile/features/auth/presentation/login_screen.dart';
import 'package:pelekapro_mobile/features/onboarding/widgets/onboarding_illustration.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key, this.authRepository});

  final AuthRepository? authRepository;

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  static const _pages = [
    _OnboardingPageData(
      title: 'Deliveries made simple',
      description:
          'See assigned deliveries, understand every stop, and keep your work organised.',
      illustrationKind: OnboardingIllustrationKind.deliveries,
      illustrationLabel: 'A delivery truck surrounded by order and route cards',
    ),
    _OnboardingPageData(
      title: 'Live tracking with privacy',
      description:
          'Location sharing starts with the delivery and stops as soon as the job ends.',
      illustrationKind: OnboardingIllustrationKind.tracking,
      illustrationLabel:
          'A navigation marker with start, live location, and privacy symbols',
    ),
    _OnboardingPageData(
      title: 'Complete with confidence',
      description:
          'Record proof, confirm collections, and finish each delivery securely.',
      illustrationKind: OnboardingIllustrationKind.completion,
      illustrationLabel:
          'A verified delivery with proof, payment, and completion symbols',
    ),
  ];

  final PageController _pageController = PageController();
  int _currentPage = 0;
  bool _isLeaving = false;

  bool get _isLastPage => _currentPage == _pages.length - 1;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _next() async {
    if (_isLastPage) {
      _openLogin();
      return;
    }

    await _pageController.nextPage(
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
    );
  }

  void _openLogin() {
    if (_isLeaving) {
      return;
    }

    _isLeaving = true;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => LoginScreen(repository: widget.authRepository),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _OnboardingHeader(onSkip: _openLogin),
            Expanded(
              child: PageView.builder(
                key: const ValueKey('onboarding-page-view'),
                controller: _pageController,
                itemCount: _pages.length,
                onPageChanged: (page) {
                  setState(() => _currentPage = page);
                },
                itemBuilder: (context, index) {
                  return _OnboardingPage(data: _pages[index]);
                },
              ),
            ),
            _OnboardingFooter(
              pageCount: _pages.length,
              currentPage: _currentPage,
              isLastPage: _isLastPage,
              onNext: _next,
            ),
          ],
        ),
      ),
    );
  }
}

class _OnboardingPageData {
  const _OnboardingPageData({
    required this.title,
    required this.description,
    required this.illustrationKind,
    required this.illustrationLabel,
  });

  final String title;
  final String description;
  final OnboardingIllustrationKind illustrationKind;
  final String illustrationLabel;
}

class _OnboardingHeader extends StatelessWidget {
  const _OnboardingHeader({required this.onSkip});

  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(22, 12, 14, 4),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AppColors.postmanOrange,
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.local_shipping_rounded,
              color: Colors.white,
              semanticLabel: 'PelekaPro',
            ),
          ),
          const SizedBox(width: 11),
          const Expanded(
            child: Text(
              'PelekaPro',
              style: TextStyle(
                color: AppColors.ink,
                fontSize: 20,
                fontWeight: FontWeight.w900,
                letterSpacing: -0.4,
              ),
            ),
          ),
          TextButton(
            key: const ValueKey('onboarding-skip'),
            onPressed: onSkip,
            child: const Text('Skip'),
          ),
        ],
      ),
    );
  }
}

class _OnboardingPage extends StatelessWidget {
  const _OnboardingPage({required this.data});

  final _OnboardingPageData data;

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.sizeOf(context).height;
    final illustrationHeight = (screenHeight * 0.38).clamp(218.0, 330.0);

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            children: [
              SizedBox(
                height: illustrationHeight,
                child: OnboardingIllustration(
                  kind: data.illustrationKind,
                  semanticLabel: data.illustrationLabel,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                data.title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  color: AppColors.ink,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                data.description,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: AppColors.mutedInk,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OnboardingFooter extends StatelessWidget {
  const _OnboardingFooter({
    required this.pageCount,
    required this.currentPage,
    required this.isLastPage,
    required this.onNext,
  });

  final int pageCount;
  final int currentPage;
  final bool isLastPage;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 10, 24, 24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 560),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Semantics(
                label: 'Onboarding page ${currentPage + 1} of $pageCount',
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(pageCount, (index) {
                    final selected = index == currentPage;

                    return AnimatedContainer(
                      key: ValueKey('onboarding-indicator-$index'),
                      duration: const Duration(milliseconds: 220),
                      width: selected ? 26 : 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: selected
                            ? AppColors.postmanOrange
                            : AppColors.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    );
                  }),
                ),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  key: const ValueKey('onboarding-next'),
                  onPressed: onNext,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(isLastPage ? 'Get Started' : 'Next'),
                      const SizedBox(width: 8),
                      Icon(
                        isLastPage
                            ? Icons.login_rounded
                            : Icons.arrow_forward_rounded,
                        size: 21,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
