// lib/core/result.dart
// Lightweight Result type used throughout repositories.
import 'friendly_error.dart';

sealed class Result<T> {
  const Result();

  bool get isSuccess => this is Success<T>;
  bool get isFailure => this is Failure<T>;
  T? get valueOrNull => this is Success<T> ? (this as Success<T>).value : null;
}

class Success<T> extends Result<T> {
  final T value;
  const Success(this.value);

  T get data => value;
}

class Failure<T> extends Result<T> {
  final String message;
  final dynamic cause;
  const Failure(this.message, [this.cause]);

  /// Calm, actionable copy for end users. [message] is sometimes a raw
  /// `e.toString()` from a repository's catch block — never display it
  /// directly; display this instead.
  String get friendlyMessage => humanizeError(cause ?? message);
}
