// ============================================================
// FILE: tags_management_page.dart
// Path: lib/presentation/screens/tags/tags_management_page.dart
// Ρόλος: Σελίδα διαχείρισης tags (δημιουργία, επεξεργασία, διαγραφή)
// ✅ Accessibility: Semantics + announcements παντού
// ✅ Dark mode: ColorsUI tokens
// ✅ Offline-safe: optimistic updates
// ✅ Session: SessionScope για userId
// ✅ Responsive: tablet/mobile/desktop
// ============================================================
// PART 1 OF 3 – Imports, Page shell, AppBar, Search bar
// ============================================================

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:family_economy/providers/tags_provider.dart';
import 'package:family_economy/core/theme/ui_tokens.dart';
import 'package:family_economy/core/accessibility/accessibility_service.dart';
import 'package:family_economy/core/services/connectivity_service.dart';

// ============================================================
// PAGE ENTRY POINT
// ============================================================

class TagsManagementPage extends StatefulWidget {
  const TagsManagementPage({super.key});

  @override
  State<TagsManagementPage> createState() => _TagsManagementPageState();
}

class _TagsManagementPageState extends State<TagsManagementPage> {
  // ──────────────────────────────────────────────────────────
  // STATE
  // ──────────────────────────────────────────────────────────
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    AccessibilityService.announceAfterFirstFrame(
        context, 'Διαχείριση Tags');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // ──────────────────────────────────────────────────────────
  // FILTERED TAGS
  // ──────────────────────────────────────────────────────────

  List<TagModel> _filteredTags(List<TagModel> tags) {
    if (_searchQuery.trim().isEmpty) return tags;
    final q = _searchQuery.toLowerCase().trim();
    return tags.where((t) => t.name.toLowerCase().contains(q)).toList();
  }

  // ──────────────────────────────────────────────────────────
  // BUILD
  // ──────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final tagsProvider = context.watch<TagsProvider>();
    final connectivity = context.watch<ConnectivityService>();
    final isOffline = !connectivity.isOnline;

    // Responsive
    final screenWidth = MediaQuery.of(context).size.width;
    final isWide = screenWidth > 700;

    final filteredTags = _filteredTags(tagsProvider.tags);

