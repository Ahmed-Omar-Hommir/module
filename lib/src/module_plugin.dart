// ignore_for_file: depend_on_referenced_packages

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/file_system/physical_file_system.dart';
import 'package:analyzer_plugin/plugin/completion_mixin.dart';
import 'package:analyzer_plugin/plugin/plugin.dart';
import 'package:analyzer_plugin/protocol/protocol_common.dart';
import 'package:analyzer_plugin/protocol/protocol_generated.dart';
import 'package:analyzer/dart/analysis/analysis_context.dart';
// ignore: implementation_imports
import 'package:analyzer_plugin/src/utilities/completion/completion_core.dart';
import 'package:analyzer_plugin/utilities/completion/completion_core.dart';

import 'rules/import_rule.dart';

class ModulePlugin extends ServerPlugin with CompletionMixin {
  ModulePlugin() : super(resourceProvider: PhysicalResourceProvider.INSTANCE);

  @override
  List<String> get fileGlobsToAnalyze => <String>['**/*.dart'];

  @override
  String get name => 'host_plugin';

  @override
  String get version => '1.0.0';

  @override
  Future<void> analyzeFile({
    required AnalysisContext analysisContext,
    required String path,
  }) async {
    final unit = await analysisContext.currentSession.getResolvedUnit(path);
    final errors = [
      if (unit is ResolvedUnitResult)
        ...validate(path, unit).map((e) => e.error),
    ];
    channel
        .sendNotification(AnalysisErrorsParams(path, errors).toNotification());
  }

  @override
  Future<void> analyzeFiles({
    required AnalysisContext analysisContext,
    required List<String> paths,
  }) {
    if (paths.isEmpty) return Future.value();
    return super.analyzeFiles(
      analysisContext: analysisContext,
      paths: paths,
    );
  }

  @override
  List<CompletionContributor> getCompletionContributors(String path) {
    return [MyCompletionContributor()];
  }

  @override
  Future<CompletionRequest> getCompletionRequest(
      CompletionGetSuggestionsParams parameters) async {
    var result = await getResolvedUnitResult(parameters.file);
    return DartCompletionRequestImpl(
      resourceProvider,
      parameters.offset,
      result,
    );
  }
}

class MyCompletionContributor implements CompletionContributor {
  @override
  Future<void> computeSuggestions(
    DartCompletionRequest request,
    CompletionCollector collector,
  ) async {
    request.checkAborted();

    final suggestions = [...collector.suggestions];

    final importSuggestions = suggestions
        .where((s) => s.kind == CompletionSuggestionKind.IMPORT)
        .toList();

    importSuggestions
        .removeWhere((s) => !s.completion.startsWith('import \'package:'));

    suggestions.removeWhere((s) => s.kind == CompletionSuggestionKind.IMPORT);

    suggestions.addAll(importSuggestions);

    collector.suggestions = suggestions;
  }
}
