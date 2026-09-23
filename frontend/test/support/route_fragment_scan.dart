import 'dart:io';

/// A feature route fragment as found on disk.
///
/// The convention it encodes is the one `lib/app/router.dart` documents: a
/// feature declares its routes in
/// `lib/features/<feature>/presentation/<name>_routes.dart`, and that file
/// exposes a top-level `<name>Routes` value the registry lists.
class RouteFragment {
  const RouteFragment({
    required this.feature,
    required this.importPath,
    required this.symbol,
  });

  /// The directory name under `lib/features/`.
  final String feature;

  /// The path the root router imports, always with forward slashes so the
  /// comparison behaves the same on Windows and on a Linux runner.
  final String importPath;

  /// The top-level value the fragment file exposes.
  final String symbol;
}

/// Finds every route fragment under [featuresDirectory].
///
/// A missing directory yields no fragments. That is the legitimate state until
/// the first feature lands — git stores no empty directory — and it mirrors the
/// backend loader, which treats an empty module directory as a no-op.
List<RouteFragment> discoverRouteFragments(Directory featuresDirectory) {
  if (!featuresDirectory.existsSync()) {
    return const <RouteFragment>[];
  }

  final List<RouteFragment> fragments = <RouteFragment>[];

  for (final FileSystemEntity entity in featuresDirectory.listSync()) {
    if (entity is! Directory) {
      continue;
    }

    final String feature = _basename(entity.path);
    final Directory presentation = Directory(
      '${entity.path}${Platform.pathSeparator}presentation',
    );
    if (!presentation.existsSync()) {
      continue;
    }

    for (final FileSystemEntity file in presentation.listSync()) {
      if (file is! File) {
        continue;
      }

      final String name = _basename(file.path);
      if (!name.endsWith('_routes.dart')) {
        continue;
      }

      fragments.add(
        RouteFragment(
          feature: feature,
          importPath: 'features/$feature/presentation/$name',
          symbol: _camelCase(name.substring(0, name.length - '.dart'.length)),
        ),
      );
    }
  }

  fragments.sort((RouteFragment a, RouteFragment b) {
    final int byFeature = a.feature.compareTo(b.feature);
    return byFeature != 0 ? byFeature : a.importPath.compareTo(b.importPath);
  });

  return fragments;
}

/// The fragments under [featuresDirectory] that [routerSource] fails to
/// register.
///
/// Both halves matter. An import without a list entry compiles and ships a
/// feature whose routes are unreachable, which is the failure this check
/// exists to catch, so the symbol has to appear outside the import lines too.
List<RouteFragment> unregisteredFragments({
  required Directory featuresDirectory,
  required String routerSource,
}) {
  // Imports are stripped because an import alone does not register anything,
  // and comments because the registry's own documentation names fragments in
  // prose — counting those would let a fragment pass on a mention rather than
  // on an entry in the list.
  final String body = routerSource
      .split('\n')
      .where((String line) {
        final String trimmed = line.trimLeft();
        return !trimmed.startsWith('import ') &&
            !trimmed.startsWith('//') &&
            !trimmed.startsWith('*') &&
            !trimmed.startsWith('/*');
      })
      .join('\n');

  return discoverRouteFragments(featuresDirectory)
      .where(
        (RouteFragment fragment) =>
            !routerSource.contains(fragment.importPath) ||
            !RegExp('\\b${RegExp.escape(fragment.symbol)}\\b').hasMatch(body),
      )
      .toList();
}

String _basename(String path) =>
    path.split(RegExp(r'[\\/]')).where((String part) => part.isNotEmpty).last;

String _camelCase(String snakeCase) {
  final List<String> parts = snakeCase.split('_');
  return parts.first +
      parts
          .skip(1)
          .map(
            (String part) =>
                part.isEmpty ? part : part[0].toUpperCase() + part.substring(1),
          )
          .join();
}