    return Scaffold(
      backgroundColor: ColorsUI.getBackground(brightness),
      appBar: AppBar(
        backgroundColor: ColorsUI.getSurface(brightness),
        elevation: 0,
        leading: Semantics(
          button: true,
          label: 'Πίσω',
          excludeSemantics: true,
          child: IconButton(
            icon: Icon(
              Icons.arrow_back_rounded,
              color: ColorsUI.getTextPrimary(brightness),
            ),
            onPressed: () => Navigator.of(context).pop(),
            tooltip: 'Πίσω',
          ),
        ),
        title: Semantics(
          header: true,
          child: Text(
            'Διαχείριση Tags',
            style: TypographyUI.titleMedium(brightness),
          ),
        ),
        actions: [
          // ─── Add Tag ───────────────────────────────────
          Semantics(
            button: true,
            label: 'Δημιουργία νέου tag',
            hint: 'Πατήστε για να δημιουργήσετε νέο tag',
            excludeSemantics: true,
            child: IconButton(
              icon: Icon(
                Icons.add_rounded,
                color: ColorsUI.getPrimary(brightness),
              ),
              onPressed: () => _showCreateDialog(context, tagsProvider),
              tooltip: 'Νέο Tag',
            ),
          ),
        ],
      ),

      // ──────────────────────────────────────────────────
      // BODY
      // ──────────────────────────────────────────────────
      body: Column(
        children: [
          // ─── Offline Banner ─────────────────────────────
          if (isOffline)
            Semantics(
              liveRegion: true,
              label: 'Εκτός σύνδεσης. Οι αλλαγές θα συγχρονιστούν αυτόματα.',
              child: ExcludeSemantics(
                child: Container(
                  width: double.infinity,
                  color: ColorsUI.getWarning(brightness).withValues(alpha: 0.15),
                  padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.cloud_off_rounded,
                        size: 16,
                        color: ColorsUI.getWarning(brightness),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Εκτός σύνδεσης. Οι αλλαγές θα συγχρονιστούν αυτόματα.',
                          style: TypographyUI.bodySmall(brightness).copyWith(
                            color: ColorsUI.getWarning(brightness),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          // ─── Error Banner ────────────────────────────────
          if (tagsProvider.error != null)
            Semantics(
              liveRegion: true,
              child: Container(
                width: double.infinity,
                color: ColorsUI.getError(brightness).withValues(alpha: 0.1),
                padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    ExcludeSemantics(
                      child: Icon(Icons.error_outline_rounded,
                          size: 16, color: ColorsUI.getError(brightness)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tagsProvider.error!,
                        style: TypographyUI.bodySmall(brightness).copyWith(
                          color: ColorsUI.getError(brightness),
                        ),
                      ),
                    ),
                    Semantics(
                      button: true,
                      label: 'Κλείσιμο μηνύματος σφάλματος',
                      child: IconButton(
                        icon: ExcludeSemantics(
                          child: Icon(Icons.close_rounded,
                              size: 16, color: ColorsUI.getError(brightness)),
                        ),
                        onPressed: tagsProvider.clearError,
                        tooltip: 'Κλείσιμο',
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // ─── Search Bar ──────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Semantics(
              label: 'Αναζήτηση tags',
              textField: true,
              child: TextField(
                controller: _searchController,
                style: TypographyUI.bodyMedium(brightness),
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  hintText: 'Αναζήτηση...',
                  hintStyle: TypographyUI.placeholder(brightness),
                  prefixIcon: ExcludeSemantics(
                    child: Icon(
                      Icons.search_rounded,
                      color: ColorsUI.getTextSecondary(brightness),
                    ),
                  ),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? Semantics(
                    button: true,
                    label: 'Καθαρισμός αναζήτησης',
                    child: IconButton(
                      icon: ExcludeSemantics(
                        child: Icon(Icons.clear_rounded,
                            color: ColorsUI.getTextSecondary(brightness)),
                      ),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                      tooltip: 'Καθαρισμός',
                    ),
                  )
                      : null,
                  filled: true,
                  fillColor: ColorsUI.getInputFill(brightness),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                    BorderSide(color: ColorsUI.getInputBorder(brightness)),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide:
                    BorderSide(color: ColorsUI.getInputBorder(brightness)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: ColorsUI.getInputFocusBorder(brightness),
                        width: 2),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 12),
                ),
              ),
            ),
          ),

          // ─── Content ─────────────────────────────────────
          Expanded(
            child: _buildContent(
              context,
              brightness,
              tagsProvider,
              filteredTags,
              isWide,
            ),
          ),
        ],
      ),

      // ──────────────────────────────────────────────────
      // FAB
      // ──────────────────────────────────────────────────
      floatingActionButton: Semantics(
        button: true,
        label: 'Δημιουργία νέου tag',
        hint: 'Πατήστε για να δημιουργήσετε νέο tag',
        excludeSemantics: true,
        child: FloatingActionButton.extended(
          onPressed: () => _showCreateDialog(context, tagsProvider),
          backgroundColor: ColorsUI.getPrimary(brightness),
          foregroundColor: ColorsUI.getOnPrimary(brightness),
          icon: const Icon(Icons.add_rounded),
          label: Text(
            'Νέο Tag',
            style: TypographyUI.labelLarge(brightness).copyWith(
              color: ColorsUI.getOnPrimary(brightness),
            ),
          ),
        ),
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // CONTENT BUILDER
  // ──────────────────────────────────────────────────────────

  Widget _buildContent(
      BuildContext context,
      Brightness brightness,
      TagsProvider tagsProvider,
      List<TagModel> filteredTags,
      bool isWide,
      ) {
    // Loading
    if (tagsProvider.loading) {
      return Semantics(
        liveRegion: true,
        label: 'Φόρτωση tags. Παρακαλώ περιμένετε.',
        child: Center(
          child: ExcludeSemantics(
            child: CircularProgressIndicator(
              color: ColorsUI.getPrimary(brightness),
            ),
          ),
        ),
      );
    }

    // Κανένα tag
    if (tagsProvider.tags.isEmpty) {
      return _buildEmptyState(context, brightness);
    }

    // Κανένα αποτέλεσμα αναζήτησης
    if (filteredTags.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.search_off_rounded,
                size: 48,
                color: ColorsUI.getTextSecondary(brightness),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Δεν βρέθηκαν tags για "$_searchQuery"',
              style: TypographyUI.bodyMedium(brightness).copyWith(
                color: ColorsUI.getTextSecondary(brightness),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // ─── Grid (wide) ή List (narrow) ─────────────────────
    if (isWide) {
      return _buildTagsGrid(context, brightness, filteredTags, tagsProvider);
    } else {
      return _buildTagsList(context, brightness, filteredTags, tagsProvider);
    }
  }

  // ──────────────────────────────────────────────────────────
  // EMPTY STATE
  // ──────────────────────────────────────────────────────────

  Widget _buildEmptyState(BuildContext context, Brightness brightness) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ExcludeSemantics(
              child: Icon(
                Icons.label_outline_rounded,
                size: 72,
                color: ColorsUI.getTextSecondary(brightness),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Δεν υπάρχουν tags',
              style: TypographyUI.titleMedium(brightness),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Δημιουργήστε tags για να οργανώσετε\nτις κινήσεις σας.',
              style: TypographyUI.bodyMedium(brightness).copyWith(
                color: ColorsUI.getTextSecondary(brightness),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Semantics(
              button: true,
              label: 'Δημιουργία πρώτου tag',
              excludeSemantics: true,
              child: ElevatedButton.icon(
                onPressed: () =>
                    _showCreateDialog(context, context.read<TagsProvider>()),
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorsUI.getPrimary(brightness),
                  foregroundColor: ColorsUI.getOnPrimary(brightness),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                icon: const ExcludeSemantics(
                  child: Icon(Icons.add_rounded),
                ),
                label: Text(
                  'Δημιουργία Tag',
                  style: TypographyUI.labelLarge(brightness).copyWith(
                    color: ColorsUI.getOnPrimary(brightness),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  // ============================================================
// PART 2 OF 3 – Grid, List, Tag Card
// Paste directly below PART 1
// ============================================================

  // ──────────────────────────────────────────────────────────
  // TAGS GRID (tablet/desktop)
  // ──────────────────────────────────────────────────────────

  Widget _buildTagsGrid(
      BuildContext context,
      Brightness brightness,
      List<TagModel> tags,
      TagsProvider tagsProvider,
      ) {
    final crossAxisCount = MediaQuery.of(context).size.width > 900 ? 4 : 3;

    final bottomPadding = 110 + MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPadding),
      child: GridView.builder(
        itemCount: tags.length,
        gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: crossAxisCount,
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 2.2,
        ),
        itemBuilder: (context, index) {
          return _TagCard(
            tag: tags[index],
            tagsProvider: tagsProvider,
            onEdit: () =>
                _showEditDialog(context, tagsProvider, tags[index]),
            onDelete: () =>
                _showDeleteConfirm(context, tagsProvider, tags[index]),
          );
        },
      ),
    );
  }

  // ──────────────────────────────────────────────────────────
  // TAGS LIST (mobile)
  // ──────────────────────────────────────────────────────────

  Widget _buildTagsList(
      BuildContext context,
      Brightness brightness,
      List<TagModel> tags,
      TagsProvider tagsProvider,
      ) {
    final bottomPadding = 110 + MediaQuery.of(context).padding.bottom;

    return ListView.separated(
      padding: EdgeInsets.fromLTRB(16, 4, 16, bottomPadding),
      itemCount: tags.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        return _TagListTile(
          tag: tags[index],
          tagsProvider: tagsProvider,
          onEdit: () =>
              _showEditDialog(context, tagsProvider, tags[index]),
          onDelete: () =>
              _showDeleteConfirm(context, tagsProvider, tags[index]),
        );
      },
    );
  }

  // ──────────────────────────────────────────────────────────
  // CREATE DIALOG
  // ──────────────────────────────────────────────────────────

  Future<void> _showCreateDialog(
      BuildContext context, TagsProvider tagsProvider) async {
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
                  borderRadius: BorderRadius.circular(16)),
              title: Semantics(
                header: true,
                child: Text('Νέο Tag',
                    style: TypographyUI.titleMedium(brightness)),
              ),
              content: _TagFormContent(
                nameController: nameController,
                selectedColor: selectedColor,
                brightness: brightness,
                onColorChanged: (hex) =>
                    setDialogState(() => selectedColor = hex),
              ),
              actions: [
                Semantics(
                  button: true,
                  label: 'Ακύρωση',
                  excludeSemantics: true,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      AccessibilityService.announcePolite('Ακύρωση');
                    },
                    child: Text('Ακύρωση',
                        style: TypographyUI.labelLarge(brightness).copyWith(
                            color: ColorsUI.getTextSecondary(brightness))),
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Αποθήκευση νέου tag',
                  excludeSemantics: true,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorsUI.getPrimary(brightness),
                      foregroundColor: ColorsUI.getOnPrimary(brightness),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) {
                        AccessibilityService.announceError(
                            'Συμπληρώστε όνομα tag');
                        return;
                      }
                      Navigator.of(dialogContext).pop();
                      final newId = await tagsProvider.createTag(
                          name: name, color: selectedColor);
                      if (newId != null) {
                        AccessibilityService.announceSuccess(
                            'Δημιουργήθηκε tag: $name');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Tag "$name" δημιουργήθηκε'),
                              backgroundColor:
                              ColorsUI.getSuccess(brightness),
                              behavior: SnackBarBehavior.floating,
                              margin: const EdgeInsets.all(16),
                            ),
                          );
                        }
                      } else {
                        AccessibilityService.announceError(
                            tagsProvider.error ?? 'Σφάλμα δημιουργίας');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  tagsProvider.error ?? 'Σφάλμα δημιουργίας'),
                              backgroundColor: ColorsUI.getError(brightness),
                              behavior: SnackBarBehavior.floating,
                              margin: const EdgeInsets.all(16),
                            ),
                          );
                        }
                      }
                    },
                    child: Text('Δημιουργία',
                        style: TypographyUI.buttonBase()),
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
  // EDIT DIALOG
  // ──────────────────────────────────────────────────────────

  Future<void> _showEditDialog(
      BuildContext context,
      TagsProvider tagsProvider,
      TagModel tag,
      ) async {
    final brightness = Theme.of(context).brightness;
    final nameController = TextEditingController(text: tag.name);
    String selectedColor = tag.color;

    AccessibilityService.announcePolite('Επεξεργασία tag: ${tag.name}');

    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            return AlertDialog(
              backgroundColor: ColorsUI.getSurface(brightness),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              title: Semantics(
                header: true,
                child: Text('Επεξεργασία Tag',
                    style: TypographyUI.titleMedium(brightness)),
              ),
              content: _TagFormContent(
                nameController: nameController,
                selectedColor: selectedColor,
                brightness: brightness,
                onColorChanged: (hex) =>
                    setDialogState(() => selectedColor = hex),
              ),
              actions: [
                Semantics(
                  button: true,
                  label: 'Ακύρωση',
                  excludeSemantics: true,
                  child: TextButton(
                    onPressed: () {
                      Navigator.of(dialogContext).pop();
                      AccessibilityService.announcePolite('Ακύρωση');
                    },
                    child: Text('Ακύρωση',
                        style: TypographyUI.labelLarge(brightness).copyWith(
                            color: ColorsUI.getTextSecondary(brightness))),
                  ),
                ),
                Semantics(
                  button: true,
                  label: 'Αποθήκευση αλλαγών tag',
                  excludeSemantics: true,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: ColorsUI.getPrimary(brightness),
                      foregroundColor: ColorsUI.getOnPrimary(brightness),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: () async {
                      final name = nameController.text.trim();
                      if (name.isEmpty) {
                        AccessibilityService.announceError(
                            'Συμπληρώστε όνομα tag');
                        return;
                      }
                      Navigator.of(dialogContext).pop();
                      final ok = await tagsProvider.updateTag(
                        uuid: tag.uuid,
                        name: name,
                        color: selectedColor,
                      );
                      if (ok) {
                        AccessibilityService.announceSuccess(
                            'Ενημερώθηκε tag: $name');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Tag "$name" ενημερώθηκε'),
                              backgroundColor:
                              ColorsUI.getSuccess(brightness),
                              behavior: SnackBarBehavior.floating,
                              margin: const EdgeInsets.all(16),
                            ),
                          );
                        }
                      } else {
                        AccessibilityService.announceError(
                            tagsProvider.error ?? 'Σφάλμα ενημέρωσης');
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                  tagsProvider.error ?? 'Σφάλμα ενημέρωσης'),
                              backgroundColor: ColorsUI.getError(brightness),
                              behavior: SnackBarBehavior.floating,
                              margin: const EdgeInsets.all(16),
                            ),
                          );
                        }
                      }
                    },
                    child: Text('Αποθήκευση',
                        style: TypographyUI.buttonBase()),
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
  // DELETE CONFIRM
  // ──────────────────────────────────────────────────────────

