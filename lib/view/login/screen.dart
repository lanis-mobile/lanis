import 'package:flutter/material.dart';
import 'package:lanis/generated/l10n.dart';
import 'auth.dart';
import 'intro_screen_page_view_models.dart';

class WelcomeLoginScreen extends StatefulWidget {
  const WelcomeLoginScreen({super.key});

  @override
  State<StatefulWidget> createState() => _WelcomeLoginScreenState();
}

enum PageType { intro, login }

class _WelcomeLoginScreenState extends State<WelcomeLoginScreen> {
  PageType currentPage = PageType.intro;
  List<String> schoolList = [];

  final PageController _pageController = PageController();
  int _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Widget buildBody() {
    Widget currentWidget;
    if (currentPage == PageType.intro) {
      final pages = intoScreenPageViewModels(context);
      currentWidget = Scaffold(
        key: const ValueKey('intro_page'),
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
                            onPressed: () {
                              setState(() {
                                currentPage = PageType.login;
                              });
                            },
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
                                onPressed: () {
                                  setState(() {
                                    currentPage = PageType.login;
                                  });
                                },
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
      );
    } else if (currentPage == PageType.login) {
      currentWidget = Scaffold(
        key: const ValueKey('login_page'),
        body: LoginForm(showBackButton: false),
      );
    } else {
      currentWidget = const Center(
        key: ValueKey('error_page'),
        child: Text("This should not happen"),
      );
    }

    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 500),
      switchInCurve: Curves.easeInOut,
      switchOutCurve: Curves.easeInOut,
      child: currentWidget,
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(canPop: false, child: buildBody());
  }
}
