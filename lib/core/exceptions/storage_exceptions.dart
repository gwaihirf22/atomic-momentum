abstract class AppException implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;

  const AppException(
    this.message, {
    this.code,
    this.originalError,
  });

  @override
  String toString() => 'AppException: $message${code != null ? ' (Code: $code)' : ''}';
}

class StorageException extends AppException {
  const StorageException(
    super.message, {
    super.code,
    super.originalError,
  });

  @override
  String toString() => 'StorageException: $message${code != null ? ' (Code: $code)' : ''}';
}

class ValidationException extends AppException {
  const ValidationException(
    super.message, {
    super.code,
    super.originalError,
  });

  @override
  String toString() => 'ValidationException: $message${code != null ? ' (Code: $code)' : ''}';
}

class NetworkException extends AppException {
  const NetworkException(
    super.message, {
    super.code,
    super.originalError,
  });

  @override
  String toString() => 'NetworkException: $message${code != null ? ' (Code: $code)' : ''}';
}

class DataMigrationException extends AppException {
  const DataMigrationException(
    super.message, {
    super.code,
    super.originalError,
  });

  @override
  String toString() => 'DataMigrationException: $message${code != null ? ' (Code: $code)' : ''}';
}