import 'package:flutter_test/flutter_test.dart';
import 'package:foodiefy/config/app_config.dart';

void main() {
  Map<String, String> base() => {
    'APP_ENV': 'staging',
    'LOCAL_RESCUE': 'false',
    'API_BASE_URL': 'https://staging.example.invalid',
    'SUPABASE_URL': 'https://project.example.invalid',
    'SUPABASE_PUBLISHABLE_KEY': 'sb_publishable_test',
  };
  test('staging rejects rescue unsafe http and server secrets', () {
    for (final change in [
      {'LOCAL_RESCUE': 'true'},
      {'API_BASE_URL': 'http://127.0.0.1:8080'},
      {'SUPABASE_PUBLISHABLE_KEY': 'sb_secret_test'},
    ]) {
      expect(
        () => AppConfig.fromValues({...base(), ...change}),
        throwsA(isA<ConfigurationException>()),
      );
    }
  });
  test('staging public https configuration is accepted', () {
    expect(AppConfig.fromValues(base()).environment, AppEnvironment.staging);
  });
}
