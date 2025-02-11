import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:path/path.dart' as path_pkg;

Iterable<AnalysisErrorFixes> validate(
  String path,
  ResolvedUnitResult unit,
  AnalysisContext analysisContext,
) sync* {
  final contextRoot = analysisContext.contextRoot;
  final rootPath = path_pkg.normalize(contextRoot.root.path);

  for (final directive in unit.unit.directives
      .where((d) => d is ImportDirective || d is ExportDirective)) {
    late final String? referencedPath;
    late final StringLiteral uriNode;
    if (directive is ImportDirective) {
      referencedPath =
          directive.element?.importedLibrary?.librarySource.fullName;
      uriNode = directive.uri;
    } else if (directive is ExportDirective) {
      referencedPath =
          directive.element?.exportedLibrary?.librarySource.fullName;
      uriNode = directive.uri;
    } else {
      continue;
    }

    if (referencedPath == null) continue;

    final importedFile = File(path_pkg.normalize(referencedPath));
    final importedFilePath = importedFile.path;

    if (!path_pkg.isWithin(rootPath, importedFilePath)) continue;

    final isPrivate = isPrivateImport(
      importedFilePath.replaceFirst(rootPath, ''),
      path.replaceFirst(rootPath, ''),
    );

    if (isPrivate) {
      final location = Location(
        unit.path,
        uriNode.offset,
        uriNode.length,
        unit.lineInfo.getLocation(uriNode.offset).lineNumber,
        unit.lineInfo.getLocation(uriNode.offset).columnNumber,
      );

      yield AnalysisErrorFixes(
        AnalysisError(
          AnalysisErrorSeverity.ERROR,
          AnalysisErrorType.LINT,
          location,
          'Direct import of ${uriNode.toString()} is not allowed. Use the index.dart file from the same module instead.',
          'direct_import_with_index',
          hasFix: false,
        ),
      );
    }
  }
}

bool isPrivateImport(
  String importedFilePath,
  String currentFilePath,
) {
  final importedFileDir = path_pkg.dirname(importedFilePath);
  final directories = getAllParentDirectories(Directory(importedFileDir));

  for (final dirPath in directories) {
    if (hasDartIndex(dirPath)) {
      final modulePath = dirPath;
      if (!_isWithin(modulePath, currentFilePath)) {
        return true;
      }
    }
  }

  return false;
}

bool _isWithin(String parent, String child) {
  final parentNormalized = path_pkg.normalize(parent);
  final childNormalized = path_pkg.normalize(child);
  return path_pkg.isWithin(parentNormalized, childNormalized);
}

bool hasDartIndex(String dirPath) =>
    File(path_pkg.join(dirPath, 'index.dart')).existsSync();

List<String> getAllParentDirectories(Directory directory) {
  List<String> directories = [];
  Directory current = directory.absolute;

  while (current.parent.path != current.path) {
    directories.add(current.path);
    current = current.parent;
  }

  directories.add(current.path);

  return directories;
}
