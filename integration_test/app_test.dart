import 'package:integration_test/integration_test.dart';

import '../test/app_scenarios.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  registerAppScenarios(screenshots: true);
}
