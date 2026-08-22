import 'package:flutter/material.dart';

import '../../platform/presentation/document_opener.dart';
import '../../auth/data/auth_api_client.dart';
import '../data/guardian_portal_api_client.dart';
import '../domain/guardian_portal_models.dart';

const _previewUnreadMessageCount = 0;

class GuardianPortalScreen extends StatefulWidget {
  const GuardianPortalScreen({
    super.key,
    required this.api,
    required this.onLogout,
    this.schoolMemberships = const [],
  });

  final GuardianPortalApiClient api;
  final VoidCallback onLogout;
  final List<AuthSchoolMembership> schoolMemberships;

  @override
  State<GuardianPortalScreen> createState() => _GuardianPortalScreenState();
}

class _GuardianPortalScreenState extends State<GuardianPortalScreen> {
  int _page = 0;
  String? _selectedFeeChildId;
  String? _selectedChildId;
  bool _showCalendar = false;
  late Future<GuardianPortalSnapshot> _snapshot;

  @override
  void initState() {
    super.initState();
    final guardianMemberships = widget.schoolMemberships
        .where((membership) => membership.membershipType == 'GUARDIAN')
        .toList(growable: false);
    if (guardianMemberships.isNotEmpty) {
      widget.api.schoolId = guardianMemberships.first.schoolId;
    }
    _snapshot = widget.api.dashboard();
  }

  void _selectSchool(String schoolId) {
    if (schoolId == widget.api.schoolId) return;
    setState(() {
      widget.api.schoolId = schoolId;
      _selectedChildId = null;
      _selectedFeeChildId = null;
      _showCalendar = false;
      _snapshot = widget.api.dashboard();
    });
  }

  void _refresh() => setState(() => _snapshot = widget.api.dashboard());

  void _openPage(int page) {
    setState(() {
      _page = page;
      _selectedChildId = null;
      _showCalendar = false;
      if (page == 1) _selectedFeeChildId = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GuardianPortalSnapshot>(
      future: _snapshot,
      builder: (context, result) {
        final data = result.data;
        return Scaffold(
          backgroundColor: const Color(0xFFF4F7F6),
          appBar: _ParentAppBar(
            schoolName: data?.schoolName ?? 'Parent portal',
            term: data == null ? '' : '${data.termName} · ${data.academicYear}',
            guardianName: data?.guardianName ?? '',
            onPayFees: data == null
                ? () {}
                : () => _showMobileMoneyComingSoon(context),
            onRefresh: _refresh,
            schoolMemberships: widget.schoolMemberships
                .where((membership) => membership.membershipType == 'GUARDIAN')
                .toList(growable: false),
            selectedSchoolId: widget.api.schoolId,
            onSchoolSelected: _selectSchool,
          ),
          body:
              result.connectionState == ConnectionState.waiting && data == null
              ? const Center(child: CircularProgressIndicator())
              : result.hasError && data == null
              ? _FriendlyError(
                  message: _errorText(result.error),
                  onRetry: _refresh,
                  onSignInAgain: widget.onLogout,
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth >= 1280;
                    final body = _content(data!);
                    if (!wide) return body;
                    return Column(
                      children: [
                        _ParentDesktopNavigation(
                          selectedIndex: _page,
                          onSelected: _openPage,
                          onLogout: widget.onLogout,
                        ),
                        Expanded(child: body),
                      ],
                    );
                  },
                ),
          bottomNavigationBar: MediaQuery.sizeOf(context).width < 1280
              ? NavigationBar(
                  selectedIndex: _page,
                  onDestinationSelected: _openPage,
                  destinations: const [
                    NavigationDestination(
                      icon: Icon(Icons.home_outlined),
                      selectedIcon: Icon(Icons.home),
                      label: 'Home',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.account_balance_wallet_outlined),
                      selectedIcon: Icon(Icons.account_balance_wallet),
                      label: 'Fees',
                    ),
                    NavigationDestination(
                      icon: _MessageNavIcon(selected: false),
                      selectedIcon: _MessageNavIcon(selected: true),
                      label: 'Messages',
                    ),
                    NavigationDestination(
                      icon: Icon(Icons.person_outline),
                      selectedIcon: Icon(Icons.person),
                      label: 'Account',
                    ),
                  ],
                )
              : null,
        );
      },
    );
  }

  Widget _content(GuardianPortalSnapshot data) {
    if (_showCalendar) {
      return _GuardianCalendarPage(
        data: data,
        onBack: () => setState(() => _showCalendar = false),
      );
    }
    if (_selectedChildId != null) {
      final children = data.children;
      final child = children.cast<GuardianChildSummary?>().firstWhere(
        (item) => item?.studentId == _selectedChildId,
        orElse: () => null,
      );
      if (child != null) {
        return _ParentChildWorkspace(
          data: data,
          child: child,
          api: widget.api,
          onBack: () => setState(() => _selectedChildId = null),
        );
      }
    }
    return switch (_page) {
      0 => _ParentHome(
        data: data,
        onOpenFees: () => _openPage(1),
        onOpenChild: (studentId) =>
            setState(() => _selectedChildId = studentId),
        onOpenMessages: () => _openPage(2),
        onOpenCalendar: () => setState(() => _showCalendar = true),
      ),
      1 => _ParentFees(
        data: data,
        api: widget.api,
        initialChildId: _selectedFeeChildId,
      ),
      2 => const _ParentMessages(),
      _ => _ParentMore(
        data: data,
        api: widget.api,
        onProfileUpdated: _refresh,
        onOpenMessages: () => _openPage(2),
        onLogout: widget.onLogout,
      ),
    };
  }
}

class _ParentAppBar extends StatelessWidget implements PreferredSizeWidget {
  const _ParentAppBar({
    required this.schoolName,
    required this.term,
    required this.guardianName,
    required this.onPayFees,
    required this.onRefresh,
    required this.schoolMemberships,
    required this.selectedSchoolId,
    required this.onSchoolSelected,
  });
  final String schoolName;
  final String term;
  final String guardianName;
  final VoidCallback onPayFees;
  final VoidCallback onRefresh;
  final List<AuthSchoolMembership> schoolMemberships;
  final String? selectedSchoolId;
  final ValueChanged<String> onSchoolSelected;
  @override
  Size get preferredSize => const Size.fromHeight(82);
  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 1280;
    return AppBar(
      toolbarHeight: 82,
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.white,
      elevation: 0,
      shape: const Border(bottom: BorderSide(color: Color(0xFFE4E9E8))),
      titleSpacing: compact ? 16 : 32,
      title: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: const Color(0xFFE1F3EF),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(Icons.school_rounded, color: Color(0xFF00796B)),
          ),
          const SizedBox(width: 13),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  schoolName,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF172235),
                  ),
                ),
                const Text(
                  'Parent portal',
                  style: TextStyle(fontSize: 12, color: Color(0xFF68778C)),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        if (schoolMemberships.length > 1)
          PopupMenuButton<String>(
            tooltip: 'Switch school',
            initialValue: selectedSchoolId,
            onSelected: onSchoolSelected,
            itemBuilder: (context) => schoolMemberships
                .map(
                  (membership) => PopupMenuItem<String>(
                    value: membership.schoolId,
                    child: Row(
                      children: [
                        Icon(
                          membership.schoolId == selectedSchoolId
                              ? Icons.check_circle
                              : Icons.school_outlined,
                          size: 18,
                          color: const Color(0xFF087F72),
                        ),
                        const SizedBox(width: 10),
                        Text(membership.schoolName),
                      ],
                    ),
                  ),
                )
                .toList(growable: false),
            icon: const Icon(Icons.swap_horiz_rounded),
          ),
        if (!compact && term.isNotEmpty)
          Container(
            margin: const EdgeInsets.symmetric(vertical: 20),
            padding: const EdgeInsets.symmetric(horizontal: 15),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F7F5),
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: const Color(0xFFD7E9E5)),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 16,
                  color: Color(0xFF087F72),
                ),
                const SizedBox(width: 8),
                Text(
                  term,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF2E4B47),
                  ),
                ),
              ],
            ),
          ),
        if (!compact) const SizedBox(width: 14),
        if (compact)
          IconButton(
            key: const Key('guardian-pay-fees'),
            tooltip: 'Pay school fees',
            onPressed: onPayFees,
            icon: const Icon(Icons.payments_outlined),
          )
        else
          FilledButton.icon(
            key: const Key('guardian-pay-fees'),
            onPressed: onPayFees,
            icon: const Icon(Icons.payments_outlined, size: 18),
            label: const Text('Pay school fees'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF087F72),
              minimumSize: const Size(154, 42),
            ),
          ),
        if (!compact) const SizedBox(width: 10),
        if (compact)
          IconButton(
            key: const Key('guardian-refresh'),
            tooltip: 'Refresh',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded),
          )
        else
          OutlinedButton.icon(
            key: const Key('guardian-refresh'),
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('Refresh'),
            style: OutlinedButton.styleFrom(
              foregroundColor: const Color(0xFF087F72),
              minimumSize: const Size(104, 42),
              side: const BorderSide(color: Color(0xFFBDD4CF)),
            ),
          ),
        if (!compact && guardianName.isNotEmpty) ...[
          const SizedBox(width: 14),
          CircleAvatar(
            radius: 20,
            backgroundColor: const Color(0xFFE1F3EF),
            foregroundColor: const Color(0xFF087F72),
            child: Text(
              _initials(guardianName),
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
          ),
        ],
        SizedBox(width: compact ? 8 : 32),
      ],
    );
  }
}

class _ParentDesktopNavigation extends StatelessWidget {
  const _ParentDesktopNavigation({
    required this.selectedIndex,
    required this.onSelected,
    required this.onLogout,
  });
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onLogout;
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      height: 70,
      color: Colors.white,
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE4E9E8))),
        ),
        child: Align(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1280),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Row(
                children: [
                  _DesktopNavItem(
                    key: const Key('guardian-nav-home'),
                    icon: Icons.home_outlined,
                    label: 'Home',
                    selected: selectedIndex == 0,
                    onTap: () => onSelected(0),
                  ),
                  _DesktopNavItem(
                    key: const Key('guardian-nav-fees'),
                    icon: Icons.account_balance_wallet_outlined,
                    label: 'Fees',
                    selected: selectedIndex == 1,
                    onTap: () => onSelected(1),
                  ),
                  _DesktopNavItem(
                    key: const Key('guardian-nav-messages'),
                    icon: Icons.forum_outlined,
                    label: 'Messages',
                    badgeCount: _previewUnreadMessageCount,
                    selected: selectedIndex == 2,
                    onTap: () => onSelected(2),
                  ),
                  _DesktopNavItem(
                    key: const Key('guardian-nav-account'),
                    icon: Icons.person_outline,
                    label: 'My account',
                    selected: selectedIndex == 3,
                    onTap: () => onSelected(3),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    key: const Key('guardian-logout'),
                    onPressed: onLogout,
                    icon: const Icon(Icons.logout_rounded, size: 18),
                    label: const Text('Sign out'),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF566577),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DesktopNavItem extends StatelessWidget {
  const _DesktopNavItem({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.badgeCount = 0,
  });
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final int badgeCount;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Material(
      color: selected ? const Color(0xFFE1F3EF) : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 11),
          child: Row(
            children: [
              Icon(
                icon,
                size: 19,
                color: selected
                    ? const Color(0xFF087F72)
                    : const Color(0xFF566577),
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                  color: selected
                      ? const Color(0xFF087F72)
                      : const Color(0xFF39485A),
                ),
              ),
              if (badgeCount > 0) ...[
                const SizedBox(width: 7),
                _UnreadBadge(
                  key: const Key('guardian-message-count'),
                  count: badgeCount,
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

class _MessageNavIcon extends StatelessWidget {
  const _MessageNavIcon({required this.selected});

  final bool selected;

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      Icon(selected ? Icons.forum : Icons.forum_outlined),
      Positioned(
        top: -7,
        right: -10,
        child: _UnreadBadge(
          key: Key(
            selected
                ? 'guardian-message-count-mobile-selected'
                : 'guardian-message-count-mobile',
          ),
          count: _previewUnreadMessageCount,
        ),
      ),
    ],
  );
}

class _UnreadBadge extends StatelessWidget {
  const _UnreadBadge({super.key, required this.count});

  final int count;

  @override
  Widget build(BuildContext context) => Container(
    height: 20,
    constraints: const BoxConstraints(minWidth: 20),
    padding: const EdgeInsets.symmetric(horizontal: 6),
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: const Color(0xFFD64045),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.white, width: 1.5),
    ),
    child: Text(
      '$count',
      style: const TextStyle(
        color: Colors.white,
        fontSize: 11,
        height: 1,
        fontWeight: FontWeight.w800,
      ),
    ),
  );
}

class _ParentHome extends StatelessWidget {
  const _ParentHome({
    required this.data,
    required this.onOpenFees,
    required this.onOpenChild,
    required this.onOpenMessages,
    required this.onOpenCalendar,
  });
  final GuardianPortalSnapshot data;
  final VoidCallback onOpenFees;
  final ValueChanged<String> onOpenChild;
  final VoidCallback onOpenMessages;
  final VoidCallback onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    // Only show students linked to this guardian by the backend. Preview
    // children made the portal look populated, but they were not authorized
    // records and led to dead-end child workspaces.
    final children = data.children;
    return _PageScroll(
      key: const ValueKey('guardian-family-home'),
      title: 'Hello, ${_firstName(data.guardianName)}',
      subtitle: children.isEmpty
          ? 'Your children will appear here after the school links them.'
          : 'Here is what needs your attention across the family.',
      children: [
        if (children.isEmpty)
          const _EmptyCard(
            icon: Icons.family_restroom_rounded,
            title: 'No children linked yet',
            message:
                'Please ask the school office to link your household to this account.',
          ),
        if (children.isNotEmpty)
          _HouseholdChildrenCard(children: children, onOpenChild: onOpenChild),
        if (children.isNotEmpty)
          _ResponsivePair(
            left: _FamilyFeeSnapshot(
              children: children,
              onOpenFees: onOpenFees,
            ),
            right: _AcademicSnapshot(
              children: children,
              onOpenChild: onOpenChild,
            ),
          ),
        _GuardianUpcomingEvents(
          events: data.calendarEvents,
          onOpenCalendar: onOpenCalendar,
        ),
      ],
    );
  }
}

class _GuardianUpcomingEvents extends StatelessWidget {
  const _GuardianUpcomingEvents({
    required this.events,
    required this.onOpenCalendar,
  });
  final List<GuardianCalendarEvent> events;
  final VoidCallback onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dateOnly = DateTime(today.year, today.month, today.day);
    final upcoming =
        events
            .where((event) {
              final end = _guardianEventDate(event.endDate);
              return end == null || !end.isBefore(dateOnly);
            })
            .toList(growable: false)
          ..sort(_compareGuardianEvents);
    final visible = upcoming.take(3).toList(growable: false);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE1F3EF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.event_outlined,
                  color: Color(0xFF087F72),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Upcoming events',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      'Important dates from the school calendar.',
                      style: TextStyle(color: Color(0xFF68778C), fontSize: 12),
                    ),
                  ],
                ),
              ),
              TextButton(
                key: const Key('guardian-open-calendar'),
                onPressed: onOpenCalendar,
                child: const Text('View calendar'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (visible.isEmpty)
            InkWell(
              onTap: onOpenCalendar,
              borderRadius: BorderRadius.circular(13),
              child: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.event_available_outlined,
                      color: Color(0xFF8793A4),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'No upcoming events have been added.',
                        style: TextStyle(color: Color(0xFF68778C)),
                      ),
                    ),
                    Icon(Icons.chevron_right_rounded, color: Color(0xFF8793A4)),
                  ],
                ),
              ),
            )
          else
            for (var index = 0; index < visible.length; index++) ...[
              _GuardianEventRow(event: visible[index], onTap: onOpenCalendar),
              if (index != visible.length - 1)
                const Divider(height: 1, color: Color(0xFFE4E9E8)),
            ],
        ],
      ),
    );
  }
}

class _GuardianCalendarPage extends StatefulWidget {
  const _GuardianCalendarPage({required this.data, required this.onBack});
  final GuardianPortalSnapshot data;
  final VoidCallback onBack;

  @override
  State<_GuardianCalendarPage> createState() => _GuardianCalendarPageState();
}

class _GuardianCalendarPageState extends State<_GuardianCalendarPage> {
  bool showAll = false;

  @override
  Widget build(BuildContext context) {
    final today = DateTime.now();
    final dateOnly = DateTime(today.year, today.month, today.day);
    final events =
        widget.data.calendarEvents
            .where((event) {
              if (showAll) return true;
              final end = _guardianEventDate(event.endDate);
              return end == null || !end.isBefore(dateOnly);
            })
            .toList(growable: false)
          ..sort(_compareGuardianEvents);
    return _PageScroll(
      key: const ValueKey('guardian-school-calendar'),
      title: 'School calendar',
      subtitle:
          '${widget.data.termName} · ${widget.data.academicYear} · Read-only',
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('guardian-calendar-back'),
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back to family home'),
          ),
        ),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              LayoutBuilder(
                builder: (context, constraints) {
                  final heading = const Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Term events',
                        style: TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Events and non-school days published by the school.',
                        style: TextStyle(color: Color(0xFF68778C)),
                      ),
                    ],
                  );
                  final filter = SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment(value: false, label: Text('Upcoming')),
                      ButtonSegment(value: true, label: Text('All term')),
                    ],
                    selected: {showAll},
                    onSelectionChanged: (value) =>
                        setState(() => showAll = value.first),
                  );
                  if (constraints.maxWidth < 620) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [heading, const SizedBox(height: 14), filter],
                    );
                  }
                  return Row(
                    children: [
                      Expanded(child: heading),
                      filter,
                    ],
                  );
                },
              ),
              const SizedBox(height: 18),
              if (events.isEmpty)
                const _InlineEmptyState(
                  icon: Icons.event_available_outlined,
                  title: 'No calendar events to show',
                  message: 'Events published by the school will appear here.',
                )
              else
                for (var index = 0; index < events.length; index++) ...[
                  _GuardianCalendarEventCard(event: events[index]),
                  if (index != events.length - 1) const SizedBox(height: 10),
                ],
            ],
          ),
        ),
      ],
    );
  }
}

class _GuardianEventRow extends StatelessWidget {
  const _GuardianEventRow({required this.event, required this.onTap});
  final GuardianCalendarEvent event;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 11),
      child: Row(
        children: [
          _GuardianEventDateBox(date: event.startDate),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title.isEmpty ? 'School event' : event.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  _guardianEventSummary(event),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF68778C),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right_rounded, color: Color(0xFF8793A4)),
        ],
      ),
    ),
  );
}