  Future<void> _showDeleteConfirm(
      BuildContext context,
      TagsProvider tagsProvider,
      TagModel tag,
      ) async {
    final brightness = Theme.of(context).brightness;

    AccessibilityService.announcePolite(
        'Επιβεβαίωση διαγραφής tag: ${tag.name}');

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: ColorsUI.getSurface(brightness),
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Semantics(
            header: true,
            child: Text('Διαγραφή Tag',
                style: TypographyUI.titleMedium(brightness)),
          ),
          content: Text(
            'Θέλετε να διαγράψετε το tag "${tag.name}";\n\nΤο tag θα αφαιρεθεί από όλες τις κινήσεις.',
            style: TypographyUI.bodyMedium(brightness),
          ),
          actions: [
            Semantics(
              button: true,
              label: 'Ακύρωση',
              excludeSemantics: true,
              child: TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                child: Text('Ακύρωση',
                    style: TypographyUI.labelLarge(brightness).copyWith(
                        color: ColorsUI.getTextSecondary(brightness))),
              ),
            ),
            Semantics(
              button: true,
              label: 'Επιβεβαίωση διαγραφής',
              excludeSemantics: true,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: ColorsUI.getError(brightness),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8)),
                ),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: Text('Διαγραφή', style: TypographyUI.buttonBase()),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed == true) {
      final ok = await tagsProvider.deleteTag(tag.uuid);
      if (ok) {
        AccessibilityService.announceSuccess('Διαγράφηκε tag: ${tag.name}');
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Tag "${tag.name}" διαγράφηκε'),
              backgroundColor: ColorsUI.getSuccess(brightness),
              behavior: SnackBarBehavior.floating,
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      } else {
        AccessibilityService.announceError('Σφάλμα διαγραφής tag');
      }
    }
  }
}
// ============================================================
// PART 3 OF 3 – _TagCard, _TagListTile, _TagFormContent
// Paste directly below PART 2
// ============================================================

