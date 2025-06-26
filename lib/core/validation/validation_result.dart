class ValidationResult {
  final bool isValid;
  final List<String> errors;
  final List<String> warnings;

  const ValidationResult({
    required this.isValid,
    this.errors = const [],
    this.warnings = const [],
  });

  factory ValidationResult.valid() {
    return const ValidationResult(isValid: true);
  }

  factory ValidationResult.invalid(List<String> errors, [List<String>? warnings]) {
    return ValidationResult(
      isValid: false,
      errors: errors,
      warnings: warnings ?? [],
    );
  }

  factory ValidationResult.warning(List<String> warnings) {
    return ValidationResult(
      isValid: true,
      warnings: warnings,
    );
  }

  ValidationResult combine(ValidationResult other) {
    return ValidationResult(
      isValid: isValid && other.isValid,
      errors: [...errors, ...other.errors],
      warnings: [...warnings, ...other.warnings],
    );
  }

  String get firstError => errors.isNotEmpty ? errors.first : '';
  
  bool get hasErrors => errors.isNotEmpty;
  bool get hasWarnings => warnings.isNotEmpty;

  @override
  String toString() {
    if (isValid && warnings.isEmpty) return 'Valid';
    
    final parts = <String>[];
    if (!isValid) parts.add('Errors: ${errors.join(', ')}');
    if (warnings.isNotEmpty) parts.add('Warnings: ${warnings.join(', ')}');
    
    return parts.join(' | ');
  }
}