import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:path/path.dart' as path_pkg;

Iterable<AnalysisErrorFixes> validate(
  String path,
  ResolvedUnitResult unit,
  AnalysisContext analysisContext,
) sync* {
  final contextRoot = analysisContext.contextRoot;
  final normalizedRoot = path_pkg.normalize(contextRoot.root.path);

  for (final directive in unit.unit.directives.whereType<ImportDirective>()) {
    final importedPath = directive.element?.name;

    // if (importedPath == null) continue;

    // final normalizedImportedPath = path_pkg.normalize(importedPath);

    // if (!normalizedImportedPath.startsWith(normalizedRoot)) continue;

    // final isPrivate = isPrivateImport(importedPath, normalizedRoot);

    // if (isPrivate) {
    final uriNode = directive.uri;
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
        'Direct import of  is not allowed because "$importedPath" "Path: $path" ',
        'direct_import_with_index',
        correction: 'Import using "" instead.',
        hasFix: false,
      ),
    );
    // }
  }
}

bool isPrivateImport(String path, String normalizedRoot) {
  final dircs = getAllParentDirectories(path, normalizedRoot);

  for (var dir in dircs) {
    if (hasDartIndex(dir)) return true;
  }

  return false;
}

bool hasDartIndex(String dir) => File('$dir/index.dart').existsSync();

List<String> getAllParentDirectories(String path, String normalizedRoot) {
  List<String> directories = [];
  Directory current = Directory(path).absolute;

  while (current.path.startsWith(normalizedRoot)) {
    directories.insert(0, current.path);
    if (current.path == normalizedRoot) break;
    current = current.parent;
  }

  return directories;
}
