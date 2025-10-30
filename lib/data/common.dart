final class Lazy<T> {
  bool evaluated;
  T? _value;
  final T Function()? getter;

  Lazy.value(T value) : _value = value, evaluated = true, getter = null;
  Lazy.getter(T Function() this.getter) : evaluated = false;

  static Lazy<T> eval<T, X>(T Function(X) func, X arg) =>
      Lazy.getter(() => func(arg));

  static Lazy<T> Function(X) call<T, X>(T Function(X) func) =>
      (arg) => Lazy.getter(() => func(arg));

  void rerun() {
    _value = getter?.call() ?? _value;
  }

  T unwrap() {
    if (!evaluated) {
      _value = getter!();
      evaluated = true;
    }
    return _value as T;
  }
}
