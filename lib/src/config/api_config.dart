class ApiConfig {
  const ApiConfig._();

  static const String defaultLocalBaseUrl =
      'http://localhost:8080/Narellallc/sma-v1/1.0.0';

  static const String productionBaseUrl =
      'https://api.airghana.org/Narellallc/sma-v1/1.0.0';

  static const String baseUrl = String.fromEnvironment(
    'SMA_API_BASE_URL',
    defaultValue: defaultLocalBaseUrl,
  );
}