class _GuardianCalendarEventCard extends StatelessWidget {
  const _GuardianCalendarEventCard({required this.event});
  final GuardianCalendarEvent event;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: const Color(0xFFF7FAF9),
      border: Border.all(color: const Color(0xFFE0E9E7)),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _GuardianEventDateBox(date: event.startDate),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 6,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(
                    event.title.isEmpty ? 'School event' : event.title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (event.category.isNotEmpty)
                    _HealthStatusChip(
                      label: event.category,
                      color: const Color(0xFF087F72),
                    ),
                  if (!event.schoolDay)
                    const _HealthStatusChip(
                      label: 'No school',
                      color: Color(0xFFD97706),
                    ),
                ],
              ),
              const SizedBox(height: 7),
              Text(
                _guardianEventDateRange(event),
                style: const TextStyle(
                  color: Color(0xFF087F72),
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (event.description.isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(
                  event.description,
                  style: const TextStyle(color: Color(0xFF68778C), height: 1.4),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

class _GuardianEventDateBox extends StatelessWidget {
  const _GuardianEventDateBox({required this.date});
  final String date;

  @override
  Widget build(BuildContext context) {
    final parsed = _guardianEventDate(date);
    return Container(
      width: 50,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFE1F3EF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            parsed == null ? '—' : '${parsed.day}'.padLeft(2, '0'),
            style: const TextStyle(
              color: Color(0xFF087F72),
              fontSize: 17,
              fontWeight: FontWeight.w900,
            ),
          ),
          Text(
            parsed == null ? '' : _guardianShortMonth(parsed.month),
            style: const TextStyle(
              color: Color(0xFF4E6D68),
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

DateTime? _guardianEventDate(String value) {
  final parts = value.split('-');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  return DateTime(year, month, day);
}

int _compareGuardianEvents(
  GuardianCalendarEvent left,
  GuardianCalendarEvent right,
) {
  final leftDate = _guardianEventDate(left.startDate);
  final rightDate = _guardianEventDate(right.startDate);
  if (leftDate == null && rightDate == null) {
    return left.title.compareTo(right.title);
  }
  if (leftDate == null) return 1;
  if (rightDate == null) return -1;
  return leftDate.compareTo(rightDate);
}

String _guardianEventSummary(GuardianCalendarEvent event) {
  final parts = <String>[
    if (event.category.isNotEmpty) event.category,
    _guardianEventDateRange(event),
  ];
  return parts.join(' · ');
}

String _guardianEventDateRange(GuardianCalendarEvent event) {
  final start = _guardianFriendlyDate(event.startDate);
  final end = _guardianFriendlyDate(event.endDate);
  final dates = end.isEmpty || end == start ? start : '$start – $end';
  final times = [
    if (event.startTime.isNotEmpty) _guardianFriendlyTime(event.startTime),
    if (event.endTime.isNotEmpty) _guardianFriendlyTime(event.endTime),
  ].join(' – ');
  return [if (dates.isNotEmpty) dates, if (times.isNotEmpty) times].join(' · ');
}

String _guardianFriendlyDate(String value) {
  final parsed = _guardianEventDate(value);
  if (parsed == null) return value;
  return '${parsed.day} ${_guardianShortMonth(parsed.month)} ${parsed.year}';
}

String _guardianFriendlyTime(String value) {
  final parts = value.split(':');
  if (parts.length < 2) return value;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return value;
  final suffix = hour >= 12 ? 'PM' : 'AM';
  final displayHour = hour % 12 == 0 ? 12 : hour % 12;
  return '$displayHour:${minute.toString().padLeft(2, '0')} $suffix';
}

String _guardianShortMonth(int month) {
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return month >= 1 && month <= 12 ? months[month - 1] : '';
}

class _HouseholdChildrenCard extends StatelessWidget {
  const _HouseholdChildrenCard({
    required this.children,
    required this.onOpenChild,
  });

  final List<GuardianChildSummary> children;
  final ValueChanged<String> onOpenChild;

  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Your children',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 5),
        const Text(
          'Select a child to view their complete school information.',
          style: TextStyle(color: Color(0xFF68778C)),
        ),
        const SizedBox(height: 18),
        LayoutBuilder(
          builder: (context, constraints) {
            final columns = constraints.maxWidth >= 980
                ? 3
                : constraints.maxWidth >= 620
                ? 2
                : 1;
            final width =
                (constraints.maxWidth - ((columns - 1) * 12)) / columns;
            return Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final child in children)
                  SizedBox(
                    width: width,
                    child: _HouseholdChildTile(
                      child: child,
                      onTap: () => onOpenChild(child.studentId),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _HouseholdChildTile extends StatelessWidget {
  const _HouseholdChildTile({required this.child, required this.onTap});
  final GuardianChildSummary child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: const Color(0xFFF7FAF9),
    borderRadius: BorderRadius.circular(16),
    child: InkWell(
      key: Key('home-open-child-${child.studentId}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 27,
              backgroundColor: const Color(0xFFE1F3EF),
              foregroundColor: const Color(0xFF087F72),
              child: Text(
                _initials(child.name),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    child.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    child.className,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Color(0xFF68778C)),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    child.termAverage == null
                        ? 'No released results yet'
                        : 'Term average ${child.termAverage!.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      color: Color(0xFF087F72),
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF8793A4)),
          ],
        ),
      ),
    ),
  );
}

class _FamilyFeeSnapshot extends StatelessWidget {
  const _FamilyFeeSnapshot({required this.children, required this.onOpenFees});
  final List<GuardianChildSummary> children;
  final VoidCallback onOpenFees;

  @override
  Widget build(BuildContext context) {
    final balance = children.fold<double>(
      0,
      (total, child) => total + child.balance,
    );
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'Family fees',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
              ),
              TextButton(onPressed: onOpenFees, child: const Text('View')),
            ],
          ),
          const SizedBox(height: 10),
          _SimpleLine(label: 'Balance', value: _money(balance)),
          const SizedBox(height: 4),
          const Text(
            'Open family fees for the complete breakdown and payment history.',
            style: TextStyle(color: Color(0xFF68778C), height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _AcademicSnapshot extends StatelessWidget {
  const _AcademicSnapshot({required this.children, required this.onOpenChild});
  final List<GuardianChildSummary> children;
  final ValueChanged<String> onOpenChild;

  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Academic snapshot',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        for (final child in children)
          InkWell(
            onTap: () => onOpenChild(child.studentId),
            child: _SimpleLine(
              label: child.name,
              value: child.termAverage == null
                  ? 'No released results'
                  : '${child.termAverage!.toStringAsFixed(0)}% term average',
            ),
          ),
      ],
    ),
  );
}

// Retained only while the school messaging/homework aggregate API is pending.
// ignore: unused_element
class _HouseholdHomework extends StatelessWidget {
  const _HouseholdHomework({required this.children, required this.onOpenChild});
  final List<GuardianChildSummary> children;
  final ValueChanged<String> onOpenChild;

  @override
  Widget build(BuildContext context) {
    final items = [
      (
        child: children[1 % children.length],
        title: 'English reading log',
        due: 'Due today',
      ),
      (
        child: children.first,
        title: 'Mathematics exercise',
        due: 'Due tomorrow',
      ),
      (child: children.last, title: 'Creative Arts project', due: 'Due Friday'),
    ];
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Homework coming up',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < items.length; index++) ...[
            ListTile(
              key: Key('homework-${items[index].child.studentId}-$index'),
              contentPadding: EdgeInsets.zero,
              title: Text(items[index].title),
              subtitle: Text(items[index].child.name),
              trailing: Text(
                items[index].due,
                style: TextStyle(
                  color: index == 0
                      ? const Color(0xFFD14343)
                      : const Color(0xFF68778C),
                  fontWeight: FontWeight.w800,
                ),
              ),
              onTap: () => onOpenChild(items[index].child.studentId),
            ),
            if (index != items.length - 1)
              const Divider(height: 1, color: Color(0xFFE4E9E8)),
          ],
        ],
      ),
    );
  }
}

// Retained only while the school announcements API is pending.
// ignore: unused_element
class _LatestAnnouncement extends StatelessWidget {
  const _LatestAnnouncement({required this.onOpenMessages});
  final VoidCallback onOpenMessages;

  @override
  Widget build(BuildContext context) => _Card(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFFFF3DF),
            borderRadius: BorderRadius.circular(13),
          ),
          child: const Icon(Icons.campaign_outlined, color: Color(0xFFD97706)),
        ),
        const SizedBox(width: 14),
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Parent meeting on Friday',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 5),
              Text(
                'All parents are invited at 3:00 PM in the school hall.',
                style: TextStyle(color: Color(0xFF68778C), height: 1.4),
              ),
            ],
          ),
        ),
        TextButton(onPressed: onOpenMessages, child: const Text('View all')),
      ],
    ),
  );
}

// Kept for reconnecting the API-backed family balance layout.
// ignore: unused_element
class _FamilyBalanceCard extends StatelessWidget {
  const _FamilyBalanceCard({
    required this.children,
    required this.onOpenFees,
    required this.onOpenChildFees,
  });

  final List<GuardianChildSummary> children;
  final VoidCallback onOpenFees;
  final ValueChanged<String> onOpenChildFees;

  @override
  Widget build(BuildContext context) {
    final netBalance = children.fold<double>(
      0,
      (total, child) => total + child.balance,
    );
    const status = 'Family balance';
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      status,
                      style: const TextStyle(color: Color(0xFF68778C)),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      _money(netBalance),
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton.icon(
                onPressed: onOpenFees,
                icon: const Icon(Icons.arrow_forward_rounded, size: 18),
                label: const Text('View all fees'),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 18),
            child: Divider(height: 1, color: Color(0xFFE4E9E8)),
          ),
          const Text(
            'Balance by child',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          for (var index = 0; index < children.length; index++) ...[
            _FamilyBalanceRow(
              child: children[index],
              onTap: () => onOpenChildFees(children[index].studentId),
            ),
            if (index != children.length - 1)
              const Divider(height: 1, color: Color(0xFFE4E9E8)),
          ],
        ],
      ),
    );
  }
}

class _FamilyBalanceRow extends StatelessWidget {
  const _FamilyBalanceRow({required this.child, required this.onTap});
  final GuardianChildSummary child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final label = child.balance == 0 ? 'Fully paid' : _money(child.balance);
    final color = child.balance > 0
        ? const Color(0xFFD97706)
        : const Color(0xFF087F72);
    return InkWell(
      key: Key('home-child-fees-${child.studentId}'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 13),
        child: Row(
          children: [
            CircleAvatar(
              radius: 21,
              backgroundColor: const Color(0xFFE1F3EF),
              foregroundColor: const Color(0xFF087F72),
              child: Text(
                _initials(child.name),
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    child.name,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    child.className,
                    style: const TextStyle(
                      color: Color(0xFF68778C),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              label,
              style: TextStyle(fontWeight: FontWeight.w900, color: color),
            ),
            const SizedBox(width: 5),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFF8793A4)),
          ],
        ),
      ),
    );
  }
}

// Kept temporarily while the dummy-data flow is reviewed; the API-connected
// child picker will be reused when the backend is reconnected.
// ignore: unused_element
class _ChildSelector extends StatelessWidget {
  const _ChildSelector({
    required this.children,
    required this.selectedIndex,
    required this.onSelected,
  });

  final List<GuardianChildSummary> children;
  final int selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      for (var index = 0; index < children.length; index++)
        ChoiceChip(
          selected: selectedIndex == index,
          onSelected: (_) => onSelected(index),
          avatar: CircleAvatar(
            backgroundColor: Colors.white,
            child: Text(
              _initials(children[index].name),
              style: const TextStyle(
                color: Color(0xFF087F72),
                fontSize: 11,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
          label: Text(children[index].name),
        ),
    ],
  );
}

class _RecentFeePayments extends StatelessWidget {
  const _RecentFeePayments();

  static const payments = [
    (
      amount: 'GH₵ 635',
      date: '9 Aug 2026',
      method: 'Cash',
      receipt: 'RCPT-20260809-002',
    ),
    (
      amount: 'GH₵ 400',
      date: '21 Jul 2026',
      method: 'Mobile Money',
      receipt: 'RCPT-20260721-014',
    ),
    (
      amount: 'GH₵ 250',
      date: '3 May 2026',
      method: 'Bank deposit',
      receipt: 'RCPT-20260503-006',
    ),
  ];

  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Text(
                'Recent fee payments',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (var index = 0; index < payments.length; index++) ...[
          _RecentPaymentRow(payment: payments[index]),
          if (index != payments.length - 1)
            const Divider(height: 1, color: Color(0xFFE4E9E8)),
        ],
      ],
    ),
  );
}

class _RecentPaymentRow extends StatelessWidget {
  const _RecentPaymentRow({required this.payment});

  final ({String amount, String date, String method, String receipt}) payment;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: Row(
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: const Color(0xFFE5F5F1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.check_rounded, color: Color(0xFF087F72)),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                payment.amount,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                '${payment.date} · ${payment.method}',
                style: const TextStyle(color: Color(0xFF68778C), fontSize: 13),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Text(
          payment.receipt,
          textAlign: TextAlign.end,
          style: const TextStyle(color: Color(0xFF68778C), fontSize: 12),
        ),
      ],
    ),
  );
}

// Kept for reconnecting the API-backed quick-action layout.
// ignore: unused_element
class _GuardianQuickActions extends StatelessWidget {
  const _GuardianQuickActions({
    required this.onOpenAcademics,
    required this.onOpenFees,
    required this.onOpenMessages,
    required this.onOpenAccount,
  });
  final VoidCallback onOpenAcademics;
  final VoidCallback onOpenFees;
  final VoidCallback onOpenMessages;
  final VoidCallback onOpenAccount;

  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Quick actions',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 15),
        LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 680;
            final width = compact
                ? (constraints.maxWidth - 10) / 2
                : (constraints.maxWidth - 30) / 4;
            return Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                _QuickAction(
                  width: width,
                  icon: Icons.menu_book_outlined,
                  label: 'Academics',
                  onTap: onOpenAcademics,
                ),
                _QuickAction(
                  width: width,
                  icon: Icons.payments_outlined,
                  label: 'Pay fees',
                  onTap: onOpenFees,
                ),
                _QuickAction(
                  width: width,
                  icon: Icons.forum_outlined,
                  label: 'Message school',
                  onTap: onOpenMessages,
                ),
                _QuickAction(
                  width: width,
                  icon: Icons.manage_accounts_outlined,
                  label: 'My details',
                  onTap: onOpenAccount,
                ),
              ],
            );
          },
        ),
      ],
    ),
  );
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({
    required this.width,
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final double width;
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: Material(
      color: const Color(0xFFF7FAF9),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 15),
          child: Row(
            children: [
              Icon(icon, size: 20, color: const Color(0xFF087F72)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

class _ResponsivePair extends StatelessWidget {
  const _ResponsivePair({required this.left, required this.right});
  final Widget left;
  final Widget right;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      if (constraints.maxWidth < 720) {
        return Column(children: [left, const SizedBox(height: 18), right]);
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: left),
          const SizedBox(width: 18),
          Expanded(child: right),
        ],
      );
    },
  );
}

class _HomeInfoPanel extends StatelessWidget {
  const _HomeInfoPanel({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => _Card(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: const Color(0xFFEAF4F2),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(icon, color: const Color(0xFF087F72)),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 5),
              Text(
                message,
                style: const TextStyle(color: Color(0xFF68778C), height: 1.4),
              ),
              if (actionLabel != null && onAction != null) ...[
                const SizedBox(height: 10),
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: const Size(0, 34),
                  ),
                  child: Text(actionLabel!),
                ),
              ],
            ],
          ),
        ),
      ],
    ),
  );
}

// ignore: unused_element
class _ChildCard extends StatelessWidget {
  const _ChildCard({
    required this.child,
    required this.api,
    required this.onOpenFees,
    required this.onOpenAcademics,
  });
  final GuardianChildSummary child;
  final GuardianPortalApiClient api;
  final VoidCallback onOpenFees;
  final VoidCallback onOpenAcademics;
  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: const Color(0xFFE1F3EF),
                  borderRadius: BorderRadius.circular(17),
                ),
                alignment: Alignment.center,
                child: Text(
                  _initials(child.name),
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                    color: Color(0xFF087F72),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.name,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      child.className,
                      style: const TextStyle(color: Color(0xFF68778C)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 20),
            child: Divider(height: 1, color: Color(0xFFE4E9E8)),
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final tiles = [
                _StatusTile(
                  icon: Icons.account_balance_wallet_outlined,
                  label: 'Fee balance',
                  value: _money(child.balance),
                  color: child.balance > 0
                      ? const Color(0xFFD97706)
                      : const Color(0xFF087F72),
                  onTap: onOpenFees,
                ),
                _StatusTile(
                  icon: Icons.calendar_month_outlined,
                  label: 'Attendance this term',
                  value: child.attendanceDays == 0
                      ? 'No records yet'
                      : '${child.attendancePercentage.toStringAsFixed(0)}%',
                  color: const Color(0xFF356AE6),
                  onTap: () => _showAttendance(context, api, child),
                ),
                _StatusTile(
                  icon: Icons.description_outlined,
                  label: 'Report card',
                  value: child.reportPublished && child.reportCurrent
                      ? 'Ready to view'
                      : child.reportPublished
                      ? 'Being updated'
                      : 'Not published yet',
                  color: child.reportPublished && child.reportCurrent
                      ? const Color(0xFF087F72)
                      : const Color(0xFF68778C),
                  onTap: onOpenAcademics,
                ),
              ];
              if (constraints.maxWidth < 720) {
                return Column(
                  children:
                      tiles
                          .expand((tile) => [tile, const SizedBox(height: 10)])
                          .toList()
                        ..removeLast(),
                );
              }
              return Row(
                children:
                    tiles
                        .expand(
                          (tile) => [
                            Expanded(child: tile),
                            const SizedBox(width: 12),
                          ],
                        )
                        .toList()
                      ..removeLast(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _StatusTile extends StatelessWidget {
  const _StatusTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(16),
    child: Container(
      constraints: const BoxConstraints(minHeight: 92),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 15),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFA),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE1E7E5)),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, size: 21, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF68778C),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w800, color: color),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.chevron_right_rounded,
            size: 20,
            color: Color(0xFF8793A4),
          ),
        ],
      ),
    ),
  );
}

// ignore: unused_element
class _ParentChildren extends StatelessWidget {
  const _ParentChildren({
    required this.data,
    required this.api,
    required this.onOpenAcademics,
    required this.onOpenFees,
  });
  final GuardianPortalSnapshot data;
  final GuardianPortalApiClient api;
  final VoidCallback onOpenAcademics;
  final VoidCallback onOpenFees;

