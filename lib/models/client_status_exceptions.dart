import 'package:lanis/generated/l10n.dart';

abstract class LanisException implements Exception {
  final String? _customCause;

  LanisException([this._customCause]);

  String get _defaultMessage;

  String get cause {
    if (_customCause != null) return _customCause;

    try {
      return _localizedMessage;
    } catch (e) {
      // Fallback to English if localization is not available
      return _defaultMessage;
    }
  }

  String get _localizedMessage => _defaultMessage;

  @override
  String toString() => cause;
}

class WrongCredentialsException extends LanisException {
  WrongCredentialsException([super.cause]);

  @override
  String get _defaultMessage => 'Wrong credentials';

  @override
  String get _localizedMessage => AppLocalizations.current.wrongCredentials;
}

class LanisDownException extends LanisException {
  LanisDownException([super.cause]);

  @override
  String get _defaultMessage => 'Lanis is down';

  @override
  String get _localizedMessage => AppLocalizations.current.lanisDown;
}

class LoginTimeoutException extends LanisException {
  final String time;

  LoginTimeoutException(this.time, [String? cause]) : super(cause);

  @override
  String get _defaultMessage => 'Login timeout: $time';

  @override
  String get _localizedMessage => AppLocalizations.current.loginTimeout(time);
}

class CredentialsIncompleteException extends LanisException {
  CredentialsIncompleteException([super.cause]);

  @override
  String get _defaultMessage => 'Credentials incomplete';

  @override
  String get _localizedMessage =>
      AppLocalizations.current.credentialsIncomplete;
}

class NetworkException extends LanisException {
  NetworkException([super.cause]);

  @override
  String get _defaultMessage => 'Network error';

  @override
  String get _localizedMessage => AppLocalizations.current.networkError;
}

class UnknownException extends LanisException {
  UnknownException([super.cause]);

  @override
  String get _defaultMessage => 'Unknown error';

  @override
  String get _localizedMessage => AppLocalizations.current.unknownError;
}

class UnauthorizedException extends LanisException {
  UnauthorizedException([super.cause]);

  @override
  String get _defaultMessage => 'Unauthorized';

  @override
  String get _localizedMessage => AppLocalizations.current.unauthorized;
}

class EncryptionCheckFailedException extends LanisException {
  EncryptionCheckFailedException([super.cause]);

  @override
  String get _defaultMessage => 'Encryption check failed';

  @override
  String get _localizedMessage =>
      AppLocalizations.current.encryptionCheckFailed;
}

class UnsaltedOrUnknownException extends LanisException {
  UnsaltedOrUnknownException([super.cause]);

  @override
  String get _defaultMessage => 'Unsalted or unknown';

  @override
  String get _localizedMessage => AppLocalizations.current.unsaltedOrUnknown;
}

class NotSupportedException extends LanisException {
  NotSupportedException([super.cause]);

  @override
  String get _defaultMessage => 'Not supported';

  @override
  String get _localizedMessage => AppLocalizations.current.notSupported;
}

class NoConnectionException extends LanisException {
  NoConnectionException([super.cause]);

  @override
  String get _defaultMessage => 'No connection';

  @override
  String get _localizedMessage => AppLocalizations.current.noConnection;
}

class AccountAlreadyExistsException extends LanisException {
  AccountAlreadyExistsException([super.cause]);

  @override
  String get _defaultMessage => 'Account already exists';

  @override
  String get _localizedMessage => AppLocalizations.current.accountExists;
}
