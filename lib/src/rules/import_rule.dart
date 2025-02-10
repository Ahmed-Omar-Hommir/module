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

    var currentDir = importedFile.parent;
    while (currentDir.path != normalizedRoot) {
      final indexDart = currentDir.getChildAssumingFile('index.dart');
      if (indexDart.exists) {
        final currentFile = resourceProvider.getFile(unit.path);
        final currentDirOfFile = currentFile.parent;
        final relativePath =
            path_pkg.relative(indexDart.path, from: currentDirOfFile.path);
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
            'Direct import of ${path_pkg.basename(importedFile.path)} is not allowed because "$posixRelativePath" exists.',
            'direct_import_with_index',
            correction: 'Import using "$posixRelativePath" instead.',
            hasFix: false,
          ),
        );

        break;
      }

      currentDir = currentDir.parent;
    }
  }
}