  @override
  Widget build(BuildContext context) => _PageScroll(
    title: 'My children',
    subtitle:
        'View each child’s school information and the guardians connected to your household.',
    children: [
      if (data.children.isEmpty)
        const _EmptyCard(
          icon: Icons.family_restroom_outlined,
          title: 'No children linked yet',
          message:
              'Please ask the school office to connect your household to this account.',
        ),
      for (final child in data.children)
        _ChildDetailCard(
          child: child,
          guardianName: data.guardianName,
          api: api,
          onOpenAcademics: onOpenAcademics,
          onOpenFees: onOpenFees,
        ),
    ],
  );
}

class _ChildDetailCard extends StatelessWidget {
  const _ChildDetailCard({
    required this.child,
    required this.guardianName,
    required this.api,
    required this.onOpenAcademics,
    required this.onOpenFees,
  });
  final GuardianChildSummary child;
  final String guardianName;
  final GuardianPortalApiClient api;
  final VoidCallback onOpenAcademics;
  final VoidCallback onOpenFees;

  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: const Color(0xFFE1F3EF),
              foregroundColor: const Color(0xFF087F72),
              child: Text(
                _initials(child.name),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    child.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${child.className} · ${child.studentId}',
                    style: const TextStyle(color: Color(0xFF68778C)),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Divider(height: 32),
        _ResponsivePair(
          left: _ChildDetailSection(
            title: 'School information',
            children: [
              _DetailLine(label: 'Grade and stream', value: child.className),
              _DetailLine(label: 'Student ID', value: child.studentId),
              _DetailLine(
                label: 'Attendance',
                value: child.attendanceDays == 0
                    ? 'No records this term'
                    : '${child.attendancePercentage.toStringAsFixed(0)}% this term',
              ),
            ],
          ),
          right: _ChildDetailSection(
            title: 'Guardians',
            children: [
              _DetailLine(label: guardianName, value: 'Signed-in guardian'),
              const _DetailLine(
                label: 'Other approved guardians',
                value: 'None shared by the school',
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            FilledButton.icon(
              onPressed: onOpenAcademics,
              icon: const Icon(Icons.menu_book_outlined),
              label: const Text('View academics'),
            ),
            OutlinedButton.icon(
              onPressed: onOpenFees,
              icon: const Icon(Icons.account_balance_wallet_outlined),
              label: const Text('View fees'),
            ),
            OutlinedButton.icon(
              onPressed: () => _showAttendance(context, api, child),
              icon: const Icon(Icons.calendar_month_outlined),
              label: const Text('Attendance'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        const Text(
          'To correct a child’s official information or guardian access, contact the school office.',
          style: TextStyle(color: Color(0xFF68778C), fontSize: 12, height: 1.4),
        ),
      ],
    ),
  );
}

class _ChildDetailSection extends StatelessWidget {
  const _ChildDetailSection({required this.title, required this.children});
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFA),
      borderRadius: BorderRadius.circular(15),
      border: Border.all(color: const Color(0xFFE3E9E7)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),
        ...children,
      ],
    ),
  );
}

class _DetailLine extends StatelessWidget {
  const _DetailLine({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(
              color: Color(0xFF68778C),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ParentChildWorkspace extends StatefulWidget {
  const _ParentChildWorkspace({
    required this.data,
    required this.child,
    required this.api,
    required this.onBack,
  });

  final GuardianPortalSnapshot data;
  final GuardianChildSummary child;
  final GuardianPortalApiClient api;
  final VoidCallback onBack;

  @override
  State<_ParentChildWorkspace> createState() => _ParentChildWorkspaceState();
}

class _ParentChildWorkspaceState extends State<_ParentChildWorkspace> {
  int section = 0;

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    return _PageScroll(
      key: ValueKey('guardian-child-${child.studentId}'),
      title: child.name,
      subtitle:
          '${child.className} · ${child.studentId} · ${widget.data.termName} ${widget.data.academicYear}',
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('child-workspace-back'),
            onPressed: widget.onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back to family home'),
          ),
        ),
        _ChildWorkspaceTabs(
          selected: section,
          onSelected: (value) => setState(() => section = value),
        ),
        switch (section) {
          0 => _ChildWorkspaceOverview(
            child: child,
            api: widget.api,
            onOpenSection: (value) => setState(() => section = value),
          ),
          1 => _PreviewScores(child: child, api: widget.api),
          2 => _PreviewHomework(child: child, api: widget.api),
          3 => const _AcademicEmptySection(
            icon: Icons.calendar_view_week_outlined,
            title: 'No timetable published',
            message:
                'The weekly timetable will appear here after the school publishes it for guardians.',
          ),
          4 => _ChildAttendancePanel(child: child, api: widget.api),
          5 => _GuardianReportsPanel(
            data: widget.data,
            child: child,
            api: widget.api,
          ),
          6 => _GuardianRequiredItemsPanel(child: child, api: widget.api),
          _ => _ChildPersonalDetails(child: child, api: widget.api),
        },
      ],
    );
  }
}

class _ChildWorkspaceTabs extends StatelessWidget {
  const _ChildWorkspaceTabs({required this.selected, required this.onSelected});
  final int selected;
  final ValueChanged<int> onSelected;

  static const tabs = [
    ('Overview', Icons.dashboard_outlined),
    ('Academics', Icons.auto_stories_outlined),
    ('Homework', Icons.task_alt_outlined),
    ('Timetable', Icons.calendar_view_week_outlined),
    ('Attendance', Icons.fact_check_outlined),
    ('Report cards', Icons.description_outlined),
    ('Items to bring', Icons.inventory_2_outlined),
    ('Child details', Icons.badge_outlined),
  ];

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (var index = 0; index < tabs.length; index++) ...[
          ChoiceChip(
            key: Key('child-tab-$index'),
            selected: selected == index,
            onSelected: (_) => onSelected(index),
            avatar: Icon(tabs[index].$2, size: 17),
            label: Text(tabs[index].$1),
          ),
          if (index != tabs.length - 1) const SizedBox(width: 8),
        ],
      ],
    ),
  );
}

class _ChildWorkspaceOverview extends StatelessWidget {
  const _ChildWorkspaceOverview({
    required this.child,
    required this.api,
    required this.onOpenSection,
  });
  final GuardianChildSummary child;
  final GuardianPortalApiClient api;
  final ValueChanged<int> onOpenSection;

  @override
  Widget build(BuildContext context) => FutureBuilder<GuardianAcademicData>(
    future: api.academics(child.studentId),
    builder: (context, result) {
      final academics = result.data;
      final pendingWork =
          academics?.activities
              .where(
                (item) =>
                    item.status == 'UPCOMING' || item.status == 'DUE_TODAY',
              )
              .length ??
          0;
      return Column(
        children: [
          if (pendingWork > 0 || !child.reportPublished)
            _OverviewAttentionCard(
              reportPublished: child.reportPublished,
              pendingWork: pendingWork,
              onOpenHomework: () => onOpenSection(2),
              onOpenReports: () => onOpenSection(5),
            ),
          if (pendingWork > 0 || !child.reportPublished)
            const SizedBox(height: 18),
          _ResponsivePair(
            left: const _AcademicEmptySection(
              icon: Icons.calendar_view_week_outlined,
              title: 'Timetable not available yet',
              message:
                  'The school has not published a guardian timetable for this class.',
            ),
            right: _OverviewAttendanceCard(
              child: child,
              onOpenAttendance: () => onOpenSection(4),
            ),
          ),
          const SizedBox(height: 18),
          if (result.connectionState == ConnectionState.waiting)
            const _Card(child: Center(child: CircularProgressIndicator()))
          else if (result.hasError)
            const _EmptyCard(
              icon: Icons.school_outlined,
              title: 'Learning progress unavailable',
              message: 'Refresh the portal and try again.',
            )
          else
            _OverviewLearningCard(
              subjects: academics?.subjects ?? const [],
              onOpenAcademics: () => onOpenSection(1),
            ),
        ],
      );
    },
  );
}

class _OverviewAttentionCard extends StatelessWidget {
  const _OverviewAttentionCard({
    required this.reportPublished,
    required this.pendingWork,
    required this.onOpenHomework,
    required this.onOpenReports,
  });
  final bool reportPublished;
  final int pendingWork;
  final VoidCallback onOpenHomework;
  final VoidCallback onOpenReports;

  @override
  Widget build(BuildContext context) => _Card(
    color: const Color(0xFFFFF8E8),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.notifications_active_outlined, color: Color(0xFFD97706)),
            SizedBox(width: 9),
            Expanded(
              child: Text(
                'Needs your attention',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (pendingWork > 0)
          _OverviewActionRow(
            title:
                '$pendingWork ${pendingWork == 1 ? 'activity is' : 'activities are'} due or coming up',
            action: 'View homework',
            onTap: onOpenHomework,
          ),
        if (!reportPublished)
          _OverviewActionRow(
            title: 'Current-term report card is not published yet',
            action: 'View reports',
            onTap: onOpenReports,
          ),
      ],
    ),
  );
}

class _OverviewActionRow extends StatelessWidget {
  const _OverviewActionRow({
    required this.title,
    required this.action,
    required this.onTap,
  });
  final String title;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 4),
    child: Row(
      children: [
        const Icon(Icons.circle, size: 7, color: Color(0xFFD97706)),
        const SizedBox(width: 9),
        Expanded(child: Text(title)),
        TextButton(onPressed: onTap, child: Text(action)),
      ],
    ),
  );
}

// ignore: unused_element
class _OverviewTodayCard extends StatelessWidget {
  const _OverviewTodayCard({required this.onOpenTimetable});
  final VoidCallback onOpenTimetable;

  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Today at school',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 12),
        const _SimpleLine(label: 'Next class', value: 'Mathematics · 10:00 AM'),
        const _SimpleLine(label: 'Classes today', value: '4 subjects'),
        const _SimpleLine(label: 'School closes', value: '3:00 PM'),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onOpenTimetable,
            icon: const Icon(Icons.calendar_view_week_outlined, size: 18),
            label: const Text('View timetable'),
          ),
        ),
      ],
    ),
  );
}

class _OverviewAttendanceCard extends StatelessWidget {
  const _OverviewAttendanceCard({
    required this.child,
    required this.onOpenAttendance,
  });
  final GuardianChildSummary child;
  final VoidCallback onOpenAttendance;

  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Attendance this term',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 10),
        Text(
          child.attendanceDays == 0
              ? 'No attendance has been recorded yet.'
              : '${child.attendancePercentage.toStringAsFixed(0)}% attendance',
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: Color(0xFF356AE6),
          ),
        ),
        const SizedBox(height: 10),
        _SimpleLine(label: 'Present', value: '${child.presentDays} days'),
        _SimpleLine(label: 'Absent', value: '${child.absentDays} days'),
        _SimpleLine(label: 'Late', value: '${child.lateDays} days'),
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: onOpenAttendance,
            icon: const Icon(Icons.fact_check_outlined, size: 18),
            label: const Text('View attendance'),
          ),
        ),
      ],
    ),
  );
}

class _OverviewLearningCard extends StatelessWidget {
  const _OverviewLearningCard({
    required this.subjects,
    required this.onOpenAcademics,
  });
  final List<GuardianSubjectPerformance> subjects;
  final VoidCallback onOpenAcademics;

  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Current learning progress',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  SizedBox(height: 3),
                  Text(
                    'Based on released exercises and assessments.',
                    style: TextStyle(color: Color(0xFF68778C)),
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: onOpenAcademics,
              child: const Text('See all'),
            ),
          ],
        ),
        const SizedBox(height: 8),
        if (subjects.isEmpty)
          const Text(
            'No released scores are available for this term yet.',
            style: TextStyle(color: Color(0xFF68778C)),
          )
        else
          for (final subject in subjects)
            if (subject.currentAverage != null)
              _SubjectPerformanceRow(
                subject: subject.subjectName,
                score: subject.currentAverage!,
              ),
      ],
    ),
  );
}

class _ChildAttendancePanel extends StatefulWidget {
  const _ChildAttendancePanel({required this.child, required this.api});
  final GuardianChildSummary child;
  final GuardianPortalApiClient api;

  @override
  State<_ChildAttendancePanel> createState() => _ChildAttendancePanelState();
}

class _ChildAttendancePanelState extends State<_ChildAttendancePanel> {
  int page = 0;
  late Future<List<GuardianAttendanceItem>> records;

  @override
  void initState() {
    super.initState();
    records = widget.api.attendance(widget.child.studentId);
  }

  void retry() => setState(() {
    page = 0;
    records = widget.api.attendance(widget.child.studentId);
  });

  @override
  Widget build(BuildContext context) {
    final child = widget.child;
    final rate = child.attendanceDays == 0
        ? 0.0
        : child.attendancePercentage / 100;
    return Column(
      children: [
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Attendance this term',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              const Text(
                'A clear summary of attendance and recent daily records.',
                style: TextStyle(color: Color(0xFF68778C)),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  SizedBox(
                    width: 92,
                    height: 92,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        SizedBox.expand(
                          child: CircularProgressIndicator(
                            value: rate,
                            strokeWidth: 9,
                            backgroundColor: const Color(0xFFE7EEEC),
                            color: const Color(0xFF087F72),
                          ),
                        ),
                        Text(
                          '${child.attendancePercentage.toStringAsFixed(0)}%',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 28),
                  Expanded(
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _AttendanceStat(
                          label: 'Present',
                          value: child.presentDays,
                          color: const Color(0xFF087F72),
                        ),
                        _AttendanceStat(
                          label: 'Late',
                          value: child.lateDays,
                          color: const Color(0xFFD97706),
                        ),
                        _AttendanceStat(
                          label: 'Absent',
                          value: child.absentDays,
                          color: const Color(0xFFD14343),
                        ),
                        _AttendanceStat(
                          label: 'Excused',
                          value: child.excusedDays,
                          color: const Color(0xFF356AE6),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        FutureBuilder<List<GuardianAttendanceItem>>(
          future: records,
          builder: (context, result) {
            if (result.connectionState == ConnectionState.waiting) {
              return const _Card(
                child: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                ),
              );
            }
            if (result.hasError) {
              return _EmptyCard(
                icon: Icons.cloud_off_outlined,
                title: 'Attendance history could not be loaded',
                message: _errorText(result.error),
                actionLabel: 'Try again',
                onAction: retry,
              );
            }
            final items = result.data ?? const <GuardianAttendanceItem>[];
            if (items.isEmpty) {
              return const _EmptyCard(
                icon: Icons.fact_check_outlined,
                title: 'No daily attendance records yet',
                message:
                    'Attendance entries will appear here after the school takes the register.',
              );
            }
            final pageCount = (items.length / 4).ceil();
            final safePage = page.clamp(0, pageCount - 1);
            final visible = items.skip(safePage * 4).take(4).toList();
            return _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Daily attendance history',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 10),
                  for (final record in visible)
                    _AttendanceHistoryRow(
                      date: _friendlyDate(record.date),
                      status: _attendanceLabel(record.status),
                      note: record.note.isNotEmpty
                          ? record.note
                          : record.minutesLate > 0
                          ? '${record.minutesLate} minutes late'
                          : '',
                    ),
                  if (pageCount > 1)
                    _ListPager(
                      page: safePage,
                      pageCount: pageCount,
                      onChanged: (value) => setState(() => page = value),
                    ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

class _AttendanceHistoryRow extends StatelessWidget {
  const _AttendanceHistoryRow({
    required this.date,
    required this.status,
    required this.note,
  });

  final String date;
  final String status;
  final String note;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'Present' => const Color(0xFF087F72),
      'Late' => const Color(0xFFD97706),
      'Absent' => const Color(0xFFD14343),
      _ => const Color(0xFF356AE6),
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE7ECEB))),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              date,
              style: const TextStyle(fontWeight: FontWeight.w700),
            ),
          ),
          if (note.isNotEmpty)
            Expanded(
              child: Text(
                note,
                style: const TextStyle(color: Color(0xFF68778C), fontSize: 13),
              ),
            ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .09),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AttendanceStat extends StatelessWidget {
  const _AttendanceStat({
    required this.label,
    required this.value,
    this.color = const Color(0xFF172235),
  });
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 126,
    child: Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .07),
        borderRadius: BorderRadius.circular(13),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: Color(0xFF68778C))),
          const SizedBox(height: 4),
          Text(
            '$value days',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: color,
            ),
          ),
        ],
      ),
    ),
  );
}

class _GuardianRequiredItemsPanel extends StatefulWidget {
  const _GuardianRequiredItemsPanel({required this.child, required this.api});
  final GuardianChildSummary child;
  final GuardianPortalApiClient api;

  @override
  State<_GuardianRequiredItemsPanel> createState() =>
      _GuardianRequiredItemsPanelState();
}

