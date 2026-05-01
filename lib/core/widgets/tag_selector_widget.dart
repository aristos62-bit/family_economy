// ============================================================
// FILE: tag_selector_widget.dart
// Path: lib/core/widgets/tag_selector_widget.dart
// Ρόλος: Reusable widget επιλογής tags κατά την εισαγωγή κίνησης
// ✅ Accessibility: Semantics + announcements
// ✅ Offline-safe: optimistic updates από TagsProvider
// ✅ Dark mode: ColorsUI tokens
// ✅ Responsive: Wrap chips, tablet/mobile/desktop
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:family_economy/providers/tags_provider.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';

// ============================================================
// TAG SELECTOR WIDGET
// Χρησιμοποιείται στο transaction_entry_details_step.dart
// ============================================================

class TagSelectorWidget extends StatefulWidget {
  /// Τρέχοντα επιλεγμένα tag UUIDs
  final List<String> selectedTagIds;

  /// Callback όταν αλλάζει η επιλογή tags
  final ValueChanged<List<String>> onChanged;

  /// Αν επιτρέπεται δημιουργία νέου tag inline
  final bool allowCreate;

  const TagSelectorWidget({
    super.key,
    required this.selectedTagIds,
    required this.onChanged,
    this.allowCreate = true,
  });

  @override
  State<TagSelectorWidget> createState() => _TagSelectorWidgetState();
}

