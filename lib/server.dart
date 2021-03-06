library laser.server;

import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:isolate';

import 'package:unittest/unittest.dart';
import 'package:yaml/yaml.dart';
import 'package:path/path.dart' as path;
import 'package:console/console.dart';
import 'package:console_ui/console_ui.dart';

part 'src/configuration.dart';
part 'src/console.dart';
part 'src/chrome.dart';
part 'src/filewatcher_server.dart';
part 'src/test_runner.dart';
part 'src/test_session.dart';
part 'src/websockets.dart';


const int CHROMEUI_PORT = 2009;
const int WEBSOCKET_PORT = 2005;


abstract class LaserUI {
  void message(String msg);
}

class LaserTestServer {

  final test_sessions = new Map<String, TestSession>();

  LaserConfiguration conf;

  LaserConsole console;
  LaserChrome chrome;
  List uis;

  IsolateTestRunner isolate_runner;
  HeadlessTestRunner headless_runner;
  IncomingWebTests incoming;

  FileWatcher fileWatcher;

  LaserTestServer(this.conf);

  Future start({bool start_console: false}) {

    // UIs
    chrome = new LaserChrome(); // also a test runner
    uis = [chrome];
    if (start_console && Terminal.supported()) {
      console = new LaserConsole();
      uis.add(console);
    }

    if (start_console)
      console.start();

    // Test Runners
    isolate_runner = new IsolateTestRunner();
    headless_runner = new HeadlessTestRunner(); // along with chrome, uses websockets

    // WebSocket Test Connections
    incoming = new IncomingWebTests();
    incoming.stream.listen((TestRunnerInstance runner) {
      test_connected(runner);
    });

    // File Watcher
    fileWatcher = new FileWatcher(conf);
    fileWatcher.start();
    fileWatcher.stream.listen((String path) {
      var test = conf.test_for(path);
      new File(test).exists().then((exists) {
          if (exists) {
            start_test(test);
          } else {
            uis.forEach((ui) => ui.message("No tests found for: ${path}"));
          }
      });
    });

    return Future.wait([chrome.start(), incoming.start()]);

  }

  void start_test(String test) {

    var runner;

    if (test.endsWith("html")) {
      runner = headless_runner;
    } else {
      runner = isolate_runner;
    }

    runner.run(test).then((runner_instance) {
      test_connected(runner_instance, test:test);
    });

  }

  void test_connected(TestRunnerInstance runner, {String test}) {

    StreamSubscription subscription = runner.stream.listen(null);
    subscription.onData((Map details) {
      test = test!=null ? test : details['test'];
      var session = test_sessions.putIfAbsent(test, ()=>new TestSession(test));
      console.session = session;
      subscription.onData((Map data) => session.onData(data));
      session.init(runner);
    });

  }

  Future stop() {
    fileWatcher.stop();
    return webSockets.stop();
  }
}