class _GuardianRequiredItemsPanelState
    extends State<_GuardianRequiredItemsPanel> {
  late Future<GuardianStudentRequirements> requirements;

  @override
  void initState() {
    super.initState();
    requirements = widget.api.requirements(widget.child.studentId);
  }

  void _reload() => setState(() {
    requirements = widget.api.requirements(widget.child.studentId);
  });

  @override
  Widget build(BuildContext context) =>
      FutureBuilder<GuardianStudentRequirements>(
        future: requirements,
        builder: (context, result) {
          if (result.connectionState == ConnectionState.waiting) {
            return const _LoadingCard();
          }
          if (result.hasError) {
            return _FriendlyError(
              message: _errorText(result.error),
              onRetry: _reload,
            );
          }
          final items = result.data?.items ?? const <GuardianRequiredItem>[];
          if (items.isEmpty) {
            return const _EmptyCard(
              icon: Icons.inventory_2_outlined,
              title: 'No items requested',
              message: 'The school has not requested any items for this term.',
            );
          }
          final delivered = items.where((item) => item.complete).length;
          final partlyDelivered = items
              .where((item) => !item.complete && item.receivedQuantity > 0)
              .length;
          return Column(
            children: [
              _Card(
                child: Row(
                  children: [
                    Expanded(
                      child: _RequirementSummary(
                        label: 'Requested',
                        value: '${items.length}',
                        color: const Color(0xFF172235),
                      ),
                    ),
                    Expanded(
                      child: _RequirementSummary(
                        label: 'Delivered',
                        value: '$delivered',
                        color: const Color(0xFF087F72),
                      ),
                    ),
                    Expanded(
                      child: _RequirementSummary(
                        label: 'Remaining',
                        value: '${items.length - delivered}',
                        color: const Color(0xFFD97706),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              _Card(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Items for this term',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    if (partlyDelivered > 0) ...[
                      const SizedBox(height: 5),
                      Text(
                        '$partlyDelivered partially delivered',
                        style: const TextStyle(color: Color(0xFF68778C)),
                      ),
                    ],
                    const SizedBox(height: 10),
                    for (var index = 0; index < items.length; index++) ...[
                      _GuardianRequiredItemRow(item: items[index]),
                      if (index != items.length - 1)
                        const Divider(height: 1, color: Color(0xFFE4E9E8)),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      );
}

class _RequirementSummary extends StatelessWidget {
  const _RequirementSummary({
    required this.label,
    required this.value,
    required this.color,
  });
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Color(0xFF68778C))),
      const SizedBox(height: 4),
      Text(
        value,
        style: TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    ],
  );
}

class _GuardianRequiredItemRow extends StatelessWidget {
  const _GuardianRequiredItemRow({required this.item});
  final GuardianRequiredItem item;

  @override
  Widget build(BuildContext context) {
    final partial = !item.complete && item.receivedQuantity > 0;
    final status = item.complete
        ? 'Delivered'
        : partial
        ? 'Partly delivered'
        : 'Not delivered';
    final color = item.complete
        ? const Color(0xFF087F72)
        : partial
        ? const Color(0xFFD97706)
        : const Color(0xFFD14343);
    final quantity = item.unit.isEmpty
        ? '${item.receivedQuantity} of ${item.requiredQuantity}'
        : '${item.receivedQuantity} of ${item.requiredQuantity} ${item.unit}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              item.complete
                  ? Icons.check_rounded
                  : partial
                  ? Icons.hourglass_bottom_rounded
                  : Icons.inventory_2_outlined,
              color: color,
            ),
          ),
          const SizedBox(width: 13),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  [
                    if (item.category.isNotEmpty) item.category,
                    quantity,
                    if (item.dueDate.isNotEmpty)
                      'Due ${_friendlyDate(item.dueDate)}',
                  ].join(' · '),
                  style: const TextStyle(color: Color(0xFF68778C)),
                ),
                if (item.instructions.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.instructions,
                    style: const TextStyle(color: Color(0xFF39485A)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: .1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ChildPersonalDetails extends StatefulWidget {
  const _ChildPersonalDetails({required this.child, required this.api});
  final GuardianChildSummary child;
  final GuardianPortalApiClient api;

  @override
  State<_ChildPersonalDetails> createState() => _ChildPersonalDetailsState();
}

class _ChildPersonalDetailsState extends State<_ChildPersonalDetails> {
  late Future<GuardianChildDetails> details;

  @override
  void initState() {
    super.initState();
    details = widget.api.childDetails(widget.child.studentId);
  }

  void retry() =>
      setState(() => details = widget.api.childDetails(widget.child.studentId));

  @override
  Widget build(BuildContext context) => FutureBuilder<GuardianChildDetails>(
    future: details,
    builder: (context, result) {
      if (result.connectionState == ConnectionState.waiting) {
        return const _Card(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
        );
      }
      if (result.hasError || result.data == null) {
        return _EmptyCard(
          icon: Icons.cloud_off_outlined,
          title: 'Child details could not be loaded',
          message: _errorText(result.error),
          actionLabel: 'Try again',
          onAction: retry,
        );
      }
      return _ChildDetailsContent(details: result.data!);
    },
  );
}

class _ChildDetailsContent extends StatelessWidget {
  const _ChildDetailsContent({required this.details});
  final GuardianChildDetails details;

  String display(String value) => value.trim().isEmpty ? 'Not recorded' : value;
  String listDisplay(List<String> values) =>
      values.isEmpty ? 'None recorded' : values.join(', ');

  @override
  Widget build(BuildContext context) {
    final medical = details.medical;
    final address = details.address;
    final addressLines = [
      address?.houseNumber ?? '',
      address?.streetName ?? '',
      address?.city ?? '',
      address?.district ?? '',
      address?.region ?? '',
      address?.country ?? '',
    ].where((value) => value.isNotEmpty).join(', ');
    return Column(
      children: [
        _ResponsivePair(
          left: _DetailsGroup(
            icon: Icons.badge_outlined,
            title: 'Personal information',
            rows: [
              ('Full name', display(details.fullName)),
              ('Student ID', display(details.studentId)),
              ('Class', display(details.gradeLevel)),
              ('Stream', display(details.stream)),
              ('Date of birth', display(details.dateOfBirth)),
              ('Gender', display(details.gender)),
              ('Country of birth', display(details.countryOfBirth)),
              ('City of birth', display(details.cityOfBirth)),
              ('Religion', display(details.religion)),
              ('Languages', listDisplay(details.languages)),
              ('Skills and interests', display(details.skillsAndInterests)),
            ],
          ),
          right: _MedicalDetailsGroup(medical: medical),
        ),
        const SizedBox(height: 18),
        _ResponsivePair(
          left: _VaccinationDetailsGroup(vaccinations: details.vaccinations),
          right: _DetailsGroup(
            icon: Icons.home_outlined,
            title: 'Address',
            rows: [
              (
                'Residential address',
                addressLines.isEmpty ? 'Not recorded' : addressLines,
              ),
              ('GhanaPost address', display(address?.ghanaPostAddress ?? '')),
              (
                'Additional directions',
                display(address?.additionalDirection ?? ''),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        _EmergencyContactsGroup(contacts: details.emergencyContacts),
        const SizedBox(height: 14),
        const Text(
          'These official records are read-only. Contact the school office if any information is incorrect.',
          style: TextStyle(color: Color(0xFF68778C)),
        ),
      ],
    );
  }
}

class _VaccinationDetailsGroup extends StatelessWidget {
  const _VaccinationDetailsGroup({required this.vaccinations});
  final List<GuardianChildVaccination> vaccinations;

  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.vaccines_outlined, color: Color(0xFF087F72)),
            SizedBox(width: 9),
            Text(
              'Vaccination records',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (vaccinations.isEmpty)
          const Text(
            'No vaccination records have been entered.',
            style: TextStyle(color: Color(0xFF68778C)),
          )
        else
          for (var index = 0; index < vaccinations.length; index++) ...[
            _VaccinationRecordTile(vaccination: vaccinations[index]),
            if (index != vaccinations.length - 1) const SizedBox(height: 10),
          ],
      ],
    ),
  );
}

String _vaccinationStatus(String status) => switch (status.toUpperCase()) {
  'YES' || 'VACCINATED' || 'RECEIVED' => 'Vaccinated',
  'NO' || 'NOT_VACCINATED' => 'Not vaccinated',
  _ => 'Not answered',
};

class _MedicalDetailsGroup extends StatelessWidget {
  const _MedicalDetailsGroup({required this.medical});
  final GuardianChildMedical? medical;

  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.health_and_safety_outlined, color: Color(0xFF087F72)),
            SizedBox(width: 9),
            Text(
              'Medical information',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            _MedicalMetric(
              label: 'Blood group',
              value: _recordedValue(medical?.bloodGroup),
              icon: Icons.bloodtype_outlined,
            ),
            _MedicalMetric(
              label: 'Height',
              value: medical?.heightCm == null
                  ? 'Not recorded'
                  : '${medical!.heightCm!.toStringAsFixed(1)} cm',
              icon: Icons.height_rounded,
            ),
            _MedicalMetric(
              label: 'Weight',
              value: medical?.weightKg == null
                  ? 'Not recorded'
                  : '${medical!.weightKg!.toStringAsFixed(1)} kg',
              icon: Icons.monitor_weight_outlined,
            ),
          ],
        ),
        const SizedBox(height: 20),
        const _MedicalSectionHeading(title: 'Medical conditions'),
        const SizedBox(height: 8),
        if (medical == null || medical!.conditions.isEmpty)
          const _MedicalEmptyText(text: 'No medical conditions recorded.')
        else
          for (var index = 0; index < medical!.conditions.length; index++) ...[
            _MedicalConditionTile(condition: medical!.conditions[index]),
            if (index != medical!.conditions.length - 1)
              const SizedBox(height: 8),
          ],
        const SizedBox(height: 20),
        _AllergyGroupDisplay(
          title: 'Food allergies',
          icon: Icons.restaurant_outlined,
          values: medical?.foodAllergies ?? const [],
        ),
        const SizedBox(height: 16),
        _AllergyGroupDisplay(
          title: 'Medical allergies',
          icon: Icons.medication_outlined,
          values: medical?.medicalAllergies ?? const [],
        ),
        const SizedBox(height: 16),
        _AllergyGroupDisplay(
          title: 'Environmental allergies',
          icon: Icons.eco_outlined,
          values: medical?.environmentalAllergies ?? const [],
        ),
      ],
    ),
  );
}

String _recordedValue(String? value) =>
    value == null || value.trim().isEmpty ? 'Not recorded' : value.trim();

class _MedicalMetric extends StatelessWidget {
  const _MedicalMetric({
    required this.label,
    required this.value,
    required this.icon,
  });
  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 132),
    padding: const EdgeInsets.symmetric(horizontal: 13, vertical: 11),
    decoration: BoxDecoration(
      color: const Color(0xFFF7FAF9),
      border: Border.all(color: const Color(0xFFE0E9E7)),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 19, color: const Color(0xFF087F72)),
        const SizedBox(width: 9),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF7A8798),
                fontSize: 9,
                fontWeight: FontWeight.w900,
                letterSpacing: .6,
              ),
            ),
            const SizedBox(height: 3),
            Text(value, style: const TextStyle(fontWeight: FontWeight.w800)),
          ],
        ),
      ],
    ),
  );
}

class _MedicalSectionHeading extends StatelessWidget {
  const _MedicalSectionHeading({required this.title, this.icon});
  final String title;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      if (icon != null) ...[
        Icon(icon, size: 18, color: const Color(0xFF087F72)),
        const SizedBox(width: 7),
      ],
      Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
    ],
  );
}

class _MedicalEmptyText extends StatelessWidget {
  const _MedicalEmptyText({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: const TextStyle(color: Color(0xFF68778C), fontSize: 13),
  );
}

class _MedicalConditionTile extends StatelessWidget {
  const _MedicalConditionTile({required this.condition});
  final GuardianMedicalCondition condition;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: const Color(0xFFFFFAF1),
      border: Border.all(color: const Color(0xFFF2DFC0)),
      borderRadius: BorderRadius.circular(13),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              condition.name.isEmpty ? 'Medical condition' : condition.name,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
            if (condition.status.isNotEmpty)
              _HealthStatusChip(label: condition.status),
          ],
        ),
        if (condition.notes.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            condition.notes,
            style: const TextStyle(color: Color(0xFF68778C), height: 1.35),
          ),
        ],
      ],
    ),
  );
}

class _AllergyGroupDisplay extends StatelessWidget {
  const _AllergyGroupDisplay({
    required this.title,
    required this.icon,
    required this.values,
  });
  final String title;
  final IconData icon;
  final List<String> values;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _MedicalSectionHeading(title: title, icon: icon),
      const SizedBox(height: 8),
      if (values.isEmpty)
        const _MedicalEmptyText(text: 'None recorded.')
      else
        Wrap(
          spacing: 7,
          runSpacing: 7,
          children: [for (final value in values) _AllergyChip(label: value)],
        ),
    ],
  );
}

class _AllergyChip extends StatelessWidget {
  const _AllergyChip({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
    decoration: BoxDecoration(
      color: const Color(0xFFFFF2F1),
      border: Border.all(color: const Color(0xFFF1CECB)),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.warning_amber_rounded,
          size: 15,
          color: Color(0xFFB34A42),
        ),
        const SizedBox(width: 5),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8D3732),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    ),
  );
}

class _VaccinationRecordTile extends StatelessWidget {
  const _VaccinationRecordTile({required this.vaccination});
  final GuardianChildVaccination vaccination;

  @override
  Widget build(BuildContext context) {
    final status = _vaccinationStatus(vaccination.status);
    final statusColor = status == 'Vaccinated'
        ? const Color(0xFF087F72)
        : status == 'Not vaccinated'
        ? const Color(0xFFD14343)
        : const Color(0xFF68778C);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: const Color(0xFFF7FAF9),
        border: Border.all(color: const Color(0xFFE0E9E7)),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  vaccination.name.isEmpty ? 'Vaccination' : vaccination.name,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
              const SizedBox(width: 8),
              _HealthStatusChip(label: status, color: statusColor),
            ],
          ),
          if (vaccination.diseaseProtected.isNotEmpty ||
              vaccination.recommendedAge.isNotEmpty ||
              vaccination.required ||
              vaccination.dateReceived.isNotEmpty) ...[
            const SizedBox(height: 9),
            Wrap(
              spacing: 7,
              runSpacing: 7,
              children: [
                if (vaccination.diseaseProtected.isNotEmpty)
                  _VaccinationMeta(
                    icon: Icons.shield_outlined,
                    label: vaccination.diseaseProtected,
                  ),
                if (vaccination.recommendedAge.isNotEmpty)
                  _VaccinationMeta(
                    icon: Icons.child_care_outlined,
                    label: 'Age ${vaccination.recommendedAge}',
                  ),
                if (vaccination.required)
                  const _VaccinationMeta(
                    icon: Icons.priority_high_rounded,
                    label: 'Required',
                  ),
                if (vaccination.dateReceived.isNotEmpty)
                  _VaccinationMeta(
                    icon: Icons.event_available_outlined,
                    label: vaccination.dateReceived,
                  ),
              ],
            ),
          ],
          if (vaccination.notes.isNotEmpty) ...[
            const SizedBox(height: 9),
            Text(
              vaccination.notes,
              style: const TextStyle(color: Color(0xFF68778C), height: 1.35),
            ),
          ],
        ],
      ),
    );
  }
}

class _HealthStatusChip extends StatelessWidget {
  const _HealthStatusChip({required this.label, this.color});
  final String label;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final foreground = color ?? const Color(0xFFD97706);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: foreground.withValues(alpha: .09),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 10,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _VaccinationMeta extends StatelessWidget {
  const _VaccinationMeta({required this.icon, required this.label});
  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
    decoration: BoxDecoration(
      color: Colors.white,
      border: Border.all(color: const Color(0xFFE0E9E7)),
      borderRadius: BorderRadius.circular(9),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: const Color(0xFF087F72)),
        const SizedBox(width: 5),
        Flexible(
          child: Text(
            label,
            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _EmergencyContactsGroup extends StatelessWidget {
  const _EmergencyContactsGroup({required this.contacts});
  final List<GuardianEmergencyContact> contacts;

  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Row(
          children: [
            Icon(Icons.contact_phone_outlined, color: Color(0xFF087F72)),
            SizedBox(width: 9),
            Text(
              'Emergency contacts',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (contacts.isEmpty)
          const Text(
            'No emergency contact is recorded.',
            style: TextStyle(color: Color(0xFF68778C)),
          )
        else
          for (var index = 0; index < contacts.length; index++) ...[
            _EmergencyContactTile(contact: contacts[index]),
            if (index != contacts.length - 1) const SizedBox(height: 10),
          ],
      ],
    ),
  );
}

class _EmergencyContactTile extends StatelessWidget {
  const _EmergencyContactTile({required this.contact});
  final GuardianEmergencyContact contact;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: const Color(0xFFF7FAF9),
      border: Border.all(color: const Color(0xFFDCE8E5)),
      borderRadius: BorderRadius.circular(16),
    ),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final identity = Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: 23,
              backgroundColor: const Color(0xFFDDF1ED),
              foregroundColor: const Color(0xFF087F72),
              child: Text(
                _initials(contact.name.isEmpty ? 'Guardian' : contact.name),
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    contact.name.isEmpty ? 'Guardian' : contact.name,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (contact.primaryGuardian) ...[
                    const SizedBox(height: 5),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFE1F3EF),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Text(
                        'Primary guardian',
                        style: TextStyle(
                          color: Color(0xFF087F72),
                          fontSize: 11,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        );
        final details = Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (contact.phoneNumber.isNotEmpty)
              _EmergencyContactDetail(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: contact.phoneNumber,
              ),
            if (contact.phoneNumber.isNotEmpty && contact.email.isNotEmpty)
              const SizedBox(height: 10),
            if (contact.email.isNotEmpty)
              _EmergencyContactDetail(
                icon: Icons.email_outlined,
                label: 'Email',
                value: contact.email,
              ),
            if (contact.phoneNumber.isEmpty && contact.email.isEmpty)
              const Text(
                'No contact details recorded',
                style: TextStyle(color: Color(0xFF68778C)),
              ),
          ],
        );
        if (constraints.maxWidth < 720) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              identity,
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 14),
              details,
            ],
          );
        }
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(flex: 2, child: identity),
            const SizedBox(width: 24),
            Expanded(flex: 3, child: details),
          ],
        );
      },
    ),
  );
}

class _EmergencyContactDetail extends StatelessWidget {
  const _EmergencyContactDetail({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 19, color: const Color(0xFF087F72)),
      const SizedBox(width: 10),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: const TextStyle(
                color: Color(0xFF7A8798),
                fontSize: 10,
                fontWeight: FontWeight.w900,
                letterSpacing: .7,
              ),
            ),
            const SizedBox(height: 3),
            SelectableText(
              value,
              style: const TextStyle(
                color: Color(0xFF172033),
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ],
        ),
      ),
    ],
  );
}

class _DetailsGroup extends StatelessWidget {
  const _DetailsGroup({
    required this.icon,
    required this.title,
    required this.rows,
  });
  final IconData icon;
  final String title;
  final List<(String, String)> rows;

  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: const Color(0xFF087F72)),
            const SizedBox(width: 9),
            Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final row in rows) _SimpleLine(label: row.$1, value: row.$2),
      ],
    ),
  );
}

class _ParentAcademics extends StatefulWidget {
  const _ParentAcademics({required this.data, required this.api});
  final GuardianPortalSnapshot data;
  final GuardianPortalApiClient api;

  @override
  State<_ParentAcademics> createState() => _ParentAcademicsState();
}

class _ParentAcademicsState extends State<_ParentAcademics> {
  String? selected;
  int section = 0;

  @override
  void initState() {
    super.initState();
    if (widget.data.children.isNotEmpty) {
      selected = widget.data.children.first.studentId;
    }
  }

  GuardianChildSummary? get child {
    for (final item in widget.data.children) {
      if (item.studentId == selected) return item;
    }
    return widget.data.children.isEmpty ? null : widget.data.children.first;
  }

