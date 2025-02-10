/// Support for doing something awesome.
///
/// More dartdocs go here.
library;

import 'dart:isolate';

import 'package:analyzer_plugin/starter.dart';

import 'src/module_plugin.dart';

void start(List<String> args, SendPort sendPort) async {
  ServerPluginStarter(
    ModulePlugin(),
  ).start(sendPort);
}
