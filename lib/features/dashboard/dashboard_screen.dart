import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';
import 'dart:ui' as ui;
import 'dart:typed_data';

import '../../auth/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_theme_controller.dart';
import '../../core/utils/rtl_support.dart';
import '../../core/services/data_sync_service.dart';
import '../../core/services/whatsapp_service.dart';

import '../../data/models/member.dart';
import '../../data/models/membership_plan.dart';
import '../../data/models/membership.dart';
import '../../data/models/payment.dart';
import '../../data/models/gym.dart';
import '../../data/models/user_profile.dart';
import '../../widgets/member_photo.dart';

/// Navigation Tab state provider
final selectedTabProvider = StateProvider<int>((ref) => 0);

/// Filter selection for members tab
final memberFilterProvider = StateProvider<String>((ref) => 'all');

String _memberInitial(String fullName) {
  final trimmedName = fullName.trim();
  return trimmedName.isEmpty ? '؟' : trimmedName[0];
}

Future<void> _saveTheme(
  BuildContext context,
  WidgetRef ref,
  AppThemeVariant? variant,
) async {
  if (variant == null) return;
  try {
    await ref.read(appThemeProvider.notifier).setTheme(variant);
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('تعذر حفظ المظهر: $error'),
        backgroundColor: context.appPalette.error,
      ),
    );
  }
}

String _normalizeSearchDigits(String value) {
  return String.fromCharCodes(value.runes.map((rune) {
    if (rune >= 0x0660 && rune <= 0x0669) return rune - 0x0660 + 0x30;
    if (rune >= 0x06F0 && rune <= 0x06F9) return rune - 0x06F0 + 0x30;
    return rune;
  })).toLowerCase();
}

bool memberMatchesSearch(Member member, String query) {
  final normalizedQuery = _normalizeSearchDigits(query.trim());
  if (normalizedQuery.isEmpty) return true;
  final normalizedName = _normalizeSearchDigits(member.fullName);
  final phoneQuery = normalizedQuery.replaceAll(RegExp(r'[^0-9]'), '');
  final phone = _normalizeSearchDigits(member.phone ?? '')
      .replaceAll(RegExp(r'[^0-9]'), '');
  return normalizedName.contains(normalizedQuery) ||
      (phoneQuery.isNotEmpty && phone.contains(phoneQuery));
}

class DashboardQuickActions extends StatelessWidget {
  final VoidCallback onAddMember;
  final VoidCallback onNewSubscription;
  final VoidCallback onRecordPayment;

  const DashboardQuickActions({
    super.key,
    required this.onAddMember,
    required this.onNewSubscription,
    required this.onRecordPayment,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: onAddMember,
            icon: const Icon(Icons.person_add_rounded, size: 18),
            label: const Text('إضافة عضو'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onNewSubscription,
            icon: const Icon(Icons.card_membership_rounded, size: 18),
            label: const Text('اشتراك جديد'),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: OutlinedButton.icon(
            onPressed: onRecordPayment,
            icon: const Icon(Icons.payment_rounded, size: 18),
            label: const Text('تسجيل دفعة'),
          ),
        ),
      ],
    );
  }
}

/// Production interactive Dashboard Screen for Gym ElDeeb (جيم الديب)
class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final currentTab = ref.watch(selectedTabProvider);
    final syncService = ref.watch(dataSyncServiceProvider);
    final profile = ref.watch(currentProfileProvider);

    final drawerWidget = Drawer(
      backgroundColor: context.appPalette.background,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  context.appPalette.surfaceCard,
                  context.appPalette.background
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: context.appPalette.primary,
              child: Text(
                _memberInitial(profile?.fullName ?? 'د'),
                style: const TextStyle(
                  color: Color(0xFF0F141C),
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                ),
              ),
            ),
            accountName: Text(
              profile?.fullName.isNotEmpty == true
                  ? profile!.fullName
                  : 'كابتن جيم الديب',
              style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: context.appPalette.textPrimary),
            ),
            accountEmail: Text(
              'فريق جيم الديب',
              style: TextStyle(
                  color: context.appPalette.textSecondary, fontSize: 12),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(0, 'الرئيسية والإحصائيات',
                    Icons.dashboard_rounded, currentTab),
                _buildDrawerItem(
                    1, 'إدارة الأعضاء', Icons.people_alt_rounded, currentTab),
                _buildDrawerItem(2, 'خطط الاشتراكات',
                    Icons.card_membership_rounded, currentTab),
                _buildDrawerItem(3, 'الاشتراكات الحالية',
                    Icons.sports_gymnastics_rounded, currentTab),
                _buildDrawerItem(7, 'اشتراكات قاربت على الانتهاء',
                    Icons.alarm_rounded, currentTab),
                _buildDrawerItem(
                    4, 'سجل المدفوعات', Icons.payments_rounded, currentTab),
                _buildDrawerItem(6, 'الملف الشخصي والإعدادات',
                    Icons.settings_rounded, currentTab),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading:
                Icon(Icons.logout_rounded, color: context.appPalette.error),
            title: Text('تسجيل الخروج',
                style: TextStyle(
                    color: context.appPalette.error,
                    fontWeight: FontWeight.bold)),
            onTap: () => _confirmLogout(context),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );

    return Scaffold(
      key: _scaffoldKey,
      drawer: drawerWidget,
      appBar: AppBar(
        title: Text(_getTabTitle(currentTab)),
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        ),
        actions: [
          if (syncService.isOffline)
            Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  Icon(Icons.wifi_off_rounded,
                      color: context.appPalette.error, size: 18),
                  SizedBox(width: 4),
                  Text('أوفلاين',
                      style: TextStyle(
                          color: context.appPalette.error,
                          fontSize: 11,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          IconButton(
            icon: syncService.syncStatus == SyncStatus.syncing
                ? SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor:
                            AlwaysStoppedAnimation(context.appPalette.primary)),
                  )
                : const Icon(Icons.sync_rounded),
            tooltip: 'تحديث البيانات',
            onPressed: syncService.syncStatus == SyncStatus.syncing
                ? null
                : () => syncService.syncAll(forceRetry: true),
          ),
        ],
      ),
      body: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: _buildBody(currentTab),
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentTab > 3 ? 0 : currentTab,
        onTap: (index) {
          ref.read(selectedTabProvider.notifier).state = index;
        },
        backgroundColor: context.appPalette.surface,
        selectedItemColor: context.appPalette.primary,
        unselectedItemColor: context.appPalette.textMuted,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(
              icon: Icon(Icons.dashboard_rounded), label: 'الرئيسية'),
          BottomNavigationBarItem(
              icon: Icon(Icons.people_alt_rounded), label: 'الأعضاء'),
          BottomNavigationBarItem(
              icon: Icon(Icons.card_membership_rounded), label: 'الخطط'),
          BottomNavigationBarItem(
              icon: Icon(Icons.sports_gymnastics_rounded), label: 'الاشتراكات'),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
      int tabIndex, String label, IconData icon, int currentTab) {
    final isSelected = tabIndex == currentTab;
    return ListTile(
      leading: Icon(icon,
          color: isSelected
              ? context.appPalette.primary
              : context.appPalette.textSecondary),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected
              ? context.appPalette.primary
              : context.appPalette.textPrimary,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onTap: () {
        ref.read(selectedTabProvider.notifier).state = tabIndex;
        Navigator.pop(context);
      },
    );
  }

  String _getTabTitle(int tab) {
    switch (tab) {
      case 0:
        return 'لوحة إحصائيات جيم الديب';
      case 1:
        return 'الأعضاء';
      case 2:
        return 'خطط وباقات الاشتراكات';
      case 3:
        return 'سجل الاشتراكات الفعالة';
      case 4:
        return 'سجل المدفوعات والإيرادات';
      case 6:
        return 'الإعدادات والملف الشخصي';
      case 7:
        return 'اشتراكات قاربت على الانتهاء';
      default:
        return 'جيم الديب';
    }
  }

  Widget _buildBody(int tab) {
    switch (tab) {
      case 0:
        return const _DashboardOverviewTab();
      case 1:
        return const _MembersTab();
      case 2:
        return const _PlansTab();
      case 3:
        return const _MembershipsTab();
      case 4:
        return const _PaymentsTab();
      case 6:
        return const _SettingsTab();
      case 7:
        return const _ExpiringMembershipsTab();
      default:
        return const Center(child: Text('جيم الديب'));
    }
  }

  void _confirmLogout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: context.appPalette.surfaceCard,
          title: const Text('تسجيل الخروج'),
          content:
              const Text('هل أنت متأكد من رغبتك في تسجيل الخروج من جيم الديب؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: context.appPalette.error),
              onPressed: () async {
                Navigator.pop(ctx);
                await ref.read(authNotifierProvider.notifier).signOut();
                if (context.mounted) context.go('/login');
              },
              child: const Text('تسجيل الخروج',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// --- TAB 0: DASHBOARD OVERVIEW ---
// ==========================================
class _DashboardOverviewTab extends ConsumerWidget {
  const _DashboardOverviewTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(dataSyncServiceProvider);

    final totalMembers = data.members.length;
    final activeMembers = data.members.where((m) => m.isActive).length;
    final inactiveMembers = totalMembers - activeMembers;

    final now = DateTime.now();
    final expiringSoonMemberships =
        expiringMembershipsWithinDays(data.memberships, now);

    final today = DateTime(now.year, now.month, now.day);
    final todayPayments = data.payments.where((p) {
      final payDate = DateTime(p.paidAt.year, p.paidAt.month, p.paidAt.day);
      return payDate.isAtSameMomentAs(today);
    }).toList();
    final todayRevenue =
        todayPayments.fold<double>(0, (sum, p) => sum + p.amount);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (data.syncStatus == SyncStatus.error)
            Container(
              key: const ValueKey('dashboard-pending-sync-banner'),
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: context.appPalette.error.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                    color: context.appPalette.error.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      color: context.appPalette.error),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'فيه بيانات لسه متسجلتش على الحساب. هنحاول تاني لما الاتصال يستقر.',
                      style: TextStyle(
                          color: context.appPalette.error, fontSize: 13),
                    ),
                  ),
                ],
              ),
            ),

          GridView.count(
            crossAxisCount: 2,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.35,
            children: [
              _buildClickableStatCard(
                context: context,
                label: 'إجمالي المشتركين',
                value: '$totalMembers',
                icon: Icons.people_rounded,
                color: context.appPalette.primary,
                onTap: () {
                  ref.read(memberFilterProvider.notifier).state = 'all';
                  ref.read(selectedTabProvider.notifier).state = 1;
                },
              ),
              _buildClickableStatCard(
                context: context,
                label: 'المشتركون النشطون',
                value: '$activeMembers',
                icon: Icons.check_circle_outline_rounded,
                color: context.appPalette.success,
                onTap: () {
                  ref.read(memberFilterProvider.notifier).state = 'active';
                  ref.read(selectedTabProvider.notifier).state = 1;
                },
              ),
              _buildClickableStatCard(
                context: context,
                label: 'غير النشطين',
                value: '$inactiveMembers',
                icon: Icons.cancel_outlined,
                color: context.appPalette.textMuted,
                onTap: () {
                  ref.read(memberFilterProvider.notifier).state = 'inactive';
                  ref.read(selectedTabProvider.notifier).state = 1;
                },
              ),
              _buildClickableStatCard(
                context: context,
                label: 'ينتهي قريباً (٧ أيام)',
                value: '${expiringSoonMemberships.length}',
                icon: Icons.alarm_rounded,
                color: context.appPalette.warning,
                onTap: () {
                  ref.read(selectedTabProvider.notifier).state = 7;
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Quick Actions Card
          Card(
            color: context.appPalette.surfaceCard,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'إجراءات سريعة',
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                              color: context.appPalette.textPrimary),
                        ),
                      ),
                      SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'جيم الديب',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.end,
                          style: TextStyle(
                              fontSize: 11,
                              color: context.appPalette.primary,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  DashboardQuickActions(
                    onAddMember: () {
                      showDialog<void>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const _AddMemberDialog(),
                      );
                    },
                    onNewSubscription: () {
                      showDialog<void>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const _AddMembershipDialog(),
                      );
                    },
                    onRecordPayment: () {
                      showDialog<void>(
                        context: context,
                        barrierDismissible: false,
                        builder: (_) => const _AddPaymentDialog(),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),

          InkWell(
            onTap: () => ref.read(selectedTabProvider.notifier).state = 4,
            borderRadius: BorderRadius.circular(16),
            child: Card(
              color: context.appPalette.surfaceCard,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  'إيرادات اليوم المستلمة',
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                      color: context.appPalette.textSecondary,
                                      fontSize: 13),
                                ),
                              ),
                              SizedBox(width: 6),
                              Icon(Icons.arrow_forward_ios_rounded,
                                  size: 12,
                                  color: context.appPalette.textMuted),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            RtlSupport.formatEgp(todayRevenue),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: context.appPalette.success),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    CircleAvatar(
                      radius: 26,
                      backgroundColor:
                          context.appPalette.success.withValues(alpha: 0.15),
                      child: Icon(Icons.monetization_on_rounded,
                          color: context.appPalette.success, size: 28),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          Row(
            children: [
              const Expanded(
                child: Text(
                  'آخر الأعضاء المسجلين',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              TextButton(
                onPressed: () =>
                    ref.read(selectedTabProvider.notifier).state = 1,
                child: Text('عرض الكل',
                    style: TextStyle(
                        color: context.appPalette.primary, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (data.members.isEmpty)
            _buildEmptyCard(context, 'لا يوجد أعضاء مسجلين بعد.')
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: data.members.length > 4 ? 4 : data.members.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final member = data.members[index];
                return ListTile(
                  tileColor: context.appPalette.surfaceCard,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  leading: MemberPhotoAvatar(
                    gymId: member.gymId,
                    fullName: member.fullName,
                    photoPath: member.photoPath,
                    radius: 22,
                  ),
                  title: Text(member.fullName,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text(
                      'انضمام: ${RtlSupport.formatDate(member.joinDate)}',
                      style: const TextStyle(fontSize: 11)),
                  trailing: Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: context.appPalette.textMuted),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: context.appPalette.surfaceCard,
                      shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(20))),
                      builder: (ctx) =>
                          _MemberDetailsBottomSheet(member: member),
                    );
                  },
                );
              },
            ),

          const SizedBox(height: 24),

          Row(
            children: [
              const Expanded(
                child: Text(
                  'آخر الإيرادات والمدفوعات',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
              ),
              TextButton(
                onPressed: () =>
                    ref.read(selectedTabProvider.notifier).state = 4,
                child: Text('سجل الدفع',
                    style: TextStyle(
                        color: context.appPalette.primary, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (data.payments.isEmpty)
            _buildEmptyCard(context, 'لا يوجد مدفوعات مسجلة بعد.')
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: data.payments.length > 4 ? 4 : data.payments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final payment = data.payments[index];
                return ListTile(
                  tileColor: context.appPalette.surfaceCard,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  leading: CircleAvatar(
                    backgroundColor:
                        context.appPalette.success.withValues(alpha: 0.15),
                    child: Icon(Icons.receipt_long_rounded,
                        color: context.appPalette.success, size: 18),
                  ),
                  title: Text(
                    payment.notes ?? 'إيصال دفع',
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    '${payment.paymentMethod == "cash" ? "نقدي" : "بطاقة/تحويل"} • ${RtlSupport.formatDate(payment.paidAt)}',
                    style: TextStyle(
                        fontSize: 11, color: context.appPalette.textSecondary),
                  ),
                  trailing: Text(
                    RtlSupport.formatEgp(payment.amount),
                    style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: context.appPalette.success,
                        fontSize: 14),
                  ),
                  onTap: () => ref.read(selectedTabProvider.notifier).state = 4,
                );
              },
            ),
        ],
      ),
    );
  }

  Widget _buildClickableStatCard({
    required BuildContext context,
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Card(
        color: context.appPalette.surfaceCard,
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Icon(icon, color: color, size: 22),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            label,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            textAlign: TextAlign.end,
                            style: TextStyle(
                                color: context.appPalette.textSecondary,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(Icons.arrow_forward_ios_rounded,
                            size: 10, color: context.appPalette.textMuted),
                      ],
                    ),
                  ),
                ],
              ),
              Text(value,
                  style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: context.appPalette.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCard(BuildContext context, String text) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: context.appPalette.surfaceCard,
          borderRadius: BorderRadius.circular(16)),
      child: Center(
          child: Text(text,
              style: TextStyle(
                  color: context.appPalette.textSecondary, fontSize: 13))),
    );
  }
}