  @override
  Widget build(BuildContext context) {
    final current = child;
    return _PageScroll(
      title: 'Academics',
      subtitle:
          'Timetable, exercises, homework, scores and published report cards.',
      children: [
        if (widget.data.children.isNotEmpty)
          _ChildPicker(
            children: widget.data.children,
            selected: selected,
            onSelected: (value) => setState(() => selected = value),
          ),
        _AcademicSectionSelector(
          selected: section,
          onSelected: (value) => setState(() => section = value),
        ),
        if (current == null)
          const _EmptyCard(
            icon: Icons.menu_book_outlined,
            title: 'No academic record available',
            message:
                'A linked child is required before academics can be shown.',
          )
        else
          switch (section) {
            0 => _AcademicOverview(child: current, api: widget.api),
            1 => const _AcademicEmptySection(
              icon: Icons.calendar_view_week_outlined,
              title: 'No timetable published',
              message:
                  'The weekly timetable will appear here after the school shares it with guardians.',
            ),
            2 => const _AcademicEmptySection(
              icon: Icons.assignment_turned_in_outlined,
              title: 'No released exercises or scores',
              message:
                  'Exercises, assessments and scores appear only after the school releases them.',
            ),
            3 => const _AcademicEmptySection(
              icon: Icons.task_alt_outlined,
              title: 'No homework shared',
              message:
                  'Assigned work, instructions and due dates will appear here when teachers publish them.',
            ),
            _ => _AcademicReportsSection(
              data: widget.data,
              child: current,
              api: widget.api,
            ),
          },
      ],
    );
  }
}

// ignore: unused_element
class _PreviewAcademics extends StatelessWidget {
  const _PreviewAcademics({
    required this.data,
    required this.api,
    required this.children,
    required this.selectedChild,
    required this.section,
    required this.onSelectChild,
    required this.onBack,
    required this.onSelectSection,
  });

  final GuardianPortalSnapshot data;
  final GuardianPortalApiClient api;
  final List<GuardianChildSummary> children;
  final GuardianChildSummary? selectedChild;
  final int section;
  final ValueChanged<String> onSelectChild;
  final VoidCallback onBack;
  final ValueChanged<int> onSelectSection;

  @override
  Widget build(BuildContext context) {
    final child = selectedChild;
    if (child == null) {
      return _PageScroll(
        title: 'Academics',
        subtitle: 'Choose a child to view their schoolwork and reports.',
        children: [
          _Card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Your children',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                for (var index = 0; index < children.length; index++) ...[
                  _AcademicChildRow(
                    child: children[index],
                    onTap: () => onSelectChild(children[index].studentId),
                  ),
                  if (index != children.length - 1)
                    const Divider(height: 1, color: Color(0xFFE4E9E8)),
                ],
              ],
            ),
          ),
        ],
      );
    }
    return _PageScroll(
      title: child.name,
      subtitle: '${child.className} · ${data.termName} ${data.academicYear}',
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded),
            label: const Text('Back to all children'),
          ),
        ),
        _AcademicSectionSelector(
          selected: section,
          onSelected: onSelectSection,
        ),
        switch (section) {
          0 => _PreviewAcademicOverview(child: child),
          1 => _PreviewTimetable(child: child),
          2 => _PreviewScores(child: child, api: api),
          3 => _PreviewHomework(child: child, api: api),
          _ => _GuardianReportsPanel(data: data, child: child, api: api),
        },
      ],
    );
  }
}

class _AcademicChildRow extends StatelessWidget {
  const _AcademicChildRow({required this.child, required this.onTap});
  final GuardianChildSummary child;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    key: Key('academic-child-${child.studentId}'),
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 15),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final identity = Row(
            children: [
              CircleAvatar(
                radius: 23,
                backgroundColor: const Color(0xFFE1F3EF),
                foregroundColor: const Color(0xFF087F72),
                child: Text(_initials(child.name)),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      child.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w900),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      child.className,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Color(0xFF68778C)),
                    ),
                  ],
                ),
              ),
              if (constraints.maxWidth < 620)
                const Icon(
                  Icons.chevron_right_rounded,
                  color: Color(0xFF8793A4),
                ),
            ],
          );
          final statuses = [
            _SmallStatus(
              label: child.attendanceDays == 0
                  ? 'Attendance pending'
                  : '${child.attendancePercentage.toStringAsFixed(0)}% attendance',
              color: const Color(0xFF356AE6),
            ),
            _SmallStatus(
              label: child.reportPublished ? 'Report ready' : 'Report pending',
              color: child.reportPublished
                  ? const Color(0xFF087F72)
                  : const Color(0xFFD97706),
            ),
          ];
          if (constraints.maxWidth < 620) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                identity,
                Padding(
                  padding: const EdgeInsets.only(left: 59, top: 10),
                  child: Wrap(spacing: 8, runSpacing: 8, children: statuses),
                ),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: identity),
              ...statuses.expand(
                (status) => [status, const SizedBox(width: 10)],
              ),
              const Icon(Icons.chevron_right_rounded, color: Color(0xFF8793A4)),
            ],
          );
        },
      ),
    ),
  );
}

class _SmallStatus extends StatelessWidget {
  const _SmallStatus({required this.label, required this.color});
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
    decoration: BoxDecoration(
      color: color.withValues(alpha: .08),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      label,
      style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: color),
    ),
  );
}

class _PreviewAcademicOverview extends StatelessWidget {
  const _PreviewAcademicOverview({required this.child});
  final GuardianChildSummary child;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _ResponsivePair(
        left: _HomeInfoPanel(
          icon: Icons.calendar_month_outlined,
          title: 'Attendance',
          message: child.attendanceDays == 0
              ? 'Attendance has not been recorded yet.'
              : '${child.presentDays} present · ${child.absentDays} absent · ${child.lateDays} late',
        ),
        right: _HomeInfoPanel(
          icon: Icons.description_outlined,
          title: 'Report card',
          message: child.reportPublished
              ? 'The latest report is ready to view.'
              : 'The latest report has not been published.',
        ),
      ),
      const SizedBox(height: 18),
      const _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This week',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 12),
            _SimpleLine(label: 'Homework due', value: '2'),
            _SimpleLine(label: 'Exercises released', value: '3'),
            _SimpleLine(label: 'New teacher messages', value: '1'),
          ],
        ),
      ),
    ],
  );
}

class _PreviewTimetable extends StatelessWidget {
  const _PreviewTimetable({required this.child});
  final GuardianChildSummary child;

  @override
  Widget build(BuildContext context) {
    const days = [
      ('Monday', 'English Language', 'Mathematics', 'Science', 'Creative Arts'),
      ('Tuesday', 'Mathematics', 'Social Studies', 'Computing', 'R.M.E.'),
      ('Wednesday', 'Science', 'English Language', 'French', 'P.E.'),
      (
        'Thursday',
        'Mathematics',
        'Computing',
        'Ghanaian Language',
        'Creative Arts',
      ),
      ('Friday', 'English Language', 'Science', 'Social Studies', 'Library'),
    ];
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Class timetable',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 5),
          Text(
            '${child.className} · Current weekly timetable',
            style: const TextStyle(color: Color(0xFF68778C)),
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowColor: WidgetStateProperty.all(const Color(0xFFF0F7F5)),
              columns: const [
                DataColumn(label: Text('Day')),
                DataColumn(label: Text('8:00–9:00')),
                DataColumn(label: Text('9:00–10:00')),
                DataColumn(label: Text('10:30–11:30')),
                DataColumn(label: Text('12:30–1:30')),
              ],
              rows: [
                for (final day in days)
                  DataRow(
                    cells: [
                      DataCell(
                        Text(
                          day.$1,
                          style: const TextStyle(fontWeight: FontWeight.w800),
                        ),
                      ),
                      DataCell(Text(day.$2)),
                      DataCell(Text(day.$3)),
                      DataCell(Text(day.$4)),
                      DataCell(Text(day.$5)),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewScores extends StatelessWidget {
  const _PreviewScores({required this.child, required this.api});
  final GuardianChildSummary child;
  final GuardianPortalApiClient api;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GuardianAcademicData>(
      future: api.academics(child.studentId),
      builder: (context, result) => _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Current subject performance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            const Text(
              'Based on exercises and assessments released this term.',
              style: TextStyle(color: Color(0xFF68778C)),
            ),
            const SizedBox(height: 14),
            if (result.connectionState == ConnectionState.waiting)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (result.hasError)
              _InlineLoadError(message: _errorText(result.error))
            else if ((result.data?.subjects ?? const []).isEmpty)
              const _InlineEmptyState(
                icon: Icons.insights_outlined,
                title: 'No released scores yet',
                message:
                    'Scores will appear here after the school completes and releases an assessment.',
              )
            else
              for (final subject in result.data!.subjects)
                _SubjectPerformanceRow(
                  subject: subject.subjectName,
                  score: subject.currentAverage ?? 0,
                ),
          ],
        ),
      ),
    );
  }
}

class _SubjectPerformanceRow extends StatelessWidget {
  const _SubjectPerformanceRow({required this.subject, required this.score});
  final String subject;
  final double score;

  @override
  Widget build(BuildContext context) {
    final color = score >= 75
        ? const Color(0xFF087F72)
        : score >= 60
        ? const Color(0xFFD08A12)
        : const Color(0xFFD14343);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Text(
              subject,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          Expanded(
            flex: 3,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: LinearProgressIndicator(
                value: score / 100,
                minHeight: 8,
                backgroundColor: const Color(0xFFE8EFED),
                color: color,
              ),
            ),
          ),
          const SizedBox(width: 14),
          SizedBox(
            width: 46,
            child: Text(
              '${score.toStringAsFixed(0)}%',
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewHomework extends StatefulWidget {
  const _PreviewHomework({required this.child, required this.api});
  final GuardianChildSummary child;
  final GuardianPortalApiClient api;

  @override
  State<_PreviewHomework> createState() => _PreviewHomeworkState();
}

class _PreviewHomeworkState extends State<_PreviewHomework> {
  int page = 0;
  late Future<GuardianAcademicData> data;

  @override
  void initState() {
    super.initState();
    data = widget.api.academics(widget.child.studentId);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<GuardianAcademicData>(
      future: data,
      builder: (context, result) {
        final records =
            result.data?.activities ?? const <GuardianAcademicActivity>[];
        final visible = records.skip(page * 4).take(4).toList();
        return _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Homework history',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              const Text(
                'Past homework, submission status and released scores.',
                style: TextStyle(color: Color(0xFF68778C)),
              ),
              const SizedBox(height: 12),
              if (result.connectionState == ConnectionState.waiting)
                const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: CircularProgressIndicator(),
                  ),
                )
              else if (result.hasError)
                _InlineLoadError(message: _errorText(result.error))
              else if (records.isEmpty)
                const _InlineEmptyState(
                  icon: Icons.task_alt_outlined,
                  title: 'No homework or exercises yet',
                  message:
                      'Work shared by the school for this term will appear here.',
                )
              else
                for (final record in visible) _HomeworkRow(record: record),
              if (records.isNotEmpty)
                _ListPager(
                  page: page,
                  pageCount: (records.length / 4).ceil(),
                  onChanged: (value) => setState(() => page = value),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _HomeworkRow extends StatelessWidget {
  const _HomeworkRow({required this.record});
  final GuardianAcademicActivity record;

  @override
  Widget build(BuildContext context) {
    final status = switch (record.status) {
      'MARKED' => 'Marked',
      'SUBMITTED' => 'Submitted',
      'UPCOMING' => 'Upcoming',
      'DUE_TODAY' => 'Due today',
      _ => 'Not submitted',
    };
    final statusColor = switch (record.status) {
      'MARKED' || 'SUBMITTED' => const Color(0xFF087F72),
      'UPCOMING' || 'DUE_TODAY' => const Color(0xFFD97706),
      _ => const Color(0xFFD14343),
    };
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 13),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE7ECEB))),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 4,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.title,
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 3),
                Text(
                  '${record.subjectName} · Due ${record.dueDate}',
                  style: const TextStyle(
                    color: Color(0xFF68778C),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          _SmallStatus(label: status, color: statusColor),
          const SizedBox(width: 14),
          SizedBox(
            width: 86,
            child: Text(
              record.percentage == null
                  ? '—'
                  : '${record.percentage!.round()}%',
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.w900),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuardianReportsPanel extends StatefulWidget {
  const _GuardianReportsPanel({
    required this.data,
    required this.child,
    required this.api,
  });
  final GuardianPortalSnapshot data;
  final GuardianChildSummary child;
  final GuardianPortalApiClient api;

  @override
  State<_GuardianReportsPanel> createState() => _GuardianReportsPanelState();
}

class _GuardianReportsPanelState extends State<_GuardianReportsPanel> {
  int page = 0;
  late Future<List<GuardianReportItem>> reports;

  @override
  void initState() {
    super.initState();
    reports = widget.api.reports(widget.child.studentId);
  }

  void retry() => setState(() {
    page = 0;
    reports = widget.api.reports(widget.child.studentId);
  });

  @override
  Widget build(BuildContext context) => FutureBuilder<List<GuardianReportItem>>(
    future: reports,
    builder: (context, result) {
      if (result.connectionState == ConnectionState.waiting) {
        return const _Card(
          child: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: CircularProgressIndicator(),
            ),
          ),
        );
      }
      if (result.hasError) {
        return _EmptyCard(
          icon: Icons.cloud_off_outlined,
          title: 'Report cards could not be loaded',
          message: _errorText(result.error),
          actionLabel: 'Try again',
          onAction: retry,
        );
      }
      final items = result.data ?? const <GuardianReportItem>[];
      if (items.isEmpty) {
        return const _EmptyCard(
          icon: Icons.description_outlined,
          title: 'No report cards available',
          message:
              'Current and historical report cards will appear here when the school prepares them.',
        );
      }
      final pageCount = (items.length / 3).ceil();
      final safePage = page.clamp(0, pageCount - 1);
      final visible = items.skip(safePage * 3).take(3).toList();
      return _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Report cards',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            const Text(
              'Current and historical terminal reports.',
              style: TextStyle(color: Color(0xFF68778C)),
            ),
            const SizedBox(height: 12),
            for (final report in visible)
              _ReportCardHistoryRow(
                childId: widget.child.studentId,
                year: report.academicYear.isEmpty
                    ? 'Academic year not recorded'
                    : report.academicYear,
                term: report.termName.isEmpty ? 'Term' : report.termName,
                status: _guardianReportStatus(report.status),
                available: report.available,
                current: report.currentTerm,
                onView: report.available && report.academicYearId > 0
                    ? () => _openReport(
                        context,
                        widget.api,
                        widget.data,
                        widget.child,
                        termId: report.termId,
                        academicYearId: report.academicYearId,
                      )
                    : null,
              ),
            if (pageCount > 1)
              _ListPager(
                page: safePage,
                pageCount: pageCount,
                onChanged: (value) => setState(() => page = value),
              ),
          ],
        ),
      );
    },
  );
}

class _ReportCardHistoryRow extends StatelessWidget {
  const _ReportCardHistoryRow({
    required this.childId,
    required this.year,
    required this.term,
    required this.status,
    required this.available,
    required this.current,
    required this.onView,
  });
  final String childId;
  final String year;
  final String term;
  final String status;
  final bool available;
  final bool current;
  final VoidCallback? onView;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(vertical: 14),
    decoration: const BoxDecoration(
      border: Border(bottom: BorderSide(color: Color(0xFFE7ECEB))),
    ),
    child: Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: const Color(0xFFE7F4F1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(
            Icons.description_outlined,
            color: Color(0xFF087F72),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$term report card',
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 3),
              Text(
                '$year${current ? ' · Current term' : ''}',
                style: const TextStyle(color: Color(0xFF68778C), fontSize: 12),
              ),
            ],
          ),
        ),
        _SmallStatus(
          label: status,
          color: available ? const Color(0xFF087F72) : const Color(0xFFD97706),
        ),
        const SizedBox(width: 12),
        OutlinedButton.icon(
          key: current ? Key('preview-open-report-$childId') : null,
          onPressed: onView,
          icon: Icon(
            available
                ? Icons.visibility_outlined
                : Icons.hourglass_empty_rounded,
            size: 17,
          ),
          label: Text(
            available
                ? 'View'
                : status == 'School updating'
                ? 'Updating'
                : 'Not ready',
          ),
        ),
      ],
    ),
  );
}

class _ListPager extends StatelessWidget {
  const _ListPager({
    required this.page,
    required this.pageCount,
    required this.onChanged,
  });
  final int page;
  final int pageCount;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 14),
    child: Row(
      children: [
        Text(
          'Page ${page + 1} of $pageCount',
          style: const TextStyle(color: Color(0xFF68778C), fontSize: 12),
        ),
        const Spacer(),
        IconButton(
          key: const Key('list-page-previous'),
          tooltip: 'Previous page',
          onPressed: page == 0 ? null : () => onChanged(page - 1),
          icon: const Icon(Icons.chevron_left_rounded),
        ),
        IconButton(
          key: const Key('list-page-next'),
          tooltip: 'Next page',
          onPressed: page >= pageCount - 1 ? null : () => onChanged(page + 1),
          icon: const Icon(Icons.chevron_right_rounded),
        ),
      ],
    ),
  );
}

class _AcademicSectionSelector extends StatelessWidget {
  const _AcademicSectionSelector({
    required this.selected,
    required this.onSelected,
  });
  final int selected;
  final ValueChanged<int> onSelected;

  static const labels = [
    ('Overview', Icons.dashboard_outlined),
    ('Timetable', Icons.calendar_view_week_outlined),
    ('Exercises & scores', Icons.assignment_turned_in_outlined),
    ('Homework', Icons.task_alt_outlined),
    ('Report cards', Icons.description_outlined),
  ];

  @override
  Widget build(BuildContext context) => SingleChildScrollView(
    scrollDirection: Axis.horizontal,
    child: Row(
      children: [
        for (var index = 0; index < labels.length; index++) ...[
          ChoiceChip(
            selected: selected == index,
            onSelected: (_) => onSelected(index),
            avatar: Icon(labels[index].$2, size: 17),
            label: Text(labels[index].$1),
          ),
          if (index != labels.length - 1) const SizedBox(width: 8),
        ],
      ],
    ),
  );
}

class _AcademicOverview extends StatelessWidget {
  const _AcademicOverview({required this.child, required this.api});
  final GuardianChildSummary child;
  final GuardianPortalApiClient api;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _ResponsivePair(
        left: _HomeInfoPanel(
          icon: Icons.school_outlined,
          title: child.className,
          message:
              'Subjects and released academic performance will be summarized here.',
        ),
        right: _HomeInfoPanel(
          icon: Icons.calendar_month_outlined,
          title: 'Attendance this term',
          message: child.attendanceDays == 0
              ? 'No attendance has been recorded yet.'
              : '${child.presentDays} present, ${child.lateDays} late and ${child.absentDays} absent.',
          actionLabel: 'View attendance',
          onAction: () => _showAttendance(context, api, child),
        ),
      ),
      const SizedBox(height: 18),
      _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Recent academic activity',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 18),
            const _InlineEmptyState(
              icon: Icons.auto_stories_outlined,
              title: 'Nothing has been released yet',
              message:
                  'Published exercises, homework and scores will appear here in date order.',
            ),
          ],
        ),
      ),
    ],
  );
}

