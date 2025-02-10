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
  final rootPath = contextRoot.root.path;

  for (var import in unit.unit.directives.whereType<ImportDirective>()) {
    final importedLibrary = import.element?.library;
    if (importedLibrary == null) continue;

    final importedPath = importedLibrary.source.fullName;
    final importedFile = resourceProvider.getFile(importedPath);

    final normalizedRoot = path_pkg.normalize(rootPath);
    final normalizedImported = path_pkg.normalize(importedFile.path);
    if (!normalizedImported.startsWith(normalizedRoot)) continue;

    final importedDir = importedFile.parent;
    final indexDart = importedDir.getChildAssumingFile('index.dart');
    if (indexDart.exists) {
      if (importedFile.shortName != 'index.dart') {
        final currentFile = resourceProvider.getFile(unit.path);
        final currentDir = currentFile.parent;
        final relativePath =
            path_pkg.relative(indexDart.path, from: currentDir.path);
        final posixRelativePath = relativePath.replaceAll(RegExp(r'\\'), '/');

        final uriLocation = import.uri;
        final location = Location(
          unit.path,
          uriLocation.offset,
          uriLocation.length,
          unit.lineInfo.getLocation(uriLocation.offset).lineNumber,
          unit.lineInfo.getLocation(uriLocation.offset).columnNumber,
        );

        yield AnalysisErrorFixes(
          AnalysisError(
            AnalysisErrorSeverity.ERROR,
            AnalysisErrorType.LINT,
            location,
            'Direct import of ${importedFile.shortName} is not allowed when index.dart exists in the same directory.',
            'direct_import_with_index',
            correction: 'Import using "$posixRelativePath" instead.',
            hasFix: false,
          ),
        );
      }
    }
  }
}
