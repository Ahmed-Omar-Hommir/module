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

    final importedFile = resourceProvider.getFile(importedPath);
    var currentDir = importedFile.parent;

    while (currentDir.path.startsWith(normalizedRoot)) {
      final indexDart = currentDir.getChildAssumingFile('index.dart');
      if (indexDart.exists) {
        final currentFile = resourceProvider.getFile(unit.path);
        final relativePath = path_pkg
            .relative(indexDart.path, from: currentFile.parent.path)
            .replaceAll(r'\', '/');

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
            'Direct import of ${path_pkg.basename(importedFile.path)} is not allowed because "$relativePath" exists.',
            'direct_import_with_index',
            correction: 'Import using "$relativePath" instead.',
            hasFix: false,
          ),
        );

        break;
      }

      if (currentDir.path == normalizedRoot) break;

      currentDir = currentDir.parent;
    }
  }
}