class _AcademicEmptySection extends StatelessWidget {
  const _AcademicEmptySection({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) =>
      _EmptyCard(icon: icon, title: title, message: message);
}

class _AcademicReportsSection extends StatelessWidget {
  const _AcademicReportsSection({
    required this.data,
    required this.child,
    required this.api,
  });
  final GuardianPortalSnapshot data;
  final GuardianChildSummary child;
  final GuardianPortalApiClient api;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      _Card(
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration: BoxDecoration(
                color: const Color(0xFFEAF4F2),
                borderRadius: BorderRadius.circular(13),
              ),
              child: const Icon(
                Icons.description_outlined,
                color: Color(0xFF087F72),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${data.termName} · ${data.academicYear}',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    child.reportPublished && child.reportCurrent
                        ? 'Published and ready to view'
                        : child.reportPublished
                        ? 'The school is updating this report'
                        : 'Not published yet',
                    style: const TextStyle(color: Color(0xFF68778C)),
                  ),
                ],
              ),
            ),
            FilledButton.icon(
              key: Key('open-report-${child.studentId}'),
              onPressed: child.reportPublished && child.reportCurrent
                  ? () => _openReport(context, api, data, child)
                  : null,
              icon: const Icon(Icons.visibility_outlined),
              label: const Text('Open report'),
            ),
          ],
        ),
      ),
      const SizedBox(height: 18),
      const _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Previous report cards',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            SizedBox(height: 18),
            _InlineEmptyState(
              icon: Icons.history_rounded,
              title: 'No earlier reports available',
              message:
                  'Historic term reports will remain here after they are published by the school.',
            ),
          ],
        ),
      ),
    ],
  );
}

class _InlineEmptyState extends StatelessWidget {
  const _InlineEmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });
  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: const Color(0xFFF8FAFA),
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      children: [
        Icon(icon, size: 30, color: const Color(0xFF8793A4)),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                message,
                style: const TextStyle(color: Color(0xFF68778C), height: 1.4),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _InlineLoadError extends StatelessWidget {
  const _InlineLoadError({required this.message});
  final String message;
  @override
  Widget build(BuildContext context) => _InlineEmptyState(
    icon: Icons.cloud_off_outlined,
    title: 'Could not load this information',
    message: message,
  );
}

class _ParentMessages extends StatefulWidget {
  const _ParentMessages();

  @override
  State<_ParentMessages> createState() => _ParentMessagesState();
}

class _ParentMessagesState extends State<_ParentMessages> {
  int section = 0;

  @override
  Widget build(BuildContext context) => _PageScroll(
    title: 'Messages',
    subtitle:
        'Read school announcements and contact the right office without searching for a staff member.',
    children: [
      LayoutBuilder(
        builder: (context, constraints) {
          final filters = Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ChoiceChip(
                selected: section == 0,
                onSelected: (_) => setState(() => section = 0),
                avatar: const Icon(Icons.campaign_outlined, size: 17),
                label: const Text('Announcements'),
              ),
              ChoiceChip(
                selected: section == 1,
                onSelected: (_) => setState(() => section = 1),
                avatar: const Icon(Icons.forum_outlined, size: 17),
                label: const Text('Conversations'),
              ),
            ],
          );
          final button = FilledButton.icon(
            onPressed: () => _showMessageComposer(context),
            icon: const Icon(Icons.edit_outlined),
            label: const Text('New message'),
          );
          if (constraints.maxWidth < 650) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                filters,
                const SizedBox(height: 12),
                SizedBox(width: double.infinity, child: button),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: filters),
              const SizedBox(width: 16),
              button,
            ],
          );
        },
      ),
      if (section == 0)
        const _Card(
          child: Column(
            children: [
              _PreviewMessageRow(
                icon: Icons.campaign_outlined,
                title: 'Parent meeting on Friday',
                message:
                    'All parents are invited at 3:00 PM in the school hall.',
                meta: 'Whole school · Today',
              ),
              Divider(height: 1, color: Color(0xFFE4E9E8)),
              _PreviewMessageRow(
                icon: Icons.event_outlined,
                title: 'Second Term activities',
                message: 'The updated school calendar is now available.',
                meta: 'Whole school · 12 Aug 2026',
              ),
            ],
          ),
        )
      else
        const _Card(
          child: Column(
            children: [
              _PreviewMessageRow(
                icon: Icons.account_balance_wallet_outlined,
                title: 'School accounts office',
                message: 'Your latest fee payment has been received.',
                meta: 'Family account · Yesterday',
              ),
              Divider(height: 1, color: Color(0xFFE4E9E8)),
              _PreviewMessageRow(
                icon: Icons.school_outlined,
                title: 'Ms. Mensah · Class teacher',
                message: 'Kofi participated well in today’s reading activity.',
                meta: 'Kofi Ofori · 13 Aug 2026',
              ),
            ],
          ),
        ),
    ],
  );
}

class _PreviewMessageRow extends StatelessWidget {
  const _PreviewMessageRow({
    required this.icon,
    required this.title,
    required this.message,
    required this.meta,
  });
  final IconData icon;
  final String title;
  final String message;
  final String meta;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 16),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          backgroundColor: const Color(0xFFE1F3EF),
          foregroundColor: const Color(0xFF087F72),
          child: Icon(icon, size: 20),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text(message, style: const TextStyle(color: Color(0xFF39485A))),
              const SizedBox(height: 5),
              Text(
                meta,
                style: const TextStyle(fontSize: 12, color: Color(0xFF8793A4)),
              ),
            ],
          ),
        ),
        const Icon(Icons.chevron_right_rounded, color: Color(0xFF8793A4)),
      ],
    ),
  );
}

class _FeesActionBanner extends StatelessWidget {
  const _FeesActionBanner({required this.data, required this.onPay});
  final GuardianPortalSnapshot data;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final balance = data.totalBalance;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF113E39),
        borderRadius: BorderRadius.circular(18),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 620;
          final details = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                balance == 0
                    ? 'Household fees are settled'
                    : 'Household balance',
                style: const TextStyle(color: Color(0xFFBFD7D2)),
              ),
              const SizedBox(height: 5),
              Text(
                _money(balance),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${data.children.length} ${data.children.length == 1 ? 'child' : 'children'} · ${data.termName}',
                style: const TextStyle(color: Color(0xFFBFD7D2)),
              ),
            ],
          );
          final button = FilledButton.icon(
            onPressed: onPay,
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Pay school fees'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF087F72),
              minimumSize: Size(compact ? double.infinity : 190, 46),
            ),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                details,
                const SizedBox(height: 18),
                SizedBox(width: double.infinity, child: button),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: details),
              const SizedBox(width: 20),
              button,
            ],
          );
        },
      ),
    );
  }
}

class _ParentFees extends StatefulWidget {
  const _ParentFees({
    required this.data,
    required this.api,
    this.initialChildId,
  });
  final GuardianPortalSnapshot data;
  final GuardianPortalApiClient api;
  final String? initialChildId;
  @override
  State<_ParentFees> createState() => _ParentFeesState();
}

class _ParentFeesState extends State<_ParentFees> {
  String? selected;
  late Future<GuardianFeeDetail>? detail;
  @override
  void initState() {
    super.initState();
    if (widget.data.children.isNotEmpty) {
      _select(widget.initialChildId ?? widget.data.children.first.studentId);
    }
  }

  @override
  void didUpdateWidget(covariant _ParentFees oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialChildId != widget.initialChildId &&
        widget.initialChildId != null) {
      _select(widget.initialChildId!);
    }
  }

  void _select(String id) {
    selected = id;
    detail = widget.api.fees(id);
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return _PageScroll(
      title: 'Fees & payments',
      subtitle:
          'See what the school has charged and the payments it has recorded.',
      children: [
        if (widget.data.children.isEmpty)
          const _EmptyCard(
            icon: Icons.account_balance_wallet_outlined,
            title: 'No fee account available',
            message: 'A linked child is required before fees can be shown.',
          )
        else ...[
          _FeesActionBanner(
            data: widget.data,
            onPay: () => _showMobileMoneyComingSoon(context),
          ),
          _ChildPicker(
            children: widget.data.children,
            selected: selected,
            onSelected: _select,
          ),
          FutureBuilder<GuardianFeeDetail>(
            future: detail,
            builder: (context, value) {
              if (value.connectionState == ConnectionState.waiting) {
                return const _LoadingCard();
              }
              if (value.hasError) {
                return _FriendlyError(
                  message: _errorText(value.error),
                  onRetry: () => _select(selected!),
                );
              }
              final fees = value.data!;
              return Column(
                children: [
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'This term',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Wrap(
                          spacing: 20,
                          runSpacing: 14,
                          children: [
                            _MoneySummary(
                              label: 'Charges',
                              value: fees.totalFees,
                            ),
                            if (fees.totalDiscounts > 0)
                              _MoneySummary(
                                label: 'Discounts',
                                value: fees.totalDiscounts,
                                color: const Color(0xFF087F72),
                              ),
                            if (fees.totalPenalties > 0)
                              _MoneySummary(
                                label: 'Extra charges',
                                value: fees.totalPenalties,
                                color: const Color(0xFFD97706),
                              ),
                            _MoneySummary(
                              label: 'Paid',
                              value: fees.totalPaid,
                              color: const Color(0xFF087F72),
                            ),
                            _MoneySummary(
                              label: 'Balance',
                              value: fees.balance,
                              color: fees.balance > 0
                                  ? const Color(0xFFD97706)
                                  : const Color(0xFF087F72),
                            ),
                          ],
                        ),
                        const SizedBox(height: 18),
                        for (final item in fees.items)
                          _SimpleLine(
                            label: item.name,
                            value: _money(item.amount),
                          ),
                        if (fees.adjustments.isNotEmpty) ...[
                          const Divider(height: 28),
                          const Text(
                            'Approved discounts and adjustments',
                            style: TextStyle(fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 4),
                          for (final adjustment in fees.adjustments)
                            _SimpleLine(
                              label: adjustment.description.isNotEmpty
                                  ? adjustment.description
                                  : adjustment.type,
                              value: adjustment.amount < 0
                                  ? '-${_money(adjustment.amount.abs())}'
                                  : '+${_money(adjustment.amount)}',
                            ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _Card(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Payment activity',
                                style: TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ),
                            OutlinedButton.icon(
                              onPressed: () =>
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Statement downloads will be connected after this design is approved.',
                                      ),
                                    ),
                                  ),
                              icon: const Icon(
                                Icons.download_outlined,
                                size: 18,
                              ),
                              label: const Text('Statement'),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        if (fees.payments.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Text(
                              'No payments have been recorded for this term yet.',
                              style: TextStyle(color: Color(0xFF68778C)),
                            ),
                          )
                        else
                          for (final payment in fees.payments)
                            _PaymentLine(payment: payment),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ],
    );
  }
}

// ignore: unused_element
class _PreviewFamilyFees extends StatelessWidget {
  const _PreviewFamilyFees({
    required this.data,
    required this.children,
    required this.selectedChild,
    required this.onSelectChild,
    required this.onBack,
  });

  final GuardianPortalSnapshot data;
  final List<GuardianChildSummary> children;
  final GuardianChildSummary? selectedChild;
  final ValueChanged<String> onSelectChild;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final child = selectedChild;
    if (child != null) {
      return _PageScroll(
        title: '${child.name} · Fees',
        subtitle: '${child.className} · ${data.termName} ${data.academicYear}',
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.arrow_back_rounded),
              label: const Text('Back to family fees'),
            ),
          ),
          _PreviewChildFeeSummary(child: child),
          _PreviewChildPayments(child: child),
        ],
      );
    }
    return _PageScroll(
      title: 'Fees & payments',
      subtitle: 'Your family balance and how it is divided between each child.',
      children: [
        _PreviewFeesBanner(
          children: children,
          termName: data.termName,
          onPay: () => _showMobileMoneyComingSoon(context),
        ),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Fees by child',
                style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 8),
              for (var index = 0; index < children.length; index++) ...[
                _FamilyBalanceRow(
                  child: children[index],
                  onTap: () => onSelectChild(children[index].studentId),
                ),
                if (index != children.length - 1)
                  const Divider(height: 1, color: Color(0xFFE4E9E8)),
              ],
            ],
          ),
        ),
        const _RecentFeePayments(),
      ],
    );
  }
}

class _PreviewFeesBanner extends StatelessWidget {
  const _PreviewFeesBanner({
    required this.children,
    required this.termName,
    required this.onPay,
  });

  final List<GuardianChildSummary> children;
  final String termName;
  final VoidCallback onPay;

  @override
  Widget build(BuildContext context) {
    final balance = children.fold<double>(
      0,
      (total, child) => total + child.balance,
    );
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: const Color(0xFF113E39),
        borderRadius: BorderRadius.circular(18),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final compact = constraints.maxWidth < 650;
          final summary = Wrap(
            spacing: 34,
            runSpacing: 14,
            children: [
              _DarkMoneySummary(label: 'Balance', value: balance),
              _DarkMoneySummary(
                label: 'Children',
                valueText: '${children.length}',
              ),
            ],
          );
          final button = FilledButton.icon(
            onPressed: onPay,
            icon: const Icon(Icons.payments_outlined),
            label: const Text('Pay school fees'),
            style: FilledButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: const Color(0xFF087F72),
            ),
          );
          if (compact) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  termName,
                  style: const TextStyle(color: Color(0xFFBFD7D2)),
                ),
                const SizedBox(height: 12),
                summary,
                const SizedBox(height: 18),
                SizedBox(width: double.infinity, child: button),
              ],
            );
          }
          return Row(
            children: [
              Expanded(child: summary),
              const SizedBox(width: 20),
              button,
            ],
          );
        },
      ),
    );
  }
}

class _DarkMoneySummary extends StatelessWidget {
  const _DarkMoneySummary({required this.label, this.value, this.valueText});
  final String label;
  final double? value;
  final String? valueText;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: Color(0xFFBFD7D2))),
      const SizedBox(height: 4),
      Text(
        valueText ?? _money(value ?? 0),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 24,
          fontWeight: FontWeight.w900,
        ),
      ),
    ],
  );
}

class _PreviewChildFeeSummary extends StatelessWidget {
  const _PreviewChildFeeSummary({required this.child});
  final GuardianChildSummary child;

  @override
  Widget build(BuildContext context) => _Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            CircleAvatar(
              radius: 25,
              backgroundColor: const Color(0xFFE1F3EF),
              foregroundColor: const Color(0xFF087F72),
              child: Text(_initials(child.name)),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Text(
                child.name,
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            OutlinedButton.icon(
              onPressed: () {},
              icon: const Icon(Icons.download_outlined, size: 18),
              label: const Text('Statement'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 28,
          runSpacing: 14,
          children: [
            _MoneySummary(label: 'Charges', value: child.totalFees),
            _MoneySummary(
              label: 'Paid',
              value: child.totalPaid,
              color: const Color(0xFF087F72),
            ),
            _MoneySummary(
              label: 'Balance',
              value: child.balance,
              color: child.balance > 0
                  ? const Color(0xFFD97706)
                  : const Color(0xFF087F72),
            ),
          ],
        ),
        const Divider(height: 32),
        _SimpleLine(label: 'Tuition', value: _money(child.totalFees * .65)),
        _SimpleLine(
          label: 'Learning materials',
          value: _money(child.totalFees * .2),
        ),
        _SimpleLine(
          label: 'Activities and services',
          value: _money(child.totalFees * .15),
        ),
      ],
    ),
  );
}

class _PreviewChildPayments extends StatelessWidget {
  const _PreviewChildPayments({required this.child});
  final GuardianChildSummary child;

  @override
  Widget build(BuildContext context) {
    final payments = _previewPaymentsFor(child);
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Transactions for this child',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          for (var index = 0; index < payments.length; index++) ...[
            _RecentPaymentRow(payment: payments[index]),
            if (index != payments.length - 1)
              const Divider(height: 1, color: Color(0xFFE4E9E8)),
          ],
        ],
      ),
    );
  }
}

List<({String amount, String date, String method, String receipt})>
_previewPaymentsFor(GuardianChildSummary child) {
  if (child.name.startsWith('Adwoa')) {
    return const [
      (
        amount: 'GH₵ 900',
        date: '21 Jul 2026',
        method: 'Mobile Money',
        receipt: 'RCPT-20260721-014',
      ),
      (
        amount: 'GH₵ 480',
        date: '2 Jul 2026',
        method: 'Cash',
        receipt: 'RCPT-20260702-008',
      ),
    ];
  }
  if (child.name.startsWith('Kwame')) {
    return const [
      (
        amount: 'GH₵ 1,000',
        date: '10 Jul 2026',
        method: 'Bank deposit',
        receipt: 'RCPT-20260710-011',
      ),
      (
        amount: 'GH₵ 450',
        date: '3 Jul 2026',
        method: 'Mobile Money',
        receipt: 'RCPT-20260703-004',
      ),
    ];
  }
  return const [
    (
      amount: 'GH₵ 635',
      date: '9 Aug 2026',
      method: 'Cash',
      receipt: 'RCPT-20260809-002',
    ),
  ];
}

Future<void> _showMobileMoneyComingSoon(BuildContext context) async {
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
      contentPadding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
      actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 22),
      title: const Row(
        children: [
          Icon(Icons.phone_android_rounded, color: Color(0xFF087F72)),
          SizedBox(width: 12),
          Expanded(child: Text('Mobile Money payments')),
        ],
      ),
      content: const SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Online Mobile Money payments are coming soon.',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
            ),
            SizedBox(height: 10),
            Text(
              'For now, please pay cash or cheque directly at the school office. The bursar will record the payment and it will appear in your payment history.',
              style: TextStyle(color: Color(0xFF68778C), height: 1.45),
            ),
            SizedBox(height: 14),
            Text(
              'No payment has been started and no money has been deducted.',
              style: TextStyle(
                color: Color(0xFF087F72),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
      actions: [
        FilledButton(
          key: Key('guardian-payment-coming-soon-close'),
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text('Close'),
        ),
      ],
    ),
  );
}

