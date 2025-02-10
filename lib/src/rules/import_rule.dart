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
  final resourceProvider = PhysicalResourceProvider.INSTANCE;

  final contextRoot = analysisContext.contextRoot;
  final normalizedRoot = path_pkg.normalize(contextRoot.root.path);

  for (final directive in unit.unit.directives.whereType<ImportDirective>()) {
    final importedLibrary = directive.element?.library;
    if (importedLibrary == null) continue;

    final importedPath = path_pkg.normalize(importedLibrary.source.fullName);

    if (!importedPath.startsWith(normalizedRoot)) continue;

    //

    final isPrivate = isPrivateImport(importedPath);

    if (isPrivate) {
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
          'Direct import of  is not allowed because "" exists.',
          'direct_import_with_index',
          correction: 'Import using "" instead.',
          hasFix: false,
        ),
      );
    }
  }
}

bool isPrivateImport(String path) {
  final dircs = getAllParentDirectories(path);

  for (var dir in dircs) {
    if (hasDartIndex(dir)) return true;
  }

  return false;
}

bool hasDartIndex(String dir) => File('$dir/index.dart').existsSync();

List<String> getAllParentDirectories(String path) {
  List<String> parts = path.split('/');

  String currentPath = parts.first;

  List<String> output = [parts.first];

  for (int i = 1; i < parts.length - 1; i++) {
    currentPath += '/${parts[i]}';
    output.add(currentPath);
  }

  return output;
}
