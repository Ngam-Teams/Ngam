import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

import '../../models/product_model.dart';
import '../../utils/ngam_category_catalog.dart';
import 'home_search_screen.dart';

/// Dedicated "Explore Categories" directory page showing all Main Categories
/// (Kategori Besar) and their Sub-Categories (Anak-Anak) with live store counts.
class CategoryExploreScreen extends StatefulWidget {
  final List<Map<String, dynamic>> shops;
  final List<ProductModel> products;
  final double? userLat;
  final double? userLng;

  const CategoryExploreScreen({
    super.key,
    this.shops = const [],
    this.products = const [],
    this.userLat,
    this.userLng,
  });

  @override
  State<CategoryExploreScreen> createState() => _CategoryExploreScreenState();
}

class _CategoryExploreScreenState extends State<CategoryExploreScreen> {
  final TextEditingController _searchCtrl = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  int _countShops(String catId) {
    if (widget.shops.isEmpty) return 0;
    return widget.shops
        .where((s) => NgamCategoryCatalog.matchesShop(s, catId))
        .length;
  }

  void _openCategoryResults(String catId, String displayLabel) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HomeSearchScreen(
          initialShops: widget.shops,
          initialProducts: widget.products,
          userLat: widget.userLat,
          userLng: widget.userLng,
          initialCategoryFilter: catId,
          initialCategoryLabel: displayLabel,
        ),
      ),
    );
  }

  List<({NgamCategoryGroup group, List<NgamSubCategory> children})>
      get _filteredSections {
    final q = _query.trim().toLowerCase();
    final out = <({NgamCategoryGroup group, List<NgamSubCategory> children})>[];
    for (final g in NgamCategoryCatalog.groups) {
      if (q.isEmpty) {
        out.add((group: g, children: g.children));
        continue;
      }
      final gTitle = g.titleKey.tr().toLowerCase();
      final groupMatches = gTitle.contains(q) ||
          g.id.contains(q) ||
          g.groupSynonyms.any((s) => s.contains(q));
      if (groupMatches) {
        out.add((group: g, children: g.children));
        continue;
      }
      final matchingSubs = g.children.where((c) {
        final cTitle = c.titleKey.tr().toLowerCase();
        return cTitle.contains(q) ||
            c.id.contains(q) ||
            c.synonyms.any((s) => s.contains(q));
      }).toList();
      if (matchingSubs.isNotEmpty) {
        out.add((group: g, children: matchingSubs));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final bool isDark = Theme.of(context).brightness == Brightness.dark;
    final Color bgColor = isDark ? const Color(0xFF0A0A14) : const Color(0xFFF8F9FA);
    final Color cardBg = isDark ? const Color(0xFF161622) : Colors.white;
    final Color textPrimary = isDark ? Colors.white : const Color(0xFF0F172A);
    final Color textSecondary = isDark ? Colors.white60 : const Color(0xFF64748B);
    final sections = _filteredSections;

    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 820),
            child: Column(
              children: [
                // Top Header Bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(12, 10, 16, 10),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        style: IconButton.styleFrom(
                          backgroundColor: isDark
                              ? Colors.white.withValues(alpha: 0.06)
                              : Colors.black.withValues(alpha: 0.05),
                        ),
                        icon: HugeIcon(
                          icon: HugeIcons.strokeRoundedArrowLeft01,
                          color: textPrimary,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'category_explore.title'.tr(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textPrimary,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              'category_explore.subtitle'.tr(),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: textSecondary,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Search Categories Field
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: (v) => setState(() => _query = v),
                    style: TextStyle(color: textPrimary, fontSize: 13.5),
                    decoration: InputDecoration(
                      hintText: 'category_explore.search_hint'.tr(),
                      hintStyle: TextStyle(color: textSecondary, fontSize: 13),
                      prefixIcon: Padding(
                        padding: const EdgeInsets.all(12),
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedSearch01,
                          color: textSecondary,
                          size: 18,
                        ),
                      ),
                      suffixIcon: _query.isNotEmpty
                          ? IconButton(
                              onPressed: () {
                                _searchCtrl.clear();
                                setState(() => _query = '');
                              },
                              icon: Icon(
                                Icons.close_rounded,
                                color: textSecondary,
                                size: 18,
                              ),
                            )
                          : null,
                      filled: true,
                      fillColor: isDark
                          ? const Color(0xFF1A1A24)
                          : Colors.black.withValues(alpha: 0.04),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 11,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: BorderSide(
                          color: isDark ? Colors.white12 : Colors.black12,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                        borderSide: const BorderSide(
                          color: Color(0xFF3B82F6),
                          width: 1.2,
                        ),
                      ),
                    ),
                  ),
                ),

                // Main Category -> Sub-Category Tree List
                Expanded(
                  child: sections.isEmpty
                      ? Center(
                          child: Text(
                            'category_explore.empty_search'.tr(),
                            style: TextStyle(color: textSecondary, fontSize: 13.5),
                          ),
                        )
                      : ListView.separated(
                          padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
                          physics: const BouncingScrollPhysics(),
                          itemCount: sections.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, idx) {
                            final sec = sections[idx];
                            final g = sec.group;
                            final gLabel = g.titleKey.tr();
                            final gCount = _countShops(g.id);

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: cardBg,
                                borderRadius: BorderRadius.circular(18),
                                border: Border.all(
                                  color: isDark
                                      ? Colors.white.withValues(alpha: 0.08)
                                      : Colors.black.withValues(alpha: 0.06),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Main Category Header (Kategori Besar)
                                  InkWell(
                                    onTap: () => _openCategoryResults(g.id, gLabel),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Row(
                                      children: [
                                        Container(
                                          width: 38,
                                          height: 38,
                                          decoration: BoxDecoration(
                                            color: g.color.withValues(
                                              alpha: isDark ? 0.16 : 0.12,
                                            ),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: g.color.withValues(alpha: 0.35),
                                            ),
                                          ),
                                          child: Center(
                                            child: HugeIcon(
                                              icon: g.icon,
                                              color: g.color,
                                              size: 19,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 11),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                gLabel,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: textPrimary,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w800,
                                                ),
                                              ),
                                              if (gCount > 0)
                                                Text(
                                                  'category_explore.shops_count'
                                                      .tr(args: ['$gCount']),
                                                  style: TextStyle(
                                                    color: g.color,
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w700,
                                                  ),
                                                ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: g.color.withValues(alpha: 0.12),
                                            borderRadius: BorderRadius.circular(100),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                'category_explore.view_all'.tr(),
                                                style: TextStyle(
                                                  color: g.color,
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.w700,
                                                ),
                                              ),
                                              const SizedBox(width: 2),
                                              Icon(
                                                Icons.chevron_right_rounded,
                                                size: 15,
                                                color: g.color,
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 12),
                                  // Sub-Categories (Anak-Anak)
                                  Wrap(
                                    spacing: 8,
                                    runSpacing: 8,
                                    children: sec.children.map((sub) {
                                      final subLabel = sub.titleKey.tr();
                                      final subCount = _countShops(sub.id);
                                      return InkWell(
                                        onTap: () =>
                                            _openCategoryResults(sub.id, subLabel),
                                        borderRadius: BorderRadius.circular(12),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 11,
                                            vertical: 7.5,
                                          ),
                                          decoration: BoxDecoration(
                                            color: isDark
                                                ? Colors.white.withValues(alpha: 0.05)
                                                : Colors.black.withValues(alpha: 0.035),
                                            borderRadius: BorderRadius.circular(12),
                                            border: Border.all(
                                              color: isDark
                                                  ? Colors.white.withValues(alpha: 0.09)
                                                  : Colors.black.withValues(alpha: 0.07),
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              HugeIcon(
                                                icon: sub.icon,
                                                color: g.color.withValues(alpha: 0.85),
                                                size: 14,
                                              ),
                                              const SizedBox(width: 6),
                                              Flexible(
                                                child: Text(
                                                  subLabel,
                                                  maxLines: 1,
                                                  overflow: TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: textPrimary,
                                                    fontSize: 12,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ),
                                              if (subCount > 0) ...[
                                                const SizedBox(width: 6),
                                                Container(
                                                  padding: const EdgeInsets.symmetric(
                                                    horizontal: 5.5,
                                                    vertical: 1.5,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: g.color.withValues(alpha: 0.18),
                                                    borderRadius:
                                                        BorderRadius.circular(8),
                                                  ),
                                                  child: Text(
                                                    '$subCount',
                                                    style: TextStyle(
                                                      color: g.color,
                                                      fontSize: 10,
                                                      fontWeight: FontWeight.w800,
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      );
                                    }).toList(),
                                  ),
                                ],
                              ),
                            );
                          },
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
