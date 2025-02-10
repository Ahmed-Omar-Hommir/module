import 'dart:isolate';

import 'package:module/module.dart';

void main(List<String> args, SendPort sendPort) async {
  start(args, sendPort);
}
