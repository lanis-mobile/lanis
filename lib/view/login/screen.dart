import 'package:flutter/material.dart';
import 'package:introduction_screen/introduction_screen.dart';
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

  @override
  void initState() {
    super.initState();
  }

  Widget buildBody() {
    if (currentPage == PageType.intro) {
      return SafeArea(
        child: IntroductionScreen(
          next: const Icon(Icons.arrow_forward),
          done: const Text("Login"),
          onDone: () {
            setState(() {
              currentPage = PageType.login;
            });
          },
          dotsDecorator: const DotsDecorator(spacing: EdgeInsets.all(2.0)),
          pages: intoScreenPageViewModels(context),
        ),
      );
    } else if (currentPage == PageType.login) {
      return Scaffold(body: LoginForm(showBackButton: false));
    }

    return const Center(child: Text("This should not happen"));
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(canPop: false, child: buildBody());
  }
}
