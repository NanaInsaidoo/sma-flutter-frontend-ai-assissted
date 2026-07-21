import 'package:flutter/material.dart';

import '../../classes/presentation/class_stream_settings_screen.dart';
import '../../theme/app_theme.dart';

enum _SchoolSettingPage { hub, streamCapacity, classTeachers }

class SchoolSettingsScreen extends StatefulWidget {
  const SchoolSettingsScreen({
    super.key,
    required this.customSchoolId,
    this.accessToken,
    this.onRefreshAccessToken,
  });

  final String customSchoolId;
  final String? accessToken;
  final Future<String?> Function()? onRefreshAccessToken;

  @override
  State<SchoolSettingsScreen> createState() => _SchoolSettingsScreenState();
}

class _SchoolSettingsScreenState extends State<SchoolSettingsScreen> {
  _SchoolSettingPage _page = _SchoolSettingPage.hub;

  @override
  Widget build(BuildContext context) {
    if (_page == _SchoolSettingPage.streamCapacity) {
      return ClassStreamSettingsScreen(
        customSchoolId: widget.customSchoolId,
        accessToken: widget.accessToken,
        onRefreshAccessToken: widget.onRefreshAccessToken,
        onBack: () => setState(() => _page = _SchoolSettingPage.hub),
      );
    }
    if (_page == _SchoolSettingPage.classTeachers) {
      return ClassTeacherSettingsScreen(
        customSchoolId: widget.customSchoolId,
        accessToken: widget.accessToken,
        onRefreshAccessToken: widget.onRefreshAccessToken,
        onBack: () => setState(() => _page = _SchoolSettingPage.hub),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Settings',
            style: TextStyle(
              color: AppColors.text,
              fontSize: 30,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Manage school-wide configuration that affects daily operations.',
            style: TextStyle(color: AppColors.muted, fontSize: 15),
          ),
          const SizedBox(height: 24),
          _SettingsGroup(
            title: 'Academic setup',
            description:
                'Configure the school structure, terms, timetable foundations, and classroom ownership.',
            children: [
              _SettingsTile(
                icon: Icons.reduce_capacity_rounded,
                color: AppColors.green,
                title: 'Stream Capacity',
                description:
                    'Set the maximum number of students each stream can hold.',
                status: 'Available',
                actionLabel: 'Edit',
                summary: const [
                  _SettingSummary(label: 'Source', value: 'Live stream data'),
                  _SettingSummary(label: 'Scope', value: 'Per stream'),
                  _SettingSummary(label: 'Save mode', value: 'Batch update'),
                ],
                onTap: () =>
                    setState(() => _page = _SchoolSettingPage.streamCapacity),
              ),
              _SettingsTile(
                icon: Icons.assignment_ind_rounded,
                color: AppColors.amber,
                title: 'Class Teacher Assignments',
                description:
                    'Assign primary and supporting class teachers per stream.',
                status: 'Available',
                actionLabel: 'Manage',
                summary: const [
                  _SettingSummary(label: 'Source', value: 'Live staff data'),
                  _SettingSummary(label: 'Primary teacher', value: 'Supported'),
                  _SettingSummary(label: 'Scope', value: 'Per stream'),
                ],
                onTap: () =>
                    setState(() => _page = _SchoolSettingPage.classTeachers),
              ),
              _SettingsTile(
                icon: Icons.calendar_month_rounded,
                color: AppColors.blue,
                title: 'Academic Term Settings',
                description:
                    'Manage academic years, active term dates, school days, holidays, and term rollover.',
                status: 'Planned',
                actionLabel: 'Review',
                summary: const [
                  _SettingSummary(label: 'Current term', value: 'From API'),
                  _SettingSummary(label: 'School days', value: 'Planned'),
                  _SettingSummary(label: 'Rollover', value: 'Planned'),
                ],
                onTap: () => _showComingSoon('Academic Term Settings'),
              ),
              _SettingsTile(
                icon: Icons.schedule_rounded,
                color: AppColors.purple,
                title: 'Timetable Settings',
                description:
                    'Define periods, break times, school day start/end times, and timetable rules.',
                status: 'Planned',
                actionLabel: 'Review',
                summary: const [
                  _SettingSummary(label: 'Periods', value: 'Planned'),
                  _SettingSummary(label: 'Breaks', value: 'Planned'),
                  _SettingSummary(label: 'Rules', value: 'Planned'),
                ],
                onTap: () => _showComingSoon('Timetable Settings'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SettingsGroup(
            title: 'Admissions & student records',
            description:
                'Control onboarding rules and student profile defaults across the school.',
            children: [
              _SettingsTile(
                icon: Icons.person_add_alt_1_rounded,
                color: AppColors.amber,
                title: 'Admission Settings',
                description:
                    'Configure required applicant documents, admission approval rules, and household defaults.',
                status: 'Planned',
                actionLabel: 'Review',
                summary: const [
                  _SettingSummary(label: 'Households', value: 'Enabled'),
                  _SettingSummary(label: 'Approvals', value: 'Planned'),
                  _SettingSummary(label: 'Documents', value: 'Planned'),
                ],
                onTap: () => _showComingSoon('Admission Settings'),
              ),
              _SettingsTile(
                icon: Icons.medical_information_outlined,
                color: AppColors.red,
                title: 'Medical & Vaccination Lookups',
                description:
                    'Review school-visible medical conditions, allergies, vaccinations, and required notes.',
                status: 'Planned',
                actionLabel: 'Review',
                summary: const [
                  _SettingSummary(label: 'Medical conditions', value: 'Lookup'),
                  _SettingSummary(label: 'Vaccinations', value: 'Lookup'),
                  _SettingSummary(label: 'Allergies', value: 'Lookup'),
                ],
                onTap: () => _showComingSoon('Medical & Vaccination Lookups'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SettingsGroup(
            title: 'Finance & requirements',
            description:
                'Set defaults for fee operations and class supply requirements.',
            children: [
              _SettingsTile(
                icon: Icons.account_balance_wallet_rounded,
                color: AppColors.green,
                title: 'Fee Defaults',
                description:
                    'Configure receipt numbering, payment methods, adjustment approval rules, and arrears handling.',
                status: 'Planned',
                actionLabel: 'Review',
                summary: const [
                  _SettingSummary(label: 'Receipts', value: 'Planned'),
                  _SettingSummary(label: 'Adjustments', value: 'Planned'),
                  _SettingSummary(label: 'Arrears', value: 'Planned'),
                ],
                onTap: () => _showComingSoon('Fee Defaults'),
              ),
              _SettingsTile(
                icon: Icons.inventory_2_outlined,
                color: AppColors.amber,
                title: 'Items & Supplies Defaults',
                description:
                    'Set default units, cash-equivalent rules, notification methods, and carry-forward behaviour.',
                status: 'Planned',
                actionLabel: 'Review',
                summary: const [
                  _SettingSummary(label: 'Units', value: 'Planned'),
                  _SettingSummary(label: 'Cash equivalent', value: 'Planned'),
                  _SettingSummary(label: 'Carry forward', value: 'Planned'),
                ],
                onTap: () => _showComingSoon('Items & Supplies Defaults'),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SettingsGroup(
            title: 'Communication & access',
            description:
                'Manage notification preferences and user access policies.',
            children: [
              _SettingsTile(
                icon: Icons.notifications_active_outlined,
                color: AppColors.blue,
                title: 'Notification Settings',
                description:
                    'Configure default guardian notification channels: SMS, WhatsApp, email, calls, or letters.',
                status: 'Planned',
                actionLabel: 'Review',
                summary: const [
                  _SettingSummary(label: 'Default channel', value: 'Planned'),
                  _SettingSummary(label: 'Guardian alerts', value: 'Planned'),
                  _SettingSummary(label: 'Templates', value: 'Planned'),
                ],
                onTap: () => _showComingSoon('Notification Settings'),
              ),
              _SettingsTile(
                icon: Icons.security_rounded,
                color: AppColors.purple,
                title: 'Role & Permission Settings',
                description:
                    'Manage school staff roles, approval rules, and access restrictions.',
                status: 'Planned',
                actionLabel: 'Review',
                summary: const [
                  _SettingSummary(label: 'Roles', value: 'School staff'),
                  _SettingSummary(label: 'Approvals', value: 'Planned'),
                  _SettingSummary(label: 'Access rules', value: 'Planned'),
                ],
                onTap: () => _showComingSoon('Role & Permission Settings'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showComingSoon(String title) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          '$title will be connected when that settings API is ready.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({
    required this.title,
    required this.description,
    required this.children,
  });

  final String title;
  final String description;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                color: AppColors.text,
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 4),
            Text(description, style: const TextStyle(color: AppColors.muted)),
            const SizedBox(height: 16),
            Column(
              children: children
                  .map(
                    (child) => Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: child,
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.status,
    required this.actionLabel,
    required this.summary,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final String status;
  final String actionLabel;
  final List<_SettingSummary> summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final available = status == 'Available';
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: .025),
              blurRadius: 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final compact = constraints.maxWidth < 720;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: .12),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Icon(icon, color: color),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 10,
                            runSpacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                title,
                                style: const TextStyle(
                                  color: AppColors.text,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 18,
                                ),
                              ),
                              _StatusBadge(label: status, available: available),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            description,
                            style: const TextStyle(
                              color: AppColors.muted,
                              fontSize: 14,
                              height: 1.35,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!compact) ...[
                      const SizedBox(width: 18),
                      _SettingsActionButton(
                        label: actionLabel,
                        available: available,
                        onPressed: onTap,
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 18),
                Wrap(
                  spacing: 18,
                  runSpacing: 14,
                  children: summary
                      .map(
                        (item) => SizedBox(
                          width: compact
                              ? double.infinity
                              : (constraints.maxWidth - 36) / 3,
                          child: _SettingSummaryBlock(item: item),
                        ),
                      )
                      .toList(),
                ),
                if (compact) ...[
                  const SizedBox(height: 16),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: _SettingsActionButton(
                      label: actionLabel,
                      available: available,
                      onPressed: onTap,
                    ),
                  ),
                ],
              ],
            );
          },
        ),
      ),
    );
  }
}

class _SettingSummary {
  const _SettingSummary({required this.label, required this.value});

  final String label;
  final String value;
}

class _SettingSummaryBlock extends StatelessWidget {
  const _SettingSummaryBlock({required this.item});

  final _SettingSummary item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.muted,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: .4,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AppColors.text,
              fontSize: 15,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsActionButton extends StatelessWidget {
  const _SettingsActionButton({
    required this.label,
    required this.available,
    required this.onPressed,
  });

  final String label;
  final bool available;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: available ? AppColors.green : AppColors.muted,
        side: BorderSide(color: available ? AppColors.green : AppColors.border),
      ),
      child: Text(label),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.label, required this.available});

  final String label;
  final bool available;

  @override
  Widget build(BuildContext context) {
    final color = available ? AppColors.green : AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: .12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}
