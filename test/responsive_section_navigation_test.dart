import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:school_management_app/src/common/responsive_section_navigation.dart';

enum _Section { overview, students, structure, catalogue, reversals, waivers }

const _items = [
  ResponsiveSectionNavigationItem(
    value: _Section.overview,
    label: 'Overview',
  ),
  ResponsiveSectionNavigationItem(
    value: _Section.students,
    label: 'Student Fees',
  ),
  ResponsiveSectionNavigationItem(
    value: _Section.structure,
    label: 'Fee Structure',
  ),
  ResponsiveSectionNavigationItem(
    value: _Section.catalogue,
    label: 'Fee Catalogue',
  ),
  ResponsiveSectionNavigationItem(
    value: _Section.reversals,
    label: 'Payment Reversals',
  ),
  ResponsiveSectionNavigationItem(
    value: _Section.waivers,
    label: 'Waivers & Discounts',
  ),
];

void main() {
  testWidgets('uses one compact, usable selector on a phone', (tester) async {
    await tester.binding.setSurfaceSize(const Size(360, 760));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    var selected = _Section.overview;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: StatefulBuilder(
              builder: (context, setState) {
                return ResponsiveSectionNavigation<_Section>(
                  selected: selected,
                  items: _items,
                  onChanged: (value) => setState(() => selected = value),
                  label: 'Fees section',
                  selectorKey: const ValueKey('section-selector'),
                  wideNavigation: const SizedBox(
                    key: ValueKey('wide-navigation'),
                    height: 120,
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );

    final selector = find.byKey(const ValueKey('section-selector'));
    expect(selector, findsOneWidget);
    expect(find.byKey(const ValueKey('wide-navigation')), findsNothing);
    expect(tester.getSize(selector).height, lessThanOrEqualTo(64));
    expect(tester.getSize(selector).width, 328);

    await tester.tap(selector);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Payment Reversals').last);
    await tester.pumpAndSettle();

    expect(selected, _Section.reversals);
    expect(find.text('Payment Reversals'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('keeps the richer navigation on larger screens', (tester) async {
    await tester.binding.setSurfaceSize(const Size(834, 1194));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ResponsiveSectionNavigation<_Section>(
            selected: _Section.overview,
            items: _items,
            onChanged: (_) {},
            selectorKey: const ValueKey('section-selector'),
            wideNavigation: const SizedBox(
              key: ValueKey('wide-navigation'),
              height: 72,
            ),
          ),
        ),
      ),
    );

    expect(find.byKey(const ValueKey('section-selector')), findsNothing);
    expect(find.byKey(const ValueKey('wide-navigation')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