// ==========================================
// --- TAB 1: MEMBERS MANAGEMENT ---
// ==========================================
class _MembersTab extends ConsumerStatefulWidget {
  const _MembersTab();

  @override
  ConsumerState<_MembersTab> createState() => _MembersTabState();
}

class _MembersTabState extends ConsumerState<_MembersTab> {
  final _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(dataSyncServiceProvider);
    final filterType = ref.watch(memberFilterProvider);
    final searchQuery = _searchQuery.trim().toLowerCase();

    final filteredMembers = data.members.where((m) {
      final matchesSearch = memberMatchesSearch(m, searchQuery);

      if (filterType == 'active') {
        return matchesSearch && m.isActive;
      } else if (filterType == 'inactive') {
        return matchesSearch && !m.isActive;
      }
      return matchesSearch;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            children: [
              TextField(
                controller: _searchController,
                onChanged: (val) => setState(() => _searchQuery = val),
                decoration: InputDecoration(
                  hintText: 'ابحث بالاسم أو رقم الهاتف...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () {
                            _searchController.clear();
                            setState(() => _searchQuery = '');
                          },
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _buildFilterChip('all', 'الكل (${data.members.length})'),
                  _buildFilterChip('active',
                      'نشط (${data.members.where((m) => m.isActive).length})'),
                  _buildFilterChip('inactive',
                      'غير نشط (${data.members.where((m) => !m.isActive).length})'),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: filteredMembers.isEmpty
              ? data.syncStatus == SyncStatus.syncing && data.members.isEmpty
                  ? Center(
                      child: CircularProgressIndicator(
                          color: context.appPalette.primary),
                    )
                  : data.syncStatus == SyncStatus.error && data.members.isEmpty
                      ? Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.cloud_off_rounded,
                                    color: context.appPalette.error, size: 40),
                                const SizedBox(height: 12),
                                Text(
                                  data.syncErrorMessage ??
                                      'تعذر تحميل بيانات الأعضاء.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: context.appPalette.textSecondary),
                                ),
                                const SizedBox(height: 16),
                                ElevatedButton.icon(
                                  onPressed: () => ref
                                      .read(dataSyncServiceProvider.notifier)
                                      .syncAll(forceRetry: true),
                                  icon: const Icon(Icons.refresh_rounded),
                                  label: const Text('إعادة المحاولة'),
                                ),
                              ],
                            ),
                          ),
                        )
                      : Center(
                          child: Padding(
                            padding: const EdgeInsets.all(24.0),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.people_outline_rounded,
                                    size: 48,
                                    color: context.appPalette.textMuted
                                        .withValues(alpha: 0.5)),
                                const SizedBox(height: 12),
                                Text(
                                  data.members.isEmpty
                                      ? 'لا يوجد أعضاء مسجلون حالياً.'
                                      : searchQuery.isNotEmpty
                                          ? 'لا توجد نتائج مطابقة للبحث.'
                                          : 'لا يوجد أعضاء ضمن هذا التصنيف.',
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                      color: context.appPalette.textSecondary,
                                      fontSize: 14),
                                ),
                                if (data.members.isNotEmpty ||
                                    searchQuery.isNotEmpty ||
                                    filterType != 'all') ...[
                                  const SizedBox(height: 16),
                                  ElevatedButton.icon(
                                    onPressed: () {
                                      if (searchQuery.isNotEmpty) {
                                        _searchController.clear();
                                        setState(() => _searchQuery = '');
                                      } else if (filterType != 'all') {
                                        ref
                                            .read(memberFilterProvider.notifier)
                                            .state = 'all';
                                      }
                                    },
                                    icon: Icon(searchQuery.isNotEmpty
                                        ? Icons.clear_rounded
                                        : Icons.filter_alt_off_rounded),
                                    label: Text(searchQuery.isNotEmpty
                                        ? 'مسح البحث'
                                        : 'عرض كل الأعضاء'),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        )
              : ListView.builder(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  itemCount: filteredMembers.length,
                  itemBuilder: (context, index) {
                    final member = filteredMembers[index];
                    return Card(
                      color: context.appPalette.surfaceCard,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: MemberPhotoAvatar(
                          gymId: member.gymId,
                          fullName: member.fullName,
                          photoPath: member.photoPath,
                          radius: 22,
                        ),
                        title: Text(member.fullName,
                            style: const TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (member.phone != null &&
                                member.phone!.isNotEmpty)
                              Text(member.phone!,
                                  style: TextStyle(
                                      fontSize: 12,
                                      color: context.appPalette.textSecondary)),
                            Text(
                                'انضمام: ${RtlSupport.formatDate(member.joinDate)}',
                                style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (member.phone != null &&
                                member.phone!.isNotEmpty)
                              IconButton(
                                icon: Icon(Icons.chat_bubble_outline_rounded,
                                    color: context.appPalette.success),
                                tooltip: 'مراسلة واتساب',
                                onPressed: () =>
                                    _openMemberWhatsapp(context, ref, member),
                              ),
                            IconButton(
                              icon: Icon(Icons.arrow_forward_ios_rounded,
                                  size: 16, color: context.appPalette.primary),
                              onPressed: () =>
                                  _showMemberDetails(context, member),
                            ),
                          ],
                        ),
                        onTap: () => _showMemberDetails(context, member),
                      ),
                    );
                  },
                ),
        ),

        // Add Member Button
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: ElevatedButton.icon(
            onPressed: () {
              showDialog(
                context: context,
                barrierDismissible: false,
                builder: (_) => const _AddMemberDialog(),
              );
            },
            icon: const Icon(Icons.person_add_rounded),
            label: const Text('إضافة عضو جديد'),
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String type, String label) {
    final activeFilter = ref.watch(memberFilterProvider);
    final isSelected = activeFilter == type;

    return ChoiceChip(
      label: Text(label,
          style: TextStyle(
              color: isSelected
                  ? const Color(0xFF0F141C)
                  : context.appPalette.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.bold)),
      selected: isSelected,
      onSelected: (_) => ref.read(memberFilterProvider.notifier).state = type,
      selectedColor: context.appPalette.primary,
      backgroundColor: context.appPalette.surface,
    );
  }
}

