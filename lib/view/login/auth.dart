import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:liblanis/liblanis.dart';
import 'package:lanis/generated/l10n.dart';
import 'package:lanis/home_page.dart';
import 'package:lanis/features/auth/auth_controller.dart';
import 'package:lanis/features/auth/account_recovery.dart';
import 'package:lanis/l10n/login_errors.dart';
import 'package:lanis/utils/logger.dart';
import 'package:lanis/utils/glitchtip.dart';
import 'package:lanis/utils/privacy_policy.dart';
import 'package:lanis/utils/safe_launch.dart';
import 'package:lanis/view/login/school_selector.dart';

class LoginForm extends ConsumerStatefulWidget {
  final bool showBackButton;
  const LoginForm({required this.showBackButton, super.key});

  @override
  ConsumerState<LoginForm> createState() => LoginFormState();
}

class LoginFormState extends ConsumerState<LoginForm> {
  static const double padding = 10.0;

  final _formKey = GlobalKey<FormState>();
  int _schoolSelectorVersion = 0;
  bool _passwordVisible = false;

  TextEditingController schoolIDController = TextEditingController();
  TextEditingController usernameController = TextEditingController();
  TextEditingController passwordController = TextEditingController();
  bool dseAgree = false;
  bool errorReportingAgree = false;
  String selectedSchoolName = "";

