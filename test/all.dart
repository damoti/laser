import 'package:laser/console_unittest.dart';
import 'configuration_test.dart' as configuration_test;
import 'test_tree_test.dart' as test_tree_test;

void main([args, port]) { laser(port);
  configuration_test.main();
  test_tree_test.main();
}