void _openMemberWhatsapp(BuildContext context, WidgetRef ref, Member member) {
  if (member.phone == null || member.phone!.trim().isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('هذا العضو ليس لديه رقم هاتف مسجل.'),
        backgroundColor: context.appPalette.error,
      ),
    );
    return;
  }

  final data = ref.read(dataSyncServiceProvider);
  final activeMembership = data.memberships
      .where((membership) =>
          membership.memberId == member.id && !membership.isExpired)
      .firstOrNull;
  final activePlanId = activeMembership?.planId;
  final planName = activePlanId != null
      ? data.plans.where((plan) => plan.id == activePlanId).firstOrNull?.name ??
          'الاشتراك الحالي'
      : 'الاشتراك الشهري';
  final dueAmount = activeMembership?.price ?? 0.0;
  final endDate = activeMembership != null
      ? RtlSupport.formatDate(activeMembership.endDate)
      : 'نهاية الشهر';

  showModalBottomSheet<void>(
    context: context,
    backgroundColor: context.appPalette.surfaceCard,
    builder: (sheetContext) => Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'مراسلة ${member.fullName} عبر واتساب:',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading:
                  Icon(Icons.chat_rounded, color: context.appPalette.success),
              title: const Text('رسالة ترحيبية وتواصل عام'),
              onTap: () {
                Navigator.pop(sheetContext);
                WhatsappService.launchWhatsApp(
                  phone: member.phone!,
                  message: WhatsappService.getGeneralContact(member.fullName),
                );
              },
            ),
            ListTile(
              leading: Icon(Icons.payment_rounded,
                  color: context.appPalette.primary),
              title: Text(
                  'تذكير بمستحقات الاشتراك (${RtlSupport.formatEgp(dueAmount)})'),
              onTap: () {
                Navigator.pop(sheetContext);
                WhatsappService.launchWhatsApp(
                  phone: member.phone!,
                  message: WhatsappService.getPaymentReminder(
                    member.fullName,
                    dueAmount,
                  ),
                );
              },
            ),
            ListTile(
              leading:
                  Icon(Icons.timer_rounded, color: context.appPalette.warning),
              title: Text('تذكير بانتهاء الاشتراك ($endDate)'),
              onTap: () {
                Navigator.pop(sheetContext);
                WhatsappService.launchWhatsApp(
                  phone: member.phone!,
                  message: WhatsappService.getExpiryReminder(
                    member.fullName,
                    planName,
                    endDate,
                  ),
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
}

void _showMemberDetails(BuildContext context, Member member) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: context.appPalette.surfaceCard,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (_) => _MemberDetailsBottomSheet(member: member),
  );
}

// ==========================================
// --- ADD MEMBER DIALOG ---
// ==========================================
class _AddMemberDialog extends ConsumerStatefulWidget {
  const _AddMemberDialog();

  @override
  ConsumerState<_AddMemberDialog> createState() => _AddMemberDialogState();
}

class _AddMemberDialogState extends ConsumerState<_AddMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _notesController = TextEditingController();
  DateTime _joinDate = DateTime.now();
  Uint8List? _photoBytes;
  bool _isSaving = false;
  String? _errorMessage;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    setState(() => _errorMessage = null);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final name = _nameController.text.trim();
      final phone = _phoneController.text.trim();
      final notes = _notesController.text.trim();

      final newMember =
          await ref.read(dataSyncServiceProvider.notifier).addMember(
                fullName: name,
                phone: phone.isNotEmpty ? phone : null,
                notes: notes.isNotEmpty ? notes : null,
                joinDate: _joinDate,
                photoBytes: _photoBytes,
              );

      if (!mounted) return;

      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'تمت إضافة العضو "${newMember.fullName}" بنجاح!',
            textDirection: ui.TextDirection.rtl,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          backgroundColor: context.appPalette.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final cleanMsg = e.toString().replaceAll('Exception: ', '').trim();
      setState(() {
        _errorMessage = cleanMsg;
        _isSaving = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content:
              Text('فشل الحفظ: $cleanMsg', textDirection: ui.TextDirection.rtl),
          backgroundColor: context.appPalette.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _joinDate,
      firstDate: DateTime(2010),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _joinDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: context.appPalette.surfaceCard,
        title: const Text('إضافة عضو جديد في جيم الديب'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_errorMessage != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: context.appPalette.error.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_errorMessage!,
                        style: TextStyle(
                            color: context.appPalette.error, fontSize: 12)),
                  ),

                MemberPhotoInput(
                  gymId: ref.watch(dataSyncServiceProvider).gymId ?? '',
                  fullName: _nameController.text,
                  existingPhotoPath: null,
                  selectedPhotoBytes: _photoBytes,
                  onPhotoSelected: (bytes) =>
                      setState(() => _photoBytes = bytes),
                  onPhotoRemoved: () => setState(() => _photoBytes = null),
                ),
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'الاسم الكامل *',
                    hintText: 'مثال: كابتن أحمد الديب',
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty)
                      return 'يرجى إدخال اسم العضو';
                    if (v.trim().length < 2) return 'الاسم قصير جداً';
                    return null;
                  },
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(
                    labelText: 'رقم الهاتف',
                    hintText: '01012345678 أو +20...',
                    prefixIcon: Icon(Icons.phone_rounded),
                  ),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),

                // Join Date Picker Row
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: context.appPalette.border),
                      borderRadius: BorderRadius.circular(10),
                      color: context.appPalette.surface,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_today_rounded,
                                size: 18, color: context.appPalette.primary),
                            SizedBox(width: 8),
                            Text('تاريخ الانضمام:',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: context.appPalette.textSecondary)),
                          ],
                        ),
                        Text(
                          DateFormat('yyyy/MM/dd').format(_joinDate),
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: context.appPalette.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),

                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(
                    labelText: 'ملاحظات الكابتن',
                    hintText: 'حالة طبية، هدف التدريب، جهة اتصال...',
                    prefixIcon: Icon(Icons.notes_rounded),
                  ),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation(Color(0xFF0F141C))))
                : const Text('حفظ العضو'),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// --- EDIT MEMBER DIALOG ---
// ==========================================
class _EditMemberDialog extends ConsumerStatefulWidget {
  final Member member;

  const _EditMemberDialog({required this.member});

  @override
  ConsumerState<_EditMemberDialog> createState() => _EditMemberDialogState();
}

