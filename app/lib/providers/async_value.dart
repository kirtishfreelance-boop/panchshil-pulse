import 'package:flutter/foundation.dart';

/// A tiny load-state container so every list screen renders loading, error and
/// empty consistently without each provider inventing its own flags.
@immutable
class AsyncValue<T> {
  const AsyncValue._({this.data, this.error, required this.isLoading});

  const AsyncValue.idle() : this._(isLoading: false);
  const AsyncValue.loading() : this._(isLoading: true);
  const AsyncValue.data(T value) : this._(data: value, isLoading: false);
  const AsyncValue.error(String message) : this._(error: message, isLoading: false);

  final T? data;
  final String? error;
  final bool isLoading;

  bool get hasData => data != null;
  bool get hasError => error != null;

  /// Keeps showing the previous data while a refresh is in flight.
  AsyncValue<T> toLoading() => AsyncValue._(data: data, isLoading: true);
}