class _TagSelectorWidgetState extends State<TagSelectorWidget> {
  // ──────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final tagsProvider = context.watch<TagsProvider>();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ─── Header ───────────────────────────────────────
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Semantics(
              header: true,
              child: Text('Tags', style: TypographyUI.labelLarge(brightness)),
            ),
            if (widget.allowCreate)
              Semantics(
                button: true,
                label: 'Δημιουργία νέου tag',
                hint: 'Πατήστε για να προσθέσετε νέο tag',
                excludeSemantics: true,
                child: TextButton.icon(
                  onPressed: () => _showCreateTagDialog(context, tagsProvider),
                  icon: Icon(
                    Icons.add_rounded,
                    size: 16,
                    color: ColorsUI.getPrimary(brightness),
                  ),
                  label: Text(
                    'Νέο tag',
                    style: TypographyUI.labelSmall(
                      brightness,
                    ).copyWith(color: ColorsUI.getPrimary(brightness)),
                  ),
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),

        // ─── Loading ──────────────────────────────────────
        if (tagsProvider.loading)
          _buildLoadingState(brightness)
        // ─── Empty State ──────────────────────────────────
        else if (tagsProvider.tags.isEmpty)
          _buildEmptyState(brightness)
        // ─── Tags Wrap ────────────────────────────────────
        else
          _buildTagsWrap(context, brightness, tagsProvider.tags),

        // ─── Error ────────────────────────────────────────
        if (tagsProvider.error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              tagsProvider.error!,
              style: TypographyUI.error(brightness),
            ),
          ),
      ],
    );
  }

  // ──────────────────────────────────────────────────────────
  // LOADING
  // ──────────────────────────────────────────────────────────

  Widget _buildLoadingState(Brightness brightness) {
    return Semantics(
      liveRegion: true,
      label: 'Φόρτωση tags. Παρακαλώ περιμένετε.',
      excludeSemantics: true,
      child: Row(
        children: [
          ExcludeSemantics(
            child: SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: ColorsUI.getPrimary(brightness),
              ),
            ),
          ),
          const SizedBox(width: 8),
          Text('Φόρτωση tags...', style: TypographyUI.bodySmall(brightness)),
        ],
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // EMPTY
  // ──────────────────────────────────────────────────────────

  Widget _buildEmptyState(Brightness brightness) {
    return Semantics(
      label: 'Δεν υπάρχουν tags. Πατήστε Νέο tag για να δημιουργήσετε.',
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
        decoration: BoxDecoration(
          color: ColorsUI.getInputFill(brightness),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: ColorsUI.getBorder(brightness)),
        ),
        child: Text(
          'Δεν υπάρχουν tags. Πατήστε "Νέο tag" για να δημιουργήσετε.',
          style: TypographyUI.bodySmall(brightness),
          textAlign: TextAlign.center,
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // TAGS WRAP
  // ──────────────────────────────────────────────────────────

  Widget _buildTagsWrap(
    BuildContext context,
    Brightness brightness,
    List<TagModel> allTags,
  ) {
    return Semantics(
      label: 'Επιλογή tags — επιτρέπεται πολλαπλή επιλογή',
      explicitChildNodes: true,
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: allTags.map((tag) {
          final isSelected = widget.selectedTagIds.contains(tag.uuid);
          final tagColor = Color(TagColorUtil.hexToInt(tag.color));

          return Semantics(
            label: 'Tag: ${tag.name}',
            value: isSelected ? 'Επιλεγμένο' : 'Μη επιλεγμένο',
            hint: isSelected ? 'Πατήστε για κατάργηση' : 'Πατήστε για επιλογή',
            button: true,
            checked: isSelected,
            excludeSemantics: true,
            child: GestureDetector(
              onTap: () => _toggleTag(tag),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: isSelected
                      ? tagColor.withValues(alpha: 0.85)
                      : tagColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isSelected
                        ? tagColor
                        : tagColor.withValues(alpha: 0.5),
                    width: isSelected ? 1.5 : 1.0,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (isSelected) ...[
                      Icon(
                        Icons.check_rounded,
                        size: 14,
                        color: _contrastColor(tagColor),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Text(
                      tag.name,
                      style: TypographyUI.labelSmall(brightness).copyWith(
                        color: isSelected ? _contrastColor(tagColor) : tagColor,
                        fontWeight: isSelected
                            ? FontWeight.w700
                            : FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // TOGGLE TAG
  // ──────────────────────────────────────────────────────────

  void _toggleTag(TagModel tag) {
    final current = List<String>.from(widget.selectedTagIds);
    if (current.contains(tag.uuid)) {
      current.remove(tag.uuid);
      AccessibilityService.announcePolite('Αφαιρέθηκε tag: ${tag.name}');
    } else {
      current.add(tag.uuid);
      AccessibilityService.announcePolite('Προστέθηκε tag: ${tag.name}');
    }
    widget.onChanged(current);
  }

  // ──────────────────────────────────────────────────────────
  // CONTRAST COLOR (white/black πάνω στο χρώμα)
  // ──────────────────────────────────────────────────────────

  Color _contrastColor(Color bg) {
    // W3C luminance formula
    final r = bg.r / 255;
    final g = bg.g / 255;
    final b = bg.b / 255;
    final luminance = 0.299 * r + 0.587 * g + 0.114 * b;
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }

  // ✅ Μετατρέπει hex κωδικό σε ελληνικό όνομα χρώματος
  // για ουσιαστικό label στον screen reader.
  String _colorName(String hex) {
    const names = {
      '#F44336': 'Κόκκινο',
      '#E91E63': 'Ροζ',
      '#9C27B0': 'Μοβ',
      '#673AB7': 'Σκούρο μοβ',
      '#3F51B5': 'Ινδικό μπλε',
      '#2196F3': 'Μπλε',
      '#03A9F4': 'Ανοιχτό μπλε',
      '#00BCD4': 'Κυανό',
      '#009688': 'Πράσινο θαλάσσης',
      '#4CAF50': 'Πράσινο',
      '#8BC34A': 'Ανοιχτό πράσινο',
      '#CDDC39': 'Λαχανί',
      '#FFEB3B': 'Κίτρινο',
      '#FFC107': 'Κεχριμπάρι',
      '#FF9800': 'Πορτοκαλί',
      '#FF5722': 'Βαθύ πορτοκαλί',
      '#795548': 'Καφέ',
      '#607D8B': 'Γκριζομπλε',
      '#9E9E9E': 'Γκρι',
      '#000000': 'Μαύρο',
    };

    final upper = hex.toUpperCase();
    return names[upper] ?? 'Χρώμα $hex';
  }

  // ──────────────────────────────────────────────────────────
  // CREATE TAG DIALOG
  // ──────────────────────────────────────────────────────────

  Future<void> _showCreateTagDialog(
    BuildContext context,
    TagsProvider tagsProvider,
  ) async {
    final brightness = Theme.of(context).brightness;
    final nameController = TextEditingController();
    String selectedColor = TagColorUtil.defaultColors.first;

    AccessibilityService.announcePolite('Δημιουργία νέου tag');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: ColorsUI.getSurface(brightness),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Semantics(
                header: true,
                child: Text(
                  'Νέο Tag',
                  style: TypographyUI.titleMedium(brightness),
                ),
              ),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // ─── Name Field ─────────────────────────
                    Semantics(
                      label: 'Όνομα tag',
                      textField: true,
                      child: TextField(
                        controller: nameController,
                        autofocus: true,
                        textCapitalization: TextCapitalization.sentences,
                        style: TypographyUI.bodyMedium(brightness),
                        decoration: InputDecoration(
                          labelText: 'Όνομα tag',
                          labelStyle: TypographyUI.labelMedium(brightness),
                          filled: true,
                          fillColor: ColorsUI.getInputFill(brightness),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: ColorsUI.getInputBorder(brightness),
                            ),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: ColorsUI.getInputBorder(brightness),
                            ),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                            borderSide: BorderSide(
                              color: ColorsUI.getInputFocusBorder(brightness),
                              width: 2,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),

                    // ─── Color Picker ───────────────────────
                    Text('Χρώμα', style: TypographyUI.labelLarge(brightness)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: TagColorUtil.defaultColors.map((hex) {
                        final color = Color(TagColorUtil.hexToInt(hex));
                        final isChosen = selectedColor == hex;
                        return Semantics(
                          label: _colorName(hex),
                          button: true,
                          selected: isChosen,
                          hint: isChosen ? 'Επιλεγμένο' : 'Πατήστε για επιλογή',
                          excludeSemantics: true,
                          child: GestureDetector(
                            onTap: () {
                              setDialogState(() => selectedColor = hex);
                              AccessibilityService.announcePolite(
                                'Επιλέχθηκε χρώμα: ${_colorName(hex)}',
                              );
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 150),
                              width: 32,
                              height: 32,
                              decoration: BoxDecoration(
                                color: color,
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: isChosen
                                      ? Colors.white
                                      : Colors.transparent,
                                  width: 2.5,
                                ),
                                boxShadow: isChosen
                                    ? [
                                        BoxShadow(
                                          color: color.withValues(alpha: 0.5),
                                          blurRadius: 6,
                                          spreadRadius: 1,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: isChosen
                                  ? Icon(
                                      Icons.check_rounded,
                                      size: 16,
                                      color: _contrastColor(color),
                                    )
                                  : null,
                            ),
                          ),
                        );
                      }).toList(),
                    ),

                    // ─── Preview ────────────────────────────
                    const SizedBox(height: 16),
                    Text(
                      'Προεπισκόπηση',
                      style: TypographyUI.labelSmall(
                        brightness,
                      ).copyWith(color: ColorsUI.getTextSecondary(brightness)),
                    ),
                    const SizedBox(height: 6),
                    _buildTagPreview(
                      nameController.text.trim().isEmpty
                          ? 'Νέο tag'
                          : nameController.text.trim(),
                      selectedColor,
                      brightness,
                    ),
                  ],
                ),
              ),
              actions: [
                // ─── Cancel ─────────────────────────────────
                Semantics(
                  button: true,
                  label: 'Ακύρωση',
                  excludeSemantics: true,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      AccessibilityService.announcePolite('Ακύρωση');
                    },
                    child: Text(
                      'Ακύρωση',
                      style: TypographyUI.labelLarge(
                        brightness,
                      ).copyWith(color: ColorsUI.getTextSecondary(brightness)),
                    ),
                  ),
                ),

                // ─── Save ───────────────────────────────────
                Semantics(
                  button: true,
                  label: 'Αποθήκευση tag',
                  excludeSemantics: true,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorsUI.getPrimary(brightness),
                      foregroundColor: ColorsUI.getOnPrimary(brightness),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) {
                        AccessibilityService.announceError(
                          'Συμπληρώστε όνομα tag',
                        );
                        return;
                      }

                      Navigator.of(dialogContext).pop();

                      final newId = await tagsProvider.createTag(
                        name: name,
                        color: selectedColor,
                      );

                      if (newId != null) {
                        // Auto-select το νέο tag
                        if (mounted) {
                          final updated = List<String>.from(
                            widget.selectedTagIds,
                          )..add(newId);
                          widget.onChanged(updated);
                        }
                        AccessibilityService.announceSuccess(
                          'Δημιουργήθηκε tag: $name',
                        );
                      } else {
                        AccessibilityService.announceError(
                          tagsProvider.error ?? 'Σφάλμα δημιουργίας tag',
                        );
                      }
                    },
                    child: Text('Δημιουργία', style: TypographyUI.buttonBase()),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────
  // TAG PREVIEW
  // ──────────────────────────────────────────────────────────

  Widget _buildTagPreview(String name, String colorHex, Brightness brightness) {
    final color = Color(TagColorUtil.hexToInt(colorHex));
    // ✅ Το preview είναι καθαρά διακοσμητικό — οπτική προεπισκόπηση μόνο.
    // Ο screen reader δεν χρειάζεται να το διαβάσει γιατί η πληροφορία
    // (όνομα + χρώμα) έχει ήδη ανακοινωθεί από τα αντίστοιχα πεδία.
    return ExcludeSemantics(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: color.withValues(alpha: 0.6)),
        ),
        child: Text(
          name,
          style: TypographyUI.labelSmall(
            brightness,
          ).copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
