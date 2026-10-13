import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// A section destination that can be shown as a compact mobile selector.
class ResponsiveSectionNavigationItem<T> {
  const ResponsiveSectionNavigationItem({
    required this.value,
    required this.label,
    this.icon,
  });

  final T value;
  final String label;
  final IconData? icon;
}

/// Keeps section navigation to one control on phones while preserving the
/// screen's richer navigation treatment on larger viewports.
class ResponsiveSectionNavigation<T> extends StatelessWidget {
  const ResponsiveSectionNavigation({
    super.key,
    required this.selected,
    required this.items,
    required this.onChanged,
    required this.wideNavigation,
    this.label = 'Section',
    this.selectorKey,
    this.mobileBreakpoint = 600,
    this.mobileFooter,
  });

  final T selected;
  final List<ResponsiveSectionNavigationItem<T>> items;
  final ValueChanged<T> onChanged;
  final Widget wideNavigation;
  final String label;
  final Key? selectorKey;
  final double mobileBreakpoint;
  final Widget? mobileFooter;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= mobileBreakpoint) return wideNavigation;

        final selector = DropdownButtonFormField<T>(
          key: selectorKey,
          value: selected,
          isExpanded: true,
          menuMaxHeight: (MediaQuery.sizeOf(context).height * .60).clamp(
            240.0,
            480.0,
          ),
          icon: const Icon(Icons.keyboard_arrow_down_rounded),
          decoration: InputDecoration(
            labelText: label,
            filled: true,
            fillColor: Colors.white,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 14,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.border),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: AppColors.green, width: 2),
            ),
          ),
          items: items
              .map(
                (item) => DropdownMenuItem<T>(
                  value: item.value,
                  child: _SectionNavigationLabel(item: item),
                ),
              )
              .toList(growable: false),
          onChanged: (value) {
            if (value != null && value != selected) onChanged(value);
          },
        );

        if (mobileFooter == null) return selector;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [selector, const SizedBox(height: 8), mobileFooter!],
        );
      },
    );
  }
}

class _SectionNavigationLabel<T> extends StatelessWidget {
  const _SectionNavigationLabel({required this.item});

  final ResponsiveSectionNavigationItem<T> item;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (item.icon != null) ...[
          Icon(item.icon, size: 19, color: AppColors.muted),
          const SizedBox(width: 10),
        ],
        Expanded(
          child: Text(item.label, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ],
    );
  }
}