// Retained temporarily as design reference until a Mobile Money provider is selected.
// ignore: unused_element
Future<void> _showPreviewPaymentSheet(
  BuildContext context,
  List<GuardianChildSummary> children, {
  GuardianPortalApiClient? api,
  VoidCallback? onSubmitted,
}) async {
  String? selectedChildId;
  String? selectedMethod;
  String? selectedNetwork;
  String? errorText;
  var submitting = false;
  final amountController = TextEditingController();
  final mobileController = TextEditingController();
  final chequeController = TextEditingController();
  final bankController = TextEditingController();
  final noteController = TextEditingController();
  await showDialog<void>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (_, setDialogState) {
        GuardianChildSummary? selectedChild;
        for (final child in children) {
          if (child.studentId == selectedChildId) selectedChild = child;
        }
        return AlertDialog(
          titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 0),
          contentPadding: const EdgeInsets.fromLTRB(24, 14, 24, 8),
          actionsPadding: const EdgeInsets.fromLTRB(24, 8, 24, 22),
          title: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFE1F3EF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.payments_outlined,
                  color: Color(0xFF087F72),
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(child: Text('Pay school fees')),
            ],
          ),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Enter the payment details. Nothing is recorded until you confirm the payment.',
                    style: TextStyle(color: Color(0xFF68778C), height: 1.4),
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    'Who are you paying for?',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final child in children)
                        ChoiceChip(
                          key: Key('guardian-payment-child-${child.studentId}'),
                          avatar: CircleAvatar(
                            backgroundColor: Colors.white,
                            foregroundColor: const Color(0xFF087F72),
                            child: Text(
                              _initials(child.name),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          label: Text(child.name),
                          selected: selectedChildId == child.studentId,
                          onSelected: (_) => setDialogState(() {
                            selectedChildId = child.studentId;
                            errorText = null;
                          }),
                        ),
                    ],
                  ),
                  if (selectedChild != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      selectedChild.balance == 0
                          ? '${selectedChild.className} · No fees currently due'
                          : '${selectedChild.className} · Balance ${_money(selectedChild.balance)}',
                      style: TextStyle(
                        color: selectedChild.balance > 0
                            ? const Color(0xFFD97706)
                            : const Color(0xFF087F72),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  TextField(
                    key: const Key('guardian-payment-amount'),
                    controller: amountController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: 'GH₵ ',
                      hintText: '0.00',
                      border: OutlineInputBorder(),
                    ),
                    onChanged: (_) => setDialogState(() => errorText = null),
                  ),
                  const SizedBox(height: 18),
                  const Text(
                    'Payment method',
                    style: TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 9),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final method in const [
                        'Mobile money',
                        'Cash',
                        'Cheque',
                      ])
                        ChoiceChip(
                          key: Key(
                            'guardian-payment-method-${method.toLowerCase().replaceAll(' ', '-')}',
                          ),
                          label: Text(method),
                          selected: selectedMethod == method,
                          onSelected: (selected) => setDialogState(() {
                            selectedMethod = selected ? method : null;
                            errorText = null;
                          }),
                        ),
                    ],
                  ),
                  if (selectedMethod == 'Mobile money') ...[
                    const SizedBox(height: 16),
                    const Text(
                      'Mobile network',
                      style: TextStyle(fontWeight: FontWeight.w800),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        for (final network in const [
                          'MTN',
                          'Telecel',
                          'AirtelTigo',
                        ])
                          ChoiceChip(
                            key: Key(
                              'guardian-payment-network-${network.toLowerCase()}',
                            ),
                            label: Text(network),
                            selected: selectedNetwork == network,
                            onSelected: (selected) => setDialogState(() {
                              selectedNetwork = selected ? network : null;
                              errorText = null;
                            }),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('guardian-payment-mobile-number'),
                      controller: mobileController,
                      keyboardType: TextInputType.phone,
                      decoration: const InputDecoration(
                        labelText: 'Mobile Money number',
                        hintText: 'e.g. 024 000 0000',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  if (selectedMethod == 'Cheque') ...[
                    const SizedBox(height: 16),
                    TextField(
                      key: const Key('guardian-payment-bank-name'),
                      controller: bankController,
                      decoration: const InputDecoration(
                        labelText: 'Bank name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      key: const Key('guardian-payment-cheque-number'),
                      controller: chequeController,
                      decoration: const InputDecoration(
                        labelText: 'Cheque number',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  if (selectedMethod != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7E8),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        selectedMethod == 'Mobile money'
                            ? 'This request stays pending until the Mobile Money transaction is confirmed.'
                            : selectedMethod == 'Cheque'
                            ? 'This request stays pending until the school receives and clears the cheque.'
                            : 'This request stays pending until the school confirms it received the cash.',
                        style: const TextStyle(
                          color: Color(0xFF8A5A00),
                          fontWeight: FontWeight.w700,
                          height: 1.35,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: noteController,
                      maxLines: 2,
                      decoration: const InputDecoration(
                        labelText: 'Note (optional)',
                        border: OutlineInputBorder(),
                      ),
                    ),
                  ],
                  if (errorText != null) ...[
                    const SizedBox(height: 14),
                    Text(
                      errorText!,
                      key: const Key('guardian-payment-error'),
                      style: const TextStyle(
                        color: Color(0xFFD64045),
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton.icon(
              key: const Key('guardian-payment-continue'),
              onPressed: submitting
                  ? null
                  : () async {
                      final amount = double.tryParse(
                        amountController.text.trim(),
                      );
                      if (selectedChildId == null ||
                          amount == null ||
                          amount <= 0 ||
                          selectedMethod == null) {
                        setDialogState(() {
                          errorText =
                              'Select a child, enter a valid amount and choose a payment method.';
                        });
                        return;
                      }
                      if (selectedMethod == 'Mobile money' &&
                          (selectedNetwork == null ||
                              mobileController.text.trim().isEmpty)) {
                        setDialogState(() {
                          errorText =
                              'Select a network and enter the Mobile Money number.';
                        });
                        return;
                      }
                      if (selectedMethod == 'Cheque' &&
                          (bankController.text.trim().isEmpty ||
                              chequeController.text.trim().isEmpty)) {
                        setDialogState(() {
                          errorText = 'Enter the bank name and cheque number.';
                        });
                        return;
                      }
                      if (api == null) {
                        setDialogState(() {
                          errorText =
                              'Payment submission is not available here.';
                        });
                        return;
                      }
                      setDialogState(() {
                        submitting = true;
                        errorText = null;
                      });
                      try {
                        final submission = await api.submitPayment(
                          studentId: selectedChildId!,
                          amount: amount,
                          paymentMethod: selectedMethod!,
                          idempotencyKey:
                              '${DateTime.now().microsecondsSinceEpoch}-${selectedChildId!}',
                          mobileNetwork: selectedNetwork,
                          mobileNumber: mobileController.text.trim().isEmpty
                              ? null
                              : mobileController.text.trim(),
                          chequeNumber: chequeController.text.trim().isEmpty
                              ? null
                              : chequeController.text.trim(),
                          bankName: bankController.text.trim().isEmpty
                              ? null
                              : bankController.text.trim(),
                          note: noteController.text.trim().isEmpty
                              ? null
                              : noteController.text.trim(),
                        );
                        if (!dialogContext.mounted) return;
                        Navigator.of(dialogContext).pop();
                        onSubmitted?.call();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              '${submission.reference} submitted. ${submission.message}',
                            ),
                          ),
                        );
                      } catch (error) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() {
                          submitting = false;
                          errorText = _errorText(error);
                        });
                      }
                    },
              icon: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded),
              label: Text(submitting ? 'Submitting…' : 'Submit payment'),
            ),
          ],
        );
      },
    ),
  );
}

class _ParentMore extends StatelessWidget {
  const _ParentMore({
    required this.data,
    required this.api,
    required this.onProfileUpdated,
    required this.onOpenMessages,
    required this.onLogout,
  });
  final GuardianPortalSnapshot data;
  final GuardianPortalApiClient api;
  final VoidCallback onProfileUpdated;
  final VoidCallback onOpenMessages;
  final VoidCallback onLogout;
  @override
  Widget build(BuildContext context) => _PageScroll(
    title: 'My account',
    subtitle: 'Manage your contact information and communication preferences.',
    children: [
      _Card(
        child: Column(
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: const Color(0xFFE3F3F0),
                  foregroundColor: const Color(0xFF087F72),
                  child: Text(
                    _initials(data.guardianName),
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        data.guardianName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${data.children.length} children linked',
                        style: const TextStyle(color: Color(0xFF68778C)),
                      ),
                    ],
                  ),
                ),
                OutlinedButton.icon(
                  onPressed: () async {
                    final changed = await _showProfileEditor(context, api);
                    if (changed) onProfileUpdated();
                  },
                  icon: const Icon(Icons.edit_outlined, size: 18),
                  label: const Text('Edit details'),
                ),
              ],
            ),
          ],
        ),
      ),
      _GuardianStoredDetailsCard(api: api),
      _OtherGuardiansCard(api: api),
      _ResponsivePair(
        left: _HomeInfoPanel(
          icon: Icons.forum_outlined,
          title: 'Messages and announcements',
          message:
              'Contact the school and review notices sent to your household.',
          actionLabel: 'Open messages',
          onAction: onOpenMessages,
        ),
        right: const _HomeInfoPanel(
          icon: Icons.notifications_outlined,
          title: 'Notifications',
          message:
              'Important academic, payment and school updates are enabled.',
        ),
      ),
      _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Account access',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 6),
            const Text(
              'Sign out when using a shared phone or computer.',
              style: TextStyle(color: Color(0xFF68778C)),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed: () => _showGuardianMergeDialog(
                    context,
                    api,
                    onMerged: onLogout,
                  ),
                  icon: const Icon(Icons.account_tree_outlined),
                  label: const Text('Connect another guardian account'),
                ),
                OutlinedButton.icon(
                  onPressed: onLogout,
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Sign out'),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(150, 46),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    ],
  );
}

Future<void> _showGuardianMergeDialog(
  BuildContext context,
  GuardianPortalApiClient api, {
  required VoidCallback onMerged,
}) async {
  final formKey = GlobalKey<FormState>();
  final otherUsername = TextEditingController();
  final otherPassword = TextEditingController();
  final canonicalUsername = TextEditingController();
  final canonicalPassword = TextEditingController();
  var submitting = false;
  String? error;
  try {
    await showDialog<void>(
      context: context,
      barrierDismissible: !submitting,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Connect guardian accounts'),
          content: SizedBox(
            width: 520,
            child: SingleChildScrollView(
              child: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Use this only when both guardian accounts belong to you. '
                      'Enter both logins, then choose which username you want to keep.',
                      style: TextStyle(color: Color(0xFF68778C)),
                    ),
                    if (error != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        error!,
                        style: const TextStyle(color: Color(0xFFD64545)),
                      ),
                    ],
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: otherUsername,
                      decoration: const InputDecoration(
                        labelText: 'Other guardian username',
                      ),
                      validator: _requiredDialogValue,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: otherPassword,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Other account password',
                      ),
                      validator: _requiredDialogValue,
                    ),
                    const SizedBox(height: 18),
                    TextFormField(
                      controller: canonicalUsername,
                      decoration: const InputDecoration(
                        labelText: 'Username to keep',
                      ),
                      validator: _requiredDialogValue,
                    ),
                    const SizedBox(height: 12),
                    TextFormField(
                      controller: canonicalPassword,
                      obscureText: true,
                      decoration: const InputDecoration(
                        labelText: 'Password for username to keep',
                      ),
                      validator: _requiredDialogValue,
                    ),
                  ],
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: submitting
                  ? null
                  : () async {
                      if (!formKey.currentState!.validate()) return;
                      setDialogState(() {
                        submitting = true;
                        error = null;
                      });
                      try {
                        await api.mergeGuardianAccounts(
                          otherUsername: otherUsername.text.trim(),
                          otherPassword: otherPassword.text,
                          canonicalUsername: canonicalUsername.text.trim(),
                          canonicalPassword: canonicalPassword.text,
                        );
                        if (!dialogContext.mounted) return;
                        Navigator.pop(dialogContext);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Accounts connected. Sign in with the username you chose to keep.',
                            ),
                          ),
                        );
                        onMerged();
                      } catch (exception) {
                        if (!dialogContext.mounted) return;
                        setDialogState(() {
                          submitting = false;
                          error = _errorText(exception);
                        });
                      }
                    },
              child: submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Connect accounts'),
            ),
          ],
        ),
      ),
    );
  } finally {
    otherUsername.dispose();
    otherPassword.dispose();
    canonicalUsername.dispose();
    canonicalPassword.dispose();
  }
}

String? _requiredDialogValue(String? value) =>
    value == null || value.trim().isEmpty ? 'Required' : null;

class _GuardianStoredDetailsCard extends StatelessWidget {
  const _GuardianStoredDetailsCard({required this.api});
  final GuardianPortalApiClient api;

  @override
  Widget build(BuildContext context) => FutureBuilder<GuardianProfile>(
    future: api.profile(),
    builder: (context, result) {
      if (result.connectionState == ConnectionState.waiting) {
        return const _LoadingCard();
      }
      if (result.hasError) {
        return _Card(
          child: _InlineLoadError(message: _errorText(result.error)),
        );
      }
      final profile = result.data!;
      final alternatePhones = profile.phoneNumbers
          .where((phone) => phone != profile.phoneNumber)
          .toList(growable: false);
      final alternateEmails = profile.emailAddresses
          .where((email) => email != profile.email)
          .toList(growable: false);
      return _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Your recorded details',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 28,
              runSpacing: 4,
              children: [
                _ProfileDetailGroup(
                  title: 'Contact',
                  lines: [
                    ('Primary phone', _shown(profile.phoneNumber)),
                    if (alternatePhones.isNotEmpty)
                      ('Other phone numbers', alternatePhones.join(', ')),
                    if (profile.workPhoneNumber.isNotEmpty)
                      ('Work phone', profile.workPhoneNumber),
                    ('Primary email', _shown(profile.email)),
                    if (alternateEmails.isNotEmpty)
                      ('Other email addresses', alternateEmails.join(', ')),
                    ('Address', _shown(profile.residentialAddress)),
                  ],
                ),
                _ProfileDetailGroup(
                  title: 'Personal',
                  lines: [
                    if (profile.title.isNotEmpty) ('Title', profile.title),
                    if (profile.dateOfBirth.isNotEmpty)
                      ('Date of birth', _friendlyDate(profile.dateOfBirth)),
                    if (profile.nationalities.isNotEmpty)
                      ('Nationality', profile.nationalities.join(', ')),
                    if (profile.languages.isNotEmpty)
                      ('Languages', profile.languages.join(', ')),
                    if (profile.religion.isNotEmpty)
                      ('Religion', profile.religion),
                    if (profile.occupations.isNotEmpty)
                      ('Occupation', profile.occupations.join(', ')),
                    if (profile.skills.isNotEmpty)
                      ('Skills', profile.skills.join(', ')),
                  ],
                ),
                if (profile.socialAccounts.isNotEmpty)
                  _ProfileDetailGroup(
                    title: 'Social accounts',
                    lines: [
                      for (final account in profile.socialAccounts)
                        (account.platform, account.account),
                    ],
                  ),
                if (profile.proofOfIdType.isNotEmpty ||
                    profile.proofOfIdNumber.isNotEmpty)
                  _ProfileDetailGroup(
                    title: 'Identification',
                    lines: [
                      ('Type', _shown(profile.proofOfIdType)),
                      ('Number', _shown(profile.proofOfIdNumber)),
                    ],
                  ),
              ],
            ),
          ],
        ),
      );
    },
  );
}

class _ProfileDetailGroup extends StatelessWidget {
  const _ProfileDetailGroup({required this.title, required this.lines});
  final String title;
  final List<(String, String)> lines;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 360,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            color: Color(0xFF087F72),
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 6),
        for (final line in lines) _SimpleLine(label: line.$1, value: line.$2),
      ],
    ),
  );
}

String _shown(String value) => value.trim().isEmpty ? 'Not provided' : value;

class _OtherGuardiansCard extends StatefulWidget {
  const _OtherGuardiansCard({required this.api});
  final GuardianPortalApiClient api;

  @override
  State<_OtherGuardiansCard> createState() => _OtherGuardiansCardState();
}

class _OtherGuardiansCardState extends State<_OtherGuardiansCard> {
  late Future<List<HouseholdGuardian>> guardians;
  final Map<String, bool> accessOverrides = {};

  @override
  void initState() {
    super.initState();
    guardians = widget.api.householdGuardians();
  }

  void reload() => setState(() => guardians = widget.api.householdGuardians());

  Future<void> _block(HouseholdGuardian guardian) async {
    final name = guardian.name;
    var reason = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Block $name?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'They will immediately lose access to this household. Their records will not be deleted.',
            ),
            const SizedBox(height: 16),
            TextField(
              key: const Key('guardian-block-reason'),
              maxLines: 3,
              onChanged: (value) => reason = value,
              decoration: const InputDecoration(
                labelText: 'Reason',
                hintText: 'Enter a short reason',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Keep access'),
          ),
          FilledButton(
            key: const Key('confirm-block-guardian'),
            onPressed: () {
              if (reason.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Enter a reason to continue.')),
                );
                return;
              }
              Navigator.pop(context, true);
            },
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFD14343),
            ),
            child: const Text('Block access'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await widget.api.blockGuardian(guardian.guardianId, reason.trim());
        setState(() => accessOverrides[guardian.guardianId] = true);
        reload();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_errorText(error))));
        }
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name can no longer access this household.')),
      );
    }
  }

  Future<void> _restore(HouseholdGuardian guardian) async {
    final name = guardian.name;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Restore access for $name?'),
        content: const Text(
          'They will be able to sign in and access this household again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            key: const Key('confirm-restore-guardian'),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Restore access'),
          ),
        ],
      ),
    );
    if (confirmed == true && mounted) {
      try {
        await widget.api.restoreGuardian(guardian.guardianId);
        setState(() => accessOverrides[guardian.guardianId] = false);
        reload();
      } catch (error) {
        if (mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(_errorText(error))));
        }
        return;
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$name can access this household again.')),
      );
    }
  }

  void _showDetails(HouseholdGuardian guardian) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(22, 0, 22, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              guardian.name,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 16),
            _ProfileLine(
              icon: Icons.phone_outlined,
              label: 'Phone',
              value: guardian.phoneNumber.isEmpty
                  ? 'Not provided'
                  : guardian.phoneNumber,
            ),
            _ProfileLine(
              icon: Icons.email_outlined,
              label: 'Email',
              value: guardian.email.isEmpty ? 'Not provided' : guardian.email,
            ),
            _ProfileLine(
              icon: Icons.lock_outline,
              label: 'Access',
              value: guardian.blocked ? 'Blocked' : 'Active',
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<HouseholdGuardian>>(
      future: guardians,
      builder: (context, result) => _Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Other guardians',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 12),
            if (result.connectionState == ConnectionState.waiting)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: CircularProgressIndicator(),
                ),
              )
            else if (result.hasError)
              _InlineLoadError(message: _errorText(result.error))
            else if ((result.data ?? const []).isEmpty)
              const Text(
                'No other guardians are linked to this household.',
                style: TextStyle(color: Color(0xFF68778C)),
              )
            else
              for (var index = 0; index < result.data!.length; index++) ...[
                _OtherGuardianRow(
                  name: result.data![index].name,
                  phone: result.data![index].phoneNumber,
                  email: result.data![index].email,
                  blocked:
                      accessOverrides[result.data![index].guardianId] ??
                      result.data![index].blocked,
                  canManage: result.data![index].canManage,
                  onView: () => _showDetails(result.data![index]),
                  onToggle: () =>
                      (accessOverrides[result.data![index].guardianId] ??
                          result.data![index].blocked)
                      ? _restore(result.data![index])
                      : _block(result.data![index]),
                ),
                if (index != result.data!.length - 1)
                  const Divider(height: 1, color: Color(0xFFE4E9E8)),
              ],
          ],
        ),
      ),
    );
  }
}

