import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lanis/generated/l10n.dart';
import 'intro_screen_page_view_models.dart';

class WelcomeLoginScreen extends StatefulWidget {
  const WelcomeLoginScreen({super.key});

  @override
  State<StatefulWidget> createState() => _WelcomeLoginScreenState();
}

class _WelcomeLoginScreenState extends State<WelcomeLoginScreen> {
  final PageController _pageController = PageController();
  int _currentPageIndex = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goToLogin() => context.go('/login');

  @override
  Widget build(BuildContext context) {
    final pages = intoScreenPageViewModels(context);
    return PopScope(
      canPop: false,
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: PageView.builder(
                  controller: _pageController,
                  itemCount: pages.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentPageIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    final page = pages[index];
                    return Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          page.image,
                          const SizedBox(height: 32),
                          Text(
                            page.title,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(fontWeight: FontWeight.bold),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          Text(
                            page.body,
                            style: Theme.of(context).textTheme.bodyLarge,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder:
                      (Widget child, Animation<double> animation) {
                    return FadeTransition(opacity: animation, child: child);
                  },
                  child: _currentPageIndex == pages.length - 1
                      ? SizedBox(
                          key: const ValueKey('continue_btn'),
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _goToLogin,
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 12.0,
                              ),
                              child: Text(
                                AppLocalizations.of(context).actionContinue,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ),
                          ),
                        )
                      : Stack(
                          key: const ValueKey('nav_stack'),
                          alignment: Alignment.center,
                          children: [
                            Align(
                              alignment: Alignment.centerLeft,
                              child: TextButton(
                                onPressed: _goToLogin,
                                child: Text(
                                  AppLocalizations.of(context).introSkip,
                                ),
                              ),
                            ),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: List.generate(
                                pages.length,
                                (index) => AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  margin: const EdgeInsets.symmetric(
                                    horizontal: 4.0,
                                  ),
                                  width: _currentPageIndex == index
                                      ? 24.0
                                      : 10.0,
                                  height: 10.0,
                                  decoration: BoxDecoration(
                                    color: _currentPageIndex == index
                                        ? Theme.of(context).colorScheme.primary
                                        : Theme.of(context)
                                              .colorScheme
                                              .onSurface
                                              .withValues(alpha: 0.2),
                                    borderRadius: BorderRadius.circular(5.0),
                                  ),
                                ),
                              ),
                            ),
                            Align(
                              alignment: Alignment.centerRight,
                              child: TextButton(
                                onPressed: () {
                                  _pageController.nextPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                child: const Icon(
                                  Icons.arrow_forward,
                                  size: 28,
                                ),
                              ),
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
