/// A value the server answered and the moment it was fetched (`DL-125`). A
/// screen that keeps showing it after a refresh failed says when it is from.
final class Loaded<T> {
  const Loaded(this.data, {required this.at});

  final T data;
  final DateTime at;
}