class _OtherGuardianRow extends StatelessWidget {
  const _OtherGuardianRow({
    required this.name,
    required this.phone,
    required this.email,
    required this.blocked,
    required this.canManage,
    required this.onView,
    required this.onToggle,
  });
  final String name;
  final String phone;
  final String email;
  final bool blocked;
  final bool canManage;
  final VoidCallback onView;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 14),
    child: LayoutBuilder(
      builder: (context, constraints) {
        final details = Row(
          children: [
            CircleAvatar(
              backgroundColor: blocked
                  ? const Color(0xFFFFE8E8)
                  : const Color(0xFFE1F3EF),
              foregroundColor: blocked
                  ? const Color(0xFFD14343)
                  : const Color(0xFF087F72),
              child: Text(_initials(name)),
            ),
            const SizedBox(width: 13),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 3),
                  Text(phone, style: const TextStyle(color: Color(0xFF68778C))),
                  Text(
                    email,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF68778C),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
          ],
        );
        final actions = Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton(onPressed: onView, child: const Text('View')),
            OutlinedButton.icon(
              key: Key('${blocked ? 'restore' : 'block'}-guardian-$name'),
              onPressed: canManage ? onToggle : null,
              icon: Icon(
                blocked ? Icons.lock_open_outlined : Icons.block_outlined,
              ),
              label: Text(blocked ? 'Restore access' : 'Block access'),
              style: OutlinedButton.styleFrom(
                foregroundColor: blocked
                    ? const Color(0xFF087F72)
                    : const Color(0xFFD14343),
              ),
            ),
          ],
        );
        if (constraints.maxWidth < 680) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [details, const SizedBox(height: 12), actions],
          );
        }
        return Row(
          children: [
            Expanded(child: details),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: blocked
                    ? const Color(0xFFFFE8E8)
                    : const Color(0xFFE5F5F1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                blocked ? 'Blocked' : 'Active',
                style: TextStyle(
                  color: blocked
                      ? const Color(0xFFD14343)
                      : const Color(0xFF087F72),
                  fontSize: 12,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
            const SizedBox(width: 12),
            actions,
          ],
        );
      },
    ),
  );
}

class _PageScroll extends StatelessWidget {
  const _PageScroll({
    super.key,
    required this.title,
    required this.subtitle,
    required this.children,
  });
  final String title;
  final String subtitle;
  final List<Widget> children;
  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 600;
    return SingleChildScrollView(
      key: PageStorageKey<String>('guardian-page-$title'),
      padding: EdgeInsets.fromLTRB(
        compact ? 16 : 32,
        compact ? 24 : 36,
        compact ? 16 : 32,
        48,
      ),
      child: Align(
        alignment: Alignment.topCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1280),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: compact ? 25 : 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -.5,
                  color: const Color(0xFF172235),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 15,
                  height: 1.45,
                  color: Color(0xFF68778C),
                ),
              ),
              SizedBox(height: compact ? 22 : 28),
              ...children.expand(
                (child) => [child, const SizedBox(height: 18)],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.child, this.color});
  final Widget child;
  final Color? color;
  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: EdgeInsets.all(MediaQuery.sizeOf(context).width < 600 ? 18 : 24),
    decoration: BoxDecoration(
      color: color ?? Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFDEE5E3)),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: .025),
          blurRadius: 18,
          offset: const Offset(0, 5),
        ),
      ],
    ),
    child: child,
  );
}

class _ChildPicker extends StatelessWidget {
  const _ChildPicker({
    required this.children,
    required this.selected,
    required this.onSelected,
  });
  final List<GuardianChildSummary> children;
  final String? selected;
  final ValueChanged<String> onSelected;
  @override
  Widget build(BuildContext context) => Wrap(
    spacing: 10,
    runSpacing: 10,
    children: [
      for (final child in children)
        ChoiceChip(
          label: Text(child.name),
          selected: selected == child.studentId,
          onSelected: (_) => onSelected(child.studentId),
        ),
    ],
  );
}

class _MoneySummary extends StatelessWidget {
  const _MoneySummary({
    required this.label,
    required this.value,
    this.color = const Color(0xFF172235),
  });
  final String label;
  final double value;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: 180,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Color(0xFF68778C))),
        const SizedBox(height: 4),
        Text(
          _money(value),
          style: TextStyle(
            fontSize: 23,
            fontWeight: FontWeight.w900,
            color: color,
          ),
        ),
      ],
    ),
  );
}

class _SimpleLine extends StatelessWidget {
  const _SimpleLine({required this.label, required this.value});
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: Text(label)),
        const SizedBox(width: 12),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _PaymentLine extends StatelessWidget {
  const _PaymentLine({required this.payment});
  final GuardianPayment payment;
  @override
  Widget build(BuildContext context) {
    final status = payment.status.toUpperCase();
    final pending = status == 'PENDING' || status == 'PROCESSING';
    final rejected = status == 'FAILED' || status == 'CANCELLED';
    final reversed = status == 'REVERSED' || status == 'REFUNDED';
    final successful = status == 'COMPLETED' || status == 'PARTIALLY_REFUNDED';
    final icon = pending
        ? Icons.schedule_rounded
        : rejected
        ? Icons.cancel_outlined
        : reversed
        ? Icons.undo_rounded
        : Icons.check_circle_outline;
    final statusColor = pending
        ? const Color(0xFFD97706)
        : rejected || reversed
        ? const Color(0xFFD94A4A)
        : const Color(0xFF087F72);
    final statusLabel = pending
        ? 'Pending confirmation'
        : rejected
        ? 'Rejected'
        : reversed
        ? 'Reversed'
        : successful
        ? 'Paid'
        : status.isEmpty
        ? 'Recorded'
        : status.replaceAll('_', ' ').toLowerCase();
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF7F9F9),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, color: statusColor),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _money(payment.amount),
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                Text(
                  statusLabel,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
                Text(
                  '${_friendlyDate(payment.date)} · ${payment.method.isEmpty ? 'Payment' : payment.method}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF68778C),
                  ),
                ),
                if (payment.reference.isNotEmpty)
                  Text(
                    '${successful ? 'Receipt' : 'Reference'} ${payment.reference}',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF68778C),
                    ),
                  ),
              ],
            ),
          ),
          if (pending)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF1D6),
                borderRadius: BorderRadius.circular(999),
              ),
              child: const Text(
                'Pending verification',
                style: TextStyle(
                  color: Color(0xFF9A6200),
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProfileLine extends StatelessWidget {
  const _ProfileLine({
    required this.icon,
    required this.label,
    required this.value,
  });
  final IconData icon;
  final String label;
  final String value;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        Icon(icon, color: const Color(0xFF087F72)),
        const SizedBox(width: 13),
        SizedBox(
          width: 70,
          child: Text(label, style: const TextStyle(color: Color(0xFF68778C))),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ),
      ],
    ),
  );
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });
  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;
  @override
  Widget build(BuildContext context) => _Card(
    child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 28),
      child: Column(
        children: [
          Icon(icon, size: 40, color: const Color(0xFF8793A4)),
          const SizedBox(height: 12),
          Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Color(0xFF68778C), height: 1.4),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.refresh_rounded),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    ),
  );
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) => const _Card(
    child: Padding(
      padding: EdgeInsets.all(28),
      child: Center(child: CircularProgressIndicator()),
    ),
  );
}

class _FriendlyError extends StatelessWidget {
  const _FriendlyError({
    required this.message,
    required this.onRetry,
    this.onSignInAgain,
  });
  final String message;
  final VoidCallback onRetry;
  final VoidCallback? onSignInAgain;
  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: _Card(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.cloud_off_outlined,
                size: 42,
                color: Color(0xFF8793A4),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(height: 1.4),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('Try again'),
              ),
              if (onSignInAgain != null) ...[
                const SizedBox(height: 8),
                TextButton(
                  key: const Key('guardian-sign-in-again'),
                  onPressed: onSignInAgain,
                  child: const Text('Sign in again'),
                ),
              ],
            ],
          ),
        ),
      ),
    ),
  );
}

Future<void> _showMessageComposer(BuildContext context) async {
  var category = 'General enquiry';
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (context, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          0,
          22,
          22 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'New message',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              const Text(
                'Choose a topic and the school will route your message to the right office.',
                style: TextStyle(color: Color(0xFF68778C), height: 1.4),
              ),
              const SizedBox(height: 18),
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(labelText: 'Message about'),
                items:
                    const [
                          'General enquiry',
                          'Fees and payments',
                          'Academics or homework',
                          'Attendance',
                          'Student welfare',
                        ]
                        .map(
                          (item) =>
                              DropdownMenuItem(value: item, child: Text(item)),
                        )
                        .toList(growable: false),
                onChanged: (value) {
                  if (value != null) {
                    setSheetState(() => category = value);
                  }
                },
              ),
              const SizedBox(height: 13),
              const TextField(
                decoration: InputDecoration(labelText: 'Subject'),
              ),
              const SizedBox(height: 13),
              const TextField(
                minLines: 4,
                maxLines: 6,
                decoration: InputDecoration(
                  labelText: 'Message',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(sheetContext).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(sheetContext).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Message sending will be connected after this design is approved.',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.send_outlined),
                      label: const Text('Send message'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

// Kept for the future payment-provider connection.
// ignore: unused_element
Future<void> _showPaymentSheet(
  BuildContext context,
  GuardianPortalSnapshot data,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.fromLTRB(
        22,
        0,
        22,
        22 + MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 660),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Pay school fees',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 5),
            const Text(
              'Choose the child and amount. Each child’s payment will receive its own receipt.',
              style: TextStyle(color: Color(0xFF68778C), height: 1.4),
            ),
            const SizedBox(height: 18),
            for (final child in data.children)
              Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFA),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE1E7E5)),
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: const Color(0xFFE1F3EF),
                      foregroundColor: const Color(0xFF087F72),
                      child: Text(
                        _initials(child.name),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            child.name,
                            style: const TextStyle(fontWeight: FontWeight.w800),
                          ),
                          Text(
                            child.balance == 0
                                ? 'Fees settled'
                                : 'Balance ${_money(child.balance)}',
                            style: const TextStyle(
                              color: Color(0xFF68778C),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(
                      width: 150,
                      child: TextField(
                        keyboardType: const TextInputType.numberWithOptions(
                          decimal: true,
                        ),
                        decoration: const InputDecoration(
                          labelText: 'Amount',
                          prefixText: 'GH₵ ',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 8),
            const Text(
              'Payment method',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            const Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  avatar: Icon(Icons.phone_android_outlined, size: 17),
                  label: Text('Mobile money'),
                ),
                Chip(
                  avatar: Icon(Icons.credit_card_outlined, size: 17),
                  label: Text('Card'),
                ),
                Chip(
                  avatar: Icon(Icons.account_balance_outlined, size: 17),
                  label: Text('Bank'),
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () {
                  Navigator.of(sheetContext).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'No payment was started. Payment processing will be connected after design approval.',
                      ),
                    ),
                  );
                },
                icon: const Icon(Icons.arrow_forward_rounded),
                label: const Text('Continue to payment'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

Future<bool> _showProfileEditor(
  BuildContext context,
  GuardianPortalApiClient api,
) async {
  GuardianProfile profile;
  try {
    profile = await api.profile();
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(_errorText(error))));
    }
    return false;
  }
  if (!context.mounted) return false;
  final email = TextEditingController(text: profile.email);
  final phone = TextEditingController(text: profile.phoneNumber);
  final address = TextEditingController(text: profile.residentialAddress);
  final occupation = TextEditingController(
    text: profile.occupations.join(', '),
  );
  var emailNotices = profile.emailNotifications;
  var smsNotices = profile.smsNotifications;
  var saving = false;
  final changed = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => StatefulBuilder(
      builder: (sheetContext, setSheetState) => Padding(
        padding: EdgeInsets.fromLTRB(
          22,
          0,
          22,
          22 + MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 620),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Edit contact details',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 5),
              const Text(
                'Official names and identity information must be corrected through the school office.',
                style: TextStyle(color: Color(0xFF68778C), height: 1.4),
              ),
              const SizedBox(height: 18),
              TextFormField(
                controller: email,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 13),
              TextFormField(
                controller: phone,
                decoration: const InputDecoration(labelText: 'Phone number'),
              ),
              const SizedBox(height: 13),
              TextField(
                controller: address,
                minLines: 2,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: 'Home address',
                  alignLabelWithHint: true,
                ),
              ),
              const SizedBox(height: 13),
              TextField(
                controller: occupation,
                decoration: const InputDecoration(
                  labelText: 'Occupation',
                  hintText: 'Separate multiple entries with commas',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Email notifications'),
                value: emailNotices,
                onChanged: (value) => setSheetState(() => emailNotices = value),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('SMS notifications'),
                value: smsNotices,
                onChanged: (value) => setSheetState(() => smsNotices = value),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: saving
                      ? null
                      : () async {
                          if (email.text.trim().isEmpty) {
                            ScaffoldMessenger.of(sheetContext).showSnackBar(
                              const SnackBar(
                                content: Text('Enter an email address.'),
                              ),
                            );
                            return;
                          }
                          setSheetState(() => saving = true);
                          try {
                            await api.updateProfile(
                              email: email.text.trim(),
                              phoneNumber: phone.text.trim(),
                              residentialAddress: address.text.trim(),
                              occupations: occupation.text
                                  .split(',')
                                  .map((v) => v.trim())
                                  .where((v) => v.isNotEmpty)
                                  .toList(),
                              emailNotifications: emailNotices,
                              smsNotifications: smsNotices,
                            );
                            if (sheetContext.mounted) {
                              Navigator.of(sheetContext).pop(true);
                            }
                          } catch (error) {
                            if (sheetContext.mounted) {
                              setSheetState(() => saving = false);
                              ScaffoldMessenger.of(sheetContext).showSnackBar(
                                SnackBar(content: Text(_errorText(error))),
                              );
                            }
                          }
                        },
                  child: Text(saving ? 'Saving…' : 'Save changes'),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  email.dispose();
  phone.dispose();
  address.dispose();
  occupation.dispose();
  if (changed == true && context.mounted) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Your details were updated.')));
  }
  return changed == true;
}

Future<void> _showAttendance(
  BuildContext context,
  GuardianPortalApiClient api,
  GuardianChildSummary child,
) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) => SafeArea(
      child: SizedBox(
        height: child.attendanceDays == 0 ? 260 : 620,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${child.name} — attendance',
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                child.attendanceDays == 0
                    ? 'No attendance has been recorded this term.'
                    : '${child.presentDays} present · ${child.lateDays} late · ${child.absentDays} absent · ${child.excusedDays} excused',
                style: const TextStyle(color: Color(0xFF68778C)),
              ),
              const SizedBox(height: 16),
              Expanded(
                child: FutureBuilder<List<GuardianAttendanceItem>>(
                  future: api.attendance(child.studentId),
                  builder: (context, value) {
                    if (value.connectionState == ConnectionState.waiting) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (value.hasError) {
                      return Center(child: Text(_errorText(value.error)));
                    }
                    if (value.data!.isEmpty) {
                      return const Center(
                        child: Text(
                          'No attendance records yet.',
                          style: TextStyle(color: Color(0xFF68778C)),
                        ),
                      );
                    }
                    return ListView.separated(
                      itemCount: value.data!.length,
                      separatorBuilder: (_, __) => const Divider(),
                      itemBuilder: (context, index) {
                        final item = value.data![index];
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            _attendanceIcon(item.status),
                            color: _attendanceColor(item.status),
                          ),
                          title: Text(_friendlyDate(item.date)),
                          subtitle: item.note.isEmpty ? null : Text(item.note),
                          trailing: Text(
                            _attendanceLabel(item.status),
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _attendanceColor(item.status),
                            ),
                          ),
                        );
                      },
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

Future<void> _openReport(
  BuildContext context,
  GuardianPortalApiClient api,
  GuardianPortalSnapshot data,
  GuardianChildSummary child, {
  int? termId,
  int? academicYearId,
}) async {
  prepareDocumentWindow();
  try {
    final bytes = await api.report(
      studentId: child.studentId,
      termId: termId ?? data.termId,
      academicYearId: academicYearId ?? data.academicYearId,
    );
    await openDocumentBytes(
      bytes,
      'application/pdf',
      '${child.name}-report-card.pdf',
    );
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(_errorText(error))));
  }
}

String _errorText(Object? error) => error is GuardianPortalException
    ? error.message
    : 'Something went wrong. Please try again.';
String _firstName(String value) =>
    value.trim().split(RegExp(r'\s+')).firstOrNull ?? 'there';
String _initials(String value) => value
    .trim()
    .split(RegExp(r'\s+'))
    .where((item) => item.isNotEmpty)
    .take(2)
    .map((item) => item[0].toUpperCase())
    .join();
String _money(double amount) =>
    'GH₵ ${amount.toStringAsFixed(amount == amount.roundToDouble() ? 0 : 2)}';
String _friendlyDate(String value) {
  final date = DateTime.tryParse(value);
  if (date == null) return value;
  const months = [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ];
  return '${date.day} ${months[date.month - 1]} ${date.year}';
}

String _attendanceLabel(String value) => switch (value.toUpperCase()) {
  'PRESENT' => 'Present',
  'LATE' => 'Late',
  'ABSENT' => 'Absent',
  'EXCUSED' => 'Excused',
  _ => value,
};
String _guardianReportStatus(String value) => switch (value.toUpperCase()) {
  'PUBLISHED' => 'Published',
  'GENERATED' => 'Preparing',
  'DRAFT' => 'Preparing',
  'NOT_GENERATED' => 'Not ready',
  'UPDATING' => 'School updating',
  _ => value.isEmpty ? 'Not ready' : value,
};
IconData _attendanceIcon(String value) => switch (value.toUpperCase()) {
  'PRESENT' => Icons.check_circle_outline,
  'LATE' => Icons.schedule_outlined,
  'ABSENT' => Icons.cancel_outlined,
  'EXCUSED' => Icons.info_outline,
  _ => Icons.circle_outlined,
};
Color _attendanceColor(String value) => switch (value.toUpperCase()) {
  'PRESENT' => const Color(0xFF087F72),
  'LATE' => const Color(0xFFD97706),
  'ABSENT' => const Color(0xFFDC3E45),
  _ => const Color(0xFF68778C),
};
