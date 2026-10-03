import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:go_router/go_router.dart';
import 'dart:ui' as ui;

import '../../auth/auth_provider.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/rtl_support.dart';
import '../../core/services/data_sync_service.dart';
import '../../core/services/whatsapp_service.dart';
import '../../core/services/csv_import_service.dart';

import '../../data/models/member.dart';
import '../../data/models/membership_plan.dart';
import '../../data/models/membership.dart';
import '../../data/models/payment.dart';
import '../../data/models/gym.dart';
import '../../data/models/user_profile.dart';

/// Navigation Tab state provider
final selectedTabProvider = StateProvider<int>((ref) => 0);

/// Filter selection for members tab
final memberFilterProvider = StateProvider<String>((ref) => 'all');

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
    final isOwner = profile?.isOwner ?? false;

    final drawerWidget = Drawer(
      backgroundColor: AppColors.background,
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.surfaceCard, AppColors.background],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Text(
                profile?.fullName.isNotEmpty == true ? profile!.fullName[0] : 'د',
                style: const TextStyle(
                  color: Color(0xFF0F141C),
                  fontWeight: FontWeight.w900,
                  fontSize: 24,
                ),
              ),
            ),
            accountName: Text(
              profile?.fullName.isNotEmpty == true ? profile!.fullName : 'كابتن جيم الديب',
              style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.textPrimary),
            ),
            accountEmail: Text(
              isOwner ? 'مالك الصالة الرياضية (Owner)' : 'مدرب معتمد (Coach)',
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildDrawerItem(0, 'الرئيسية والإحصائيات', Icons.dashboard_rounded, currentTab),
                _buildDrawerItem(1, 'إدارة الأعضاء', Icons.people_alt_rounded, currentTab),
                _buildDrawerItem(2, 'خطط الاشتراكات', Icons.card_membership_rounded, currentTab),
                _buildDrawerItem(3, 'الاشتراكات الحالية', Icons.sports_gymnastics_rounded, currentTab),
                _buildDrawerItem(4, 'سجل المدفوعات', Icons.payments_rounded, currentTab),
                _buildDrawerItem(5, 'استيراد CSV', Icons.file_upload_rounded, currentTab),
                _buildDrawerItem(6, 'الملف الشخصي والإعدادات', Icons.settings_rounded, currentTab),
              ],
            ),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.logout_rounded, color: AppColors.error),
            title: const Text('تسجيل الخروج', style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
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
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8.0),
              child: Row(
                children: [
                  Icon(Icons.wifi_off_rounded, color: AppColors.error, size: 18),
                  SizedBox(width: 4),
                  Text('أوفلاين', style: TextStyle(color: AppColors.error, fontSize: 11, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          IconButton(
            icon: syncService.syncStatus == SyncStatus.syncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(AppColors.primary)),
                  )
                : const Icon(Icons.sync_rounded),
            tooltip: 'تحديث البيانات',
            onPressed: syncService.syncStatus == SyncStatus.syncing ? null : () => syncService.syncAll(),
          ),
        ],
      ),
      body: Directionality(
        textDirection: ui.TextDirection.rtl,
        child: _buildBody(currentTab),
      ),
      floatingActionButton: _buildFloatingActionButton(context, ref, currentTab),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: currentTab > 3 ? 0 : currentTab,
        onTap: (index) {
          ref.read(selectedTabProvider.notifier).state = index;
        },
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textMuted,
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.dashboard_rounded), label: 'الرئيسية'),
          BottomNavigationBarItem(icon: Icon(Icons.people_alt_rounded), label: 'الأعضاء'),
          BottomNavigationBarItem(icon: Icon(Icons.card_membership_rounded), label: 'الخطط'),
          BottomNavigationBarItem(icon: Icon(Icons.sports_gymnastics_rounded), label: 'الاشتراكات'),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(int tabIndex, String label, IconData icon, int currentTab) {
    final isSelected = tabIndex == currentTab;
    return ListTile(
      leading: Icon(icon, color: isSelected ? AppColors.primary : AppColors.textSecondary),
      title: Text(
        label,
        style: TextStyle(
          color: isSelected ? AppColors.primary : AppColors.textPrimary,
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
      case 5:
        return 'استيراد بيانات الأعضاء';
      case 6:
        return 'الإعدادات والملف الشخصي';
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
      case 5:
        return const _CsvImportTab();
      case 6:
        return const _SettingsTab();
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
          backgroundColor: AppColors.surfaceCard,
          title: const Text('تسجيل الخروج'),
          content: const Text('هل أنت متأكد من رغبتك في تسجيل الخروج من جيم الديب؟'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () async {
                Navigator.pop(ctx);
                await ref.read(authNotifierProvider.notifier).signOut();
                if (context.mounted) context.go('/login');
              },
              child: const Text('تسجيل الخروج', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  Widget? _buildFloatingActionButton(BuildContext context, WidgetRef ref, int currentTab) {
    if (currentTab == 0 || currentTab == 1) {
      return FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: const Color(0xFF0F141C),
        icon: const Icon(Icons.person_add_rounded),
        label: const Text('إضافة عضو جديد', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const _AddMemberDialog(),
          );
        },
      );
    } else if (currentTab == 2) {
      return FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: const Color(0xFF0F141C),
        icon: const Icon(Icons.playlist_add_rounded),
        label: const Text('إضافة باقة جديدة', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const _AddPlanDialog(),
          );
        },
      );
    } else if (currentTab == 3) {
      return FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        foregroundColor: const Color(0xFF0F141C),
        icon: const Icon(Icons.card_membership_rounded),
        label: const Text('تسجيل اشتراك جديد', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const _AddMembershipDialog(),
          );
        },
      );
    } else if (currentTab == 4) {
      return FloatingActionButton.extended(
        backgroundColor: AppColors.success,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.payment_rounded),
        label: const Text('تسجيل إيصال دفع', style: TextStyle(fontWeight: FontWeight.bold)),
        onPressed: () {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (_) => const _AddPaymentDialog(),
          );
        },
      );
    }
    return null;
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
    final sevenDaysFromNow = now.add(const Duration(days: 7));
    final expiringSoon = data.memberships.where((m) {
      return m.endDate.isAfter(now) && m.endDate.isBefore(sevenDaysFromNow);
    }).length;

    final today = DateTime(now.year, now.month, now.day);
    final todayPayments = data.payments.where((p) {
      final payDate = DateTime(p.paidAt.year, p.paidAt.month, p.paidAt.day);
      return payDate.isAtSameMomentAs(today);
    }).toList();
    final todayRevenue = todayPayments.fold<double>(0, (sum, p) => sum + p.amount);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (data.syncStatus == SyncStatus.error)
            Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppColors.error.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.warning_amber_rounded, color: AppColors.error),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'فيه بيانات لسه متسجلتش على الحساب. هنحاول تاني لما الاتصال يستقر.',
                      style: const TextStyle(color: AppColors.error, fontSize: 13),
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
                label: 'إجمالي المشتركين',
                value: '$totalMembers',
                icon: Icons.people_rounded,
                color: AppColors.primary,
                onTap: () {
                  ref.read(memberFilterProvider.notifier).state = 'all';
                  ref.read(selectedTabProvider.notifier).state = 1;
                },
              ),
              _buildClickableStatCard(
                label: 'المشتركون النشطون',
                value: '$activeMembers',
                icon: Icons.check_circle_outline_rounded,
                color: AppColors.success,
                onTap: () {
                  ref.read(memberFilterProvider.notifier).state = 'active';
                  ref.read(selectedTabProvider.notifier).state = 1;
                },
              ),
              _buildClickableStatCard(
                label: 'غير النشطين',
                value: '$inactiveMembers',
                icon: Icons.cancel_outlined,
                color: AppColors.textMuted,
                onTap: () {
                  ref.read(memberFilterProvider.notifier).state = 'inactive';
                  ref.read(selectedTabProvider.notifier).state = 1;
                },
              ),
              _buildClickableStatCard(
                label: 'ينتهي قريباً (٧ أيام)',
                value: '$expiringSoon',
                icon: Icons.alarm_rounded,
                color: AppColors.warning,
                onTap: () {
                  ref.read(selectedTabProvider.notifier).state = 3;
                },
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Quick Actions Card
          Card(
            color: AppColors.surfaceCard,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('إجراءات سريعة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.textPrimary)),
                      Text('جيم الديب', style: TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      ElevatedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => const _AddMemberDialog(),
                            );
                          },
                          icon: const Icon(Icons.person_add_rounded, size: 16),
                          label: const Text('إضافة عضو', style: TextStyle(fontSize: 12)),
                        ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => const _AddMembershipDialog(),
                            );
                          },
                          icon: const Icon(Icons.card_membership_rounded, size: 16),
                          label: const Text('اشتراك جديد', style: TextStyle(fontSize: 12)),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      OutlinedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => const _AddPaymentDialog(),
                            );
                          },
                          icon: const Icon(Icons.payment_rounded, size: 16),
                          label: const Text('تسجيل دفعة', style: TextStyle(fontSize: 12)),
                        ),
                      const SizedBox(height: 8),
                      OutlinedButton.icon(
                          onPressed: () {
                            ref.read(selectedTabProvider.notifier).state = 5;
                          },
                          icon: const Icon(Icons.upload_file_rounded, size: 16),
                          label: const Text('استيراد CSV', style: TextStyle(fontSize: 12)),
                        ),
                    ],
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
              color: AppColors.surfaceCard,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Text('إيرادات اليوم المستلمة', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                            SizedBox(width: 6),
                            Icon(Icons.arrow_forward_ios_rounded, size: 12, color: AppColors.textMuted),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          RtlSupport.formatEgp(todayRevenue),
                          style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.success),
                        ),
                      ],
                    ),
                    CircleAvatar(
                      radius: 26,
                      backgroundColor: AppColors.success.withOpacity(0.15),
                      child: const Icon(Icons.monetization_on_rounded, color: AppColors.success, size: 28),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('آخر الأعضاء المسجلين', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              TextButton(
                onPressed: () => ref.read(selectedTabProvider.notifier).state = 1,
                child: const Text('عرض الكل', style: TextStyle(color: AppColors.primary, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (data.members.isEmpty)
            _buildEmptyCard('لا يوجد أعضاء مسجلين بعد.')
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: data.members.length > 4 ? 4 : data.members.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final member = data.members[index];
                return ListTile(
                  tileColor: AppColors.surfaceCard,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.primary.withOpacity(0.15),
                    child: Text(member.fullName[0], style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                  ),
                  title: Text(member.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  subtitle: Text('انضمام: ${RtlSupport.formatDate(member.joinDate)}', style: const TextStyle(fontSize: 11)),
                  trailing: const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AppColors.textMuted),
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: AppColors.surfaceCard,
                      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
                      builder: (ctx) => _MemberDetailsBottomSheet(member: member),
                    );
                  },
                );
              },
            ),

          const SizedBox(height: 24),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('آخر الإيرادات والمدفوعات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              TextButton(
                onPressed: () => ref.read(selectedTabProvider.notifier).state = 4,
                child: const Text('سجل الدفع', style: TextStyle(color: AppColors.primary, fontSize: 12)),
              ),
            ],
          ),
          const SizedBox(height: 8),

          if (data.payments.isEmpty)
            _buildEmptyCard('لا يوجد مدفوعات مسجلة بعد.')
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: data.payments.length > 4 ? 4 : data.payments.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final payment = data.payments[index];
                return ListTile(
                  tileColor: AppColors.surfaceCard,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: CircleAvatar(
                    backgroundColor: AppColors.success.withOpacity(0.15),
                    child: const Icon(Icons.receipt_long_rounded, color: AppColors.success, size: 18),
                  ),
                  title: Text(
                    payment.notes ?? 'إيصال دفع',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  subtitle: Text(
                    '${payment.paymentMethod == "cash" ? "نقدي" : "بطاقة/تحويل"} • ${RtlSupport.formatDate(payment.paidAt)}',
                    style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                  ),
                  trailing: Text(
                    RtlSupport.formatEgp(payment.amount),
                    style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success, fontSize: 14),
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
        color: AppColors.surfaceCard,
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
                  Row(
                    children: [
                      Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11, fontWeight: FontWeight.bold)),
                      const SizedBox(width: 4),
                      const Icon(Icons.arrow_forward_ios_rounded, size: 10, color: AppColors.textMuted),
                    ],
                  ),
                ],
              ),
              Text(value, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: AppColors.textPrimary)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyCard(String text) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: AppColors.surfaceCard, borderRadius: BorderRadius.circular(16)),
      child: Center(child: Text(text, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
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

    final filteredMembers = data.members.where((m) {
      final nameMatch = m.fullName.toLowerCase().contains(_searchQuery.toLowerCase());
      final phoneMatch = m.phone?.contains(_searchQuery) ?? false;
      final matchesSearch = nameMatch || phoneMatch;

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
                  _buildFilterChip('active', 'نشط (${data.members.where((m) => m.isActive).length})'),
                  _buildFilterChip('inactive', 'غير نشط (${data.members.where((m) => !m.isActive).length})'),
                ],
              ),
            ],
          ),
        ),

        Expanded(
          child: filteredMembers.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.people_outline_rounded, size: 48, color: AppColors.textMuted.withOpacity(0.5)),
                        const SizedBox(height: 12),
                        const Text(
                          'لا يوجد أعضاء يطابقون البحث أو القائمة فارغة',
                          style: TextStyle(color: AppColors.textSecondary, fontSize: 14),
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          onPressed: () {
                            showDialog(
                              context: context,
                              barrierDismissible: false,
                              builder: (_) => const _AddMemberDialog(),
                            );
                          },
                          icon: const Icon(Icons.person_add_rounded),
                          label: const Text('إضافة عضو جديد الآن'),
                        ),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filteredMembers.length,
                  itemBuilder: (context, index) {
                    final member = filteredMembers[index];
                    return Card(
                      color: AppColors.surfaceCard,
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ListTile(
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primary.withOpacity(0.12),
                          child: Text(member.fullName[0], style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.bold)),
                        ),
                        title: Text(member.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                        subtitle: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [if (member.phone?.isNotEmpty == true) Text(member.phone!), Text('أضافه: ${data.creatorName(member.createdBy)}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted))]),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (member.phone != null && member.phone!.isNotEmpty)
                              Text(member.phone!, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                            Text('انضمام: ${RtlSupport.formatDate(member.joinDate)}', style: const TextStyle(fontSize: 11)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (member.phone != null && member.phone!.isNotEmpty)
                              IconButton(
                                icon: const Icon(Icons.chat_bubble_outline_rounded, color: AppColors.success),
                                tooltip: 'مراسلة واتساب',
                                onPressed: () => _openWhatsapp(member),
                              ),
                            IconButton(
                              icon: const Icon(Icons.arrow_forward_ios_rounded, size: 16, color: AppColors.primary),
                              onPressed: () => _showMemberDetails(member),
                            ),
                          ],
                        ),
                        onTap: () => _showMemberDetails(member),
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
      label: Text(label, style: TextStyle(color: isSelected ? const Color(0xFF0F141C) : AppColors.textPrimary, fontSize: 12, fontWeight: FontWeight.bold)),
      selected: isSelected,
      onSelected: (_) => ref.read(memberFilterProvider.notifier).state = type,
      selectedColor: AppColors.primary,
      backgroundColor: AppColors.surface,
    );
  }

  void _openWhatsapp(Member member) {
    if (member.phone == null || member.phone!.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('هذا العضو ليس لديه رقم هاتف مسجل.'), backgroundColor: AppColors.error),
      );
      return;
    }

    final data = ref.read(dataSyncServiceProvider);
    final activeMembership = data.memberships.where((m) => m.memberId == member.id && !m.isExpired).firstOrNull;
    final planName = activeMembership?.planId != null
        ? data.plans.where((p) => p.id == activeMembership!.planId).firstOrNull?.name ?? 'الاشتراك الحالي'
        : 'الاشتراك الشهري';

    final dueAmount = activeMembership?.price ?? 0.0;
    final endDateStr = activeMembership != null ? RtlSupport.formatDate(activeMembership.endDate) : 'نهاية الشهر';

    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.surfaceCard,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('مراسلة ${member.fullName} عبر واتساب:', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.chat_rounded, color: AppColors.success),
                title: const Text('رسالة ترحيبية وتواصل عام'),
                onTap: () {
                  Navigator.pop(ctx);
                  WhatsappService.launchWhatsApp(
                    phone: member.phone!,
                    message: WhatsappService.getGeneralContact(member.fullName),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.payment_rounded, color: AppColors.primary),
                title: Text('تذكير بمستحقات الاشتراك (${RtlSupport.formatEgp(dueAmount)})'),
                onTap: () {
                  Navigator.pop(ctx);
                  WhatsappService.launchWhatsApp(
                    phone: member.phone!,
                    message: WhatsappService.getPaymentReminder(member.fullName, dueAmount),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.timer_rounded, color: AppColors.warning),
                title: Text('تذكير بانتهاء الاشتراك ($endDateStr)'),
                onTap: () {
                  Navigator.pop(ctx);
                  WhatsappService.launchWhatsApp(
                    phone: member.phone!,
                    message: WhatsappService.getExpiryReminder(member.fullName, planName, endDateStr),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showMemberDetails(Member member) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceCard,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => _MemberDetailsBottomSheet(member: member),
    );
  }
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

      final newMember = await ref.read(dataSyncServiceProvider.notifier).addMember(
            fullName: name,
            phone: phone.isNotEmpty ? phone : null,
            notes: notes.isNotEmpty ? notes : null,
            joinDate: _joinDate,
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
          backgroundColor: AppColors.success,
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
          content: Text('فشل الحفظ: $cleanMsg', textDirection: ui.TextDirection.rtl),
          backgroundColor: AppColors.error,
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
        backgroundColor: AppColors.surfaceCard,
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
                      color: AppColors.error.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_errorMessage!, style: const TextStyle(color: AppColors.error, fontSize: 12)),
                  ),

                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'الاسم الكامل *',
                    hintText: 'مثال: كابتن أحمد الديب',
                    prefixIcon: Icon(Icons.person_rounded),
                  ),
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'يرجى إدخال اسم العضو';
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(10),
                      color: AppColors.surface,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
                            const SizedBox(width: 8),
                            const Text('تاريخ الانضمام:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                          ],
                        ),
                        Text(
                          DateFormat('yyyy/MM/dd').format(_joinDate),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
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
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Color(0xFF0F141C))))
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
      await ref.read(dataSyncServiceProvider.notifier).editMember(
            widget.member.copyWith(
              fullName: _nameController.text.trim(),
              phone: _phoneController.text.trim().isNotEmpty ? _phoneController.text.trim() : null,
              notes: _notesController.text.trim().isNotEmpty ? _notesController.text.trim() : null,
              joinDate: _joinDate,
              isActive: _isActive,
            ),
          );

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث بيانات العضو بنجاح!', textDirection: ui.TextDirection.rtl), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ أثناء التعديل: $e', textDirection: ui.TextDirection.rtl), backgroundColor: AppColors.error),
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
        backgroundColor: AppColors.surfaceCard,
        title: const Text('تعديل بيانات العضو'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameController,
                  decoration: const InputDecoration(labelText: 'الاسم الكامل *'),
                  validator: (v) => v == null || v.trim().isEmpty ? 'الاسم مطلوب' : null,
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
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                    decoration: BoxDecoration(
                      border: Border.all(color: AppColors.border),
                      borderRadius: BorderRadius.circular(10),
                      color: AppColors.surface,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.calendar_today_rounded, size: 18, color: AppColors.primary),
                            SizedBox(width: 8),
                            Text('تاريخ الانضمام:', style: TextStyle(fontSize: 13, color: AppColors.textSecondary)),
                          ],
                        ),
                        Text(
                          DateFormat('yyyy/MM/dd').format(_joinDate),
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.textPrimary),
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
                  activeColor: AppColors.primary,
                  contentPadding: EdgeInsets.zero,
                  onChanged: (v) => setState(() => _isActive = v),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: _isSaving ? null : () => Navigator.of(context).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving ? const CircularProgressIndicator() : const Text('حفظ التعديلات'),
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

    final memberMemberships = data.memberships.where((m) => m.memberId == member.id).toList();
    final memberPayments = data.payments.where((p) {
      if (p.membershipId != null && memberMemberships.any((m) => m.id == p.membershipId)) return true;
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
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: AppColors.primary.withOpacity(0.2),
                        child: Text(member.fullName[0], style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.primary)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(member.fullName, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17)),
                            Text(member.isActive ? 'عضو نشط' : 'عضو غير نشط', style: TextStyle(color: member.isActive ? AppColors.success : AppColors.error, fontSize: 11, fontWeight: FontWeight.bold)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('رقم الهاتف المسجل', style: TextStyle(color: AppColors.textSecondary, fontSize: 11)),
                    Text(member.phone ?? 'غير متوفر', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  ],
                ),
                if (member.phone != null && member.phone!.isNotEmpty)
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.success, foregroundColor: Colors.white),
                    icon: const Icon(Icons.chat, size: 16),
                    label: const Text('واتساب'),
                    onPressed: () {
                      WhatsappService.launchWhatsApp(
                        phone: member.phone!,
                        message: WhatsappService.getGeneralContact(member.fullName),
                      );
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),

            _buildDetailItem('تاريخ الانضمام', RtlSupport.formatDate(member.joinDate)),
            _buildDetailItem('ملاحظات الكابتن', member.notes ?? 'لا توجد ملاحظات مدونة.'),

            const Divider(height: 28),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('سجل الاشتراكات والباقات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                TextButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => _CreateMembershipDialog(preSelectedMemberId: member.id),
                    );
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('اشتراك جديد', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (memberMemberships.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
                child: const Center(child: Text('لا يوجد اشتراكات مسجلة لهذا العضو.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
              )
            else
              ...memberMemberships.map((m) {
                final plan = data.plans.where((p) => p.id == m.planId).firstOrNull;
                final expired = m.isExpired;
                return Card(
                  color: AppColors.surface,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    dense: true,
                    title: Text(plan?.name ?? 'باقة مخصصة', style: const TextStyle(fontWeight: FontWeight.bold)),
                    subtitle: Text('من ${RtlSupport.formatDate(m.startDate)} إلى ${RtlSupport.formatDate(m.endDate)} • ${RtlSupport.formatEgp(m.price)}'),
                    trailing: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: expired ? AppColors.error.withOpacity(0.1) : AppColors.success.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(expired ? 'منتهي' : 'نشط', style: TextStyle(color: expired ? AppColors.error : AppColors.success, fontSize: 10, fontWeight: FontWeight.bold)),
                    ),
                  ),
                );
              }),

            const Divider(height: 28),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('سجل المدفوعات والإيصالات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                TextButton.icon(
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (_) => _RecordPaymentDialog(preSelectedMemberId: member.id),
                    );
                  },
                  icon: const Icon(Icons.add, size: 16),
                  label: const Text('تسجيل دفعة', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            if (memberPayments.isEmpty)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
                child: const Center(child: Text('لا يوجد سجل مدفوعات مسجل.', style: TextStyle(fontSize: 12, color: AppColors.textSecondary))),
              )
            else
              ...memberPayments.map((p) {
                return Card(
                  color: AppColors.surface,
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    dense: true,
                    title: Text(RtlSupport.formatEgp(p.amount), style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.success)),
                    subtitle: Text('${p.paymentMethod == "cash" ? "نقدي" : "فيزا"} • ${RtlSupport.formatDate(p.paidAt)}'),
                    trailing: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 16),
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
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
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

  Widget _buildDetailItem(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 11)),
          const SizedBox(height: 2),
          Text(val, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  void _confirmDeleteMember(BuildContext context, WidgetRef ref, Member member) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          title: const Text('تأكيد الحذف'),
          content: Text('هل أنت متأكد من حذف العضو ${member.fullName} نهائياً؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () async {
                Navigator.pop(ctx);
                Navigator.pop(context); // Close bottom sheet
                await ref.read(dataSyncServiceProvider.notifier).deleteMember(member.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم حذف العضو بنجاح', textDirection: ui.TextDirection.rtl)),
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
              ? const Center(child: Text('لا توجد باقات اشتراك مسجلة حالياً.', style: TextStyle(color: AppColors.textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: data.plans.length,
                  itemBuilder: (context, index) {
                    final plan = data.plans[index];
                    return Card(
                      color: AppColors.surfaceCard,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(plan.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: plan.isActive ? AppColors.success.withOpacity(0.1) : AppColors.error.withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(plan.isActive ? 'مفعلة' : 'معطلة', style: TextStyle(color: plan.isActive ? AppColors.success : AppColors.error, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                Text('المدة: ${plan.durationDays} يوم', style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(RtlSupport.formatEgp(plan.price), style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.primary)),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_rounded, color: AppColors.textSecondary, size: 20),
                                      onPressed: () {
                                        showDialog(context: context, builder: (_) => _EditPlanDialog(plan: plan));
                                      },
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_rounded, color: AppColors.error, size: 20),
                                      onPressed: () => _confirmDeletePlan(context, ref, plan),
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
          child: ElevatedButton.icon(
            onPressed: () {
              showDialog(context: context, builder: (_) => const _AddPlanDialog());
            },
            icon: const Icon(Icons.add_card_rounded),
            label: const Text('إضافة باقة جديدة'),
          ),
        ),
      ],
    );
  }

  void _confirmDeletePlan(BuildContext context, WidgetRef ref, MembershipPlan plan) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          title: const Text('تأكيد حذف الباقة'),
          content: Text('هل أنت متأكد من حذف الباقة ${plan.name} نهائياً؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () async {
                Navigator.pop(ctx);
                await ref.read(dataSyncServiceProvider.notifier).deletePlan(plan.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم حذف الباقة بنجاح', textDirection: ui.TextDirection.rtl)),
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
        const SnackBar(content: Text('تمت إضافة الباقة بنجاح!', textDirection: ui.TextDirection.rtl), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل الحفظ: $e', textDirection: ui.TextDirection.rtl), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text('إضافة باقة اشتراك جديدة'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'اسم الباقة *'),
                validator: (v) => v == null || v.trim().isEmpty ? 'الاسم مطلوب' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _durationCtrl,
                decoration: const InputDecoration(labelText: 'المدة باليوم *'),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || int.tryParse(v) == null ? 'أدخل رقم صحيح' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceCtrl,
                decoration: const InputDecoration(labelText: 'سعر الاشتراك (ج.م) *'),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || double.tryParse(v) == null ? 'أدخل مبلغ صحيح' : null,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: _isSaving ? null : () => Navigator.of(context).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving ? const CircularProgressIndicator() : const Text('إضافة'),
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
    _durationCtrl = TextEditingController(text: widget.plan.durationDays.toString());
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
        const SnackBar(content: Text('تم تعديل الباقة بنجاح!', textDirection: ui.TextDirection.rtl), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل التعديل: $e', textDirection: ui.TextDirection.rtl), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text('تعديل باقة الاشتراك'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'اسم الباقة *'),
                validator: (v) => v == null || v.trim().isEmpty ? 'الاسم مطلوب' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _durationCtrl,
                decoration: const InputDecoration(labelText: 'المدة باليوم *'),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || int.tryParse(v) == null ? 'أدخل رقم صحيح' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceCtrl,
                decoration: const InputDecoration(labelText: 'السعر (ج.م) *'),
                keyboardType: TextInputType.number,
                validator: (v) => v == null || double.tryParse(v) == null ? 'أدخل مبلغ صحيح' : null,
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                title: const Text('حالة الباقة مفعلة'),
                value: _isActive,
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => _isActive = v),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: _isSaving ? null : () => Navigator.of(context).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving ? const CircularProgressIndicator() : const Text('حفظ التعديلات'),
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
              ? const Center(child: Text('لا توجد اشتراكات مفعلة حالياً.', style: TextStyle(color: AppColors.textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: data.memberships.length,
                  itemBuilder: (context, index) {
                    final membership = data.memberships[index];
                    final member = data.members.where((m) => m.id == membership.memberId).firstOrNull ??
                        Member(id: '', gymId: '', fullName: 'عضو محذوف', joinDate: DateTime.now(), createdAt: DateTime.now(), updatedAt: DateTime.now());
                    final plan = data.plans.where((p) => p.id == membership.planId).firstOrNull ??
                        MembershipPlan(id: '', gymId: '', name: 'باقة مخصصة', createdAt: DateTime.now(), updatedAt: DateTime.now());

                    final expired = membership.isExpired;

                    return Card(
                      color: AppColors.surfaceCard,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: ListTile(
                        onTap: () {
                          showDialog(context: context, builder: (_) => _EditMembershipDialog(membership: membership));
                        },
                        leading: CircleAvatar(
                          backgroundColor: expired ? AppColors.error.withOpacity(0.12) : AppColors.success.withOpacity(0.12),
                          child: Icon(expired ? Icons.timer_off_rounded : Icons.offline_bolt_rounded, color: expired ? AppColors.error : AppColors.success),
                        ),
                        title: Text(member.fullName, style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('الباقة: ${plan.name} • القيمة: ${RtlSupport.formatEgp(membership.price)}', style: const TextStyle(fontSize: 12)),
                            Text('من: ${RtlSupport.formatDate(membership.startDate)} إلى ${RtlSupport.formatDate(membership.endDate)}', style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                            Text('سجّل الاشتراك: ${data.creatorName(membership.createdBy)}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                          ],
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: expired ? AppColors.error.withOpacity(0.1) : AppColors.success.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                expired ? 'منتهي' : (membership.status == 'cancelled' ? 'ملغى' : 'ساري'),
                                style: TextStyle(color: expired ? AppColors.error : AppColors.success, fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(Icons.edit_rounded, size: 18, color: AppColors.textSecondary),
                              tooltip: 'تعديل بيانات الاشتراك',
                              onPressed: () {
                                showDialog(context: context, builder: (_) => _EditMembershipDialog(membership: membership));
                              },
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AppColors.error),
                              tooltip: 'حذف الاشتراك',
                              onPressed: () => _confirmDeleteMembership(context, ref, membership),
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
          child: ElevatedButton.icon(
            onPressed: () {
              showDialog(context: context, builder: (_) => const _CreateMembershipDialog());
            },
            icon: const Icon(Icons.add_task_rounded),
            label: const Text('تسجيل اشتراك لعضو'),
          ),
        ),
      ],
    );
  }

  void _confirmDeleteMembership(BuildContext context, WidgetRef ref, Membership membership) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          title: const Text('تأكيد حذف الاشتراك'),
          content: const Text('هل أنت متأكد من حذف هذا الاشتراك؟ سيتم وضع علامة ملغى وحذفه من السجلات.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () async {
                Navigator.pop(ctx);
                await ref.read(dataSyncServiceProvider.notifier).deleteMembership(membership.id);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('تم حذف الاشتراك بنجاح', textDirection: ui.TextDirection.rtl)),
                );
              },
              child: const Text('حذف الاشتراك', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
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
  ConsumerState<_EditMembershipDialog> createState() => _EditMembershipDialogState();
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
    _priceCtrl = TextEditingController(text: widget.membership.price.toString());
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

      await ref.read(dataSyncServiceProvider.notifier).editMembership(updated);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث بيانات الاشتراك بنجاح!', textDirection: ui.TextDirection.rtl), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ أثناء التعديل: $e', textDirection: ui.TextDirection.rtl), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(dataSyncServiceProvider);

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text('تعديل بيانات الاشتراك'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _planId,
                  decoration: const InputDecoration(labelText: 'خطة / باقة الاشتراك'),
                  items: data.plans.map((p) {
                    return DropdownMenuItem(value: p.id, child: Text('${p.name} (${p.price} ج.م)'));
                  }).toList(),
                  onChanged: (val) {
                    setState(() {
                      _planId = val;
                      final selected = data.plans.where((p) => p.id == val).firstOrNull;
                      if (selected != null) {
                        _priceCtrl.text = selected.price.toString();
                        _endDate = _startDate.add(Duration(days: selected.durationDays));
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceCtrl,
                  decoration: const InputDecoration(labelText: 'سعر الاشتراك (ج.م) *'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || double.tryParse(v) == null ? 'أدخل مبلغ صحيح' : null,
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('تاريخ البدء', style: TextStyle(fontSize: 12)),
                  subtitle: Text(DateFormat('yyyy/MM/dd').format(_startDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.calendar_today_rounded, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: _startDate, firstDate: DateTime(2020), lastDate: DateTime(2035));
                    if (picked != null) setState(() => _startDate = picked);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('تاريخ الانتهاء', style: TextStyle(fontSize: 12)),
                  subtitle: Text(DateFormat('yyyy/MM/dd').format(_endDate), style: const TextStyle(fontWeight: FontWeight.bold)),
                  trailing: const Icon(Icons.calendar_today_rounded, size: 18),
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: _endDate, firstDate: DateTime(2020), lastDate: DateTime(2035));
                    if (picked != null) setState(() => _endDate = picked);
                  },
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _status,
                  decoration: const InputDecoration(labelText: 'حالة الاشتراك'),
                  items: const [
                    DropdownMenuItem(value: 'active', child: Text('ساري ومفعل (Active)')),
                    DropdownMenuItem(value: 'expired', child: Text('منتهي (Expired)')),
                    DropdownMenuItem(value: 'cancelled', child: Text('ملغى / متوقف (Cancelled)')),
                  ],
                  onChanged: (val) => setState(() => _status = val ?? 'active'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: _isSaving ? null : () => Navigator.of(context).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving ? const CircularProgressIndicator() : const Text('حفظ التعديلات'),
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
  ConsumerState<_CreateMembershipDialog> createState() => _CreateMembershipDialogState();
}

class _CreateMembershipDialogState extends ConsumerState<_CreateMembershipDialog> {
  String? _selectedMemberId;
  String? _selectedPlanId;
  final _priceCtrl = TextEditingController();
  DateTime _startDate = DateTime.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 30));
  bool _recordPaymentNow = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedMemberId = widget.preSelectedMemberId;
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
        const SnackBar(content: Text('يرجى اختيار العضو والباقة أولاً', textDirection: ui.TextDirection.rtl), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final price = double.tryParse(_priceCtrl.text) ?? 0.0;
      final newMembership = await ref.read(dataSyncServiceProvider.notifier).createMembership(
            memberId: _selectedMemberId!,
            planId: _selectedPlanId!,
            startDate: _startDate,
            endDate: _endDate,
            price: price,
          );

      if (_recordPaymentNow) {
        await ref.read(dataSyncServiceProvider.notifier).recordPayment(
              membershipId: newMembership.id,
              amount: price,
              paymentMethod: 'cash',
              paidAt: DateTime.now(),
              notes: 'دفعة تفعيل اشتراك',
            );
      }

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تفعيل الاشتراك بنجاح!', textDirection: ui.TextDirection.rtl), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تفعيل الاشتراك: $e', textDirection: ui.TextDirection.rtl), backgroundColor: AppColors.error),
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
          backgroundColor: AppColors.surfaceCard,
          title: const Text('تنبيه'),
          content: const Text('الرجاء إضافة عضو واحد على الأقل أولاً لتسجيل اشتراك.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً'))],
        ),
      );
    }

    if (data.plans.isEmpty) {
      return Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          title: const Text('تنبيه'),
          content: const Text('الرجاء إضافة باقة أسعار أولاً لتفعيل الاشتراك.'),
          actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('حسناً'))],
        ),
      );
    }

    _selectedMemberId ??= data.members.first.id;
    _selectedPlanId ??= data.plans.first.id;
    if (_priceCtrl.text.isEmpty) {
      _priceCtrl.text = data.plans.first.price.toString();
    }

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text('تسجيل باقة اشتراك لعضو'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedMemberId,
                decoration: const InputDecoration(labelText: 'اختر العضو'),
                items: data.members.map((m) => DropdownMenuItem(value: m.id, child: Text(m.fullName))).toList(),
                onChanged: (val) => setState(() => _selectedMemberId = val),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedPlanId,
                decoration: const InputDecoration(labelText: 'باقة الاشتراك'),
                items: data.plans.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name} (${p.price} ج.م)'))).toList(),
                onChanged: (val) {
                  final p = data.plans.firstWhere((p) => p.id == val);
                  setState(() {
                    _selectedPlanId = val;
                    _priceCtrl.text = p.price.toString();
                    _endDate = _startDate.add(Duration(days: p.durationDays));
                  });
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _priceCtrl,
                decoration: const InputDecoration(labelText: 'السعر الفعلي المطلوب (ج.م)'),
                keyboardType: TextInputType.number,
              ),
              const SizedBox(height: 12),
              CheckboxListTile(
                title: const Text('تسجيل استلام الدفعة نقداً فوراً', style: TextStyle(fontSize: 12)),
                value: _recordPaymentNow,
                activeColor: AppColors.primary,
                contentPadding: EdgeInsets.zero,
                onChanged: (v) => setState(() => _recordPaymentNow = v ?? true),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: _isSaving ? null : () => Navigator.of(context).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving ? const CircularProgressIndicator() : const Text('تفعيل الاشتراك'),
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
              ? const Center(child: Text('لا توجد مدفوعات مسجلة حالياً.', style: TextStyle(color: AppColors.textSecondary)))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: data.payments.length,
                  itemBuilder: (context, index) {
                    final payment = data.payments[index];

                    return Card(
                      color: AppColors.surfaceCard,
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16.0),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  payment.notes ?? 'إيصال دفع',
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                const SizedBox(height: 3),
                                Text('سجّل الدفعة: ${data.creatorName(payment.recordedBy)}', style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                const SizedBox(height: 4),
                                Text(
                                  RtlSupport.formatEgp(payment.amount),
                                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AppColors.success),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text(
                                  'طريقة الدفع: ${payment.paymentMethod == "cash" ? "نقدي" : "بطاقة/تحويل"}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 4),
                                Text(RtlSupport.formatDate(payment.paidAt), style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                                const SizedBox(height: 4),
                                Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit_rounded, color: AppColors.textSecondary, size: 18),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () {
                                        showDialog(context: context, builder: (_) => _EditPaymentDialog(payment: payment));
                                      },
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(Icons.delete_rounded, color: AppColors.error, size: 18),
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(),
                                      onPressed: () => _confirmDeletePayment(context, ref, payment),
                                    ),
                                  ],
                                ),
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
          child: ElevatedButton.icon(
            onPressed: () {
              showDialog(context: context, builder: (_) => const _RecordPaymentDialog());
            },
            icon: const Icon(Icons.add_reaction_rounded),
            label: const Text('تسجيل إيراد / دفعة مستلمة'),
          ),
        ),
      ],
    );
  }

  void _confirmDeletePayment(BuildContext context, WidgetRef ref, Payment payment) {
    showDialog(
      context: context,
      builder: (ctx) => Directionality(
        textDirection: ui.TextDirection.rtl,
        child: AlertDialog(
          backgroundColor: AppColors.surfaceCard,
          title: const Text('تأكيد حذف الدفعة المالية'),
          content: Text('تحذير مالي: هل تريد تأكيد حذف هذه الدفعة بقيمة (${RtlSupport.formatEgp(payment.amount)})؟ سيؤثر هذا على إجمالي إيرادات الخزينة.'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('تراجع')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () async {
                Navigator.pop(ctx);
                await ref.read(dataSyncServiceProvider.notifier).deletePayment(payment.id);
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('تم حذف الدفعة المالية بنجاح!', textDirection: ui.TextDirection.rtl), backgroundColor: AppColors.success),
                  );
                }
              },
              child: const Text('تأكيد الحذف', style: TextStyle(color: Colors.white)),
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

      await ref.read(dataSyncServiceProvider.notifier).editPayment(updated);

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث الدفعة المالية بنجاح!', textDirection: ui.TextDirection.rtl), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ أثناء التعديل: $e', textDirection: ui.TextDirection.rtl), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text('تعديل الدفعة المالية'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _amountCtrl,
                  decoration: const InputDecoration(labelText: 'المبلغ المستلم (ج.م) *'),
                  keyboardType: TextInputType.number,
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'المبلغ مطلوب';
                    final parsed = double.tryParse(val);
                    if (parsed == null || parsed <= 0) return 'أدخل مبلغ صحيح';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _method,
                  decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('نقدي كاش')),
                    DropdownMenuItem(value: 'vodafone_cash', child: Text('فودافون كاش / محفظة')),
                    DropdownMenuItem(value: 'instapay', child: Text('إنستاباي (InstaPay)')),
                    DropdownMenuItem(value: 'card', child: Text('بطاقة بنكية / فيزا')),
                  ],
                  onChanged: (val) => setState(() => _method = val ?? 'cash'),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(labelText: 'ملاحظات الإيصال'),
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
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
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
class _RecordPaymentDialog extends ConsumerStatefulWidget {
  final String? preSelectedMemberId;

  const _RecordPaymentDialog({this.preSelectedMemberId});

  @override
  ConsumerState<_RecordPaymentDialog> createState() => _RecordPaymentDialogState();
}

class _RecordPaymentDialogState extends ConsumerState<_RecordPaymentDialog> {
  final _formKey = GlobalKey<FormState>();
  final _amountCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _method = 'cash';
  String? _selectedMemberId;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedMemberId = widget.preSelectedMemberId;
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
      final data = ref.read(dataSyncServiceProvider);
      String? linkedMembershipId;
      String? memberName;

      if (_selectedMemberId != null) {
        final member = data.members.where((m) => m.id == _selectedMemberId).firstOrNull;
        memberName = member?.fullName;
        final mem = data.memberships.where((m) => m.memberId == _selectedMemberId && !m.isExpired).firstOrNull;
        linkedMembershipId = mem?.id;
      }

      final noteText = _notesCtrl.text.isNotEmpty
          ? _notesCtrl.text
          : (memberName != null ? 'دفعة للعضو: $memberName' : null);

      await ref.read(dataSyncServiceProvider.notifier).recordPayment(
            membershipId: linkedMembershipId,
            amount: double.parse(_amountCtrl.text),
            paymentMethod: _method,
            paidAt: DateTime.now(),
            notes: noteText,
          );

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل الدفعة بنجاح!', textDirection: ui.TextDirection.rtl), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تسجيل الدفعة: $e', textDirection: ui.TextDirection.rtl), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(dataSyncServiceProvider);

    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text('تسجيل دفعة إيراد جديدة'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (data.members.isNotEmpty)
                  DropdownButtonFormField<String>(
                    value: _selectedMemberId,
                    decoration: const InputDecoration(labelText: 'اختر العضو المسدد (اختياري)'),
                    items: [
                      const DropdownMenuItem(value: null, child: Text('دفعة عامة بدون ربط بعضو')),
                      ...data.members.map((m) => DropdownMenuItem(value: m.id, child: Text(m.fullName))),
                    ],
                    onChanged: (val) => setState(() => _selectedMemberId = val),
                  ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountCtrl,
                  decoration: const InputDecoration(labelText: 'قيمة المبلغ المستلم (ج.م) *'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || double.tryParse(v) == null ? 'أدخل مبلغ صحيح' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _method,
                  decoration: const InputDecoration(labelText: 'طريقة الدفع'),
                  items: const [
                    DropdownMenuItem(value: 'cash', child: Text('نقدي (Cash)')),
                    DropdownMenuItem(value: 'card', child: Text('فيزا / شبكة (Card)')),
                    DropdownMenuItem(value: 'vodafone_cash', child: Text('فودافون كاش / محفظة')),
                  ],
                  onChanged: (val) => setState(() => _method = val!),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _notesCtrl,
                  decoration: const InputDecoration(labelText: 'ملاحظات وتفاصيل الدفع'),
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: _isSaving ? null : () => Navigator.of(context).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving ? const CircularProgressIndicator() : const Text('تسجيل الدفعة'),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// --- TAB 5: CSV IMPORT WORKSTATION ---
// ==========================================
class _CsvImportTab extends ConsumerStatefulWidget {
  const _CsvImportTab();

  @override
  ConsumerState<_CsvImportTab> createState() => _CsvImportTabState();
}

class _CsvImportTabState extends ConsumerState<_CsvImportTab> {
  List<ParsedImportRow> _parsedRows = [];
  bool _isLoading = false;
  String? _fileName;

  void _pickAndParse() async {
    setState(() => _isLoading = true);
    try {
      final rows = await ref.read(csvImportServiceProvider).pickAndParseCsv();
      setState(() {
        _parsedRows = rows;
        _fileName = 'كشف_الأعضاء.csv';
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString(), textDirection: ui.TextDirection.rtl), backgroundColor: AppColors.error),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _triggerImport() async {
    if (_parsedRows.isEmpty) return;
    setState(() => _isLoading = true);

    final auth = ref.read(authNotifierProvider);
    final gymId = auth.gym?.id ?? auth.profile?.gymId;
    final importedBy = auth.profile?.id;

    if (gymId == null) {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('معرف الجيم غير متوفر')));
      return;
    }

    try {
      final results = await ref.read(csvImportServiceProvider).executeImport(
            gymId: gymId,
            fileName: _fileName ?? 'import_csv.csv',
            rowsToImport: _parsedRows,
            importedBy: importedBy,
          );

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (ctx) => Directionality(
          textDirection: ui.TextDirection.rtl,
          child: AlertDialog(
            backgroundColor: AppColors.surfaceCard,
            title: const Text('اكتمل الاستيراد بنجاح!'),
            content: Text(
              'إجمالي السطور المعالجة: ${results['total']}\n'
              'تم استيراد بنجاح: ${results['imported']} أعضاء\n'
              'فشل: ${results['failed']}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  setState(() {
                    _parsedRows = [];
                    _fileName = null;
                  });
                  ref.read(selectedTabProvider.notifier).state = 1; // View members
                },
                child: const Text('رؤية الأعضاء الجدد'),
              ),
            ],
          ),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.toString(), textDirection: ui.TextDirection.rtl), backgroundColor: AppColors.error),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'استيراد بيانات الأعضاء',
            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: AppColors.primary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          const Text(
            'اختار ملف الأعضاء من جهازك، وراجع البيانات قبل إضافتها.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 20),

          if (_parsedRows.isEmpty) ...[
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircleAvatar(
                      radius: 36,
                      backgroundColor: AppColors.primary.withOpacity(0.12),
                      child: const Icon(Icons.file_copy_rounded, color: AppColors.primary, size: 36),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton.icon(
                      onPressed: _isLoading ? null : _pickAndParse,
                      icon: const Icon(Icons.file_upload_rounded),
                      label: _isLoading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Color(0xFF0F141C))))
                          : const Text('اختيار ملف الأعضاء'),
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            Text('معاينة السطور الجاهزة للاستيراد (${_parsedRows.length} سطر):', style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: _parsedRows.length,
                itemBuilder: (context, index) {
                  final row = _parsedRows[index];
                  final isInvalid = row.status == 'invalid';
                  return Card(
                    color: isInvalid ? AppColors.error.withOpacity(0.08) : AppColors.surface,
                    child: ListTile(
                      title: Text(row.fullName ?? 'بدون اسم', style: TextStyle(fontWeight: FontWeight.bold, color: isInvalid ? AppColors.error : AppColors.textPrimary)),
                      subtitle: Text('تليفون: ${row.phone ?? "غير محدد"} • انضمام: ${row.joinDate != null ? DateFormat('yyyy/MM/dd').format(row.joinDate!) : "اليوم"}', style: const TextStyle(fontSize: 11)),
                      trailing: isInvalid
                          ? const Icon(Icons.error_outline_rounded, color: AppColors.error)
                          : const Icon(Icons.check_circle_outline_rounded, color: AppColors.success),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() => _parsedRows = []),
                    child: const Text('إلغاء واختيار ملف آخر'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _triggerImport,
                    child: _isLoading ? const CircularProgressIndicator() : const Text('استيراد الأعضاء'),
                  ),
                ),
              ],
            )
          ],
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

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('معلومات الصالة الرياضية (جيم الديب)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              if (auth.profile?.isOwner == true)
                TextButton.icon(
                  onPressed: () {
                    showDialog(context: context, builder: (_) => _EditGymInfoDialog(gym: auth.gym));
                  },
                  icon: const Icon(Icons.edit_rounded, size: 16),
                  label: const Text('تعديل بيانات الجيم'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            color: AppColors.surfaceCard,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildSettingRow('اسم الصالة (العربي)', auth.gym?.name ?? 'جيم الديب'),
                  const Divider(),
                  _buildSettingRow('اسم الصالة (English)', 'Gym ElDeeb'),
                  const Divider(),
                  _buildSettingRow('رقم هاتف الصالة', auth.gym?.phone ?? 'غير مسجل'),
                  const Divider(),
                  _buildSettingRow('العملة المعتمدة', auth.gym?.currency ?? 'EGP'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.surfaceCard.withOpacity(0.5),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.surfaceBorder),
            ),
            child: const Text(
              'ملاحظة: مخطط قاعدة البيانات الحالي لجدول gyms لا يحتوي على حقل للعنوان/الموقع الجغرافي. تم الالتزام بالمخطط الرسمي وعدم اختلاق أعمدة غير متوافقة.',
              style: TextStyle(fontSize: 11, color: AppColors.textMuted),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('الملف الشخصي للكابتن', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              TextButton.icon(
                onPressed: () {
                  showDialog(context: context, builder: (_) => _EditProfileDialog(profile: auth.profile));
                },
                icon: const Icon(Icons.edit_rounded, size: 16),
                label: const Text('تعديل الاسم'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            color: AppColors.surfaceCard,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildSettingRow('الاسم بالكامل', auth.profile?.fullName ?? 'كابتن الصالة'),
                  const Divider(),
                  _buildSettingRow('الصلاحية (ثابتة RLS)', auth.profile?.isOwner == true ? 'مالك الصالة الرياضية (Owner)' : 'مدرب معتمد (Coach)'),
                  const Divider(),
                  _buildSettingRow('معرف الحساب (User ID)', auth.profile?.id ?? 'غير متوفر'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          const Text('المظهر واللغة', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 8),
          Card(
            color: AppColors.surfaceCard,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildSettingRow('المظهر', 'الوضع الداكن الذهبي (جيم الديب)'),
                  const Divider(),
                  _buildSettingRow('اللغة', 'العربية (افتراضي) / English'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text('حالة تحديث البيانات', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
              TextButton.icon(
                onPressed: () async {
                  final sync = ref.read(dataSyncServiceProvider.notifier);
                  await sync.syncAll(forceRetry: true);
                  if (!context.mounted) return;

                  final state = ref.read(dataSyncServiceProvider);
                  final message = state.syncStatus == SyncStatus.synced
                      ? 'تمت مزامنة البيانات بنجاح.'
                      : (state.syncErrorMessage ?? 'تعذرت المزامنة، راجع البيانات أو الصلاحيات.');
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(message, textDirection: ui.TextDirection.rtl),
                      backgroundColor: state.syncStatus == SyncStatus.synced
                          ? AppColors.success
                          : AppColors.error,
                    ),
                  );
                },
                icon: const Icon(Icons.refresh_rounded, size: 16),
                label: const Text('مزامنة فورية'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Card(
            color: AppColors.surfaceCard,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  _buildSettingRow('الاتصال بالإنترنت', syncService.isOffline ? 'غير متصل (Offline)' : 'متصل بالشبكة (Online)'),
                  const Divider(),
                  _buildSettingRow('حالة تحديث البيانات', syncService.syncStatus == SyncStatus.synced ? 'مكتملة ومؤمنة (Synced)' : 'في انتظار التحديث / جاري التحديث'),
                ],
              ),
            ),
          ),
          const SizedBox(height: 32),

          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, foregroundColor: Colors.white),
            onPressed: () => _confirmLogout(context, ref),
            icon: const Icon(Icons.logout_rounded),
            label: const Text('تسجيل خروج آمن من الجلسة'),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            label,
            style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 4),
          SelectableText(
            value,
            textAlign: TextAlign.start,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 13,
              color: AppColors.textPrimary,
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
          backgroundColor: AppColors.surfaceCard,
          title: const Text('تسجيل الخروج'),
          content: const Text('هل تريد تأكيد تسجيل الخروج من جيم الديب ومسح بيانات الجلسة محلياً؟'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('إلغاء')),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.error),
              onPressed: () async {
                Navigator.pop(ctx);
                await ref.read(authNotifierProvider.notifier).signOut();
                if (context.mounted) context.go('/login');
              },
              child: const Text('تأكيد الخروج', style: TextStyle(color: Colors.white)),
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
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _currencyCtrl;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.gym?.name ?? 'جيم الديب');
    _phoneCtrl = TextEditingController(text: widget.gym?.phone ?? '');
    _currencyCtrl = TextEditingController(text: widget.gym?.currency ?? 'EGP');
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _currencyCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await ref.read(dataSyncServiceProvider.notifier).updateGymInfo(
            name: _nameCtrl.text.trim(),
            phone: _phoneCtrl.text.trim().isEmpty ? null : _phoneCtrl.text.trim(),
            currency: _currencyCtrl.text.trim(),
          );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث بيانات الصالة الرياضية بنجاح!', textDirection: ui.TextDirection.rtl), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ أثناء التعديل: $e', textDirection: ui.TextDirection.rtl), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surfaceCard,
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
                  validator: (val) => val == null || val.trim().isEmpty ? 'اسم الصالة مطلوب' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _phoneCtrl,
                  decoration: const InputDecoration(labelText: 'رقم هاتف الصالة'),
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _currencyCtrl,
                  decoration: const InputDecoration(labelText: 'العملة المعتمدة'),
                ),
                const SizedBox(height: 12),
                const Text(
                  'ملاحظة: جدول gyms لا يحتوي على حقل للعنوان في قاعدة البيانات الحالية.',
                  style: TextStyle(fontSize: 10, color: AppColors.textMuted),
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
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
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
      await ref.read(dataSyncServiceProvider.notifier).updateProfileName(_nameCtrl.text.trim());

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تحديث الاسم بنجاح!', textDirection: ui.TextDirection.rtl), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('خطأ أثناء التعديل: $e', textDirection: ui.TextDirection.rtl), backgroundColor: AppColors.error),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text('تعديل الاسم في الملف الشخصي'),
        content: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(labelText: 'الاسم الكامل للكابتن *'),
                validator: (val) => val == null || val.trim().isEmpty ? 'الاسم مطلوب' : null,
              ),
              const SizedBox(height: 12),
              Text(
                'الرتبة (${widget.profile?.role ?? "coach"}) ومعرف الجيم محمية بقواعد الأمان RLS ولا يمكن تعديلها.',
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ],
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
                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
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
class _AddMembershipDialog extends ConsumerStatefulWidget {
  final String? preSelectedMemberId;

  const _AddMembershipDialog({this.preSelectedMemberId});

  @override
  ConsumerState<_AddMembershipDialog> createState() => _AddMembershipDialogState();
}

class _AddMembershipDialogState extends ConsumerState<_AddMembershipDialog> {
  final _formKey = GlobalKey<FormState>();
  String? _selectedMemberId;
  String? _selectedPlanId;
  final DateTime _startDate = DateTime.now();
  final _priceCtrl = TextEditingController();
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _selectedMemberId = widget.preSelectedMemberId;
  }

  @override
  void dispose() {
    _priceCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleSave() async {
    if (_isSaving) return;
    if (!_formKey.currentState!.validate()) return;
    if (_selectedMemberId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار العضو', textDirection: ui.TextDirection.ltr), backgroundColor: AppColors.error),
      );
      return;
    }
    if (_selectedPlanId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('يرجى اختيار الباقة', textDirection: ui.TextDirection.ltr), backgroundColor: AppColors.error),
      );
      return;
    }

    setState(() => _isSaving = true);

    var membershipCreated = false;
    try {
      final data = ref.read(dataSyncServiceProvider);
      final plan = data.plans.where((p) => p.id == _selectedPlanId).firstOrNull;
      final durationDays = plan?.durationDays ?? 30;
      final price = double.tryParse(_priceCtrl.text) ?? plan?.price ?? 0.0;
      final endDate = _startDate.add(Duration(days: durationDays));

      final membership = await ref.read(dataSyncServiceProvider.notifier).createMembership(
            memberId: _selectedMemberId!,
            planId: _selectedPlanId,
            startDate: _startDate,
            endDate: endDate,
            price: price,
          );
      membershipCreated = true;

      // The form labels this value as the amount paid, so keep the cash ledger
      // consistent with the membership created from the same submission.
      if (price > 0) {
        await ref.read(dataSyncServiceProvider.notifier).recordPayment(
              membershipId: membership.id,
              amount: price,
              paymentMethod: 'cash',
              paidAt: DateTime.now(),
              notes: 'دفعة تفعيل اشتراك',
            );
      }

      if (!mounted) return;
      Navigator.of(context).pop();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('تم تسجيل الاشتراك بنجاح!', textDirection: ui.TextDirection.ltr), backgroundColor: AppColors.success),
      );
    } catch (e) {
      if (!mounted) return;
      if (membershipCreated) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تم إنشاء الاشتراك، لكن تعذّر تسجيل الدفعة. راجع سجل المدفوعات قبل إعادة التسجيل. ($e)', textDirection: ui.TextDirection.rtl),
            backgroundColor: AppColors.error,
            duration: const Duration(seconds: 7),
          ),
        );
      } else {
        setState(() => _isSaving = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تسجيل الاشتراك: $e', textDirection: ui.TextDirection.ltr), backgroundColor: AppColors.error),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(dataSyncServiceProvider);
    return Directionality(
      textDirection: ui.TextDirection.rtl,
      child: AlertDialog(
        backgroundColor: AppColors.surfaceCard,
        title: const Text('تسجيل اشتراك جديد'),
        content: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: _selectedMemberId,
                  decoration: const InputDecoration(labelText: 'العضو *'),
                  items: data.members.map((m) => DropdownMenuItem(value: m.id, child: Text(m.fullName))).toList(),
                  onChanged: (v) => setState(() => _selectedMemberId = v),
                  validator: (v) => v == null ? 'يرجى اختيار العضو' : null,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: _selectedPlanId,
                  decoration: const InputDecoration(labelText: 'الباقة *'),
                  items: data.plans.map((p) => DropdownMenuItem(value: p.id, child: Text('${p.name} (${p.price} ج.م)'))).toList(),
                  onChanged: (v) {
                    setState(() {
                      _selectedPlanId = v;
                      final plan = data.plans.where((p) => p.id == v).firstOrNull;
                      if (plan != null) {
                        _priceCtrl.text = plan.price.toString();
                      }
                    });
                  },
                  validator: (v) => v == null ? 'يرجى اختيار الباقة' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _priceCtrl,
                  decoration: const InputDecoration(labelText: 'المبلغ المدفوع (ج.م)'),
                  keyboardType: TextInputType.number,
                  validator: (v) => v == null || double.tryParse(v) == null ? 'أدخل مبلغ صحيح' : null,
                ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(onPressed: _isSaving ? null : () => Navigator.of(context).pop(), child: const Text('إلغاء')),
          ElevatedButton(
            onPressed: _isSaving ? null : _handleSave,
            child: _isSaving ? const CircularProgressIndicator() : const Text('تسجيل'),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// --- ADD PAYMENT DIALOG ---
// ==========================================
class _AddPaymentDialog extends StatelessWidget {
  final String? preSelectedMemberId;

  const _AddPaymentDialog({super.key, this.preSelectedMemberId});

  @override
  Widget build(BuildContext context) {
    return _RecordPaymentDialog(preSelectedMemberId: preSelectedMemberId);
  }
}