// ============================================================
// TAG CARD (Grid view – tablet/desktop)
// ============================================================

class _TagCard extends StatelessWidget {
  final TagModel tag;
  final TagsProvider tagsProvider;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TagCard({
    required this.tag,
    required this.tagsProvider,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final tagColor = Color(TagColorUtil.hexToInt(tag.color));

    return Semantics(
      label: 'Tag: ${tag.name}',
      hint: 'Πατήστε παρατεταμένα για επιλογές',
      child: InkWell(
        onTap: onEdit,
        onLongPress: () => _showOptions(context),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: tagColor.withValues(alpha:0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tagColor.withValues(alpha:0.4)),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            children: [
              // ─── Color dot ────────────────────────────────
              ExcludeSemantics(
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: tagColor,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // ─── Name ─────────────────────────────────────
              Expanded(
                child: Text(
                  tag.name,
                  style: TypographyUI.labelMedium(brightness).copyWith(
                    color: tagColor,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),

              // ─── Options ──────────────────────────────────
              Semantics(
                button: true,
                label: 'Επιλογές για tag ${tag.name}',
                excludeSemantics: true,
                child: IconButton(
                  icon: Icon(Icons.more_vert_rounded,
                      size: 18,
                      color: ColorsUI.getTextSecondary(brightness)),
                  onPressed: () => _showOptions(context),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(
                      minWidth: 32, minHeight: 32),
                  tooltip: 'Επιλογές',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    showModalBottomSheet(
      context: context,
      backgroundColor: ColorsUI.getSurface(brightness),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => _TagOptionsSheet(
        tag: tag,
        onEdit: onEdit,
        onDelete: onDelete,
      ),
    );
  }
}

// ============================================================
// TAG LIST TILE (List view – mobile)
// ============================================================

class _TagListTile extends StatelessWidget {
  final TagModel tag;
  final TagsProvider tagsProvider;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TagListTile({
    required this.tag,
    required this.tagsProvider,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final tagColor = Color(TagColorUtil.hexToInt(tag.color));

    return Semantics(
      label: 'Tag: ${tag.name}',
      hint: 'Σύρετε αριστερά για διαγραφή ή πατήστε για επεξεργασία',
      child: Dismissible(
        key: Key('tag_${tag.uuid}'),
        direction: DismissDirection.endToStart,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20),
          decoration: BoxDecoration(
            color: ColorsUI.getError(brightness),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const ExcludeSemantics(
            child: Icon(Icons.delete_rounded,
                color: Colors.white, size: 24),
          ),
        ),
        confirmDismiss: (_) async {
          // Επιστρέφουμε false → η κάρτα δεν dismisses αυτόματα
          // Εμφανίζουμε dialog επιβεβαίωσης
          onDelete();
          return false;
        },
        child: InkWell(
          onTap: onEdit,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: ColorsUI.getCard(brightness),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: ColorsUI.getBorder(brightness)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                // ─── Color dot ──────────────────────────────
                ExcludeSemantics(
                  child: Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: tagColor,
                      shape: BoxShape.circle,
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // ─── Tag chip ───────────────────────────────
                ExcludeSemantics(
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: tagColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: tagColor.withValues(alpha: 0.4)),
                    ),
                    child: Text(
                      tag.name,
                      style: TypographyUI.labelSmall(brightness).copyWith(
                        color: tagColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),

                const Spacer(),

                // ─── Edit ───────────────────────────────────
                Semantics(
                  button: true,
                  label: 'Επεξεργασία tag ${tag.name}',
                  excludeSemantics: true,
                  child: IconButton(
                    icon: Icon(Icons.edit_rounded,
                        size: 18,
                        color: ColorsUI.getPrimary(brightness)),
                    onPressed: onEdit,
                    tooltip: 'Επεξεργασία',
                  ),
                ),

                // ─── Delete ─────────────────────────────────
                Semantics(
                  button: true,
                  label: 'Διαγραφή tag ${tag.name}',
                  excludeSemantics: true,
                  child: IconButton(
                    icon: Icon(Icons.delete_outline_rounded,
                        size: 18,
                        color: ColorsUI.getError(brightness)),
                    onPressed: onDelete,
                    tooltip: 'Διαγραφή',
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================
// TAG OPTIONS BOTTOM SHEET
// ============================================================

class _TagOptionsSheet extends StatelessWidget {
  final TagModel tag;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _TagOptionsSheet({
    required this.tag,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final tagColor = Color(TagColorUtil.hexToInt(tag.color));

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ─── Handle ─────────────────────────────────────
            ExcludeSemantics(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: ColorsUI.getBorder(brightness),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // ─── Tag header ─────────────────────────────────
            Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: 16, vertical: 8),
              child: Semantics(
                label: 'Tag: ${tag.name}',
                child: ExcludeSemantics(
                  child: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                            color: tagColor, shape: BoxShape.circle),
                      ),
                      const SizedBox(width: 8),
                      Text(tag.name,
                          style: TypographyUI.titleSmall(brightness).copyWith(
                              color: tagColor)),
                    ],
                  ),
                ),
              ),
            ),

            ExcludeSemantics(
              child: Divider(color: ColorsUI.getDivider(brightness)),
            ),

            // ─── Edit ───────────────────────────────────────
            Semantics(
              button: true,
              label: 'Επεξεργασία tag ${tag.name}',
              excludeSemantics: true,
              child: ListTile(
                leading: Icon(Icons.edit_rounded,
                    color: ColorsUI.getPrimary(brightness)),
                title: Text('Επεξεργασία',
                    style: TypographyUI.bodyMedium(brightness)),
                onTap: () {
                  Navigator.of(context).pop();
                  onEdit();
                },
              ),
            ),

            // ─── Delete ─────────────────────────────────────
            Semantics(
              button: true,
              label: 'Διαγραφή tag ${tag.name}',
              excludeSemantics: true,
              child: ListTile(
                leading: Icon(Icons.delete_outline_rounded,
                    color: ColorsUI.getError(brightness)),
                title: Text('Διαγραφή',
                    style: TypographyUI.bodyMedium(brightness).copyWith(
                        color: ColorsUI.getError(brightness))),
                onTap: () {
                  Navigator.of(context).pop();
                  onDelete();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================
// TAG FORM CONTENT (κοινό για Create & Edit dialog)
// ============================================================

class _TagFormContent extends StatelessWidget {
  final TextEditingController nameController;
  final String selectedColor;
  final Brightness brightness;
  final ValueChanged<String> onColorChanged;

  const _TagFormContent({
    required this.nameController,
    required this.selectedColor,
    required this.brightness,
    required this.onColorChanged,
  });

  Color _contrastColor(Color bg) {
    final r = bg.r / 255;
    final g = bg.g / 255;
    final b = bg.b / 255;
    final luminance = 0.299 * r + 0.587 * g + 0.114 * b;
    return luminance > 0.5 ? Colors.black87 : Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ─── Name Field ─────────────────────────────────
          Semantics(
            label: 'Όνομα tag',
            textField: true,
            child: TextField(
              controller: nameController,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              style: TypographyUI.bodyMedium(brightness),
              decoration: InputDecoration(
                labelText: 'Όνομα tag *',
                labelStyle: TypographyUI.labelMedium(brightness),
                filled: true,
                fillColor: ColorsUI.getInputFill(brightness),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                  BorderSide(color: ColorsUI.getInputBorder(brightness)),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide:
                  BorderSide(color: ColorsUI.getInputBorder(brightness)),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide(
                      color: ColorsUI.getInputFocusBorder(brightness),
                      width: 2),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // ─── Color Label ────────────────────────────────
          Text('Χρώμα', style: TypographyUI.labelLarge(brightness)),
          const SizedBox(height: 8),

          // ─── Color Grid ─────────────────────────────────
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: TagColorUtil.defaultColors.map((hex) {
              final color = Color(TagColorUtil.hexToInt(hex));
              final isChosen = selectedColor == hex;
              return Semantics(
                button: true,
                label: 'Χρώμα',
                selected: isChosen,
                excludeSemantics: true,
                child: GestureDetector(
                  onTap: () {
                    onColorChanged(hex);
                    AccessibilityService.announcePolite('Επιλέχθηκε χρώμα');
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isChosen ? Colors.white : Colors.transparent,
                        width: 2.5,
                      ),
                      boxShadow: isChosen
                          ? [
                        BoxShadow(
                          color: color.withValues(alpha:0.5),
                          blurRadius: 6,
                          spreadRadius: 1,
                        )
                      ]
                          : null,
                    ),
                    child: isChosen
                        ? Icon(Icons.check_rounded,
                        size: 16, color: _contrastColor(color))
                        : null,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          // ─── Preview ────────────────────────────────────
          ExcludeSemantics(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Προεπισκόπηση',
                  style: TypographyUI.labelSmall(brightness).copyWith(
                    color: ColorsUI.getTextSecondary(brightness),
                  ),
                ),
                const SizedBox(height: 6),
                _buildPreview(context),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreview(BuildContext context) {
    final color = Color(TagColorUtil.hexToInt(selectedColor));
    final name = nameController.text.trim().isEmpty
        ? 'Νέο tag'
        : nameController.text.trim();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha:0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha:0.6)),
      ),
      child: Text(
        name,
        style: TypographyUI.labelSmall(brightness).copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}