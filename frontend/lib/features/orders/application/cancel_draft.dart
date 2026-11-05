import '../../../core/formatting/server_text.dart';
import '../../../core/localization/generated/app_localizations.dart';
import '../../../core/network/api_failure.dart';
import '../domain/customer_orders.dart';

/// The reasons the cancel sheet offers as chips (`DL-133`).
enum CancelChip { wrongItems, changedMind, tooSlow, otherAddress, other }

/// The words of a [chip].
String cancelChipLabel(AppLocalizations l10n, CancelChip chip) =>
    switch (chip) {
      CancelChip.wrongItems => l10n.cancelChipWrongItems,
      CancelChip.changedMind => l10n.cancelChipChangedMind,
      CancelChip.tooSlow => l10n.cancelChipTooSlow,
      CancelChip.otherAddress => l10n.cancelChipOtherAddress,
      CancelChip.other => l10n.cancelChipOther,
    };

/// What the Customer has chosen and written in the cancel sheet; [details]
/// is whether the details field was opened.
final class CancelDraft {
  const CancelDraft({this.chip, this.text = '', this.details = false});

  static const CancelDraft empty = CancelDraft();

  final CancelChip? chip;
  final String text;
  final bool details;

  /// A copy with the given parts changed; [clearChip] drops the chip.
  CancelDraft copyWith({
    CancelChip? chip,
    bool clearChip = false,
    String? text,
    bool? details,
  }) => CancelDraft(
    chip: clearChip ? null : chip ?? this.chip,
    text: text ?? this.text,
    details: details ?? this.details,
  );

  bool get isEmpty => chip == null && text.isEmpty && !details;

  @override
  bool operator ==(Object other) =>
      other is CancelDraft &&
      other.chip == chip &&
      other.text == text &&
      other.details == details;

  @override
  int get hashCode => Object.hash(chip, text, details);
}

/// The reason as it is sent: the chip's words, with the Customer's words
/// after a colon; no chip, or «other», is the words alone.
String composeCancelReason(
  CancelDraft draft,
  String Function(CancelChip) label,
) {
  final String words = trimLikeServer(draft.text);
  final CancelChip? chip = draft.chip;
  if (chip == null || chip == CancelChip.other) {
    return words;
  }
  final String head = label(chip);
  return trimLikeServer(words.isEmpty ? head : '$head: $words');
}

/// The server's limit of a reason, in characters (`docs/09` section 22).
const int cancelReasonLimit = 300;

/// What stops a cancel from being sent.
enum CancelBlock { empty, tooLong }

/// Why [reason] cannot be sent yet, or `null`; only a request needs words.
CancelBlock? cancelBlock(String reason, {required bool request}) {
  if (reason.runes.length > cancelReasonLimit) {
    return CancelBlock.tooLong;
  }
  if (request && reason.isEmpty) {
    return CancelBlock.empty;
  }
  return null;
}

/// The face the cancel sheet shows.
enum CancelSheetMode { direct, request, retry, closed }

/// The sheet's face: a repeat of an unconfirmed send beats the rest; a
/// direct cancel becomes a request once the server asked for a reason.
CancelSheetMode cancelSheetMode(
  CustomerOrder order, {
  required bool unconfirmed,
  required bool forcedRequest,
}) {
  if (unconfirmed) {
    return CancelSheetMode.retry;
  }
  if (order.canCancelDirectly && !forcedRequest) {
    return CancelSheetMode.direct;
  }
  if (order.canRequestCancellation ||
      (forcedRequest && order.canCancelDirectly)) {
    return CancelSheetMode.request;
  }
  return CancelSheetMode.closed;
}

/// Shopping began since the order was shown: the cancel now asks an
/// Operator, and a request needs its reason (`DL-65` (1)).
bool cancelNeedsReason(ApiFailure? failure) =>
    failure is ApiRefusal &&
    failure.status == 422 &&
    failure.error.errors.containsKey('reason');
