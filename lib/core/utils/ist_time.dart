/// India (Asia/Kolkata) does not observe daylight saving time, so its UTC
/// offset is permanently +5:30 — safe to hardcode without pulling in the
/// full `timezone`/tz-database package just for one fixed offset.
///
/// The backend sends timestamps as standard UTC ISO 8601 strings (Mongoose's
/// default Date serialization, e.g. "2026-07-22T10:30:00.000Z").
/// DateTime.parse() correctly reads those as UTC, but formatting a UTC
/// DateTime directly with `intl`'s DateFormat prints UTC wall-clock time,
/// not IST — DateFormat doesn't do any timezone conversion on its own, it
/// just prints whatever fields are already on the DateTime. `toIst` is what
/// actually shifts those fields to Kolkata time before formatting.
extension IstDateTime on DateTime {
  static const Duration _istOffset = Duration(hours: 5, minutes: 30);

  /// A DateTime carrying IST wall-clock field values (hour, minute, day, …),
  /// ready to hand straight to DateFormat. Internally still flagged UTC by
  /// Dart — that's intentional and required so DateFormat prints these
  /// fields verbatim. Do NOT call `.toLocal()` on the result: the device's
  /// timezone is irrelevant here and would double-shift it.
  DateTime get toIst => toUtc().add(_istOffset);
}