class _EditMemberDialogState extends ConsumerState<_EditMemberDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _notesController;
  late bool _isActive;
  late DateTime _joinDate;
  bool _isSaving = false;
  Uint8List? _photoBytes;
  bool _removePhoto = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.member.fullName);
    _phoneController = TextEditingController(text: widget.member.phone ?? '');
    _notesController = TextEditingController(text: widget.member.notes ?? '');
    _isActive = widget.member.isActive;
    _joinDate = widget.member.joinDate;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final service = ref.read(dataSyncServiceProvider.notifier);
      final oldPhotoPath = widget.member.photoPath;
      String? nextPhotoPath = oldPhotoPath;
      final updatedMember = widget.member.copyWith(
        fullName: _nameController.text.trim(),
        phone: _phoneController.text.trim().isNotEmpty
            ? _phoneController.text.trim()
            : null,
        notes: _notesController.text.trim().isNotEmpty
            ? _notesController.text.trim()
            : null,
        joinDate: _joinDate,
        isActive: _isActive,
      );
      await service.validateMember(
        candidate: updatedMember,
        excludingMemberId: widget.member.id,
      );
      if (_removePhoto) {
        nextPhotoPath = null;
      } else if (_photoBytes != null) {
        final extension = oldPhotoPath?.toLowerCase().endsWith('.jpg') == true
            ? 'jpeg'
            : 'jpg';
        nextPhotoPath = await service.uploadMemberPhoto(
          memberId: widget.member.id,
          photoBytes: _photoBytes!,
          extension: extension,
        );
      }

      final persistedRemotely = await service.editMember(
        updatedMember.copyWith(
          photoPath: nextPhotoPath,
          clearPhotoPath: _removePhoto,
        ),
        photoPathToDelete: oldPhotoPath != nextPhotoPath ? oldPhotoPath : null,
      );

      if (!mounted) return;
      Navigator.of(context).pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                persistedRemotely
                    ? 'تم تحديث بيانات العضو بنجاح!'
                    : 'تم حفظ التعديلات محلياً وستتم مزامنتها لاحقاً.',
                textDirection: ui.TextDirection.rtl),
            backgroundColor: context.appPalette.success),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('خطأ أثناء التعديل: $e',
                textDirection: ui.TextDirection.rtl),
            backgroundColor: context.appPalette.error),
      );
    }
  }

  Future<void> _pickJoinDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _joinDate,
      firstDate: DateTime(2010),
      lastDate: DateTime.now().add(const Duration(days: 30)),
    );
    if (picked != null) {
      setState(() => _joinDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: context.appPalette.surfaceCard,
        title: const Text('تعديل بيانات العضو'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                MemberPhotoInput(
                  gymId: widget.member.gymId,
                  fullName: _nameController.text,
                  existingPhotoPath:
                      _removePhoto ? null : widget.member.photoPath,
                  selectedPhotoBytes: _photoBytes,
                  onPhotoSelected: (bytes) => setState(() {
                    _photoBytes = bytes;
                    _removePhoto = false;
                  }),
                  onPhotoRemoved: () => setState(() {
                    _photoBytes = null;
                    _removePhoto = true;
                  }),
                ),
                TextFormField(
                  controller: _nameController,
                  decoration:
                      const InputDecoration(labelText: 'الاسم الكامل *'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'الاسم مطلوب' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneController,
                  decoration: const InputDecoration(labelText: 'رقم الهاتف'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                InkWell(
                  onTap: _pickJoinDate,
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: context.appPalette.border),
                      borderRadius: BorderRadius.circular(10),
                      color: context.appPalette.surface,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.calendar_today_rounded,
                                size: 18, color: context.appPalette.primary),
                            SizedBox(width: 8),
                            Text('تاريخ الانضمام:',
                                style: TextStyle(
                                    fontSize: 13,
                                    color: context.appPalette.textSecondary)),
                          ],
                        ),
                        Text(
                          DateFormat('yyyy/MM/dd').format(_joinDate),
                          style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: context.appPalette.textPrimary),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesController,
                  decoration: const InputDecoration(labelText: 'الملاحظات'),
                  maxLines: 2,
                ),
                const SizedBox(height: 12),
                SwitchListTile(
                  title: const Text('حالة الحساب نشط'),
                  value: _isActive,
                  activeThumbColor: context.appPalette.primary,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving
                ? const CircularProgressIndicator()
                : const Text('حفظ التعديلات'),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// --- DETAILED MEMBER BOTTOM SHEET ---
// ==========================================
class _MemberDetailsBottomSheet extends ConsumerWidget {
  final Member member;

  const _MemberDetailsBottomSheet({required this.member});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(dataSyncServiceProvider);

    final memberMemberships =
        data.memberships.where((m) => m.memberId == member.id).toList();
    final memberPayments = data.payments.where((p) {
      if (p.membershipId != null &&
          memberMemberships.any((m) => m.id == p.membershipId)) return true;
      if (p.notes != null && p.notes!.contains(member.fullName)) return true;
      return false;
    }).toList();

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: DraggableScrollableSheet(
        initialChildSize: 0.8,
        maxChildSize: 0.95,
        minChildSize: 0.5,
        expand: false,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      MemberPhotoAvatar(
                        gymId: member.gymId,
                        fullName: member.fullName,
                        photoPath: member.photoPath,
                        radius: 22,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(member.fullName,
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 17)),
                            Text(member.isActive ? 'عضو نشط' : 'عضو غير نشط',
                                style: TextStyle(
                                    color: member.isActive
                                        ? context.appPalette.success
                                        : context.appPalette.error,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('رقم الهاتف المسجل',
                        style: TextStyle(
                            color: context.appPalette.textSecondary,
                            fontSize: 11)),
                    Text(member.phone ?? 'غير متوفر',
                        style: const TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                if (member.phone != null && member.phone!.isNotEmpty)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: context.appPalette.success,
                        foregroundColor: Colors.white),
                    icon: const Icon(Icons.chat, size: 16),
                    label: const Text('واتساب'),
                    onPressed: () {
                      WhatsappService.launchWhatsApp(
                        phone: member.phone!,
                        message:
                            WhatsappService.getGeneralContact(member.fullName),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),
            _buildDetailItem(context, 'تاريخ الانضمام',
                RtlSupport.formatDate(member.joinDate)),
            _buildDetailItem(context, 'ملاحظات الكابتن',
                member.notes ?? 'لا توجد ملاحظات مدونة.'),
            const Divider(height: 28),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 4,
              children: [
                const Text('سجل الاشتراكات والباقات',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                TextButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => _CreateMembershipDialog(
                          preSelectedMemberId: member.id),
                    );
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label:
                      const Text('اشتراك جديد', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (memberMemberships.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: context.appPalette.surface,
                    borderRadius: BorderRadius.circular(10)),
                child: Center(
                    child: Text('لا يوجد اشتراكات مسجلة لهذا العضو.',
                        style: TextStyle(
                            fontSize: 12,
                            color: context.appPalette.textSecondary))),
              )
            else
              ...memberMemberships.map((m) {
                final plan =
                    data.plans.where((p) => p.id == m.planId).firstOrNull;
                final expired = m.isExpired;
                return Card(
                  color: context.appPalette.surface,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    dense: true,
                    title: Text(plan?.name ?? 'باقة مخصصة',
                        style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text(
                        'من ${RtlSupport.formatDate(m.startDate)} إلى ${RtlSupport.formatDate(m.endDate)} • ${RtlSupport.formatEgp(m.price)}'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: expired
                            ? context.appPalette.error.withValues(alpha: 0.1)
                            : context.appPalette.success.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(expired ? 'منتهي' : 'نشط',
                          style: TextStyle(
                              color: expired
                                  ? context.appPalette.error
                                  : context.appPalette.success,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              }),
            const Divider(height: 28),
            Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              runSpacing: 4,
              children: [
                const Text('سجل المدفوعات والإيصالات',
                    style:
                        TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                TextButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) =>
                          _RecordPaymentDialog(preSelectedMemberId: member.id),
                    );
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label:
                      const Text('تسجيل دفعة', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (memberPayments.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                    color: context.appPalette.surface,
                    borderRadius: BorderRadius.circular(10)),
                child: Center(
                    child: Text('لا يوجد سجل مدفوعات مسجل.',
                        style: TextStyle(
                            fontSize: 12,
                            color: context.appPalette.textSecondary))),
              )
            else
              ...memberPayments.map((p) {
                return Card(
                  color: context.appPalette.surface,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    dense: true,
                    title: Text(RtlSupport.formatEgp(p.amount),
                        style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: context.appPalette.success)),
                    subtitle: Text(
                        '${p.paymentMethod == "cash" ? "نقدي" : "فيزا"} • ${RtlSupport.formatDate(p.paidAt)}'),
                    trailing: Icon(Icons.check_circle_rounded,
                        color: context.appPalette.success, size: 16),
                  ),
                );
              }),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.edit_rounded, size: 18),
                    label: const Text('تعديل البيانات'),
                    onPressed: () {
                      showDialog(
                        context: context,
                        builder: (_) => _EditMemberDialog(member: member),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                        backgroundColor: context.appPalette.error,
                        foregroundColor: Colors.white),
                    icon: const Icon(Icons.delete_forever_rounded, size: 18),
                    label: const Text('حذف العضو'),
                    onPressed: () => _confirmDeleteMember(context, ref, member),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(BuildContext context, String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: TextStyle(
                  color: context.appPalette.textSecondary, fontSize: 11)),
          const SizedBox(height: 2),
          Text(val,
              style:
                  const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _confirmDeleteMember(
      BuildContext context, WidgetRef ref, Member member) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: context.appPalette.surfaceCard,
          title: const Text('تأكيد الحذف'),
          content:
              Text('هل أنت متأكد من حذف العضو ${member.fullName} نهائياً؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: context.appPalette.error),
              onPressed: () async {
                Navigator.pop(ctx);
                Navigator.pop(context); // Close bottom sheet
                await ref
                    .read(dataSyncServiceProvider.notifier)
                    .deleteMember(member.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('تم حذف العضو بنجاح',
                          textDirection: ui.TextDirection.rtl)),
                );
              },
              child: const Text('حذف', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// --- TAB 2: PLANS & PRICING ---
// ==========================================
class _PlansTab extends ConsumerWidget {
  const _PlansTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(dataSyncServiceProvider);

    return Column(
      children: [
        Expanded(
          child: data.plans.isEmpty
              ? Center(
                  child: Text('لا توجد باقات اشتراك مسجلة حالياً.',
                      style:
                          TextStyle(color: context.appPalette.textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: data.plans.length,
                  itemBuilder: (context, index) {
                    final plan = data.plans[index];
                    return Card(
                      color: context.appPalette.surfaceCard,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(
                                          plan.name,
                                          maxLines: 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                            horizontal: 6, vertical: 2),
                                        decoration: BoxDecoration(
                                          color: plan.isActive
                                              ? context.appPalette.success
                                                  .withValues(alpha: 0.1)
                                              : context.appPalette.error
                                                  .withValues(alpha: 0.1),
                                          borderRadius:
                                              BorderRadius.circular(4),
                                        ),
                                        child: Text(
                                            plan.isActive ? 'مفعلة' : 'معطلة',
                                            style: TextStyle(
                                                color: plan.isActive
                                                    ? context.appPalette.success
                                                    : context.appPalette.error,
                                                fontSize: 10,
                                                fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text('المدة: ${plan.durationDays} يوم',
                                      style: TextStyle(
                                          fontSize: 12,
                                          color: context
                                              .appPalette.textSecondary)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(RtlSupport.formatEgp(plan.price),
                                    style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                        color: context.appPalette.primary)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: Icon(Icons.edit_rounded,
                                          color:
                                              context.appPalette.textSecondary,
                                          size: 20),
                                      onPressed: () {
                                        showDialog(
                                            context: context,
                                            builder: (_) =>
                                                _EditPlanDialog(plan: plan));
                                      },
                                    ),
                                    IconButton(
                                      icon: Icon(Icons.delete_rounded,
                                          color: context.appPalette.error,
                                          size: 20),
                                      onPressed: () => _confirmDeletePlan(
                                          context, ref, plan),
                                    ),
                                  ],
                                )
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                showDialog<void>(
                    context: context, builder: (_) => const _AddPlanDialog());
              },
              icon: const Icon(Icons.add_card_rounded),
              label: const Text('إضافة باقة جديدة'),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmDeletePlan(
      BuildContext context, WidgetRef ref, MembershipPlan plan) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: context.appPalette.surfaceCard,
          title: const Text('تأكيد حذف الباقة'),
          content: Text('هل أنت متأكد من حذف الباقة ${plan.name} نهائياً؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: context.appPalette.error),
              onPressed: () async {
                Navigator.pop(ctx);
                await ref
                    .read(dataSyncServiceProvider.notifier)
                    .deletePlan(plan.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('تم حذف الباقة بنجاح',
                          textDirection: ui.TextDirection.rtl)),
                );
              },
              child: const Text('حذف', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// --- ADD PLAN DIALOG ---
// ==========================================
class _AddPlanDialog extends ConsumerStatefulWidget {
  const _AddPlanDialog();

  @override
  ConsumerState<_AddPlanDialog> createState() => _AddPlanDialogState();
}

class _AddPlanDialogState extends ConsumerState<_AddPlanDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _durationCtrl = TextEditingController(text: '30');
  final _priceCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _durationCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await ref.read(dataSyncServiceProvider.notifier).addPlan(
            name: _nameCtrl.text.trim(),
            durationDays: int.parse(_durationCtrl.text),
            price: double.parse(_priceCtrl.text),
          );

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('تمت إضافة الباقة بنجاح!',
                textDirection: ui.TextDirection.rtl),
            backgroundColor: context.appPalette.success),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('فشل الحفظ: $e', textDirection: ui.TextDirection.rtl),
            backgroundColor: context.appPalette.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: context.appPalette.surfaceCard,
        title: const Text('إضافة باقة اشتراك جديدة'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'اسم الباقة *'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'الاسم مطلوب' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _durationCtrl,
                decoration: const InputDecoration(labelText: 'المدة باليوم *'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final duration = int.tryParse(v ?? '');
                  return duration == null || duration <= 0
                      ? 'أدخل مدة أكبر من صفر'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceCtrl,
                decoration:
                    const InputDecoration(labelText: 'سعر الاشتراك (ج.م) *'),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || double.tryParse(v) == null
                    ? 'أدخل مبلغ صحيح'
                    : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving
                ? const CircularProgressIndicator()
                : const Text('إضافة'),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// --- EDIT PLAN DIALOG ---
// ==========================================
class _EditPlanDialog extends ConsumerStatefulWidget {
  final MembershipPlan plan;

  const _EditPlanDialog({required this.plan});

  @override
  ConsumerState<_EditPlanDialog> createState() => _EditPlanDialogState();
}

class _EditPlanDialogState extends ConsumerState<_EditPlanDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;
  late TextEditingController _durationCtrl;
  late TextEditingController _priceCtrl;
  late bool _isActive;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.plan.name);
    _durationCtrl =
        TextEditingController(text: widget.plan.durationDays.toString());
    _priceCtrl = TextEditingController(text: widget.plan.price.toString());
    _isActive = widget.plan.isActive;
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _durationCtrl.dispose();
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      await ref.read(dataSyncServiceProvider.notifier).editPlan(
            widget.plan.copyWith(
              name: _nameCtrl.text.trim(),
              durationDays: int.parse(_durationCtrl.text),
              price: double.parse(_priceCtrl.text),
              isActive: _isActive,
            ),
          );

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('تم تعديل الباقة بنجاح!',
                textDirection: ui.TextDirection.rtl),
            backgroundColor: context.appPalette.success),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content:
                Text('فشل التعديل: $e', textDirection: ui.TextDirection.rtl),
            backgroundColor: context.appPalette.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: context.appPalette.surfaceCard,
        title: const Text('تعديل باقة الاشتراك'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'اسم الباقة *'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'الاسم مطلوب' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _durationCtrl,
                decoration: const InputDecoration(labelText: 'المدة باليوم *'),
                keyboardType: TextInputType.number,
                validator: (v) {
                  final duration = int.tryParse(v ?? '');
                  return duration == null || duration <= 0
                      ? 'أدخل مدة أكبر من صفر'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceCtrl,
                decoration: const InputDecoration(labelText: 'السعر (ج.م) *'),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || double.tryParse(v) == null
                    ? 'أدخل مبلغ صحيح'
                    : null,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('حالة الباقة مفعلة'),
                value: _isActive,
                activeThumbColor: context.appPalette.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => _isActive = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving
                ? const CircularProgressIndicator()
                : const Text('حفظ التعديلات'),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// --- TAB 3: MEMBERSHIPS LOGS ---
// ==========================================
class _MembershipsTab extends ConsumerWidget {
  const _MembershipsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(dataSyncServiceProvider);

    return Column(
      children: [
        Expanded(
          child: data.memberships.isEmpty
              ? Center(
                  child: Text('لا توجد اشتراكات مفعلة حالياً.',
                      style:
                          TextStyle(color: context.appPalette.textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: data.memberships.length,
                  itemBuilder: (context, index) {
                    final membership = data.memberships[index];
                    final member = data.members
                            .where((m) => m.id == membership.memberId)
                            .firstOrNull ??
                        Member(
                            id: '',
                            gymId: '',
                            fullName: 'عضو محذوف',
                            joinDate: DateTime.now(),
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now());
                    final plan = data.plans
                            .where((p) => p.id == membership.planId)
                            .firstOrNull ??
                        MembershipPlan(
                            id: '',
                            gymId: '',
                            name: 'باقة مخصصة',
                            createdAt: DateTime.now(),
                            updatedAt: DateTime.now());

                    final expired = membership.isExpired;

                    return Card(
                      color: context.appPalette.surfaceCard,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        onTap: () {
                          showDialog(
                              context: context,
                              builder: (_) => _EditMembershipDialog(
                                  membership: membership));
                        },
                        leading: CircleAvatar(
                          backgroundColor: expired
                              ? context.appPalette.error.withValues(alpha: 0.12)
                              : context.appPalette.success
                                  .withValues(alpha: 0.12),
                          child: Icon(
                              expired
                                  ? Icons.timer_off_rounded
                                  : Icons.offline_bolt_rounded,
                              color: expired
                                  ? context.appPalette.error
                                  : context.appPalette.success),
                        ),
                        title: Text(member.fullName,
                            style:
                                const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                                'الباقة: ${plan.name} • القيمة: ${RtlSupport.formatEgp(membership.price)}',
                                style: const TextStyle(fontSize: 12)),
                            Text(
                                'من: ${RtlSupport.formatDate(membership.startDate)} إلى ${RtlSupport.formatDate(membership.endDate)}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: context.appPalette.textSecondary)),
                            Text(
                                'سجّل الاشتراك: ${data.creatorName(membership.createdBy)}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: context.appPalette.textMuted)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: expired
                                    ? context.appPalette.error
                                        .withValues(alpha: 0.1)
                                    : context.appPalette.success
                                        .withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                expired
                                    ? 'منتهي'
                                    : (membership.status == 'cancelled'
                                        ? 'ملغى'
                                        : 'ساري'),
                                style: TextStyle(
                                    color: expired
                                        ? context.appPalette.error
                                        : context.appPalette.success,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.edit_rounded,
                                  size: 18,
                                  color: context.appPalette.textSecondary),
                              tooltip: 'تعديل بيانات الاشتراك',
                              onPressed: () {
                                showDialog(
                                    context: context,
                                    builder: (_) => _EditMembershipDialog(
                                        membership: membership));
                              },
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline_rounded,
                                  size: 18, color: context.appPalette.error),
                              tooltip: 'حذف الاشتراك',
                              onPressed: () => _confirmDeleteMembership(
                                  context, ref, membership),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                showDialog<void>(
                    context: context,
                    builder: (_) => const _CreateMembershipDialog());
              },
              icon: const Icon(Icons.add_task_rounded),
              label: const Text('تسجيل اشتراك لعضو'),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmDeleteMembership(
      BuildContext context, WidgetRef ref, Membership membership) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: context.appPalette.surfaceCard,
          title: const Text('تأكيد حذف الاشتراك'),
          content: const Text(
              'هل أنت متأكد من حذف هذا الاشتراك؟ سيتم وضع علامة ملغى وحذفه من السجلات.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: context.appPalette.error),
              onPressed: () async {
                Navigator.pop(ctx);
                await ref
                    .read(dataSyncServiceProvider.notifier)
                    .deleteMembership(membership.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                      content: Text('تم حذف الاشتراك بنجاح',
                          textDirection: ui.TextDirection.rtl)),
                );
              },
              child: const Text('حذف الاشتراك',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExpiringMembershipsTab extends ConsumerWidget {
  const _ExpiringMembershipsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(dataSyncServiceProvider);
    final today = DateTime.now();
    final memberships = expiringMembershipsWithinDays(data.memberships, today)
      ..sort((a, b) => a.endDate.compareTo(b.endDate));

    if (memberships.isEmpty && data.syncStatus == SyncStatus.syncing) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    if (memberships.isEmpty && data.syncStatus == SyncStatus.error) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off_rounded, size: 40),
              const SizedBox(height: 12),
              Text(
                data.syncErrorMessage ?? 'تعذر تحميل الاشتراكات.',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: () => ref
                    .read(dataSyncServiceProvider.notifier)
                    .syncAll(forceRetry: true),
                icon: const Icon(Icons.refresh_rounded),
                label: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        ),
      );
    }
    if (memberships.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24),
          child: Text(
            'لا توجد اشتراكات نشطة تنتهي خلال الأيام السبعة القادمة.',
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    return Column(
      children: [
        if (data.syncStatus == SyncStatus.error)
          MaterialBanner(
            content: Text(
              data.syncErrorMessage ?? 'تعذر تحديث بيانات الاشتراكات.',
            ),
            leading: const Icon(Icons.cloud_off_rounded),
            actions: [
              TextButton(
                onPressed: () => ref
                    .read(dataSyncServiceProvider.notifier)
                    .syncAll(forceRetry: true),
                child: const Text('إعادة المحاولة'),
              ),
            ],
          ),
        Expanded(
          child: ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: memberships.length,
            itemBuilder: (context, index) {
              final membership = memberships[index];
              final member = data.members
                  .where((item) => item.id == membership.memberId)
                  .firstOrNull;
              final remainingDays = membership.daysRemainingAt(today);
              return Card(
                margin: const EdgeInsets.only(bottom: 12),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        context.appPalette.warning.withValues(alpha: 0.15),
                    child: Icon(
                      Icons.alarm_rounded,
                      color: context.appPalette.warning,
                    ),
                  ),
                  title: Text(
                    member?.fullName ?? 'عضو محذوف',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'تاريخ الانتهاء: ${RtlSupport.formatDate(membership.endDate)}',
                  ),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        remainingDays == 0
                            ? 'اليوم'
                            : 'متبقي $remainingDays يوم',
                        textAlign: TextAlign.end,
                        style: TextStyle(
                          color: context.appPalette.warning,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (member?.phone?.trim().isNotEmpty == true)
                        IconButton(
                          constraints: const BoxConstraints.tightFor(
                              width: 36, height: 40),
                          padding: EdgeInsets.zero,
                          tooltip: 'مراسلة واتساب',
                          icon: Icon(
                            Icons.chat_bubble_outline_rounded,
                            size: 19,
                            color: context.appPalette.success,
                          ),
                          onPressed: () =>
                              _openMemberWhatsapp(context, ref, member!),
                        ),
                      if (member != null)
                        IconButton(
                          constraints: const BoxConstraints.tightFor(
                              width: 36, height: 40),
                          padding: EdgeInsets.zero,
                          tooltip: 'عرض تفاصيل العضو',
                          icon: Icon(
                            Icons.arrow_forward_ios_rounded,
                            size: 16,
                            color: context.appPalette.primary,
                          ),
                          onPressed: () => _showMemberDetails(context, member),
                        ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

// ==========================================
// --- EDIT MEMBERSHIP DIALOG ---
// ==========================================
class _EditMembershipDialog extends ConsumerStatefulWidget {
  final Membership membership;

  const _EditMembershipDialog({required this.membership});

  @override
  ConsumerState<_EditMembershipDialog> createState() =>
      _EditMembershipDialogState();
}

class _EditMembershipDialogState extends ConsumerState<_EditMembershipDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _planId;
  late final TextEditingController _priceCtrl;
  late DateTime _startDate;
  late DateTime _endDate;
  late String _status;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _planId = widget.membership.planId;
    _priceCtrl =
        TextEditingController(text: widget.membership.price.toString());
    _startDate = widget.membership.startDate;
    _endDate = widget.membership.endDate;
    _status = widget.membership.status;
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final updated = widget.membership.copyWith(
        planId: _planId,
        price: double.tryParse(_priceCtrl.text) ?? widget.membership.price,
        startDate: _startDate,
        endDate: _endDate,
        status: _status,
      );

      final service = ref.read(dataSyncServiceProvider.notifier);
      await service.editMembership(updated);
      final isPending = await service.isMembershipPending(updated.id);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                isPending
                    ? 'تم حفظ التعديل محلياً، ولم يؤكده الخادم بعد.'
                    : 'تم تحديث بيانات الاشتراك بنجاح!',
                textDirection: ui.TextDirection.rtl),
            backgroundColor: isPending
                ? context.appPalette.warning
                : context.appPalette.success),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('خطأ أثناء التعديل: $e',
                textDirection: ui.TextDirection.rtl),
            backgroundColor: context.appPalette.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(dataSyncServiceProvider);

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: context.appPalette.surfaceCard,
        title: const Text('تعديل بيانات الاشتراك'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _planId,
                  decoration:
                      const InputDecoration(labelText: 'خطة / باقة الاشتراك'),
                  items: data.plans.map((p) {
                    return DropdownMenuItem(
                      value: p.id,
                      child: Text(
                        '${p.name} (${p.price} ج.م)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    );
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _planId = val;
                      final selected =
                          data.plans.where((p) => p.id == val).firstOrNull;
                      if (selected != null) {
                        _priceCtrl.text = selected.price.toString();
                        _endDate = selected.endDateFor(_startDate);
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceCtrl,
                  decoration:
                      const InputDecoration(labelText: 'سعر الاشتراك (ج.م) *'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || double.tryParse(v) == null
                      ? 'أدخل مبلغ صحيح'
                      : null,
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title:
                      const Text('تاريخ البدء', style: TextStyle(fontSize: 12)),
                  subtitle: Text(DateFormat('yyyy/MM/dd').format(_startDate),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.calendar_today_rounded, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035));
                    if (picked != null) setState(() => _startDate = picked);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('تاريخ الانتهاء',
                      style: TextStyle(fontSize: 12)),
                  subtitle: Text(DateFormat('yyyy/MM/dd').format(_endDate),
                      style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.calendar_today_rounded, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(
                        context: context,
                        initialDate: _endDate,
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2035));
                    if (picked != null) setState(() => _endDate = picked);
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: 'حالة الاشتراك'),
                  items: const [
                    DropdownMenuItem(
                      value: 'active',
                      child: Text(
                        'ساري ومفعل (Active)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'expired',
                      child: Text(
                        'منتهي (Expired)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'cancelled',
                      child: Text(
                        'ملغى / متوقف (Cancelled)',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                  onChanged: (val) => setState(() => _status = val ?? 'active'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
              onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving
                ? const CircularProgressIndicator()
                : const Text('حفظ التعديلات'),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// --- CREATE MEMBERSHIP DIALOG ---
// ==========================================
class _CreateMembershipDialog extends ConsumerStatefulWidget {
  final String? preSelectedMemberId;

  const _CreateMembershipDialog({this.preSelectedMemberId});

  @override
  ConsumerState<_CreateMembershipDialog> createState() =>
      _CreateMembershipDialogState();
}

class _CreateMembershipDialogState
    extends ConsumerState<_CreateMembershipDialog> {
  String? _selectedMemberId;
  String? _selectedPlanId;
  final _priceCtrl = TextEditingController();
  late DateTime _startDate;
  late DateTime _endDate;
  bool _recordPaymentNow = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedMemberId = widget.preSelectedMemberId;
    _startDate = DateUtils.dateOnly(DateTime.now());
    _endDate = MembershipPlan.endDateForDuration(_startDate, 30);
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    if (_selectedMemberId == null || _selectedPlanId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: const Text('يرجى اختيار العضو والباقة أولاً',
                textDirection: ui.TextDirection.rtl),
            backgroundColor: context.appPalette.error),
      );
      return;
    }

    final data = ref.read(dataSyncServiceProvider);
    if (!data.members.any((member) => member.id == _selectedMemberId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('العضو المحدد غير متاح.'),
          backgroundColor: context.appPalette.error,
        ),
      );
      return;
    }
    final price = double.tryParse(_priceCtrl.text);
    if (price == null ||
        !price.isFinite ||
        price < 0 ||
        (_recordPaymentNow && price <= 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _recordPaymentNow
                ? 'أدخل سعراً أكبر من صفر لتسجيل دفعة.'
                : 'أدخل سعراً صحيحاً غير سالب.',
            textDirection: ui.TextDirection.rtl,
          ),
          backgroundColor: context.appPalette.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final result =
          await ref.read(dataSyncServiceProvider.notifier).createMembership(
                memberId: _selectedMemberId!,
                planId: _selectedPlanId!,
                startDate: _startDate,
                endDate: _endDate,
                price: price,
                initialPaymentAmount: _recordPaymentNow ? price : null,
                paymentNotes: 'دفعة تفعيل اشتراك',
              );

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(
          result.isPending
              ? 'تم حفظ طلب الاشتراك محلياً، ولم يُؤكد بعد من الخادم.'
              : 'تم تفعيل الاشتراك بنجاح!',
          textDirection: ui.TextDirection.rtl,
        ),
        backgroundColor: result.isPending
            ? context.appPalette.warning
            : context.appPalette.success,
      ));
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('تعذر تفعيل الاشتراك: $e',
                textDirection: ui.TextDirection.rtl),
            backgroundColor: context.appPalette.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(dataSyncServiceProvider);

    if (data.members.isEmpty) {
      return Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: context.appPalette.surfaceCard,
          title: const Text('تنبيه'),
          content: const Text(
              'الرجاء إضافة عضو واحد على الأقل أولاً لتسجيل اشتراك.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('حسناً'))
          ],
        ),
      );
    }

    if (data.activePlans.isEmpty) {
      return Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: context.appPalette.surfaceCard,
          title: const Text('تنبيه'),
          content: const Text(
              'لا توجد باقات مفعلة حالياً. فعّل باقة أو أضف باقة جديدة أولاً.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('حسناً'))
          ],
        ),
      );
    }

    _selectedMemberId ??= data.members.first.id;
    if (!data.activePlans.any((plan) => plan.id == _selectedPlanId)) {
      _selectedPlanId = data.activePlans.first.id;
      _priceCtrl.text = data.activePlans.first.price.toString();
    }
    if (_priceCtrl.text.isEmpty) {
      _priceCtrl.text = data.activePlans
          .firstWhere((plan) => plan.id == _selectedPlanId)
          .price
          .toString();
    }

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        scrollable: true,
        backgroundColor: context.appPalette.surfaceCard,
        title: const Text('تسجيل باقة اشتراك لعضو'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _SearchableMemberPicker(
              members: data.members,
              selectedMemberId: _selectedMemberId,
              allowUnlinked: false,
              label: 'العضو *',
              onChanged: (value) => setState(() => _selectedMemberId = value),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              isExpanded: true,
              initialValue: _selectedPlanId,
              decoration: const InputDecoration(labelText: 'باقة الاشتراك'),
              items: data.activePlans
                  .map((p) => DropdownMenuItem(
                      value: p.id, child: Text('${p.name} (${p.price} ج.م)')))
                  .toList(),
              onChanged: (val) {
                final p = data.activePlans.firstWhere((p) => p.id == val);
                setState(() {
                  _selectedPlanId = val;
                  _priceCtrl.text = p.price.toString();
                  _endDate = p.endDateFor(_startDate);
                });
              },
            ),
            const SizedBox(height: 12),
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('فترة الاشتراك'),
              subtitle: Text(
                'من ${DateFormat('yyyy/MM/dd').format(_startDate)} إلى '
                '${DateFormat('yyyy/MM/dd').format(_endDate)}',
              ),
              trailing: const Icon(Icons.calendar_today_rounded, size: 18),
              onTap: _isSaving
                  ? null
                  : () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: _startDate,
                        firstDate: DateTime(2000),
                        lastDate: DateTime(2100),
                      );
                      if (picked == null || !mounted) return;
                      setState(() {
                        _startDate = DateUtils.dateOnly(picked);
                        final plan = data.activePlans
                            .where((plan) => plan.id == _selectedPlanId)
                            .first;
                        _endDate = plan.endDateFor(_startDate);
                      });
                    },
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _priceCtrl,
              decoration: const InputDecoration(
                  labelText: 'السعر الفعلي المطلوب (ج.م)'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),
            CheckboxListTile(
              title: const Text('تسجيل دفعة كاملة الآن',
                  style: TextStyle(fontSize: 12)),
              value: _recordPaymentNow,
              activeColor: context.appPalette.primary,
              contentPadding: EdgeInsets.zero,
              subtitle: const Text(
                'سيتم إنشاء سجل دفع بمبلغ سعر الاشتراك فقط عند التأكيد.',
              ),
              onChanged: _isSaving
                  ? null
                  : (v) => setState(() => _recordPaymentNow = v ?? false),
            ),
          ],
        ),
        actions: [
          TextButton(
              onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving
                ? const CircularProgressIndicator()
                : const Text('تفعيل الاشتراك'),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// --- TAB 4: PAYMENTS RECORDER ---
// ==========================================
class _PaymentsTab extends ConsumerWidget {
  const _PaymentsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final data = ref.watch(dataSyncServiceProvider);

    return Column(
      children: [
        Expanded(
          child: data.payments.isEmpty
              ? Center(
                  child: Text('لا توجد مدفوعات مسجلة حالياً.',
                      style:
                          TextStyle(color: context.appPalette.textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: data.payments.length,
                  itemBuilder: (context, index) {
                    final payment = data.payments[index];

                    return Card(
                      color: context.appPalette.surfaceCard,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 3,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    payment.notes ?? 'إيصال دفع',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                      'سجّل الدفعة: ${data.creatorName(payment.recordedBy)}',
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: context.appPalette.textMuted)),
                                  const SizedBox(height: 4),
                                  Text(
                                    RtlSupport.formatEgp(payment.amount),
                                    style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                        color: context.appPalette.success),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 2,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'طريقة الدفع: ${payment.paymentMethod == "cash" ? "نقدي" : "بطاقة/تحويل"}',
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.end,
                                    style: const TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(RtlSupport.formatDate(payment.paidAt),
                                      style: TextStyle(
                                          fontSize: 11,
                                          color: context.appPalette.textMuted)),
                                  const SizedBox(height: 4),
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      IconButton(
                                        icon: Icon(Icons.edit_rounded,
                                            color: context
                                                .appPalette.textSecondary,
                                            size: 18),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                            minWidth: 48, minHeight: 48),
                                        onPressed: () {
                                          showDialog(
                                              context: context,
                                              builder: (_) =>
                                                  _EditPaymentDialog(
                                                      payment: payment));
                                        },
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.delete_rounded,
                                            color: context.appPalette.error,
                                            size: 18),
                                        padding: EdgeInsets.zero,
                                        constraints: const BoxConstraints(
                                            minWidth: 48, minHeight: 48),
                                        onPressed: () => _confirmDeletePayment(
                                            context, ref, payment),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: () {
                showDialog<void>(
                    context: context,
                    builder: (_) => const _RecordPaymentDialog());
              },
              icon: const Icon(Icons.add_reaction_rounded),
              label: const Text('تسجيل إيراد / دفعة مستلمة'),
            ),
          ),
        ),
      ],
    );
  }

  void _confirmDeletePayment(
      BuildContext context, WidgetRef ref, Payment payment) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: context.appPalette.surfaceCard,
          title: const Text('تأكيد حذف الدفعة المالية'),
          content: Text(
              'تحذير مالي: هل تريد تأكيد حذف هذه الدفعة بقيمة (${RtlSupport.formatEgp(payment.amount)})؟ سيؤثر هذا على إجمالي إيرادات الخزينة.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('تراجع')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: context.appPalette.error),
              onPressed: () async {
                Navigator.pop(ctx);
                await ref
                    .read(dataSyncServiceProvider.notifier)
                    .deletePayment(payment.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('تم حذف الدفعة المالية بنجاح!',
                            textDirection: ui.TextDirection.rtl),
                        backgroundColor: context.appPalette.success),
                  );
                }
              },
              child: const Text('تأكيد الحذف',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// --- EDIT PAYMENT DIALOG ---
// ==========================================
class _EditPaymentDialog extends ConsumerStatefulWidget {
  final Payment payment;

  const _EditPaymentDialog({required this.payment});

  @override
  ConsumerState<_EditPaymentDialog> createState() => _EditPaymentDialogState();
}

class _EditPaymentDialogState extends ConsumerState<_EditPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountCtrl;
  late final TextEditingController _notesCtrl;
  late String _method;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _amountCtrl = TextEditingController(text: widget.payment.amount.toString());
    _notesCtrl = TextEditingController(text: widget.payment.notes ?? '');
    _method = widget.payment.paymentMethod;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      final updated = widget.payment.copyWith(
        amount: double.parse(_amountCtrl.text.trim()),
        paymentMethod: _method,
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
      );

      final service = ref.read(dataSyncServiceProvider.notifier);
      await service.editPayment(updated);
      final isPending = await service.isPaymentPending(updated.id);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                isPending
                    ? 'تم حفظ التعديل محلياً، ولم يؤكده الخادم بعد.'
                    : 'تم تحديث الدفعة المالية بنجاح!',
                textDirection: ui.TextDirection.rtl),
            backgroundColor: isPending
                ? context.appPalette.warning
                : context.appPalette.success),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('خطأ أثناء التعديل: $e',
                textDirection: ui.TextDirection.rtl),
            backgroundColor: context.appPalette.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: context.appPalette.surfaceCard,
        title: const Text('تعديل الدفعة المالية'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _amountCtrl,
                  decoration: const InputDecoration(
                      labelText: 'المبلغ المستلم (ج.م) *'),
                  keyboardType: TextInputType.number,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty)
                      return 'المبلغ مطلوب';
                    final parsed = double.tryParse(val);
                    if (parsed == null || parsed <= 0) return 'أدخل مبلغ صحيح';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: _method,
                  decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('نقدي كاش')),
                    DropdownMenuItem(
                        value: 'vodafone_cash',
                        child: Text('فودافون كاش / محفظة')),
                    DropdownMenuItem(
                        value: 'instapay', child: Text('إنستاباي (InstaPay)')),
                    DropdownMenuItem(
                        value: 'card', child: Text('بطاقة بنكية / فيزا')),
                  ],
                  onChanged: (val) => setState(() => _method = val ?? 'cash'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesCtrl,
                  decoration:
                      const InputDecoration(labelText: 'ملاحظات الإيصال'),
                  maxLines: 2,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black))
                : const Text('حفظ التعديل'),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// --- RECORD PAYMENT DIALOG ---
// ==========================================
class _MemberSelectionResult {
  final String? memberId;

  const _MemberSelectionResult(this.memberId);
}

class _SearchableMemberPicker extends StatefulWidget {
  final List<Member> members;
  final String? selectedMemberId;
  final ValueChanged<String?> onChanged;
  final bool allowUnlinked;
  final String label;

  const _SearchableMemberPicker({
    required this.members,
    required this.selectedMemberId,
    required this.onChanged,
    this.allowUnlinked = true,
    this.label = 'العضو المسدد (اختياري)',
  });

  @override
  State<_SearchableMemberPicker> createState() =>
      _SearchableMemberPickerState();
}

class _SearchableMemberPickerState extends State<_SearchableMemberPicker> {
  Future<void> _openMemberSearch() async {
    final result = await showDialog<_MemberSelectionResult>(
      context: context,
      builder: (_) => _MemberSearchDialog(
        key: UniqueKey(),
        members: widget.members,
        allowUnlinked: widget.allowUnlinked,
      ),
    );
    if (result != null) widget.onChanged(result.memberId);
  }

  @override
  Widget build(BuildContext context) {
    final selectedMember = widget.members
        .where((member) => member.id == widget.selectedMemberId)
        .firstOrNull;
    final selectedUnavailable =
        widget.selectedMemberId != null && selectedMember == null;

    return InputDecorator(
      decoration: InputDecoration(
        labelText: widget.label,
        suffixIcon: IconButton(
          tooltip: 'بحث عن عضو',
          onPressed: _openMemberSearch,
          icon: const Icon(Icons.search_rounded),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: _openMemberSearch,
              child: Text(
                selectedMember == null
                    ? selectedUnavailable
                        ? 'العضو المحدد غير متاح'
                        : widget.allowUnlinked
                            ? 'دفعة عامة بدون ربط بعضو'
                            : 'اختر عضواً'
                    : [
                        selectedMember.fullName,
                        if (selectedMember.phone?.isNotEmpty == true)
                          selectedMember.phone!,
                      ].join(' • '),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (widget.selectedMemberId != null)
            IconButton(
              tooltip: 'إزالة ربط العضو',
              constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
              onPressed: () => widget.onChanged(null),
              icon: const Icon(Icons.close_rounded),
            ),
        ],
      ),
    );
  }
}

class _MemberSearchDialog extends StatefulWidget {
  final List<Member> members;
  final bool allowUnlinked;

  const _MemberSearchDialog({
    super.key,
    required this.members,
    required this.allowUnlinked,
  });

  @override
  State<_MemberSearchDialog> createState() => _MemberSearchDialogState();
}

class _MemberSearchDialogState extends State<_MemberSearchDialog> {
  late final TextEditingController _searchController;
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController(text: '');
    _query = '';
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final matchingMembers = widget.members
        .where((member) => memberMatchesSearch(member, _query))
        .toList();

    final media = MediaQuery.of(context);
    final availableHeight = (media.size.height - media.viewInsets.bottom - 32)
        .clamp(0.0, 560.0)
        .toDouble();

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: Dialog(
        backgroundColor: context.appPalette.surfaceCard,
        surfaceTintColor: Colors.transparent,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 420,
            maxHeight: availableHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(
                  widget.allowUnlinked ? 'اختر العضو المسدد' : 'اختر العضو',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchController,
                  autofocus: true,
                  onChanged: (value) => setState(() => _query = value),
                  decoration: const InputDecoration(
                    labelText: 'بحث بالاسم أو رقم الهاتف',
                    prefixIcon: Icon(Icons.search_rounded),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: matchingMembers.isEmpty
                      ? const Center(
                          child: Text('لا يوجد عضو مطابق لبحثك.'),
                        )
                      : ListView.builder(
                          itemCount: matchingMembers.length,
                          itemBuilder: (context, index) {
                            final member = matchingMembers[index];
                            return ListTile(
                              title: Text(
                                member.fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              subtitle:
                                  Text(member.phone ?? 'لا يوجد رقم هاتف'),
                              onTap: () => Navigator.of(context).pop(
                                _MemberSelectionResult(member.id),
                              ),
                            );
                          },
                        ),
                ),
                if (widget.allowUnlinked)
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context)
                            .pop(const _MemberSelectionResult(null)),
                        child: const Text('دفعة عامة بدون ربط بعضو'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('إلغاء'),
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
}

class _RecordPaymentDialog extends ConsumerStatefulWidget {
  final String? preSelectedMemberId;

  const _RecordPaymentDialog({this.preSelectedMemberId});

  @override
  ConsumerState<_RecordPaymentDialog> createState() =>
      _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends ConsumerState<_RecordPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _descriptionCtrl = TextEditingController();
  final _paymentId = const Uuid().v4();
  final _paidAt = DateTime.now();
  String _method = 'cash';
  String? _selectedMemberId;
  String? _selectedMembershipId;
  String? _selectedPlanId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedMemberId = widget.preSelectedMemberId;
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _descriptionCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);

    try {
      final data = ref.read(dataSyncServiceProvider);
      String? linkedMembershipId;
      String? memberName;

      if (_selectedMemberId != null) {
        final member =
            data.members.where((m) => m.id == _selectedMemberId).firstOrNull;
        if (member == null) {
          throw StateError('العضو المحدد لم يعد متاحاً.');
        }
        memberName = member.fullName;
        final selectedMembership = data.memberships
            .where((membership) =>
                membership.id == _selectedMembershipId &&
                membership.memberId == _selectedMemberId &&
                membership.status == 'active' &&
                membership.deletedAt == null)
            .firstOrNull;
        if (_selectedMembershipId != null && selectedMembership == null) {
          throw StateError('الاشتراك المحدد لم يعد متاحاً.');
        }
        linkedMembershipId = selectedMembership?.id;
      }

      final selectedPlan = data.activePlans
          .where((plan) => plan.id == _selectedPlanId)
          .firstOrNull;
      if (_selectedPlanId != null && selectedPlan == null) {
        throw StateError('الباقة المحددة لم تعد متاحة.');
      }
      final noteText = [
        if (memberName != null && linkedMembershipId == null)
          'العضو: $memberName',
        if (selectedPlan != null) 'الباقة: ${selectedPlan.name}',
        if (_descriptionCtrl.text.trim().isNotEmpty)
          _descriptionCtrl.text.trim(),
      ].join(' • ');

      final service = ref.read(dataSyncServiceProvider.notifier);
      await service.recordPayment(
        paymentId: _paymentId,
        membershipId: linkedMembershipId,
        amount: double.parse(_amountCtrl.text),
        paymentMethod: _method,
        paidAt: _paidAt,
        notes: noteText.isEmpty ? null : noteText,
      );
      final isPending = await service.isPaymentPending(_paymentId);

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text(
                isPending
                    ? 'تم حفظ الدفعة محلياً، ولم يؤكدها الخادم بعد.'
                    : 'تم تسجيل الدفعة بنجاح!',
                textDirection: ui.TextDirection.rtl),
            backgroundColor: isPending
                ? context.appPalette.warning
                : context.appPalette.success),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('فشل تسجيل الدفعة: $e',
                textDirection: ui.TextDirection.rtl),
            backgroundColor: context.appPalette.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(dataSyncServiceProvider);
    final selectedMemberMemberships = data.memberships
        .where((membership) =>
            membership.memberId == _selectedMemberId &&
            membership.status == 'active' &&
            membership.deletedAt == null)
        .toList();
    if (!selectedMemberMemberships
        .any((membership) => membership.id == _selectedMembershipId)) {
      _selectedMembershipId = null;
    }

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        scrollable: true,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        backgroundColor: context.appPalette.surfaceCard,
        title: const Text('تسجيل دفعة إيراد جديدة'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (data.members.isNotEmpty || _selectedMemberId != null)
                _SearchableMemberPicker(
                  members: data.members,
                  selectedMemberId: _selectedMemberId,
                  onChanged: (value) => setState(() {
                    _selectedMemberId = value;
                    _selectedMembershipId = null;
                  }),
                ),
              const SizedBox(height: 12),
              if (_selectedMemberId != null)
                DropdownButtonFormField<String>(
                  isExpanded: true,
                  initialValue: _selectedMembershipId ?? '',
                  decoration: const InputDecoration(
                    labelText: 'ربط باشتراك قائم (اختياري)',
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: '',
                      child: Text('دفعة عامة للعضو'),
                    ),
                    ...selectedMemberMemberships.map((membership) {
                      final planName = data.plans
                          .where((plan) => plan.id == membership.planId)
                          .firstOrNull
                          ?.name;
                      final label = planName == null
                          ? 'اشتراك حتى ${RtlSupport.formatDate(membership.endDate)}'
                          : '$planName • ${RtlSupport.formatDate(membership.endDate)}';
                      return DropdownMenuItem(
                        value: membership.id,
                        child: Text(label,
                            maxLines: 1, overflow: TextOverflow.ellipsis),
                      );
                    }),
                  ],
                  onChanged: (value) => setState(
                    () => _selectedMembershipId =
                        value == null || value.isEmpty ? null : value,
                  ),
                ),
              if (_selectedMemberId != null) const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _selectedPlanId ?? '',
                decoration: const InputDecoration(
                  labelText: 'الباقة (اختيارية، لا تنشئ اشتراكاً)',
                ),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('بدون باقة'),
                  ),
                  ...data.activePlans.map(
                    (plan) => DropdownMenuItem(
                      value: plan.id,
                      child: Text('${plan.name} (${plan.price} ج.م)',
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
                onChanged: (value) => setState(
                  () => _selectedPlanId =
                      value == null || value.isEmpty ? null : value,
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _amountCtrl,
                decoration: const InputDecoration(
                    labelText: 'قيمة المبلغ المستلم (ج.م) *'),
                keyboardType: TextInputType.number,
                validator: (value) {
                  final amount = double.tryParse(value ?? '');
                  return amount == null || !amount.isFinite || amount <= 0
                      ? 'أدخل مبلغاً أكبر من صفر'
                      : null;
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                isExpanded: true,
                initialValue: _method,
                decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                items: const [
                  DropdownMenuItem(
                    value: 'cash',
                    child: Text('نقدي (Cash)',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: 'card',
                    child: Text('فيزا / شبكة (Card)',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                  DropdownMenuItem(
                    value: 'vodafone_cash',
                    child: Text('فودافون كاش / محفظة',
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _method = val);
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descriptionCtrl,
                decoration:
                    const InputDecoration(labelText: 'وصف أو ملاحظات إضافية'),
                maxLines: 2,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: _isSaving ? null : () => Navigator.of(context).pop(),
              child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('تسجيل الدفعة'),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// --- TAB 6: SETTINGS & PROFILE TAB ---
// ==========================================
class _SettingsTab extends ConsumerWidget {
  const _SettingsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authNotifierProvider);
    final syncService = ref.watch(dataSyncServiceProvider);
    final selectedTheme = ref.watch(appThemeProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSectionHeader(
            'معلومات الصالة الرياضية (جيم الديب)',
            TextButton.icon(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (_) => _EditGymInfoDialog(gym: auth.gym),
                );
              },
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: const Text('تعديل بيانات الجيم'),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: context.appPalette.surfaceCard,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildSettingRow(context, 'اسم الصالة (العربي)',
                      auth.gym?.name ?? 'جيم الديب'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          const SizedBox(height: 20),
          _buildSectionHeader(
            'الملف الشخصي للكابتن',
            TextButton.icon(
              onPressed: () {
                showDialog<void>(
                  context: context,
                  builder: (_) => _EditProfileDialog(profile: auth.profile),
                );
              },
              icon: const Icon(Icons.edit_rounded, size: 16),
              label: const Text('تعديل الاسم'),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: context.appPalette.surfaceCard,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildSettingRow(context, 'الاسم بالكامل',
                      auth.profile?.fullName ?? 'كابتن الصالة'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text('المظهر واللغة',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Card(
            color: context.appPalette.surfaceCard,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  DropdownButtonFormField<AppThemeVariant>(
                    isExpanded: true,
                    initialValue: selectedTheme,
                    decoration: const InputDecoration(
                      labelText: 'لون التطبيق',
                      prefixIcon: Icon(Icons.palette_outlined),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: AppThemeVariant.darkGold,
                        child: Text('داكن وذهبي'),
                      ),
                      DropdownMenuItem(
                        value: AppThemeVariant.darkBlue,
                        child: Text('داكن وأزرق'),
                      ),
                      DropdownMenuItem(
                        value: AppThemeVariant.light,
                        child: Text('المظهر الفاتح'),
                      ),
                      DropdownMenuItem(
                        value: AppThemeVariant.darkPurple,
                        child: Text('داكن وبنفسجي'),
                      ),
                      DropdownMenuItem(
                        value: AppThemeVariant.darkGreen,
                        child: Text('داكن وأخضر'),
                      ),
                      DropdownMenuItem(
                        value: AppThemeVariant.neutral,
                        child: Text('محايد وعصري'),
                      ),
                    ],
                    onChanged: (variant) => _saveTheme(context, ref, variant),
                  ),
                  const Divider(),
                  _buildSettingRow(context, 'اللغة', 'العربية (افتراضي)'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          _buildSectionHeader(
            'حالة تحديث البيانات',
            TextButton.icon(
              onPressed: () async {
                final sync = ref.read(dataSyncServiceProvider.notifier);
                await sync.syncAll(forceRetry: true);
                if (!context.mounted) return;

                final state = ref.read(dataSyncServiceProvider);
                final message = state.syncStatus == SyncStatus.synced
                    ? 'تمت مزامنة البيانات بنجاح.'
                    : (state.syncErrorMessage ??
                        'تعذرت المزامنة، راجع البيانات أو الصلاحيات.');
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(message, textDirection: ui.TextDirection.rtl),
                    backgroundColor: state.syncStatus == SyncStatus.synced
                        ? context.appPalette.success
                        : context.appPalette.error,
                  ),
                );
              },
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('مزامنة فورية'),
            ),
          ),
          const SizedBox(height: 8),
          Card(
            color: context.appPalette.surfaceCard,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildSettingRow(
                      context,
                      'الاتصال بالإنترنت',
                      syncService.isOffline
                          ? 'غير متصل (Offline)'
                          : 'متصل بالشبكة (Online)'),
                  const Divider(),
                  _buildSettingRow(
                      context,
                      'حالة تحديث البيانات',
                      syncService.syncStatus == SyncStatus.synced
                          ? 'مكتملة ومؤمنة (Synced)'
                          : 'في انتظار التحديث / جاري التحديث'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
                backgroundColor: context.appPalette.error,
                foregroundColor: Colors.white),
            onPressed: () => _confirmLogout(context, ref),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('تسجيل خروج آمن من الجلسة'),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, Widget? action) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final heading = Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
        );
        if (action == null) return heading;
        if (constraints.maxWidth < 380) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              heading,
              Align(
                alignment: AlignmentDirectional.centerEnd,
                child: action,
              ),
            ],
          );
        }
        return Row(
          children: [
            Expanded(child: heading),
            action,
          ],
        );
      },
    );
  }

  Widget _buildSettingRow(BuildContext context, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: TextStyle(
                color: context.appPalette.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            textAlign: TextAlign.start,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: context.appPalette.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  void _confirmLogout(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: context.appPalette.surfaceCard,
          title: const Text('تسجيل الخروج'),
          content: const Text(
              'هل تريد تأكيد تسجيل الخروج من جيم الديب ومسح بيانات الجلسة محلياً؟'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                  backgroundColor: context.appPalette.error),
              onPressed: () async {
                Navigator.pop(ctx);
                await ref.read(authNotifierProvider.notifier).signOut();
                if (context.mounted) context.go('/login');
              },
              child: const Text('تأكيد الخروج',
                  style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// --- EDIT GYM INFO DIALOG ---
// ==========================================
class _EditGymInfoDialog extends ConsumerStatefulWidget {
  final Gym? gym;

  const _EditGymInfoDialog({this.gym});

  @override
  ConsumerState<_EditGymInfoDialog> createState() => _EditGymInfoDialogState();
}

class _EditGymInfoDialogState extends ConsumerState<_EditGymInfoDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.gym?.name ?? 'جيم الديب');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(dataSyncServiceProvider.notifier).updateGymInfo(
            name: _nameCtrl.text.trim(),
          );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('تم تحديث بيانات الصالة الرياضية بنجاح!',
                textDirection: ui.TextDirection.rtl),
            backgroundColor: context.appPalette.success),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('خطأ أثناء التعديل: $e',
                textDirection: ui.TextDirection.rtl),
            backgroundColor: context.appPalette.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        scrollable: true,
        backgroundColor: context.appPalette.surfaceCard,
        title: const Text('تعديل بيانات جيم الديب'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'اسم الصالة *'),
                  validator: (val) => val == null || val.trim().isEmpty
                      ? 'اسم الصالة مطلوب'
                      : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black))
                : const Text('حفظ البيانات'),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// --- EDIT PROFILE DIALOG ---
// ==========================================
class _EditProfileDialog extends ConsumerStatefulWidget {
  final UserProfile? profile;

  const _EditProfileDialog({this.profile});

  @override
  ConsumerState<_EditProfileDialog> createState() => _EditProfileDialogState();
}

class _EditProfileDialogState extends ConsumerState<_EditProfileDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.profile?.fullName ?? '');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await ref
          .read(dataSyncServiceProvider.notifier)
          .updateProfileName(_nameCtrl.text.trim());

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('تم تحديث الاسم بنجاح!',
                textDirection: ui.TextDirection.rtl),
            backgroundColor: context.appPalette.success),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('خطأ أثناء التعديل: $e',
                textDirection: ui.TextDirection.rtl),
            backgroundColor: context.appPalette.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: context.appPalette.surfaceCard,
        title: const Text('تعديل الاسم في الملف الشخصي'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                      labelText: 'الاسم الكامل للكابتن *'),
                  validator: (val) =>
                      val == null || val.trim().isEmpty ? 'الاسم مطلوب' : null,
                ),
                const SizedBox(height: 12),
                Text(
                  'الرتبة (${widget.profile?.role ?? "coach"}) ومعرف الجيم محمية بقواعد الأمان RLS ولا يمكن تعديلها.',
                  style: TextStyle(
                      fontSize: 10, color: context.appPalette.textMuted),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          ElevatedButton(
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.black))
                : const Text('حفظ الاسم'),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// --- ADD MEMBERSHIP DIALOG ---
// ==========================================
class _AddMembershipDialog extends StatelessWidget {
  const _AddMembershipDialog();

  @override
  Widget build(BuildContext context) {
    return const _CreateMembershipDialog();
  }
}

// ==========================================
// --- ADD PAYMENT DIALOG ---
// ==========================================
class _AddPaymentDialog extends StatelessWidget {
  final String? preSelectedMemberId;

  const _AddPaymentDialog() : preSelectedMemberId = null;

  @override
  Widget build(BuildContext context) {
    return _RecordPaymentDialog(preSelectedMemberId: preSelectedMemberId);
  }
}