  @override
  void initState() {
    super.initState();
    // Mirror the device-wide GlitchTip choice when adding another account.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final shared = ref.read(sharedOverAccountSettingsProvider);
      setState(() {
        errorReportingAgree = isGlitchTipEnabled(shared);
      });
    });
  }

  void login(String username, String password, String schoolID) async {
    ClearTextAccount? attemptedAccount;
    if (_passwordVisible) setState(() => _passwordVisible = false);
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(AppLocalizations.of(context).logInTitle),
        content: const Center(
          heightFactor: 1.2,
          child: CircularProgressIndicator(),
        ),
      ),
    );
    try {
      final schoolId = int.parse(schoolID);
      final accounts = await ref.read(accountsProvider.future);
      if (accounts.any(
        (a) => a.schoolID == schoolId && a.username == username,
      )) {
        throw AccountAlreadyExistsException();
      }

      final config = ref.read(lanisConfigProvider);
      attemptedAccount = ClearTextAccount(
        localId: -1,
        schoolID: schoolId,
        username: username,
        password: password,
        schoolName: selectedSchoolName,
      );
      await verifyAccountLogin(
        attemptedAccount,
        config,
        ref.read(connectionCheckerProvider),
      );
      if (!mounted) return;

      // Persist first-time choices only after Schulportal accepts the login.
      final shared = ref.read(sharedOverAccountSettingsProvider);
      acceptPrivacyPolicy(shared);
      setGlitchTipEnabled(shared, errorReportingAgree);

      final newID = await ref
          .read(accountsProvider.notifier)
          .add(
            schoolId: schoolId,
            username: username,
            password: password,
            schoolName: selectedSchoolName,
          );
      final ok = await ref
          .read(authControllerProvider.notifier)
          .loginWithAccount(newID, removeAccountOnFailure: true);
      if (!mounted) return;
      Navigator.pop(context); // pop dialog
      if (ok) {
        TextInput.finishAutofillContext();
        context.go(firstSupportedHomePath(ref));
        return;
      }
      if (!mounted) return;
      await _showLoginError(
        ref.read(authControllerProvider).exception,
        attemptedAccount,
      );
    } catch (ex, s) {
      if (ex is! LanisException) {
        logger.e('Login failed: ${ex.runtimeType}', stackTrace: s);
      }
      if (!mounted) return;
      Navigator.pop(context); // pop dialog
      await _showLoginError(ex is LanisException ? ex : null, attemptedAccount);
    }
  }

  Future<void> _showLoginError(
    LanisException? exception,
    ClearTextAccount? attemptedAccount,
  ) async {
    final l10n = AppLocalizations.of(context);
    final accountError = localizedAccountLoginError(l10n, exception);
    final canOpenPortal =
        exception is PasswordChangeRequiredException && attemptedAccount != null;
    final openPortal = canOpenPortal
        ? await _showFirstLoginSheet(l10n)
        : await showDialog<bool>(
            context: context,
            builder: (dialogContext) => AlertDialog(
              title: Text(l10n.error),
              content: Text(accountError ?? exception?.cause ?? l10n.unknownError),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
    if (!mounted || accountError == null) return;
    TextInput.finishAutofillContext(shouldSave: false);
    _formKey.currentState?.reset();
    setState(() {
      schoolIDController.clear();
      usernameController.clear();
      passwordController.clear();
      selectedSchoolName = '';
      dseAgree = false;
      errorReportingAgree = isGlitchTipEnabled(
        ref.read(sharedOverAccountSettingsProvider),
      );
      _schoolSelectorVersion++;
    });
    if (openPortal == true && attemptedAccount != null) {
      await openPortalPasswordChange(
        context,
        attemptedAccount,
        ref.read(lanisConfigProvider),
      );
    }
  }

  Future<bool?> _showFirstLoginSheet(AppLocalizations l10n) {
    return showModalBottomSheet<bool>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                l10n.firstLoginTitle,
                style: Theme.of(sheetContext).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              Text(l10n.firstLoginPasswordMessage),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => Navigator.pop(sheetContext, true),
                icon: const Icon(Icons.open_in_new),
                label: Text(l10n.setInitialPassword),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    schoolIDController.dispose();
    usernameController.dispose();
    passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        if (widget.showBackButton)
          Padding(
            padding: EdgeInsets.only(right: 32, top: 32),
            child: IconButton(
              onPressed: () {
                // Welcome uses go('/login') (no stack); account switcher uses push.
                if (context.canPop()) {
                  context.pop();
                } else {
                  context.go('/welcome');
                }
              },
              icon: Icon(Icons.arrow_back),
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(padding),
          child: Center(
            child: Container(
              constraints: BoxConstraints(maxWidth: 550),
              child: Form(
                key: _formKey,
                child: AutofillGroup(
                  onDisposeAction: AutofillContextAction.cancel,
                  child: Center(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const SizedBox(height: padding),
                          Center(
                            child: Column(
                              children: [
                                const Icon(Icons.person, size: 70),
                                Text(
                                  AppLocalizations.of(context).logIn,
                                  style: const TextStyle(fontSize: 35),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: padding * 5),
                          SchoolSelector(
                            key: ValueKey(_schoolSelectorVersion),
                            controller: schoolIDController,
                            outContext: context,
                            onSchoolSelected: (name) {
                              selectedSchoolName = name;
                              setState(() {});
                            },
                          ),
                          const SizedBox(height: padding),
                          TextFormField(
                            controller: usernameController,
                            enabled: schoolIDController.text != "",
                            autofillHints: [AutofillHints.username],
                            autocorrect: false,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(
                                context,
                              ).authUsernameHint,
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return AppLocalizations.of(
                                  context,
                                ).authValidationError;
                              }

                              return null;
                            },
                          ),
                          const SizedBox(height: padding),
                          TextFormField(
                            controller: passwordController,
                            enabled: schoolIDController.text.isNotEmpty,
                            autofillHints: [AutofillHints.password],
                            autocorrect: false,
                            obscureText: !_passwordVisible,
                            enableSuggestions: false,
                            keyboardType: TextInputType.visiblePassword,
                            decoration: InputDecoration(
                              labelText: AppLocalizations.of(
                                context,
                              ).authPasswordHint,
                              suffixIcon: IconButton(
                                tooltip: _passwordVisible
                                    ? AppLocalizations.of(context).hidePassword
                                    : AppLocalizations.of(context).showPassword,
                                icon: Icon(
                                  _passwordVisible
                                      ? Icons.visibility
                                      : Icons.visibility_off,
                                ),
                                onPressed: schoolIDController.text.isEmpty
                                    ? null
                                    : () => setState(() {
                                        _passwordVisible = !_passwordVisible;
                                      }),
                              ),
                            ),
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return AppLocalizations.of(
                                  context,
                                ).authValidationError;
                              }
                              return null;
                            },
                          ),
                          const SizedBox(height: padding),
                          Visibility(
                            child: ExcludeSemantics(
                              child: CheckboxListTile(
                                enabled: schoolIDController.text.isNotEmpty,
                                value: dseAgree,
                                title: RichText(
                                  text: TextSpan(
                                    text: AppLocalizations.of(
                                      context,
                                    ).authIAccept,
                                    style: DefaultTextStyle.of(context).style,
                                    children: <TextSpan>[
                                      TextSpan(
                                        text: AppLocalizations.of(
                                          context,
                                        ).authTermsOfService,
                                        style: TextStyle(
                                          color: Theme.of(
                                            context,
                                          ).colorScheme.primary,
                                        ),
                                        recognizer: TapGestureRecognizer()
                                          ..onTap = () => safeLaunchUrl(
                                            Uri.parse(privacyPolicyUrl),
                                            context: context,
                                          ),
                                      ),
                                      TextSpan(
                                        text: AppLocalizations.of(
                                          context,
                                        ).authOfLanisMobile,
                                      ),
                                    ],
                                  ),
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    dseAgree = val!;
                                  });
                                },
                              ),
                            ),
                          ),
                          Visibility(
                            child: ExcludeSemantics(
                              child: CheckboxListTile(
                                enabled: schoolIDController.text.isNotEmpty,
                                value: errorReportingAgree,
                                title: Text(
                                  AppLocalizations.of(
                                    context,
                                  ).authErrorReportingOptional,
                                  style: DefaultTextStyle.of(context).style,
                                ),
                                onChanged: (val) {
                                  setState(() {
                                    errorReportingAgree = val!;
                                  });
                                },
                              ),
                            ),
                          ),
                          const SizedBox(height: padding),
                          FilledButton(
                            onPressed: dseAgree
                                ? () {
                                    if (_formKey.currentState!.validate()) {
                                      login(
                                        usernameController.text.toLowerCase(),
                                        passwordController.text,
                                        schoolIDController.text,
                                      );
                                    }
                                  }
                                : null,
                            child: Text(AppLocalizations.of(context).logIn),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton(
                                onPressed: schoolIDController.text.isNotEmpty
                                    ? () => safeLaunchUrl(
                                        Uri.parse(
                                          "https://start.schulportal.hessen.de/benutzerverwaltung.php?a=userPWreminder&i=${schoolIDController.text}",
                                        ),
                                        context: context,
                                      )
                                    : null,
                                child: Text(
                                  AppLocalizations.of(
                                    context,
                                  ).authResetPassword,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
