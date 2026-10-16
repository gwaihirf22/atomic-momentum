/// Turns a provider's error text into a message for people: a validation
/// problem is shown as written ("Name cannot be empty"); anything else
/// (storage failures, stack-trace-ish text) becomes [fallback].
String friendlyError(String? raw, {required String fallback}) {
  if (raw == null) return fallback;
  final validation = RegExp(r'ValidationException: (.+?)(?: \(Code: [^)]*\))?$').firstMatch(raw);
  if (validation != null) return validation.group(1)!.trim();
  return fallback;
}
