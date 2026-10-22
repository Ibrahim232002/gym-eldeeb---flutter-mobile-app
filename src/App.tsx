/**
 * @license
 * SPDX-License-Identifier: Apache-2.0
 */

import React, { useState, useEffect } from 'react';
import { createClient, Session, User } from '@supabase/supabase-js';
import {
  Dumbbell,
  Shield,
  Wifi,
  WifiOff,
  Smartphone,
  FolderTree,
  FileCode,
  CheckCircle2,
  Lock,
  Users,
  CreditCard,
  Calendar,
  ArrowRight,
  LogOut,
  Copy,
  Check,
  Sparkles,
  RefreshCw,
  KeyRound,
  Eye,
  EyeOff,
  AlertCircle,
  HelpCircle,
  Building2,
  X,
  Search,
  Phone,
  MessageSquare,
  Trash2,
  Edit3,
  Plus,
  CheckCircle,
  Settings,
  Globe,
  Moon,
  Sun,
  Clock,
  TrendingUp,
  ChevronLeft,
  UserCheck,
  LayoutDashboard,
  User as UserIcon
} from 'lucide-react';

// Real Supabase Client for Interactive Web Testing (Matching Flutter Configuration)
const SUPABASE_URL = 'https://rpwcjfayhdwbsnecomnk.supabase.co';
const SUPABASE_ANON_KEY = 'sb_publishable_rtuOsvmeYSvl827xFVYp4A_Z0gmqmGy';
const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY);

// Flutter Architecture Files for Phase 2 Verification & Code Explorer
const FLUTTER_FILES: Record<string, { category: string; description: string; code: string }> = {
  'lib/auth/auth_repository.dart': {
    category: 'Auth (Phase 2)',
    description: 'Real Supabase Auth repository: Email/Password sign-in & sign-up, session persistence, clean Arabic errors, strict RLS enforcement, and Edge Function invocation with Bearer token.',
    code: `import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/constants/supabase_constants.dart';
import '../data/models/user_profile.dart';

class AuthRepository {
  final SupabaseClient _supabase;
  AuthRepository(this._supabase);

  // Real Supabase sign in with Arabic error mapping
  Future<void> signIn({required String email, required String password}) async {
    try {
      await _supabase.auth.signInWithPassword(email: email.trim(), password: password.trim());
    } on AuthException catch (e) {
      throw Exception(_mapAuthExceptionToArabic(e));
    }
  }

  // Real Supabase sign up - Client NEVER assigns role or gym_id
  Future<void> signUp({required String email, required String password, required String fullName}) async {
    try {
      await _supabase.auth.signUp(
        email: email.trim(),
        password: password.trim(),
        data: {'full_name': fullName.trim()},
      );
    } on AuthException catch (e) {
      throw Exception(_mapAuthExceptionToArabic(e));
    }
  }

  // Invoke secure join-gym Edge Function with Bearer token & JSON payload
  Future<void> joinGym({required String fullName, required String inviteCode}) async {
    final session = _supabase.auth.currentSession;
    final accessToken = session?.accessToken;
    if (accessToken == null) throw Exception('الجلسة غير صالحة');

    final response = await _supabase.functions.invoke(
      'join-gym',
      headers: {'Authorization': 'Bearer \$accessToken'},
      body: {'full_name': fullName.trim(), 'invite_code': inviteCode.trim()},
    );

    if (response.status != 200) {
      throw Exception('تعذر الانضمام للجيم، تأكد من صحة رمز الدعوة');
    }
  }
}`
  },
  'lib/auth/auth_provider.dart': {
    category: 'State (Phase 2)',
    description: 'Riverpod StateNotifier managing persistent Supabase Auth state, automatic session restoration, and gym linkage resolution.',
    code: `class AuthNotifier extends StateNotifier<AuthState> {
  final AuthRepository _repository;
  AuthNotifier(this._repository) : super(AuthState.initial()) {
    initializeAuth();
  }

  Future<void> initializeAuth() async {
    state = AuthState.loading();
    final user = _repository.currentUser;
    if (user == null) {
      state = AuthState.unauthenticated();
      return;
    }
    await refreshUserSession();
  }

  Future<void> refreshUserSession() async {
    final profile = await _repository.fetchUserProfile();
    if (profile == null || !profile.hasGym) {
      state = AuthState.authenticatedNoGym(profile ?? UserProfile(id: _repository.currentUser!.id, fullName: ''));
      return;
    }
    final gym = await _repository.fetchGym(profile.gymId!);
    state = AuthState.authenticatedWithGym(profile: profile, gym: gym!);
  }
}`
  },
  'lib/features/auth/login_screen.dart': {
    category: 'UI (Phase 2)',
    description: 'Login screen featuring real email/password authentication, loading spinners, Arabic validation, and RTL layout.',
    code: `// Login screen connects directly to authNotifierProvider.signIn(email, password)
// On success: routes to /dashboard if gym exists, or /join-gym if new coach/owner.`
  },
  'lib/features/auth/register_screen.dart': {
    category: 'UI (Phase 2)',
    description: 'Register screen with Full Name, Email, Password, and Confirm Password verification, routing new users directly to Join Gym.',
    code: `// Validates all fields including password matching
// Successfully creates Supabase Auth user without granting owner privileges directly`
  },
  'lib/features/gym/join_gym_screen.dart': {
    category: 'UI (Phase 2)',
    description: 'Join Gym screen collecting Full Name and Invite Code, calling https://rpwcjfayhdwbsnecomnk.supabase.co/functions/v1/join-gym.',
    code: `// Sends {"full_name": ..., "invite_code": ...} to join-gym Edge Function with Authorization Bearer header`
  },
  'pubspec.yaml': {
    category: 'Config',
    description: 'Flutter dependencies with supabase_flutter, flutter_riverpod, go_router, connectivity_plus, shared_preferences, and Google Fonts.',
    code: `name: gym_eldeeb
description: "Gym ElDeeb - Production Arabic-first Gym Management Flutter App"
dependencies:
  flutter: { sdk: flutter }
  flutter_localizations: { sdk: flutter }
  supabase_flutter: ^2.8.0
  flutter_riverpod: ^2.6.1
  go_router: ^14.8.1
  shared_preferences: ^2.3.5
  connectivity_plus: ^6.1.3
  google_fonts: ^6.2.1
  intl: ^0.19.0`
  }
};

export default function App() {
  const [activeTab, setActiveTab] = useState<'simulator' | 'code' | 'schema'>('simulator');
  const [currentScreen, setCurrentScreen] = useState<'splash' | 'login' | 'register' | 'join-gym' | 'dashboard'>('splash');
  const [isOnline, setIsOnline] = useState(true);
  const [selectedFile, setSelectedFile] = useState<string>('lib/auth/auth_repository.dart');
  const [copied, setCopied] = useState(false);

  // Real Supabase State in Web Environment
  const [session, setSession] = useState<Session | null>(null);
  const [currentUser, setCurrentUser] = useState<User | null>(null);
  const [profile, setProfile] = useState<{ id: string; full_name: string; role: string; gym_id: string | null } | null>(null);
  const [gym, setGym] = useState<{ id: string; name: string; currency: string; phone?: string | null } | null>(null);

  // Sub-tab navigation inside Dashboard
  const [dashboardTab, setDashboardTab] = useState<'overview' | 'members' | 'plans' | 'memberships' | 'payments' | 'settings'>('overview');

  // Real Database Lists
  const [realMembers, setRealMembers] = useState<any[]>([]);
  const [realPlans, setRealPlans] = useState<any[]>([]);
  const [realMemberships, setRealMemberships] = useState<any[]>([]);
  const [realPayments, setRealPayments] = useState<any[]>([]);

  // Member Quick Add Form
  const [newMemberName, setNewMemberName] = useState('');
  const [newMemberPhone, setNewMemberPhone] = useState('');

  // Plan Quick Add Form
  const [newPlanName, setNewPlanName] = useState('');
  const [newPlanDays, setNewPlanDays] = useState('30');
  const [newPlanPrice, setNewPlanPrice] = useState('350');

  // Payment Quick Add Form
  const [newPaymentAmount, setNewPaymentAmount] = useState('350');
  const [newPaymentMethod, setNewPaymentMethod] = useState('cash');
  const [newPaymentNotes, setNewPaymentNotes] = useState('');

  // Interactive Modals & Active Selections
  const [showAddMemberModal, setShowAddMemberModal] = useState(false);
  const [showAddPlanModal, setShowAddPlanModal] = useState(false);
  const [showAddPaymentModal, setShowAddPaymentModal] = useState(false);
  const [showAddMembershipModal, setShowAddMembershipModal] = useState(false);
  const [selectedMemberForDetails, setSelectedMemberForDetails] = useState<any | null>(null);
  const [editingMember, setEditingMember] = useState<any | null>(null);
  const [editingPlan, setEditingPlan] = useState<any | null>(null);
  const [editingMembership, setEditingMembership] = useState<any | null>(null);
  const [editingPayment, setEditingPayment] = useState<any | null>(null);
  const [editingGymInfo, setEditingGymInfo] = useState<any | null>(null);
  const [editingProfile, setEditingProfile] = useState<any | null>(null);
  const [showLogoutConfirm, setShowLogoutConfirm] = useState(false);
  const [appTheme, setAppTheme] = useState<'dark' | 'light'>('dark');
  const [appLanguage, setAppLanguage] = useState<'ar' | 'en'>('ar');

  // Search & Filter
  const [memberSearchQuery, setMemberSearchQuery] = useState('');
  const [memberFilter, setMemberFilter] = useState<'all' | 'active' | 'inactive' | 'expiring'>('all');

  // Add Member Modal State
  const [modalMemberName, setModalMemberName] = useState('');
  const [modalMemberPhone, setModalMemberPhone] = useState('');
  const [modalMemberJoinDate, setModalMemberJoinDate] = useState(new Date().toISOString().substring(0, 10));
  const [modalMemberNotes, setModalMemberNotes] = useState('');
  const [modalFeedback, setModalFeedback] = useState<{ type: 'error' | 'success'; message: string } | null>(null);
  const [isModalSaving, setIsModalSaving] = useState(false);

  // Membership Modal State
  const [memMemberId, setMemMemberId] = useState('');
  const [memPlanId, setMemPlanId] = useState('');
  const [memStartDate, setMemStartDate] = useState(new Date().toISOString().substring(0, 10));
  const [memEndDate, setMemEndDate] = useState(() => {
    const d = new Date();
    d.setDate(d.getDate() + 30);
    return d.toISOString().substring(0, 10);
  });
  const [memPrice, setMemPrice] = useState('350');
  const [memRecordPayment, setMemRecordPayment] = useState(true);

  // Global Toast
  const [globalToast, setGlobalToast] = useState<{ type: 'success' | 'error'; message: string } | null>(null);

  // Form Inputs
  const [loginEmail, setLoginEmail] = useState('');
  const [loginPassword, setLoginPassword] = useState('');
  const [showPassword, setShowPassword] = useState(false);

  const [registerName, setRegisterName] = useState('');
  const [registerEmail, setRegisterEmail] = useState('');
  const [registerPassword, setRegisterPassword] = useState('');
  const [registerConfirmPassword, setRegisterConfirmPassword] = useState('');
  const [showRegisterPassword, setShowRegisterPassword] = useState(false);

  const [joinFullName, setJoinFullName] = useState('');
  const [joinInviteCode, setJoinInviteCode] = useState('');

  // UI Feedback
  const [authError, setAuthError] = useState<string | null>(null);
  const [authSuccess, setAuthSuccess] = useState<string | null>(null);
  const [isSubmitting, setIsSubmitting] = useState(false);

  // On App startup: check Supabase session & restore user
  useEffect(() => {
    async function initAuth() {
      try {
        const { data: { session: initialSession } } = await supabase.auth.getSession();
        if (initialSession?.user) {
          setSession(initialSession);
          setCurrentUser(initialSession.user);
          await loadUserProfileAndGym(initialSession.user.id, initialSession.user.user_metadata?.full_name);
        } else {
          // No user logged in
          setTimeout(() => setCurrentScreen('login'), 1200);
        }
      } catch (err) {
        console.warn('Supabase session check:', err);
        setTimeout(() => setCurrentScreen('login'), 1200);
      }
    }

    initAuth();

    const { data: { subscription } } = supabase.auth.onAuthStateChange(async (_event, newSession) => {
      setSession(newSession);
      setCurrentUser(newSession?.user ?? null);
      if (newSession?.user) {
        await loadUserProfileAndGym(newSession.user.id, newSession.user.user_metadata?.full_name);
      }
    });

    return () => {
      subscription.unsubscribe();
    };
  }, []);

  // Fetch Profile & Gym from Supabase
  const loadUserProfileAndGym = async (userId: string, metadataName?: string) => {
    try {
      const { data: profileData, error: profileErr } = await supabase
        .from('profiles')
        .select('*')
        .eq('id', userId)
        .maybeSingle();

      if (profileErr) {
        console.warn('Profile fetch note:', profileErr.message);
      }

      const activeFullName = profileData?.full_name || metadataName || 'كابتن جيم الديب';
      const resolvedProfile = {
        id: userId,
        full_name: activeFullName,
        role: profileData?.role || 'coach',
        gym_id: profileData?.gym_id || null,
      };

      setProfile(resolvedProfile);
      setJoinFullName(activeFullName);

      if (resolvedProfile.gym_id) {
        const { data: gymData } = await supabase
          .from('gyms')
          .select('*')
          .eq('id', resolvedProfile.gym_id)
          .maybeSingle();

        if (gymData) {
          setGym({
            id: gymData.id,
            name: gymData.name || 'جيم الديب',
            currency: gymData.currency || 'EGP',
            phone: gymData.phone || null,
          });
        } else {
          setGym({
            id: resolvedProfile.gym_id,
            name: 'جيم الديب',
            currency: 'EGP',
            phone: null,
          });
        }
        await fetchGymData(resolvedProfile.gym_id);
        setCurrentScreen('dashboard');
      } else {
        // Authenticated user with no gym -> go to Join Gym
        setCurrentScreen('join-gym');
      }
    } catch (e) {
      console.error('Error resolving session:', e);
      setCurrentScreen('join-gym');
    }
  };

  const fetchGymData = async (gymId: string) => {
    try {
      const [membersRes, plansRes, memsRes, payRes] = await Promise.all([
        supabase.from('members').select('*').eq('gym_id', gymId).order('full_name', { ascending: true }),
        supabase.from('membership_plans').select('*').eq('gym_id', gymId).order('name', { ascending: true }),
        supabase.from('memberships').select('*').eq('gym_id', gymId).order('start_date', { ascending: false }),
        supabase.from('payments').select('*').eq('gym_id', gymId).order('paid_at', { ascending: false }),
      ]);

      if (membersRes.data) setRealMembers(membersRes.data);
      if (plansRes.data) setRealPlans(plansRes.data);
      if (memsRes.data) setRealMemberships(memsRes.data);
      if (payRes.data) setRealPayments(payRes.data);
    } catch (err) {
      console.warn('Could not fetch gym data:', err);
    }
  };

  // WhatsApp click-to-chat with Egyptian number normalization & toast feedback
  const openWhatsappChat = (phone: string, fullName: string) => {
    if (!phone || !phone.trim()) {
      setGlobalToast({ type: 'error', message: 'هذا العضو ليس لديه رقم هاتف مسجل.' });
      setTimeout(() => setGlobalToast(null), 3000);
      return;
    }
    let clean = phone.replace(/[\s\-()+]+/g, '');
    if (clean.startsWith('0020')) clean = clean.substring(2);
    else if (clean.startsWith('+20')) clean = clean.substring(3);
    else if (clean.startsWith('20')) clean = clean;
    else if (clean.startsWith('01')) clean = '20' + clean.substring(1);
    else if (clean.startsWith('1') && clean.length === 10) clean = '20' + clean;

    const msg = encodeURIComponent(`السلام عليكم يا كابتن ${fullName}، نتشرف بالتواصل معك من جيم الديب 💪`);
    const waUrl = `https://wa.me/${clean}?text=${msg}`;
    
    // Create temporary safe link click for clean navigation
    const link = document.createElement('a');
    link.href = waUrl;
    link.target = '_blank';
    link.rel = 'noopener noreferrer';
    document.body.appendChild(link);
    link.click();
    document.body.removeChild(link);

    setGlobalToast({ type: 'success', message: `جارٍ فتح محادثة واتساب مع "${fullName}"...` });
    setTimeout(() => setGlobalToast(null), 3000);
  };

  // Save Member (Add Member)
  const handleSaveMember = async (e?: React.FormEvent) => {
    if (e) e.preventDefault();
    if (isModalSaving) return;
    setModalFeedback(null);

    const name = modalMemberName.trim();
    if (!name || name.length < 2) {
      setModalFeedback({ type: 'error', message: 'يرجى إدخال اسم العضو بالكامل (حرفين على الأقل)' });
      return;
    }

    setIsModalSaving(true);
    const gymId = profile?.gym_id || gym?.id || 'd0000000-0000-0000-0000-000000000001';
    const newId = crypto.randomUUID();
    const phone = modalMemberPhone.trim() || null;
    const notes = modalMemberNotes.trim() || null;
    const joinDate = modalMemberJoinDate || new Date().toISOString().substring(0, 10);

    const newMemberRecord = {
      id: newId,
      gym_id: gymId,
      full_name: name,
      phone: phone,
      notes: notes,
      join_date: joinDate,
      is_active: true,
      created_by: currentUser?.id || session?.user?.id || null,
      sync_version: 1,
      created_at: new Date().toISOString(),
      updated_at: new Date().toISOString(),
    };

    try {
      if (isOnline) {
        const { data, error } = await supabase.from('members').insert({
          id: newId,
          gym_id: gymId,
          full_name: name,
          phone: phone,
          notes: notes,
          join_date: joinDate,
          is_active: true,
          created_by: currentUser?.id || session?.user?.id || null,
          sync_version: 1,
        }).select().single();

        if (error) {
          console.warn('Supabase insert failed, saving to local offline queue:', error.message);
          const queue = JSON.parse(localStorage.getItem('pending_offline_actions') || '[]');
          queue.push({ id: crypto.randomUUID(), table: 'members', action: 'create', payload: newMemberRecord });
          localStorage.setItem('pending_offline_actions', JSON.stringify(queue));
        } else if (data) {
          Object.assign(newMemberRecord, data);
        }
      } else {
        const queue = JSON.parse(localStorage.getItem('pending_offline_actions') || '[]');
        queue.push({ id: crypto.randomUUID(), table: 'members', action: 'create', payload: newMemberRecord });
        localStorage.setItem('pending_offline_actions', JSON.stringify(queue));
      }

      setRealMembers(prev => [newMemberRecord, ...prev.filter(m => m.id !== newId)]);

      const cached = JSON.parse(localStorage.getItem(`cached_members_${gymId}`) || '[]');
      localStorage.setItem(`cached_members_${gymId}`, JSON.stringify([newMemberRecord, ...cached.filter((m: any) => m.id !== newId)]));

      setModalMemberName('');
      setModalMemberPhone('');
      setModalMemberNotes('');
      setShowAddMemberModal(false);
      setGlobalToast({ type: 'success', message: `تمت إضافة العضو "${name}" بنجاح!` });
      setTimeout(() => setGlobalToast(null), 4000);
    } catch (err: any) {
      setModalFeedback({ type: 'error', message: err?.message || 'حدث خطأ أثناء حفظ العضو' });
    } finally {
      setIsModalSaving(false);
    }
  };

  // Save Edited Member
  const handleSaveEditedMember = async () => {
    if (!editingMember) return;
    setIsModalSaving(true);
    try {
      const { id, full_name, phone, notes, is_active, join_date } = editingMember;
      const updatedFields = {
        full_name: full_name.trim(),
        phone: phone?.trim() || null,
        notes: notes?.trim() || null,
        join_date: join_date ? join_date.substring(0, 10) : new Date().toISOString().substring(0, 10),
        is_active,
        updated_at: new Date().toISOString(),
      };
      if (isOnline) {
        await supabase.from('members').update(updatedFields).eq('id', id);
      }
      setRealMembers(prev => prev.map(m => m.id === id ? { ...m, ...updatedFields } : m));
      if (selectedMemberForDetails?.id === id) {
        setSelectedMemberForDetails({ ...selectedMemberForDetails, ...updatedFields });
      }
      setEditingMember(null);
      setGlobalToast({ type: 'success', message: `تم تحديث بيانات "${full_name}" بنجاح!` });
      setTimeout(() => setGlobalToast(null), 3000);
    } catch (err: any) {
      setGlobalToast({ type: 'error', message: 'فشل التعديل: ' + (err?.message || 'خطأ غير معروف') });
      setTimeout(() => setGlobalToast(null), 4000);
    } finally {
      setIsModalSaving(false);
    }
  };

  // Delete Member
  const handleDeleteMember = async (memberId: string, memberName: string) => {
    if (!confirm(`هل أنت متأكد من حذف العضو "${memberName}" من صالة الجيم؟`)) return;
    try {
      if (isOnline) {
        await supabase.from('members').delete().eq('id', memberId);
      }
      setRealMembers(prev => prev.filter(m => m.id !== memberId));
      if (selectedMemberForDetails?.id === memberId) {
        setSelectedMemberForDetails(null);
      }
      setGlobalToast({ type: 'success', message: `تم حذف العضو "${memberName}" بنجاح!` });
      setTimeout(() => setGlobalToast(null), 3000);
    } catch (err: any) {
      setGlobalToast({ type: 'error', message: 'فشل الحذف: ' + (err?.message || 'خطأ') });
      setTimeout(() => setGlobalToast(null), 3000);
    }
  };

  // Save Edited Plan
  const handleSaveEditedPlan = async () => {
    if (!editingPlan || !editingPlan.name?.trim()) {
      setGlobalToast({ type: 'error', message: 'يرجى إدخال اسم الباقة' });
      setTimeout(() => setGlobalToast(null), 3000);
      return;
    }
    setIsModalSaving(true);
    try {
      const updated = {
        name: editingPlan.name.trim(),
        duration_days: parseInt(String(editingPlan.duration_days)) || 30,
        price: parseFloat(String(editingPlan.price)) || 0,
        is_active: editingPlan.is_active ?? true,
        updated_at: new Date().toISOString(),
      };
      if (isOnline) {
        await supabase.from('membership_plans').update(updated).eq('id', editingPlan.id);
      }
      setRealPlans(prev => prev.map(p => p.id === editingPlan.id ? { ...p, ...updated } : p));
      setEditingPlan(null);
      setGlobalToast({ type: 'success', message: `تم تحديث باقة "${updated.name}" بنجاح!` });
      setTimeout(() => setGlobalToast(null), 3000);
    } catch (err: any) {
      setGlobalToast({ type: 'error', message: 'فشل تعديل الباقة: ' + (err?.message || 'خطأ غير معروف') });
      setTimeout(() => setGlobalToast(null), 4000);
    } finally {
      setIsModalSaving(false);
    }
  };

  // Toggle Plan Active
  const handleTogglePlanActive = async (plan: any) => {
    const newStatus = !plan.is_active;
    try {
      if (isOnline) {
        await supabase.from('membership_plans').update({
          is_active: newStatus,
          updated_at: new Date().toISOString(),
        }).eq('id', plan.id);
      }
      setRealPlans(prev => prev.map(p => p.id === plan.id ? { ...p, is_active: newStatus } : p));
      setGlobalToast({ type: 'success', message: `تم ${newStatus ? 'تفعيل' : 'تعطيل'} باقة "${plan.name}"!` });
      setTimeout(() => setGlobalToast(null), 3000);
    } catch (err: any) {
      setGlobalToast({ type: 'error', message: 'فشل تغيير حالة الباقة: ' + (err?.message || 'خطأ') });
      setTimeout(() => setGlobalToast(null), 3000);
    }
  };

  // Delete Plan
  const handleDeletePlan = async (planId: string, planName: string) => {
    if (!confirm(`هل أنت متأكد من حذف باقة "${planName}" نهائياً من الجيم؟`)) return;
    try {
      if (isOnline) {
        await supabase.from('membership_plans').delete().eq('id', planId);
      }
      setRealPlans(prev => prev.filter(p => p.id !== planId));
      setGlobalToast({ type: 'success', message: `تم حذف باقة "${planName}" بنجاح!` });
      setTimeout(() => setGlobalToast(null), 3000);
    } catch (err: any) {
      setGlobalToast({ type: 'error', message: 'فشل حذف الباقة: ' + (err?.message || 'خطأ') });
      setTimeout(() => setGlobalToast(null), 3000);
    }
  };

  // Save Edited Membership
  const handleSaveEditedMembership = async () => {
    if (!editingMembership) return;
    setIsModalSaving(true);
    try {
      const updated = {
        plan_id: editingMembership.plan_id,
        start_date: editingMembership.start_date,
        end_date: editingMembership.end_date,
        price: parseFloat(String(editingMembership.price)) || 0,
        status: editingMembership.status || 'active',
        updated_at: new Date().toISOString(),
      };
      if (isOnline) {
        await supabase.from('memberships').update(updated).eq('id', editingMembership.id);
      }
      setRealMemberships(prev => prev.map(m => m.id === editingMembership.id ? { ...m, ...updated } : m));
      setEditingMembership(null);
      setGlobalToast({ type: 'success', message: 'تم تحديث بيانات الاشتراك بنجاح!' });
      setTimeout(() => setGlobalToast(null), 3000);
    } catch (err: any) {
      setGlobalToast({ type: 'error', message: 'فشل تعديل الاشتراك: ' + (err?.message || 'خطأ') });
      setTimeout(() => setGlobalToast(null), 4000);
    } finally {
      setIsModalSaving(false);
    }
  };

  // Delete Membership
  const handleDeleteMembership = async (memId: string) => {
    if (!confirm('تنبيه: هل أنت متأكد من إلغاء وحذف هذا الاشتراك نهائياً؟')) return;
    try {
      if (isOnline) {
        await supabase.from('memberships').delete().eq('id', memId);
      }
      setRealMemberships(prev => prev.filter(m => m.id !== memId));
      setGlobalToast({ type: 'success', message: 'تم حذف سجل الاشتراك بنجاح!' });
      setTimeout(() => setGlobalToast(null), 3000);
    } catch (err: any) {
      setGlobalToast({ type: 'error', message: 'فشل حذف الاشتراك: ' + (err?.message || 'خطأ') });
      setTimeout(() => setGlobalToast(null), 3000);
    }
  };

  // Save Edited Payment
  const handleSaveEditedPayment = async () => {
    if (!editingPayment) return;
    const amt = parseFloat(String(editingPayment.amount));
    if (!amt || amt <= 0) {
      setGlobalToast({ type: 'error', message: 'يرجى إدخال مبلغ صحيح' });
      setTimeout(() => setGlobalToast(null), 3000);
      return;
    }
    setIsModalSaving(true);
    try {
      const updated = {
        amount: amt,
        payment_method: editingPayment.payment_method || 'cash',
        paid_at: editingPayment.paid_at || new Date().toISOString(),
        notes: editingPayment.notes?.trim() || null,
        updated_at: new Date().toISOString(),
      };
      if (isOnline) {
        await supabase.from('payments').update(updated).eq('id', editingPayment.id);
      }
      setRealPayments(prev => prev.map(p => p.id === editingPayment.id ? { ...p, ...updated } : p));
      setEditingPayment(null);
      setGlobalToast({ type: 'success', message: `تم تحديث بيانات الدفعة (${amt} ج.م) بنجاح!` });
      setTimeout(() => setGlobalToast(null), 3000);
    } catch (err: any) {
      setGlobalToast({ type: 'error', message: 'فشل تعديل الدفعة: ' + (err?.message || 'خطأ') });
      setTimeout(() => setGlobalToast(null), 4000);
    } finally {
      setIsModalSaving(false);
    }
  };

  // Delete Payment with financial warning confirmation
  const handleDeletePayment = async (payId: string, amount: number) => {
    if (!confirm(`تنبيه مالي مهم:\nهل أنت متأكد من حذف هذه الدفعة المالية بقيمة (${amount} ج.م)؟\nهذا الإجراء سيعدل إجمالي الإيرادات في الخزينة.`)) return;
    try {
      if (isOnline) {
        await supabase.from('payments').delete().eq('id', payId);
      }
      setRealPayments(prev => prev.filter(p => p.id !== payId));
      setGlobalToast({ type: 'success', message: 'تم حذف الدفعة المالية بنجاح!' });
      setTimeout(() => setGlobalToast(null), 3000);
    } catch (err: any) {
      setGlobalToast({ type: 'error', message: 'فشل حذف الدفعة: ' + (err?.message || 'خطأ') });
      setTimeout(() => setGlobalToast(null), 3000);
    }
  };

  // Save Gym Information
  const handleSaveGymInfo = async () => {
    if (!editingGymInfo) return;
    setIsModalSaving(true);
    try {
      const gymId = gym?.id || profile?.gym_id;
      if (!gymId) throw new Error('معرف الصالة غير متوفر');
      const updated = {
        name: editingGymInfo.name?.trim() || 'جيم الديب',
        phone: editingGymInfo.phone?.trim() || null,
        currency: editingGymInfo.currency?.trim() || 'EGP',
        updated_at: new Date().toISOString(),
      };
      if (isOnline) {
        await supabase.from('gyms').update(updated).eq('id', gymId);
      }
      setGym(prev => prev ? { ...prev, ...updated, id: gymId } : { id: gymId, ...updated });
      setEditingGymInfo(null);
      setGlobalToast({ type: 'success', message: 'تم حفظ وتحديث بيانات جيم الديب بنجاح!' });
      setTimeout(() => setGlobalToast(null), 3000);
    } catch (err: any) {
      setGlobalToast({ type: 'error', message: 'فشل حفظ بيانات الجيم: ' + (err?.message || 'خطأ') });
      setTimeout(() => setGlobalToast(null), 4000);
    } finally {
      setIsModalSaving(false);
    }
  };

  // Save Profile Name
  const handleSaveProfile = async () => {
    if (!editingProfile || !editingProfile.full_name?.trim()) {
      setGlobalToast({ type: 'error', message: 'يرجى إدخال الاسم الكامل' });
      setTimeout(() => setGlobalToast(null), 3000);
      return;
    }
    setIsModalSaving(true);
    try {
      const userId = currentUser?.id || session?.user?.id || profile?.id;
      if (!userId) throw new Error('معرف المستخدم غير متوفر');
      const newName = editingProfile.full_name.trim();
      if (isOnline) {
        // RLS allows updating only full_name
        await supabase.from('profiles').update({
          full_name: newName,
          updated_at: new Date().toISOString(),
        }).eq('id', userId);
      }
      setProfile(prev => prev ? { ...prev, full_name: newName } : null);
      setEditingProfile(null);
      setGlobalToast({ type: 'success', message: 'تم تحديث اسم الملف الشخصي بنجاح!' });
      setTimeout(() => setGlobalToast(null), 3000);
    } catch (err: any) {
      setGlobalToast({ type: 'error', message: 'فشل تحديث الملف الشخصي: ' + (err?.message || 'خطأ') });
      setTimeout(() => setGlobalToast(null), 4000);
    } finally {
      setIsModalSaving(false);
    }
  };

  // Trigger Manual Sync
  const triggerManualSync = async () => {
    setGlobalToast({ type: 'success', message: 'جاري مزامنة البيانات مع خوادم جيم الديب...' });
    try {
      const gymId = gym?.id || profile?.gym_id;
      if (gymId) {
        await fetchGymData(gymId);
      }
      setGlobalToast({ type: 'success', message: 'اكتملت مزامنة جميع الجداول بنجاح!' });
      setTimeout(() => setGlobalToast(null), 3000);
    } catch (err: any) {
      setGlobalToast({ type: 'error', message: 'فشل المزامنة: ' + (err?.message || 'خطأ بالاتصال') });
      setTimeout(() => setGlobalToast(null), 3000);
    }
  };

  // Save Plan
  const handleSavePlan = async () => {
    if (!newPlanName.trim()) {
      setGlobalToast({ type: 'error', message: 'يرجى إدخال اسم باقة الاشتراك' });
      setTimeout(() => setGlobalToast(null), 3000);
      return;
    }
    setIsModalSaving(true);
    try {
      const gymId = profile?.gym_id || gym?.id || 'd0000000-0000-0000-0000-000000000001';
      const planRecord = {
        id: crypto.randomUUID(),
        gym_id: gymId,
        name: newPlanName.trim(),
        duration_days: parseInt(newPlanDays) || 30,
        price: parseFloat(newPlanPrice) || 350,
        is_active: true,
        sync_version: 1,
      };

      if (isOnline) {
        const { data } = await supabase.from('membership_plans').insert(planRecord).select().single();
        if (data) Object.assign(planRecord, data);
      }

      setRealPlans(prev => [...prev, planRecord]);
      setShowAddPlanModal(false);
      setNewPlanName('');
      setGlobalToast({ type: 'success', message: `تمت إضافة باقة "${planRecord.name}" بنجاح!` });
      setTimeout(() => setGlobalToast(null), 3000);
    } catch (err: any) {
      setGlobalToast({ type: 'error', message: 'فشل حفظ الباقة: ' + (err?.message || 'خطأ') });
      setTimeout(() => setGlobalToast(null), 3000);
    } finally {
      setIsModalSaving(false);
    }
  };

  // Save Membership
  const handleSaveMembership = async () => {
    if (!memMemberId || !memPlanId) {
      setGlobalToast({ type: 'error', message: 'يرجى اختيار العضو وباقة الاشتراك' });
      setTimeout(() => setGlobalToast(null), 3000);
      return;
    }
    setIsModalSaving(true);
    try {
      const gymId = profile?.gym_id || gym?.id || 'd0000000-0000-0000-0000-000000000001';
      const newMembershipId = crypto.randomUUID();
      const plan = realPlans.find(p => p.id === memPlanId);
      const member = realMembers.find(m => m.id === memMemberId);
      const price = parseFloat(memPrice) || plan?.price || 350;

      const memRecord = {
        id: newMembershipId,
        gym_id: gymId,
        member_id: memMemberId,
        plan_id: memPlanId,
        start_date: memStartDate,
        end_date: memEndDate,
        price: price,
        status: 'active',
        created_by: currentUser?.id || session?.user?.id || null,
        sync_version: 1,
      };

      if (isOnline) {
        const { data } = await supabase.from('memberships').insert(memRecord).select().single();
        if (data) Object.assign(memRecord, data);

        if (memRecordPayment) {
          const { data: payData } = await supabase.from('payments').insert({
            id: crypto.randomUUID(),
            gym_id: gymId,
            membership_id: newMembershipId,
            amount: price,
            payment_method: 'cash',
            paid_at: new Date().toISOString(),
            notes: `اشتراك: ${plan?.name || 'باقة'} - ${member?.full_name || ''}`,
            recorded_by: currentUser?.id || session?.user?.id || null,
            sync_version: 1,
          }).select().single();
          if (payData) setRealPayments(prev => [payData, ...prev]);
        }
      }

      setRealMemberships(prev => [memRecord, ...prev]);
      setShowAddMembershipModal(false);
      setGlobalToast({ type: 'success', message: `تم تفعيل اشتراك "${member?.full_name}" بنجاح!` });
      setTimeout(() => setGlobalToast(null), 3000);
    } catch (err: any) {
      setGlobalToast({ type: 'error', message: 'فشل حفظ الاشتراك: ' + (err?.message || 'خطأ') });
      setTimeout(() => setGlobalToast(null), 3000);
    } finally {
      setIsModalSaving(false);
    }
  };

  // Save Payment
  const handleSavePayment = async () => {
    const amt = parseFloat(newPaymentAmount);
    if (!amt || amt <= 0) {
      setGlobalToast({ type: 'error', message: 'يرجى إدخال مبلغ دفع صحيح' });
      setTimeout(() => setGlobalToast(null), 3000);
      return;
    }
    setIsModalSaving(true);
    try {
      const gymId = profile?.gym_id || gym?.id || 'd0000000-0000-0000-0000-000000000001';
      const payRecord = {
        id: crypto.randomUUID(),
        gym_id: gymId,
        amount: amt,
        payment_method: newPaymentMethod,
        paid_at: new Date().toISOString(),
        notes: newPaymentNotes.trim() || null,
        recorded_by: currentUser?.id || session?.user?.id || null,
        sync_version: 1,
      };

      if (isOnline) {
        const { data } = await supabase.from('payments').insert(payRecord).select().single();
        if (data) Object.assign(payRecord, data);
      }

      setRealPayments(prev => [payRecord, ...prev]);
      setShowAddPaymentModal(false);
      setNewPaymentNotes('');
      setGlobalToast({ type: 'success', message: `تم تسجيل إيصال دفع بمبلغ ${amt} ج.م بنجاح!` });
      setTimeout(() => setGlobalToast(null), 3000);
    } catch (err: any) {
      setGlobalToast({ type: 'error', message: 'فشل تسجيل الدفعة: ' + (err?.message || 'خطأ') });
      setTimeout(() => setGlobalToast(null), 3000);
    } finally {
      setIsModalSaving(false);
    }
  };

  // 1. Real Login
  const handleRealLogin = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    setAuthError(null);
    setAuthSuccess(null);

    try {
      const { data, error } = await supabase.auth.signInWithPassword({
        email: loginEmail.trim(),
        password: loginPassword,
      });

      if (error) {
        if (error.message.toLowerCase().includes('invalid login credentials')) {
          setAuthError('البريد الإلكتروني أو كلمة المرور غير صحيحة');
        } else if (error.message.toLowerCase().includes('email not confirmed')) {
          setAuthError('يرجى تأكيد بريدك الإلكتروني أولاً');
        } else {
          setAuthError(error.message);
        }
        setIsSubmitting(false);
        return;
      }

      if (data.user) {
        await loadUserProfileAndGym(data.user.id, data.user.user_metadata?.full_name);
      }
    } catch (err: any) {
      setAuthError(err.message || 'حدث خطأ غير متوقع أثناء تسجيل الدخول');
    } finally {
      setIsSubmitting(false);
    }
  };

  // 2. Real Register
  const handleRealRegister = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    setAuthError(null);
    setAuthSuccess(null);

    if (registerPassword !== registerConfirmPassword) {
      setAuthError('كلمتا المرور غير متطابقتين');
      setIsSubmitting(false);
      return;
    }

    if (registerPassword.length < 6) {
      setAuthError('كلمة المرور يجب أن لا تقل عن 6 أحرف');
      setIsSubmitting(false);
      return;
    }

    try {
      const { data, error } = await supabase.auth.signUp({
        email: registerEmail.trim(),
        password: registerPassword,
        options: {
          data: {
            full_name: registerName.trim(),
          },
        },
      });

      if (error) {
        if (error.message.toLowerCase().includes('already registered') || error.message.toLowerCase().includes('user already exists')) {
          setAuthError('هذا البريد الإلكتروني مسجل بالفعل، يرجى تسجيل الدخول');
        } else {
          setAuthError(error.message);
        }
        setIsSubmitting(false);
        return;
      }

      if (data.user) {
        // Set local name and route directly to Join Gym flow
        setJoinFullName(registerName.trim());
        setAuthSuccess('تم إنشاء الحساب بنجاح! أدخل رمز الدعوة للانضمام للجيم.');

        if (data.session) {
          await loadUserProfileAndGym(data.user.id, registerName.trim());
          setCurrentScreen('join-gym');
        } else {
          // If Supabase project requires email confirmation
          setAuthSuccess('تم إنشاء الحساب بنجاح! يرجى مراجعة بريدك الإلكتروني لتأكيد التسجيل أو تسجيل الدخول.');
          setTimeout(() => setCurrentScreen('login'), 2500);
        }
      }
    } catch (err: any) {
      setAuthError(err.message || 'حدث خطأ أثناء إنشاء الحساب');
    } finally {
      setIsSubmitting(false);
    }
  };

  // 3. Real Join Gym via Edge Function (https://rpwcjfayhdwbsnecomnk.supabase.co/functions/v1/join-gym)
  const handleRealJoinGym = async (e: React.FormEvent) => {
    e.preventDefault();
    setIsSubmitting(true);
    setAuthError(null);
    setAuthSuccess(null);

    const code = joinInviteCode.trim();
    const name = joinFullName.trim();

    if (!name) {
      setAuthError('يرجى إدخال الاسم بالكامل');
      setIsSubmitting(false);
      return;
    }

    if (!code) {
      setAuthError('يرجى إدخال رمز دعوة صحيح');
      setIsSubmitting(false);
      return;
    }

    const currentToken = session?.access_token;
    if (!currentToken) {
      setAuthError('الجلسة غير صالحة، يرجى تسجيل الدخول مجدداً');
      setIsSubmitting(false);
      return;
    }

    try {
      // Call Edge Function using Supabase Functions SDK with Authorization Bearer header
      const response = await supabase.functions.invoke('join-gym', {
        headers: {
          Authorization: `Bearer ${currentToken}`,
        },
        body: {
          full_name: name,
          invite_code: code,
        },
      });

      if (response.error) {
        const errorData = response.data;
        const msg = errorData?.error || errorData?.message || response.error?.message || 'تعذر الانضمام للجيم، يرجى التأكد من كود الدعوة';
        let friendlyMsg = msg;
        if (msg.toLowerCase().includes('invalid') || msg.toLowerCase().includes('not found')) {
          friendlyMsg = 'رمز الدعوة غير صحيح أو غير موجود';
        } else if (msg.toLowerCase().includes('expire')) {
          friendlyMsg = 'رمز الدعوة منتهي الصلاحية';
        } else if (msg.toLowerCase().includes('max') || msg.toLowerCase().includes('limit') || msg.toLowerCase().includes('used')) {
          friendlyMsg = 'تم استنفاد الحد الأقصى لاستخدام رمز الدعوة هذا';
        } else if (msg.toLowerCase().includes('already')) {
          friendlyMsg = 'هذا الحساب مرتبط بالفعل بصالة جيم';
        }
        setAuthError(friendlyMsg);
        setIsSubmitting(false);
        return;
      }

      setAuthSuccess('تم الانضمام للجيم بنجاح! مرحباً بك في جيم الديب.');
      if (currentUser) {
        await loadUserProfileAndGym(currentUser.id, name);
      }
      setCurrentScreen('dashboard');
    } catch (err: any) {
      setAuthError(err.message || 'حدث خطأ في الاتصال بالـ Edge Function');
    } finally {
      setIsSubmitting(false);
    }
  };

  // Real Sign Out
  const handleRealSignOut = async () => {
    setIsSubmitting(true);
    try {
      await supabase.auth.signOut();
      setSession(null);
      setCurrentUser(null);
      setProfile(null);
      setGym(null);
      setLoginPassword('');
      setCurrentScreen('login');
    } catch (err) {
      console.warn('Signout warning:', err);
      setCurrentScreen('login');
    } finally {
      setIsSubmitting(false);
    }
  };

  // Add Member Modal Handler
  const handleAddMemberModalSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setModalFeedback(null);

    const name = modalMemberName.trim();
    if (!name) {
      setModalFeedback({ type: 'error', message: 'يرجى إدخال اسم العضو الكامل' });
      return;
    }

    setIsModalSaving(true);

    try {
      let effectiveGymId = profile?.gym_id;
      if (!effectiveGymId) {
        // Fallback: Query first gym from database
        const { data: gyms } = await supabase.from('gyms').select('id').limit(1);
        if (gyms && gyms.length > 0) {
          effectiveGymId = gyms[0].id;
        }
      }

      if (!effectiveGymId) {
        throw new Error('لم يتم العثور على صالة جيم مرتبطة بهذا الحساب. يرجى الانضمام للجيم برمز الدعوة أولاً.');
      }

      const { data: newMember, error } = await supabase.from('members').insert({
        gym_id: effectiveGymId,
        full_name: name,
        phone: modalMemberPhone.trim() || null,
        join_date: modalMemberJoinDate || new Date().toISOString().substring(0, 10),
        notes: modalMemberNotes.trim() || null,
        is_active: true,
      }).select().single();

      if (error) throw error;

      if (newMember) {
        setRealMembers(prev => [newMember, ...prev]);
        setModalFeedback({ type: 'success', message: `تمت إضافة العضو "${name}" بنجاح!` });
        setTimeout(() => {
          setShowAddMemberModal(false);
          setModalMemberName('');
          setModalMemberPhone('');
          setModalMemberNotes('');
          setModalFeedback(null);
        }, 1000);
      }
    } catch (err: any) {
      setModalFeedback({ type: 'error', message: err.message || 'فشل حفظ العضو، يرجى المحاولة مرة أخرى.' });
    } finally {
      setIsModalSaving(false);
    }
  };

  const handleCopyCode = () => {
    navigator.clipboard.writeText(FLUTTER_FILES[selectedFile]?.code || '');
    setCopied(true);
    setTimeout(() => setCopied(false), 2000);
  };

  const isDark = appTheme === 'dark';

  return (
    <div className={`min-h-screen flex flex-col font-['Cairo',sans-serif] transition-colors duration-200 ${isDark ? 'bg-[#080C14] text-slate-100' : 'bg-[#F1F5F9] text-slate-900'}`} dir="rtl">
      {/* Top Bar */}
      <header className={`border-b sticky top-0 z-50 px-4 lg:px-8 py-3 transition-colors ${isDark ? 'border-[#1E2B45] bg-[#0F1626]/90 backdrop-blur' : 'border-slate-200 bg-white/95 backdrop-blur shadow-xs'}`}>
        <div className="max-w-7xl mx-auto flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-10 h-10 rounded-xl bg-gradient-to-br from-[#D4AF37] to-[#B89728] flex items-center justify-center shadow-lg shadow-amber-500/20 text-slate-950">
              <Dumbbell className="w-5 h-5 stroke-[2.5]" />
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h1 className={`font-black text-lg tracking-tight ${isDark ? 'text-slate-100' : 'text-slate-900'}`}>
                  جيم الديب <span className="text-[#D4AF37] font-normal">|</span> Gym ElDeeb
                </h1>
                <span className="text-[11px] font-bold px-2 py-0.5 rounded-md bg-emerald-500/15 text-emerald-400 border border-emerald-500/30 flex items-center gap-1">
                  <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
                  <span>نظام إدارة الصالة</span>
                </span>
              </div>
              <p className={`text-xs ${isDark ? 'text-slate-400' : 'text-slate-500'}`}>
                تطبيق الموبايل فلاتر • مصادقة Supabase السحابية • إدارة المشتركين والمدفوعات
              </p>
            </div>
          </div>

          {/* Navigation Tabs & Theme Switcher */}
          <div className="flex items-center gap-2">
            <button
              type="button"
              onClick={() => {
                const next = appTheme === 'dark' ? 'light' : 'dark';
                setAppTheme(next);
                setGlobalToast({ type: 'success', message: `تم تفعيل ${next === 'dark' ? 'الوضع الداكن الذهبي' : 'الوضع الفاتح'}` });
                setTimeout(() => setGlobalToast(null), 2500);
              }}
              title="تبديل المظهر"
              className={`p-2 rounded-xl border transition flex items-center gap-1.5 text-xs font-bold ${
                isDark
                  ? 'bg-[#151F33] hover:bg-[#1E2B45] text-amber-300 border-[#1E2B45]'
                  : 'bg-slate-100 hover:bg-slate-200 text-slate-700 border-slate-200'
              }`}
            >
              {isDark ? <Sun className="w-4 h-4 text-[#D4AF37]" /> : <Moon className="w-4 h-4 text-slate-700" />}
              <span className="hidden sm:inline">{isDark ? 'الداكن' : 'الفاتح'}</span>
            </button>

            <div className={`flex items-center gap-1 p-1 rounded-xl border ${isDark ? 'bg-[#151F33] border-[#1E2B45]' : 'bg-slate-100 border-slate-200'}`}>
              <button
                onClick={() => setActiveTab('simulator')}
                className={`px-3 py-1.5 rounded-lg text-xs font-bold transition flex items-center gap-1.5 ${
                  activeTab === 'simulator'
                    ? 'bg-[#D4AF37] text-slate-950 shadow-sm'
                    : isDark ? 'text-slate-300 hover:text-white' : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                <Smartphone className="w-3.5 h-3.5" />
                <span>المحاكي المباشر (Simulator)</span>
              </button>
              <button
                onClick={() => setActiveTab('code')}
                className={`px-3 py-1.5 rounded-lg text-xs font-bold transition flex items-center gap-1.5 ${
                  activeTab === 'code'
                    ? 'bg-[#D4AF37] text-slate-950 shadow-sm'
                    : isDark ? 'text-slate-300 hover:text-white' : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                <FileCode className="w-3.5 h-3.5" />
                <span>أكواد Flutter</span>
              </button>
              <button
                onClick={() => setActiveTab('schema')}
                className={`px-3 py-1.5 rounded-lg text-xs font-bold transition flex items-center gap-1.5 ${
                  activeTab === 'schema'
                    ? 'bg-[#D4AF37] text-slate-950 shadow-sm'
                    : isDark ? 'text-slate-300 hover:text-white' : 'text-slate-600 hover:text-slate-900'
                }`}
              >
                <Shield className="w-3.5 h-3.5" />
                <span>ضوابط RLS والأمان</span>
              </button>
            </div>
          </div>
        </div>
      </header>

      {/* Main Content Area */}
      <main className="flex-1 max-w-7xl mx-auto w-full p-4 lg:p-6">
        {activeTab === 'simulator' && (
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
            {/* Left Column: Real Auth Inspection & Phase 2 Checklist */}
            <div className="lg:col-span-4 space-y-4">
              {/* Phase 2 Requirements Checklist Card */}
              <div className={`border rounded-2xl p-5 shadow-lg transition-colors ${isDark ? 'bg-[#0F1626] border-[#1E2B45]' : 'bg-white border-slate-200 shadow-sm'}`}>
                <div className="flex items-center justify-between mb-3">
                  <h3 className={`font-bold text-sm flex items-center gap-2 ${isDark ? 'text-slate-100' : 'text-slate-900'}`}>
                    <CheckCircle2 className="w-4 h-4 text-emerald-400" />
                    <span>متطلبات المصادقة والـ Backend:</span>
                  </h3>
                  <span className="text-[11px] font-bold text-emerald-400 bg-emerald-500/10 px-2.5 py-0.5 rounded-full border border-emerald-500/30">
                    مكتمل
                  </span>
                </div>
                <ul className={`space-y-2 text-xs ${isDark ? 'text-slate-300' : 'text-slate-600'}`}>
                  <li className="flex items-start gap-2">
                    <Check className="w-3.5 h-3.5 text-emerald-400 shrink-0 mt-0.5" />
                    <span><b>الهوية المعتمدة:</b> "جيم الديب" (Gym ElDeeb) بهوية ذهبية رياضية راقية.</span>
                  </li>
                  <li className="flex items-start gap-2">
                    <Check className="w-3.5 h-3.5 text-emerald-400 shrink-0 mt-0.5" />
                    <span><b>شاشة الدخول (Login):</b> مصادقة Supabase حقيقية، مؤشر تحميل، ورسائل خطأ عربية.</span>
                  </li>
                  <li className="flex items-start gap-2">
                    <Check className="w-3.5 h-3.5 text-emerald-400 shrink-0 mt-0.5" />
                    <span><b>شاشة التسجيل (Register):</b> الاسم، البريد، كلمة المرور، وتأكيد كلمة المرور.</span>
                  </li>
                  <li className="flex items-start gap-2">
                    <Check className="w-3.5 h-3.5 text-emerald-400 shrink-0 mt-0.5" />
                    <span><b>حماية الرتب والجيم (RLS):</b> لا يمكن للعميل ترقية رتبته؛ التوجيه فوراً لـ Join Gym.</span>
                  </li>
                  <li className="flex items-start gap-2">
                    <Check className="w-3.5 h-3.5 text-emerald-400 shrink-0 mt-0.5" />
                    <span><b>شاشة Join Gym والـ Edge Function:</b> استدعاء <code className="text-[#D4AF37] font-mono text-[10px]">join-gym</code> السحابية للتحقق من كود الدعوة.</span>
                  </li>
                </ul>
              </div>

              {/* Live Session Status */}
              <div className={`border rounded-2xl p-5 shadow-lg transition-colors ${isDark ? 'bg-[#0F1626] border-[#1E2B45]' : 'bg-white border-slate-200 shadow-sm'}`}>
                <div className="flex items-center justify-between">
                  <h3 className={`font-bold text-sm flex items-center gap-2 ${isDark ? 'text-slate-100' : 'text-slate-900'}`}>
                    <KeyRound className="w-4 h-4 text-[#D4AF37]" />
                    <span>حالة جلسة Supabase الحالية</span>
                  </h3>
                  <span className={`text-[10px] px-2.5 py-0.5 rounded-full font-bold ${
                    currentUser ? 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/30' : isDark ? 'bg-slate-800 text-slate-400' : 'bg-slate-100 text-slate-600'
                  }`}>
                    {currentUser ? 'مستخدم نشط (Active)' : 'غير مسجل (Guest)'}
                  </span>
                </div>

                {currentUser ? (
                  <div className={`space-y-2 text-xs p-3 rounded-xl border mt-3 ${isDark ? 'text-slate-300 bg-[#080C14] border-[#1E2B45]' : 'text-slate-700 bg-slate-50 border-slate-200'}`}>
                    <div className="flex justify-between items-center">
                      <span className={isDark ? 'text-slate-400' : 'text-slate-500'}>البريد:</span>
                      <span className="font-mono text-[#D4AF37] text-[11px] truncate max-w-[180px]">{currentUser.email}</span>
                    </div>
                    <div className="flex justify-between items-center">
                      <span className={isDark ? 'text-slate-400' : 'text-slate-500'}>الاسم:</span>
                      <span className="font-semibold">{profile?.full_name || 'غير محدد'}</span>
                    </div>
                    <div className="flex justify-between items-center">
                      <span className={isDark ? 'text-slate-400' : 'text-slate-500'}>الرتبة:</span>
                      <span className="px-2 py-0.5 rounded-md text-[10px] font-bold bg-amber-500/15 text-[#D4AF37] border border-amber-500/30">
                        {profile?.role === 'owner' ? 'مالك (Owner)' : 'مدرب (Coach)'}
                      </span>
                    </div>
                    <div className="flex justify-between items-center">
                      <span className={isDark ? 'text-slate-400' : 'text-slate-500'}>الجيم:</span>
                      <span>{gym?.name || (profile?.gym_id ? 'معرف: ' + profile.gym_id.substring(0, 8) + '...' : 'لم ينضم بعد')}</span>
                    </div>
                    <div className={`pt-2 border-t flex justify-end ${isDark ? 'border-[#1E2B45]' : 'border-slate-200'}`}>
                      <button
                        onClick={handleRealSignOut}
                        disabled={isSubmitting}
                        className="text-xs text-rose-500 hover:text-rose-600 flex items-center gap-1 font-bold"
                      >
                        <LogOut className="w-3.5 h-3.5" />
                        <span>تسجيل الخروج من Supabase</span>
                      </button>
                    </div>
                  </div>
                ) : (
                  <div className={`text-xs p-3 rounded-xl border text-center mt-3 ${isDark ? 'text-slate-400 bg-[#080C14] border-[#1E2B45]' : 'text-slate-500 bg-slate-50 border-slate-200'}`}>
                    لا توجد جلسة نشطة حالياً. يمكنك تسجيل الدخول أو إنشاء حساب جديد في المحاكي لاختبار دورة المصادقة كاملة.
                  </div>
                )}

                {/* Direct Screen Navigation */}
                <div className={`pt-3 border-t space-y-2 mt-3 ${isDark ? 'border-[#1E2B45]' : 'border-slate-200'}`}>
                  <span className={`text-xs font-semibold ${isDark ? 'text-slate-400' : 'text-slate-500'}`}>التنقل السريع بين الشاشات:</span>
                  <div className="grid grid-cols-3 gap-1.5">
                    {[
                      { id: 'splash', label: '1. Splash' },
                      { id: 'login', label: '2. Login' },
                      { id: 'register', label: '3. Register' },
                      { id: 'join-gym', label: '4. Join Gym' },
                      { id: 'dashboard', label: '5. Dashboard' },
                    ].map(screen => (
                      <button
                        key={screen.id}
                        onClick={() => {
                          setAuthError(null);
                          setAuthSuccess(null);
                          setCurrentScreen(screen.id as any);
                        }}
                        className={`py-1.5 px-2 rounded-lg text-xs font-bold transition border btn-tactile ${
                          currentScreen === screen.id
                            ? 'bg-[#D4AF37] text-slate-950 border-[#D4AF37] shadow-sm'
                            : isDark ? 'bg-[#151F33] border-[#1E2B45] text-slate-300 hover:bg-[#1E2B45]' : 'bg-slate-100 border-slate-200 text-slate-700 hover:bg-slate-200'
                        }`}
                      >
                        {screen.label}
                      </button>
                    ))}
                  </div>
                </div>

                {/* Connectivity Toggle */}
                <div className={`pt-3 border-t flex items-center justify-between mt-3 ${isDark ? 'border-[#1E2B45]' : 'border-slate-200'}`}>
                  <div className="flex items-center gap-2">
                    {isOnline ? (
                      <Wifi className="w-4 h-4 text-emerald-400" />
                    ) : (
                      <WifiOff className="w-4 h-4 text-rose-400" />
                    )}
                    <span className={`text-xs ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>
                      الاتصال: <b className={isOnline ? 'text-emerald-500 font-bold' : 'text-rose-500 font-bold'}>{isOnline ? 'متصل (Online)' : 'أوفلاين (Offline)'}</b>
                    </span>
                  </div>
                  <button
                    onClick={() => setIsOnline(!isOnline)}
                    className={`px-3 py-1 text-xs rounded-lg border font-bold transition btn-tactile ${
                      isDark ? 'bg-[#151F33] hover:bg-[#1E2B45] border-[#1E2B45] text-slate-200' : 'bg-slate-100 hover:bg-slate-200 border-slate-200 text-slate-700'
                    }`}
                  >
                    تبديل الحالة
                  </button>
                </div>
              </div>

              {/* Edge Function & Backend Endpoints */}
              <div className={`border rounded-2xl p-4 text-xs space-y-1.5 transition-colors ${isDark ? 'bg-[#0F1626]/70 border-[#1E2B45] text-slate-400' : 'bg-white border-slate-200 text-slate-600 shadow-sm'}`}>
                <div className="flex items-center gap-1.5 text-[#D4AF37] font-bold">
                  <Shield className="w-3.5 h-3.5" />
                  <span>دالة الانضمام السحابية (Edge Function):</span>
                </div>
                <p className={`font-mono text-[11px] break-all ${isDark ? 'text-slate-300' : 'text-slate-800'}`}>
                  https://rpwcjfayhdwbsnecomnk.supabase.co/functions/v1/join-gym
                </p>
                <p className={`text-[11px] leading-relaxed ${isDark ? 'text-slate-400' : 'text-slate-500'}`}>
                  يتم التحقق من كود الدعوة وتحديد صلاحيات المالك المشترك تلقائياً من جهة السيرفر، مع منع تعديل الجيم أو الرول من طرف التطبيق.
                </p>
              </div>
            </div>

            {/* Right Column: High-Fidelity Mobile Device Mockup */}
            <div className="lg:col-span-8 flex justify-center">
              <div className={`w-[390px] max-w-full rounded-[44px] shadow-2xl overflow-hidden flex flex-col h-[750px] relative ring-1 transition-colors ${
                isDark
                  ? 'bg-[#080C14] border-[6px] border-[#151F33] ring-[#1E2B45] text-slate-100'
                  : 'bg-[#F8FAFC] border-[6px] border-slate-300 ring-slate-200 text-slate-900'
              }`}>
                {/* Mobile Status Bar */}
                <div className={`px-6 pt-3 pb-2 flex items-center justify-between text-[11px] border-b select-none transition-colors ${
                  isDark
                    ? 'bg-[#0F1626] text-slate-300 border-[#1E2B45]'
                    : 'bg-white text-slate-700 border-slate-200 shadow-2xs'
                }`}>
                  <span className="font-bold font-mono tabular-nums">09:41</span>
                  <div className={`w-20 h-4 rounded-full mx-auto ${isDark ? 'bg-[#080C14]' : 'bg-slate-200'}`} />
                  <div className="flex items-center gap-1.5">
                    {isOnline ? (
                      <Wifi className="w-3.5 h-3.5 text-emerald-500" />
                    ) : (
                      <WifiOff className="w-3.5 h-3.5 text-rose-500" />
                    )}
                    <span className="text-[10px] font-mono">5G</span>
                    <div className={`w-4 h-2 border rounded-xs p-0.5 flex items-center ${isDark ? 'border-slate-500' : 'border-slate-400'}`}>
                      <div className="w-full h-full bg-emerald-500 rounded-2xs" />
                    </div>
                  </div>
                </div>

                {/* Offline-First Banner */}
                {!isOnline && (
                  <div className="bg-rose-600 text-white text-[11px] py-1 px-3 text-center flex items-center justify-center gap-1.5 font-bold animate-fadeIn">
                    <WifiOff className="w-3 h-3" />
                    <span>وضع أوفلاين (غير متصل) - يتم حفظ التغييرات محلياً</span>
                  </div>
                )}

                {/* Mobile Screen Container */}
                <div className={`flex-1 overflow-y-auto flex flex-col transition-colors ${
                  isDark ? 'bg-[#080C14]' : 'bg-[#F8FAFC]'
                }`}>
                  {/* SCREEN 1: SPLASH */}
                  {currentScreen === 'splash' && (
                    <div className="flex-1 flex flex-col items-center justify-center p-6 text-center animate-fadeIn">
                      <div className="w-24 h-24 rounded-3xl bg-gradient-to-br from-[#D4AF37] to-[#B89728] flex items-center justify-center shadow-xl shadow-amber-500/25 mb-6 animate-pulse gold-glow">
                        <Dumbbell className="w-12 h-12 text-slate-950 stroke-[2.5]" />
                      </div>
                      <h2 className={`text-2xl font-black tracking-tight mb-1 ${isDark ? 'text-slate-100' : 'text-slate-900'}`}>جيم الديب</h2>
                      <p className="text-xs text-[#D4AF37] font-bold tracking-wider mb-8">
                        GYM ELDEEB • نظام إدارة الصالة الرياضية
                      </p>
                      <div className="w-7 h-7 border-2 border-[#D4AF37] border-t-transparent rounded-full animate-spin mb-3" />
                      <p className={`text-xs ${isDark ? 'text-slate-400' : 'text-slate-500'}`}>جارٍ التحقق من جلسة Supabase...</p>
                    </div>
                  )}

                  {/* SCREEN 2: LOGIN */}
                  {currentScreen === 'login' && (
                    <div className="flex-1 p-6 flex flex-col justify-center animate-fadeIn">
                      <div className="text-center mb-6">
                        <div className="w-16 h-16 rounded-2xl bg-amber-500/10 border border-amber-500/30 flex items-center justify-center mx-auto mb-3 text-[#D4AF37]">
                          <Dumbbell className="w-8 h-8 stroke-[2.5]" />
                        </div>
                        <h2 className={`text-xl font-black ${isDark ? 'text-slate-100' : 'text-slate-900'}`}>تسجيل الدخول للمدربين والمالكين</h2>
                        <p className={`text-xs mt-1 ${isDark ? 'text-slate-400' : 'text-slate-500'}`}>سجل دخولك لمتابعة صالة الألعاب الرياضية والاشتراكات</p>
                      </div>

                      {authSuccess && (
                        <div className="bg-emerald-500/15 border border-emerald-500/30 rounded-xl p-3 text-xs text-emerald-500 text-center mb-4 flex items-center justify-center gap-1.5 font-bold">
                          <CheckCircle2 className="w-4 h-4 shrink-0" />
                          <span>{authSuccess}</span>
                        </div>
                      )}

                      {authError && (
                        <div className="bg-rose-500/15 border border-rose-500/30 rounded-xl p-3 text-xs text-rose-500 text-center mb-4 flex items-center justify-center gap-1.5 font-bold">
                          <AlertCircle className="w-4 h-4 shrink-0" />
                          <span>{authError}</span>
                        </div>
                      )}

                      <form onSubmit={handleRealLogin} className="space-y-4">
                        <div>
                          <label className={`block text-xs font-bold mb-1.5 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>البريد الإلكتروني</label>
                          <input
                            type="email"
                            value={loginEmail}
                            onChange={e => setLoginEmail(e.target.value)}
                            required
                            disabled={isSubmitting}
                            className={`w-full border rounded-xl px-3.5 py-2.5 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] disabled:opacity-60 transition ${
                              isDark ? 'bg-[#0F1626] border-[#1E2B45] text-slate-100' : 'bg-white border-slate-300 text-slate-900'
                            }`}
                            placeholder="coach@gymeldeeb.com"
                          />
                        </div>

                        <div>
                          <label className={`block text-xs font-bold mb-1.5 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>كلمة المرور</label>
                          <div className="relative">
                            <input
                              type={showPassword ? 'text' : 'password'}
                              value={loginPassword}
                              onChange={e => setLoginPassword(e.target.value)}
                              required
                              disabled={isSubmitting}
                              className={`w-full border rounded-xl px-3.5 py-2.5 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] disabled:opacity-60 transition ${
                                isDark ? 'bg-[#0F1626] border-[#1E2B45] text-slate-100' : 'bg-white border-slate-300 text-slate-900'
                              }`}
                              placeholder="••••••••"
                            />
                            <button
                              type="button"
                              onClick={() => setShowPassword(!showPassword)}
                              className={`absolute left-3 top-2.5 ${isDark ? 'text-slate-400 hover:text-slate-200' : 'text-slate-500 hover:text-slate-700'}`}
                            >
                              {showPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                            </button>
                          </div>
                        </div>

                        <button
                          type="submit"
                          disabled={isSubmitting}
                          className="w-full bg-[#D4AF37] hover:bg-[#E5C158] active:scale-98 text-slate-950 font-bold text-xs py-3 rounded-xl transition flex items-center justify-center gap-2 shadow-lg shadow-amber-500/20 disabled:opacity-50 btn-tactile"
                        >
                          {isSubmitting ? (
                            <RefreshCw className="w-4 h-4 animate-spin" />
                          ) : (
                            <>
                              <span>تسجيل الدخول</span>
                              <ArrowRight className="w-4 h-4 rotate-180" />
                            </>
                          )}
                        </button>
                      </form>

                      <div className="mt-6 text-center">
                        <button
                          onClick={() => {
                            setAuthError(null);
                            setAuthSuccess(null);
                            setCurrentScreen('register');
                          }}
                          className={`text-xs ${isDark ? 'text-slate-400 hover:text-slate-200' : 'text-slate-600 hover:text-slate-900'}`}
                        >
                          ليس لديك حساب بعد؟ <span className="text-[#D4AF37] font-bold hover:underline">إنشاء حساب جديد</span>
                        </button>
                      </div>
                    </div>
                  )}

                  {/* SCREEN 3: REGISTER */}
                  {currentScreen === 'register' && (
                    <div className="flex-1 p-6 flex flex-col justify-center animate-fadeIn">
                      <div className="text-center mb-5">
                        <div className="w-14 h-14 rounded-2xl bg-amber-500/10 border border-amber-500/30 flex items-center justify-center mx-auto mb-2 text-[#D4AF37]">
                          <Dumbbell className="w-7 h-7 stroke-[2.5]" />
                        </div>
                        <h2 className={`text-xl font-black ${isDark ? 'text-slate-100' : 'text-slate-900'}`}>إنشاء حساب جديد</h2>
                        <p className={`text-xs mt-1 ${isDark ? 'text-slate-400' : 'text-slate-500'}`}>انضم إلى كادر إدارة جيم الديب</p>
                      </div>

                      {authError && (
                        <div className="bg-rose-500/15 border border-rose-500/30 rounded-xl p-3 text-xs text-rose-500 text-center mb-4 flex items-center justify-center gap-1.5 font-bold">
                          <AlertCircle className="w-4 h-4 shrink-0" />
                          <span>{authError}</span>
                        </div>
                      )}

                      <form onSubmit={handleRealRegister} className="space-y-3">
                        <div>
                          <label className={`block text-xs font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>الاسم بالكامل</label>
                          <input
                            type="text"
                            value={registerName}
                            onChange={e => setRegisterName(e.target.value)}
                            required
                            disabled={isSubmitting}
                            placeholder="كابتن أحمد الديب"
                            className={`w-full border rounded-xl px-3.5 py-2.5 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] disabled:opacity-60 transition ${
                              isDark ? 'bg-[#0F1626] border-[#1E2B45] text-slate-100' : 'bg-white border-slate-300 text-slate-900'
                            }`}
                          />
                        </div>

                        <div>
                          <label className={`block text-xs font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>البريد الإلكتروني</label>
                          <input
                            type="email"
                            value={registerEmail}
                            onChange={e => setRegisterEmail(e.target.value)}
                            required
                            disabled={isSubmitting}
                            placeholder="coach@gymeldeeb.com"
                            className={`w-full border rounded-xl px-3.5 py-2.5 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] disabled:opacity-60 transition ${
                              isDark ? 'bg-[#0F1626] border-[#1E2B45] text-slate-100' : 'bg-white border-slate-300 text-slate-900'
                            }`}
                          />
                        </div>

                        <div>
                          <label className={`block text-xs font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>كلمة المرور</label>
                          <div className="relative">
                            <input
                              type={showRegisterPassword ? 'text' : 'password'}
                              value={registerPassword}
                              onChange={e => setRegisterPassword(e.target.value)}
                              required
                              disabled={isSubmitting}
                              placeholder="•••••••• (6 أحرف على الأقل)"
                              className={`w-full border rounded-xl px-3.5 py-2.5 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] disabled:opacity-60 transition ${
                                isDark ? 'bg-[#0F1626] border-[#1E2B45] text-slate-100' : 'bg-white border-slate-300 text-slate-900'
                              }`}
                            />
                            <button
                              type="button"
                              onClick={() => setShowRegisterPassword(!showRegisterPassword)}
                              className={`absolute left-3 top-2.5 ${isDark ? 'text-slate-400 hover:text-slate-200' : 'text-slate-500 hover:text-slate-700'}`}
                            >
                              {showRegisterPassword ? <EyeOff className="w-4 h-4" /> : <Eye className="w-4 h-4" />}
                            </button>
                          </div>
                        </div>

                        <div>
                          <label className={`block text-xs font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>تأكيد كلمة المرور</label>
                          <input
                            type={showRegisterPassword ? 'text' : 'password'}
                            value={registerConfirmPassword}
                            onChange={e => setRegisterConfirmPassword(e.target.value)}
                            required
                            disabled={isSubmitting}
                            placeholder="••••••••"
                            className={`w-full border rounded-xl px-3.5 py-2.5 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] disabled:opacity-60 transition ${
                              isDark ? 'bg-[#0F1626] border-[#1E2B45] text-slate-100' : 'bg-white border-slate-300 text-slate-900'
                            }`}
                          />
                        </div>

                        <button
                          type="submit"
                          disabled={isSubmitting}
                          className="w-full bg-[#D4AF37] hover:bg-[#E5C158] active:scale-98 text-slate-950 font-bold text-xs py-3 rounded-xl transition flex items-center justify-center gap-2 shadow-lg shadow-amber-500/20 disabled:opacity-50 mt-2 btn-tactile"
                        >
                          {isSubmitting ? (
                            <RefreshCw className="w-4 h-4 animate-spin" />
                          ) : (
                            <>
                              <span>إنشاء الحساب والمتابعة</span>
                              <ArrowRight className="w-4 h-4 rotate-180" />
                            </>
                          )}
                        </button>
                      </form>

                      <div className="text-center pt-3">
                        <button
                          onClick={() => {
                            setAuthError(null);
                            setAuthSuccess(null);
                            setCurrentScreen('login');
                          }}
                          className={`text-xs ${isDark ? 'text-slate-400 hover:text-slate-200' : 'text-slate-600 hover:text-slate-900'}`}
                        >
                          لديك حساب بالفعل؟ <span className="text-[#D4AF37] font-bold hover:underline">تسجيل الدخول</span>
                        </button>
                      </div>
                    </div>
                  )}

                  {/* SCREEN 4: JOIN GYM */}
                  {currentScreen === 'join-gym' && (
                    <div className="flex-1 p-6 flex flex-col justify-center animate-fadeIn">
                      <div className="text-center mb-4">
                        <div className="w-14 h-14 rounded-2xl bg-amber-500/10 border border-amber-500/30 flex items-center justify-center mx-auto mb-2 text-[#D4AF37]">
                          <KeyRound className="w-7 h-7" />
                        </div>
                        <h2 className={`text-lg font-black ${isDark ? 'text-slate-100' : 'text-slate-900'}`}>الانضمام لصالة الجيم</h2>
                        <p className={`text-xs mt-1 ${isDark ? 'text-slate-400' : 'text-slate-500'}`}>
                          أهلاً بك يا {joinFullName || profile?.full_name || 'كابتن'}. يرجى إدخال اسمك ورمز الدعوة للانضمام كمدرب أو شريك في إدارة جيم الديب.
                        </p>
                      </div>

                      {/* Edge Function Security Notice */}
                      <div className={`border rounded-xl p-3 mb-3 text-xs space-y-1 ${
                        isDark ? 'bg-[#0F1626] border-[#1E2B45] text-slate-300' : 'bg-white border-slate-200 text-slate-700 shadow-2xs'
                      }`}>
                        <div className="flex items-center gap-1.5 text-[#D4AF37] font-bold">
                          <Shield className="w-3.5 h-3.5" />
                          <span>تحقق أمني مشفر (Edge Function)</span>
                        </div>
                        <p className={`text-[11px] leading-relaxed ${isDark ? 'text-slate-400' : 'text-slate-500'}`}>
                          يتم إرسال رمز الدعوة مع توكن الجلسة (Bearer Token) مباشرة إلى دالة <code className="text-[#D4AF37] font-mono">join-gym</code> السحابية لربط الجيم ومنح الصلاحيات بأمان تام.
                        </p>
                      </div>

                      {authError && (
                        <div className="bg-rose-500/15 border border-rose-500/30 rounded-xl p-3 text-xs text-rose-500 text-center mb-3 flex items-center justify-center gap-1.5 font-bold">
                          <AlertCircle className="w-4 h-4 shrink-0" />
                          <span>{authError}</span>
                        </div>
                      )}

                      <form onSubmit={handleRealJoinGym} className="space-y-3.5">
                        <div>
                          <label className={`block text-xs font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>الاسم الكامل</label>
                          <input
                            type="text"
                            value={joinFullName}
                            onChange={e => setJoinFullName(e.target.value)}
                            required
                            disabled={isSubmitting}
                            placeholder="الاسم المسجل في كادر الجيم"
                            className={`w-full border rounded-xl px-3.5 py-2.5 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] disabled:opacity-60 transition ${
                              isDark ? 'bg-[#0F1626] border-[#1E2B45] text-slate-100' : 'bg-white border-slate-300 text-slate-900'
                            }`}
                          />
                        </div>

                        <div>
                          <label className={`block text-xs font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>رمز الدعوة (Invite Code)</label>
                          <input
                            type="text"
                            value={joinInviteCode}
                            onChange={e => setJoinInviteCode(e.target.value.toUpperCase())}
                            required
                            disabled={isSubmitting}
                            placeholder="مثال: ELDEEB-OWNER-2026"
                            className={`w-full border rounded-xl px-3.5 py-2.5 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] font-mono tracking-wider text-center disabled:opacity-60 transition ${
                              isDark ? 'bg-[#0F1626] border-[#1E2B45] text-[#D4AF37]' : 'bg-white border-slate-300 text-slate-900 font-bold'
                            }`}
                          />
                        </div>

                        <button
                          type="submit"
                          disabled={isSubmitting}
                          className="w-full bg-[#D4AF37] hover:bg-[#E5C158] active:scale-98 text-slate-950 font-bold text-xs py-3 rounded-xl transition flex items-center justify-center gap-2 shadow-lg shadow-amber-500/20 disabled:opacity-50 btn-tactile"
                        >
                          {isSubmitting ? (
                            <RefreshCw className="w-4 h-4 animate-spin" />
                          ) : (
                            <>
                              <span>تأكيد الرمز والانضمام للجيم</span>
                              <Check className="w-4 h-4" />
                            </>
                          )}
                        </button>
                      </form>

                      <div className="mt-4 text-center">
                        <button
                          onClick={handleRealSignOut}
                          className={`text-xs ${isDark ? 'text-slate-400 hover:text-slate-200' : 'text-slate-600 hover:text-slate-900'}`}
                        >
                          تسجيل الدخول بحساب آخر
                        </button>
                      </div>
                    </div>
                  )}

                  {/* SCREEN 5: DASHBOARD */}
                  {currentScreen === 'dashboard' && (
                    <div className="flex-1 flex flex-col min-h-0 relative animate-fadeIn">
                      {/* 1. TOP APP BAR (56px Compact Luxury Header) */}
                      <div className={`sticky top-0 z-30 px-3.5 py-2.5 border-b backdrop-blur-md transition-colors flex items-center justify-between ${
                        isDark ? 'bg-[#0A0F1A]/95 border-[#1A253A]' : 'bg-white/95 border-slate-200 shadow-2xs'
                      }`}>
                        {/* Brand Zone (RTL Right) */}
                        <div className="flex items-center gap-2">
                          <div className="w-8 h-8 rounded-xl bg-gradient-to-br from-[#D4AF37] to-[#997C22] p-[1px] shadow-sm flex items-center justify-center">
                            <div className={`w-full h-full rounded-[11px] flex items-center justify-center font-black text-xs ${
                              isDark ? 'bg-[#0A0F1A] text-[#D4AF37]' : 'bg-white text-slate-950'
                            }`}>
                              <Dumbbell className="w-4 h-4 text-[#D4AF37] stroke-[2.5]" />
                            </div>
                          </div>
                          <div>
                            <div className="flex items-center gap-1.5">
                              <h3 className={`font-black text-xs tracking-tight ${isDark ? 'text-slate-100' : 'text-slate-900'}`}>
                                {gym?.name || 'جيم الديب'}
                              </h3>
                              <span className="w-2 h-2 rounded-full bg-emerald-400 animate-pulse" title="متصل بالسيرفر" />
                            </div>
                            <p className={`text-[10px] ${isDark ? 'text-slate-400' : 'text-slate-500'}`}>
                              GYM ELDEEB • الصالة الرئيسية
                            </p>
                          </div>
                        </div>

                        {/* User & Actions Zone (RTL Left) */}
                        <div className="flex items-center gap-1.5">
                          {/* Sync / Offline Status Chip */}
                          <div className={`px-2 py-1 rounded-lg text-[10px] font-bold flex items-center gap-1 border ${
                            isOnline
                              ? isDark ? 'bg-emerald-500/10 text-emerald-400 border-emerald-500/20' : 'bg-emerald-50 text-emerald-700 border-emerald-200'
                              : 'bg-rose-500/15 text-rose-400 border-rose-500/30'
                          }`}>
                            {isOnline ? <Wifi className="w-3 h-3 text-emerald-400" /> : <WifiOff className="w-3 h-3 text-rose-400" />}
                            <span>{isOnline ? 'متصل' : 'أوفلاين'}</span>
                          </div>

                          {/* Coach Profile Avatar Chip */}
                          <button
                            onClick={() => setDashboardTab('settings')}
                            className={`flex items-center gap-1.5 p-1 rounded-xl border transition btn-tactile ${
                              isDark ? 'bg-[#121A2B] border-[#1E2B45] hover:border-[#D4AF37]/50' : 'bg-slate-100 border-slate-200 hover:border-slate-300'
                            }`}
                            title="الملف الشخصي والإعدادات"
                          >
                            <div className="w-6 h-6 rounded-lg bg-[#D4AF37]/20 text-[#D4AF37] flex items-center justify-center font-bold text-xs">
                              {profile?.full_name ? profile.full_name[0] : 'ك'}
                            </div>
                            <span className={`text-[10px] font-bold max-w-[65px] truncate hidden sm:inline ${isDark ? 'text-slate-200' : 'text-slate-800'}`}>
                              {profile?.full_name?.split(' ')[0] || 'كابتن'}
                            </span>
                          </button>
                        </div>
                      </div>

                      {/* 2. SCROLLABLE SCREEN BODY */}
                      <div className="flex-1 overflow-y-auto p-3.5 space-y-3.5 pb-20">
                        {/* SUB-VIEW 0: OVERVIEW (REDESIGNED FROM THE GROUND UP) */}
                        {dashboardTab === 'overview' && (
                          <div className="space-y-3.5 animate-fadeIn">
                            {/* 2.1 DASHBOARD HERO SECTION */}
                            <div className={`p-4 rounded-2xl border relative overflow-hidden transition-all shadow-lg ${
                              isDark
                                ? 'bg-gradient-to-br from-[#121A2B] via-[#0C1220] to-[#080C14] border-[#1F2E4A]'
                                : 'bg-gradient-to-br from-slate-900 via-slate-800 to-slate-900 border-slate-700 text-white shadow-md'
                            }`}>
                              {/* Background Gold Ambient Glow */}
                              <div className="absolute -top-12 -left-12 w-36 h-36 rounded-full bg-[#D4AF37]/15 blur-2xl pointer-events-none" />
                              <div className="absolute -bottom-10 -right-10 w-28 h-28 rounded-full bg-emerald-500/10 blur-xl pointer-events-none" />

                              <div className="relative z-10 space-y-2">
                                <div className="flex items-center justify-between">
                                  <div className="flex items-center gap-1.5 text-[11px] text-[#D4AF37] font-bold">
                                    <Clock className="w-3.5 h-3.5" />
                                    <span>{new Date().toLocaleDateString('ar-EG', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })}</span>
                                  </div>
                                  <span className="text-[10px] px-2 py-0.5 rounded-full bg-emerald-500/20 text-emerald-300 border border-emerald-500/30 font-bold flex items-center gap-1">
                                    <span className="w-1.5 h-1.5 rounded-full bg-emerald-400 animate-pulse" />
                                    <span>مفتوح • الصالة نشطة</span>
                                  </span>
                                </div>

                                <div>
                                  <h2 className="text-base font-black text-white tracking-tight flex items-center gap-1.5">
                                    <span>أهلاً بك، يا كابتن {profile?.full_name?.split(' ')[0] || 'باسم'}</span>
                                    <span className="text-lg">💪</span>
                                  </h2>
                                  <p className="text-xs text-slate-300 mt-0.5 leading-relaxed">
                                    لوحة تحكم جيم الديب • متابعة الأعضاء، تجديد الاشتراكات وإيرادات اليوم
                                  </p>
                                </div>

                                {/* Micro KPI Strip inside Hero */}
                                <div className="pt-2 border-t border-white/10 flex items-center justify-between text-xs">
                                  <div className="flex items-center gap-1.5 text-slate-300 text-[11px]">
                                    <Shield className="w-3.5 h-3.5 text-[#D4AF37]" />
                                    <span>الرتبة: <b>{profile?.role === 'owner' ? 'مالك الصالة (Owner)' : 'مدرب معتمد (Coach)'}</b></span>
                                  </div>
                                  <div className="text-[11px] text-amber-300 font-mono font-bold">
                                    عملة النظام: {gym?.currency || 'EGP'}
                                  </div>
                                </div>
                              </div>
                            </div>

                            {/* 2.2 ASYMMETRICAL STATISTICS / KPIS (NOT 4 IDENTICAL BOXES) */}
                            <div className="space-y-2.5">
                              {/* 1 Dominant Feature KPI Card: Total Members & Active Ratio */}
                              <div
                                onClick={() => setDashboardTab('members')}
                                className={`p-4 rounded-2xl border cursor-pointer transition group btn-tactile relative overflow-hidden ${
                                  isDark
                                    ? 'bg-[#0E1524] hover:bg-[#121C30] border-[#1E2B45] hover:border-[#D4AF37]/40'
                                    : 'bg-white hover:bg-slate-50 border-slate-200 shadow-sm'
                                }`}
                              >
                                <div className="flex items-center justify-between mb-2">
                                  <div className="flex items-center gap-2">
                                    <div className="w-9 h-9 rounded-xl bg-[#D4AF37]/15 text-[#D4AF37] flex items-center justify-center font-bold">
                                      <Users className="w-5 h-5 group-hover:scale-110 transition" />
                                    </div>
                                    <div>
                                      <h4 className={`text-xs font-bold ${isDark ? 'text-slate-200' : 'text-slate-800'}`}>إجمالي أعضاء الجيم والنشاط</h4>
                                      <p className={`text-[10px] ${isDark ? 'text-slate-400' : 'text-slate-500'}`}>قاعدة بيانات المشتركين المسجلين</p>
                                    </div>
                                  </div>
                                  <span className="text-[10px] px-2 py-0.5 rounded-full font-bold bg-[#D4AF37]/15 text-[#D4AF37] border border-[#D4AF37]/30 flex items-center gap-1">
                                    <TrendingUp className="w-3 h-3" />
                                    <span>سجل معتمد</span>
                                  </span>
                                </div>

                                <div className="flex items-end justify-between mt-2">
                                  <div>
                                    <div className="text-2xl font-black font-mono tabular-nums text-[#D4AF37] tracking-tight">
                                      {realMembers.length} <span className="text-xs font-normal text-slate-400">عضو مسجل</span>
                                    </div>
                                    <div className="text-[11px] text-emerald-400 font-bold flex items-center gap-1 mt-0.5">
                                      <CheckCircle2 className="w-3 h-3" />
                                      <span>{realMembers.filter(m => m.is_active).length} مشترك نشط حالياً ({realMembers.length > 0 ? Math.round((realMembers.filter(m => m.is_active).length / realMembers.length) * 100) : 0}%)</span>
                                    </div>
                                  </div>
                                  <div className="text-left text-xs text-[#D4AF37] font-bold flex items-center gap-0.5 group-hover:translate-x-[-2px] transition">
                                    <span>عرض الكل</span>
                                    <ChevronLeft className="w-3.5 h-3.5" />
                                  </div>
                                </div>

                                {/* Active Ratio Progress Bar */}
                                <div className={`w-full h-1.5 rounded-full mt-3 overflow-hidden ${isDark ? 'bg-slate-800' : 'bg-slate-100'}`}>
                                  <div
                                    className="h-full bg-gradient-to-r from-[#D4AF37] to-emerald-400 rounded-full transition-all duration-500"
                                    style={{ width: `${realMembers.length > 0 ? (realMembers.filter(m => m.is_active).length / realMembers.length) * 100 : 0}%` }}
                                  />
                                </div>
                              </div>

                              {/* 3 Secondary Specialized KPI Tiles (2+1 Layout) */}
                              <div className="grid grid-cols-2 gap-2.5">
                                {/* Tile 1: Expiring Soon (Urgent Amber Pulse) */}
                                {(() => {
                                  const expiringCount = realMemberships.filter(m => {
                                    const diff = Math.ceil((new Date(m.end_date).getTime() - new Date().getTime()) / (1000 * 60 * 60 * 24));
                                    return diff >= 0 && diff <= 7;
                                  }).length;

                                  return (
                                    <button
                                      onClick={() => {
                                        setDashboardTab('memberships');
                                      }}
                                      className={`p-3 rounded-xl border text-right transition group btn-tactile ${
                                        isDark
                                          ? 'bg-[#0E1524] hover:bg-[#151F33] border-[#1E2B45]'
                                          : 'bg-white hover:bg-slate-50 border-slate-200 shadow-2xs'
                                      }`}
                                    >
                                      <div className="flex items-center justify-between mb-1.5">
                                        <div className="w-7 h-7 rounded-lg bg-amber-500/15 text-amber-400 flex items-center justify-center">
                                          <AlertCircle className="w-4 h-4 group-hover:scale-110 transition" />
                                        </div>
                                        <span className="text-[9px] px-1.5 py-0.5 rounded font-bold bg-amber-500/10 text-amber-400 border border-amber-500/20">
                                          خلال ٧ أيام
                                        </span>
                                      </div>
                                      <div className="text-lg font-black font-mono tabular-nums text-amber-400">
                                        {expiringCount} <span className="text-xs text-slate-400">اشتراك</span>
                                      </div>
                                      <div className={`text-[10px] mt-0.5 ${isDark ? 'text-slate-400' : 'text-slate-500'}`}>
                                        تحتاج للتجديد والمتابعة
                                      </div>
                                    </button>
                                  );
                                })()}

                                {/* Tile 2: Total Revenue (Gold Currency Tile) */}
                                <button
                                  onClick={() => setDashboardTab('payments')}
                                  className={`p-3 rounded-xl border text-right transition group btn-tactile ${
                                    isDark
                                      ? 'bg-[#0E1524] hover:bg-[#151F33] border-[#1E2B45]'
                                      : 'bg-white hover:bg-slate-50 border-slate-200 shadow-2xs'
                                  }`}
                                >
                                  <div className="flex items-center justify-between mb-1.5">
                                    <div className="w-7 h-7 rounded-lg bg-emerald-500/15 text-emerald-400 flex items-center justify-center">
                                      <CreditCard className="w-4 h-4 group-hover:scale-110 transition" />
                                    </div>
                                    <span className="text-[9px] px-1.5 py-0.5 rounded font-bold bg-emerald-500/10 text-emerald-400 border border-emerald-500/20 font-mono">
                                      {realPayments.length} إيصال
                                    </span>
                                  </div>
                                  <div className="text-lg font-black font-mono tabular-nums text-emerald-400">
                                    {realPayments.reduce((acc, p) => acc + Number(p.amount || 0), 0)} <span className="text-[10px] text-slate-400">ج.م</span>
                                  </div>
                                  <div className={`text-[10px] mt-0.5 ${isDark ? 'text-slate-400' : 'text-slate-500'}`}>
                                    إجمالي تحصيل الاشتراكات
                                  </div>
                                </button>
                              </div>
                            </div>

                            {/* 2.3 QUICK ACTIONS (MODERN ACTION TILES) */}
                            <div className="space-y-2">
                              <div className="flex items-center justify-between px-1">
                                <span className={`text-xs font-bold ${isDark ? 'text-slate-200' : 'text-slate-800'}`}>الإجراءات السريعة</span>
                                <span className="text-[10px] text-[#D4AF37] font-bold">تسجيل فوري</span>
                              </div>

                              {/* Prominent Primary CTA: Add Member */}
                              <button
                                onClick={() => {
                                  setModalMemberName('');
                                  setModalMemberPhone('');
                                  setModalMemberNotes('');
                                  setModalFeedback(null);
                                  setShowAddMemberModal(true);
                                }}
                                className="w-full p-3.5 bg-gradient-to-r from-[#D4AF37] via-[#E5C158] to-[#D4AF37] hover:opacity-95 text-slate-950 font-bold text-xs rounded-2xl flex items-center justify-between shadow-lg shadow-amber-500/20 transition btn-tactile group"
                              >
                                <div className="flex items-center gap-2.5">
                                  <div className="w-9 h-9 rounded-xl bg-slate-950 text-[#D4AF37] flex items-center justify-center shadow-xs">
                                    <Users className="w-5 h-5 group-hover:scale-110 transition" />
                                  </div>
                                  <div className="text-right">
                                    <div className="font-black text-sm">تسجيل عضو جديد في الجيم</div>
                                    <div className="text-[10px] text-slate-900 font-medium">إدخال الاسم، الهاتف، وبدء الاشتراك فوراً</div>
                                  </div>
                                </div>
                                <Plus className="w-5 h-5 group-hover:rotate-90 transition transform" />
                              </button>

                              {/* 3 Sleek Secondary Quick Action Tiles */}
                              <div className="grid grid-cols-2 gap-2">
                                <button
                                  onClick={() => setShowAddPaymentModal(true)}
                                  className={`p-2.5 rounded-xl border text-center transition flex flex-col items-center justify-center gap-1 btn-tactile ${
                                    isDark
                                      ? 'bg-[#0E1524] hover:bg-[#151F33] border-[#1E2B45] text-slate-200'
                                      : 'bg-white hover:bg-slate-50 border-slate-200 text-slate-800 shadow-2xs'
                                  }`}
                                >
                                  <div className="w-7 h-7 rounded-lg bg-emerald-500/15 text-emerald-400 flex items-center justify-center">
                                    <CreditCard className="w-4 h-4" />
                                  </div>
                                  <span className="text-[11px] font-bold">تسجيل دفعة</span>
                                </button>

                                <button
                                  onClick={() => {
                                    setMemMemberId(realMembers[0]?.id || '');
                                    setMemPlanId(realPlans[0]?.id || '');
                                    setShowAddMembershipModal(true);
                                  }}
                                  className={`p-2.5 rounded-xl border text-center transition flex flex-col items-center justify-center gap-1 btn-tactile ${
                                    isDark
                                      ? 'bg-[#0E1524] hover:bg-[#151F33] border-[#1E2B45] text-slate-200'
                                      : 'bg-white hover:bg-slate-50 border-slate-200 text-slate-800 shadow-2xs'
                                  }`}
                                >
                                  <div className="w-7 h-7 rounded-lg bg-sky-500/15 text-sky-400 flex items-center justify-center">
                                    <Calendar className="w-4 h-4" />
                                  </div>
                                  <span className="text-[11px] font-bold">اشتراك جديد</span>
                                </button>

                              </div>
                            </div>

                            {/* 2.4 RECENT MEMBERS PREVIEW */}
                            <div className="space-y-2 pt-1">
                              <div className="flex items-center justify-between px-1">
                                <span className={`text-xs font-bold ${isDark ? 'text-slate-200' : 'text-slate-800'}`}>آخر الأعضاء المسجلين</span>
                                <button
                                  onClick={() => setDashboardTab('members')}
                                  className="text-[11px] text-[#D4AF37] font-bold hover:underline flex items-center gap-0.5"
                                >
                                  <span>عرض كل الأعضاء ({realMembers.length})</span>
                                  <ChevronLeft className="w-3 h-3" />
                                </button>
                              </div>

                              <div className="space-y-1.5">
                                {realMembers.slice(0, 3).map(m => (
                                  <div
                                    key={m.id}
                                    className={`p-2.5 rounded-xl border flex items-center justify-between text-xs transition ${
                                      isDark
                                        ? 'bg-[#0E1524] border-[#1E2B45] hover:border-[#2D3F65]'
                                        : 'bg-white border-slate-200 hover:border-slate-300 shadow-2xs'
                                    }`}
                                  >
                                    <div
                                      onClick={() => setSelectedMemberForDetails(m)}
                                      className="flex items-center gap-2.5 cursor-pointer flex-1"
                                    >
                                      <div className="w-8 h-8 rounded-xl bg-gradient-to-br from-[#D4AF37]/20 to-[#997C22]/10 border border-[#D4AF37]/30 text-[#D4AF37] flex items-center justify-center font-bold text-xs">
                                        {m.full_name ? m.full_name[0] : 'ع'}
                                      </div>
                                      <div>
                                        <div className="flex items-center gap-1.5">
                                          <span className={`font-bold ${isDark ? 'text-slate-100' : 'text-slate-900'}`}>{m.full_name}</span>
                                          <span className={`text-[9px] px-1.5 py-0.2 rounded-full font-bold ${
                                            m.is_active ? 'bg-emerald-500/15 text-emerald-400' : 'bg-rose-500/15 text-rose-400'
                                          }`}>
                                            {m.is_active ? 'نشط' : 'متوقف'}
                                          </span>
                                        </div>
                                        <div className={`text-[10px] ${isDark ? 'text-slate-400' : 'text-slate-500'}`}>
                                          {m.phone || 'بدون هاتف'} • انضمام: {m.join_date || 'اليوم'}
                                        </div>
                                      </div>
                                    </div>

                                    <div className="flex items-center gap-1">
                                      {m.phone && (
                                        <button
                                          onClick={() => openWhatsappChat(m.phone, m.full_name)}
                                          className="p-1.5 rounded-lg bg-emerald-500/15 text-emerald-400 hover:bg-emerald-500/25 transition btn-tactile"
                                          title="مراسلة عبر واتساب"
                                        >
                                          <MessageSquare className="w-3.5 h-3.5" />
                                        </button>
                                      )}
                                      <button
                                        onClick={() => setSelectedMemberForDetails(m)}
                                        className={`p-1.5 rounded-lg transition btn-tactile ${
                                          isDark ? 'bg-[#162032] hover:bg-[#1E2B45] text-slate-300' : 'bg-slate-100 hover:bg-slate-200 text-slate-700'
                                        }`}
                                        title="عرض التفاصيل"
                                      >
                                        <ChevronLeft className="w-3.5 h-3.5" />
                                      </button>
                                    </div>
                                  </div>
                                ))}
                              </div>
                            </div>

                            {/* 2.5 RECENT PAYMENTS PREVIEW */}
                            <div className="space-y-2 pt-1">
                              <div className="flex items-center justify-between px-1">
                                <span className={`text-xs font-bold ${isDark ? 'text-slate-200' : 'text-slate-800'}`}>أحدث عمليات التحصيل</span>
                                <button
                                  onClick={() => setDashboardTab('payments')}
                                  className="text-[11px] text-[#D4AF37] font-bold hover:underline flex items-center gap-0.5"
                                >
                                  <span>سجل المدفوعات ({realPayments.length})</span>
                                  <ChevronLeft className="w-3 h-3" />
                                </button>
                              </div>

                              <div className="space-y-1.5">
                                {realPayments.slice(0, 3).map(p => (
                                  <div
                                    key={p.id}
                                    className={`p-2.5 rounded-xl border flex items-center justify-between text-xs transition ${
                                      isDark
                                        ? 'bg-[#0E1524] border-[#1E2B45]'
                                        : 'bg-white border-slate-200 shadow-2xs'
                                    }`}
                                  >
                                    <div className="flex items-center gap-2">
                                      <div className="w-7 h-7 rounded-lg bg-emerald-500/15 text-emerald-400 flex items-center justify-center">
                                        <CreditCard className="w-3.5 h-3.5" />
                                      </div>
                                      <div>
                                        <div className={`font-bold ${isDark ? 'text-slate-200' : 'text-slate-900'}`}>
                                          {p.notes || 'سداد اشتراك جيم الديب'}
                                        </div>
                                        <div className={`text-[9px] ${isDark ? 'text-slate-400' : 'text-slate-500'}`}>
                                          {p.paid_at ? new Date(p.paid_at).toLocaleDateString('ar-EG') : 'اليوم'}
                                        </div>
                                      </div>
                                    </div>
                                    <div className="text-right">
                                      <div className="font-bold text-emerald-400 font-mono tabular-nums text-xs">
                                        +{p.amount} ج.م
                                      </div>
                                      <span className="text-[9px] px-1.5 py-0.2 rounded bg-emerald-500/10 text-emerald-400 font-bold">
                                        {p.payment_method === 'cash' ? 'كاش' : p.payment_method === 'vodafone_cash' ? 'فودافون كاش' : p.payment_method === 'instapay' ? 'إنستاباي' : 'فيزا'}
                                      </span>
                                    </div>
                                  </div>
                                ))}
                              </div>
                            </div>
                          </div>
                        )}

                      {/* SUB-VIEW 1: MEMBERS (REDESIGNED) */}
                      {dashboardTab === 'members' && (
                        <div className="space-y-3 animate-fadeIn">
                          {/* Search & Sticky Filters Header */}
                          <div className="space-y-2.5">
                            {/* Search Input with gold focus border */}
                            <div className="relative">
                              <Search className="w-4 h-4 text-slate-400 absolute right-3.5 top-3" />
                              <input
                                type="text"
                                placeholder="ابحث بالاسم أو رقم الهاتف..."
                                value={memberSearchQuery}
                                onChange={e => setMemberSearchQuery(e.target.value)}
                                className={`w-full border rounded-2xl pr-10 pl-8 py-2.5 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] transition shadow-2xs ${
                                  isDark
                                    ? 'bg-[#0E1524] border-[#1E2B45] text-slate-100 placeholder-slate-500'
                                    : 'bg-white border-slate-300 text-slate-900 placeholder-slate-400'
                                }`}
                              />
                              {memberSearchQuery && (
                                <button
                                  onClick={() => setMemberSearchQuery('')}
                                  className="absolute left-3 top-2.5 text-slate-400 hover:text-slate-200 text-xs w-5 h-5 flex items-center justify-center rounded-full bg-slate-700/50"
                                >
                                  ✕
                                </button>
                              )}
                            </div>

                            {/* Filter Chips / Segmented Control */}
                            <div className="flex items-center gap-1.5 overflow-x-auto pb-0.5 text-xs">
                              {[
                                { id: 'all', label: `الكل (${realMembers.length})` },
                                { id: 'active', label: `النشطون (${realMembers.filter(m => m.is_active).length})` },
                                { id: 'expiring', label: `تنتهي قريباً (${realMemberships.filter(m => {
                                  const diff = Math.ceil((new Date(m.end_date).getTime() - new Date().getTime()) / (1000 * 60 * 60 * 24));
                                  return diff >= 0 && diff <= 7;
                                }).length})` },
                                { id: 'inactive', label: `غير نشط (${realMembers.filter(m => !m.is_active).length})` },
                              ].map(f => (
                                <button
                                  key={f.id}
                                  onClick={() => setMemberFilter(f.id as any)}
                                  className={`px-3 py-1.5 rounded-xl font-bold transition whitespace-nowrap btn-tactile ${
                                    memberFilter === f.id
                                      ? 'bg-[#D4AF37] text-slate-950 shadow-md shadow-amber-500/20'
                                      : isDark
                                        ? 'bg-[#0E1524] text-slate-400 hover:text-slate-200 border border-[#1E2B45]'
                                        : 'bg-white text-slate-600 hover:text-slate-900 border border-slate-200'
                                  }`}
                                >
                                  {f.label}
                                </button>
                              ))}
                            </div>
                          </div>

                          {/* Members List */}
                          <div className="space-y-2.5 max-h-[420px] overflow-y-auto pr-0.5">
                            {(() => {
                              const displayed = realMembers.filter(m => {
                                const q = memberSearchQuery.toLowerCase();
                                const nameMatch = m.full_name?.toLowerCase().includes(q);
                                const phoneMatch = m.phone?.includes(q);
                                const matchesSearch = !q || nameMatch || phoneMatch;

                                if (memberFilter === 'active') return matchesSearch && m.is_active;
                                if (memberFilter === 'inactive') return matchesSearch && !m.is_active;
                                if (memberFilter === 'expiring') {
                                  const mem = realMemberships.find(x => x.member_id === m.id);
                                  if (!mem) return false;
                                  const diff = Math.ceil((new Date(mem.end_date).getTime() - new Date().getTime()) / (1000 * 60 * 60 * 24));
                                  return matchesSearch && diff >= 0 && diff <= 7;
                                }
                                return matchesSearch;
                              });

                              if (displayed.length === 0) {
                                return (
                                  <div className={`p-8 rounded-2xl border text-center space-y-3 ${
                                    isDark ? 'bg-[#0E1524]/70 border-[#1E2B45]' : 'bg-white border-slate-200 shadow-2xs'
                                  }`}>
                                    <div className="w-12 h-12 rounded-2xl bg-amber-500/10 text-[#D4AF37] flex items-center justify-center mx-auto">
                                      <Users className="w-6 h-6" />
                                    </div>
                                    <div>
                                      <h4 className={`font-bold text-xs ${isDark ? 'text-slate-200' : 'text-slate-800'}`}>
                                        {memberSearchQuery ? 'لا توجد نتائج مطابقة للبحث' : 'لا يوجد أعضاء مسجلين حتى الآن'}
                                      </h4>
                                      <p className={`text-[11px] mt-1 ${isDark ? 'text-slate-400' : 'text-slate-500'}`}>
                                        {memberSearchQuery ? 'جرب البحث باسم أو رقم هاتف آخر' : 'ابدأ بإضافة أول مشترك في صالة جيم الديب لتسجيل الاشتراكات'}
                                      </p>
                                    </div>
                                    <button
                                      onClick={() => {
                                        setModalMemberName('');
                                        setModalMemberPhone('');
                                        setModalMemberNotes('');
                                        setModalFeedback(null);
                                        setShowAddMemberModal(true);
                                      }}
                                      className="px-4 py-2 bg-[#D4AF37] hover:bg-[#E5C158] text-slate-950 font-bold text-xs rounded-xl transition shadow-md shadow-amber-500/20 btn-tactile"
                                    >
                                      + إضافة عضو جديد الآن
                                    </button>
                                  </div>
                                );
                              }

                              return displayed.map(m => {
                                const membership = realMemberships.find(x => x.member_id === m.id);
                                const plan = membership ? realPlans.find(p => p.id === membership.plan_id) : null;
                                const isExpiring = membership ? (() => {
                                  const diff = Math.ceil((new Date(membership.end_date).getTime() - new Date().getTime()) / (1000 * 60 * 60 * 24));
                                  return diff >= 0 && diff <= 7;
                                })() : false;

                                return (
                                  <div
                                    key={m.id}
                                    className={`p-3.5 rounded-2xl border transition-all space-y-2.5 ${
                                      isDark
                                        ? 'bg-[#0E1524] border-[#1E2B45] hover:border-[#2A3B5D]'
                                        : 'bg-white border-slate-200 hover:border-slate-300 shadow-2xs'
                                    }`}
                                  >
                                    {/* Member Card Top Row */}
                                    <div className="flex items-start justify-between">
                                      <div
                                        onClick={() => setSelectedMemberForDetails(m)}
                                        className="flex items-center gap-3 cursor-pointer flex-1"
                                      >
                                        <div className="w-10 h-10 rounded-2xl bg-gradient-to-br from-[#D4AF37]/25 to-[#997C22]/10 border border-[#D4AF37]/40 text-[#D4AF37] flex items-center justify-center font-black text-sm shadow-xs">
                                          {m.full_name ? m.full_name[0] : 'ع'}
                                        </div>
                                        <div>
                                          <div className="flex items-center gap-2">
                                            <span className={`font-bold text-xs ${isDark ? 'text-slate-100' : 'text-slate-900'}`}>{m.full_name}</span>
                                            <span className={`text-[9px] px-2 py-0.5 rounded-full font-bold flex items-center gap-1 ${
                                              m.is_active
                                                ? 'bg-emerald-500/15 text-emerald-400 border border-emerald-500/30'
                                                : 'bg-rose-500/15 text-rose-400 border border-rose-500/30'
                                            }`}>
                                              <span className={`w-1.5 h-1.5 rounded-full ${m.is_active ? 'bg-emerald-400' : 'bg-rose-400'}`} />
                                              <span>{m.is_active ? 'اشتراك نشط' : 'متوقف'}</span>
                                            </span>
                                          </div>
                                          <div className={`text-[10px] mt-0.5 ${isDark ? 'text-slate-400' : 'text-slate-500'}`}>
                                            {m.phone ? m.phone : 'بدون هاتف'} • انضمام: {m.join_date || 'اليوم'}
                                          </div>
                                        </div>
                                      </div>

                                      {/* Subscription Tag */}
                                      <div className="text-left">
                                        <span className={`text-[10px] px-2 py-0.5 rounded-lg font-bold ${
                                          isExpiring
                                            ? 'bg-amber-500/15 text-amber-300 border border-amber-500/30 animate-pulse'
                                            : plan
                                              ? 'bg-sky-500/15 text-sky-300 border border-sky-500/30'
                                              : isDark ? 'bg-slate-800 text-slate-400' : 'bg-slate-100 text-slate-600'
                                        }`}>
                                          {isExpiring ? '⚠️ ينتهي قريباً' : plan ? plan.name : 'بدون باقة'}
                                        </span>
                                      </div>
                                    </div>

                                    {/* Action Bar (Tactile Buttons) */}
                                    <div className={`pt-2 border-t flex items-center justify-between ${isDark ? 'border-[#1E2B45]' : 'border-slate-100'}`}>
                                      <div className="flex items-center gap-1.5">
                                        {m.phone && (
                                          <button
                                            onClick={() => openWhatsappChat(m.phone, m.full_name)}
                                            className="px-2.5 py-1.5 rounded-xl bg-emerald-500/15 hover:bg-emerald-500/25 text-emerald-400 text-[11px] font-bold flex items-center gap-1 border border-emerald-500/30 transition btn-tactile"
                                            title="مراسلة عبر واتساب"
                                          >
                                            <MessageSquare className="w-3.5 h-3.5" />
                                            <span>واتساب</span>
                                          </button>
                                        )}
                                        <button
                                          onClick={() => setSelectedMemberForDetails(m)}
                                          className={`px-2.5 py-1.5 rounded-xl text-[11px] font-bold flex items-center gap-1 border transition btn-tactile ${
                                            isDark ? 'bg-[#162032] hover:bg-[#1E2B45] text-slate-200 border-[#1E2B45]' : 'bg-slate-100 hover:bg-slate-200 text-slate-700 border-slate-200'
                                          }`}
                                        >
                                          <UserCheck className="w-3.5 h-3.5 text-[#D4AF37]" />
                                          <span>الملف</span>
                                        </button>
                                      </div>

                                      <div className="flex items-center gap-1">
                                        <button
                                          onClick={() => setEditingMember(m)}
                                          className={`p-1.5 rounded-xl transition btn-tactile ${
                                            isDark ? 'bg-[#162032] hover:bg-[#1E2B45] text-slate-300' : 'bg-slate-100 hover:bg-slate-200 text-slate-700'
                                          }`}
                                          title="تعديل بيانات العضو"
                                        >
                                          <Edit3 className="w-3.5 h-3.5 text-[#D4AF37]" />
                                        </button>
                                        <button
                                          onClick={() => handleDeleteMember(m.id, m.full_name)}
                                          className="p-1.5 rounded-xl hover:bg-rose-500/20 text-slate-400 hover:text-rose-400 transition btn-tactile"
                                          title="حذف العضو"
                                        >
                                          <Trash2 className="w-3.5 h-3.5" />
                                        </button>
                                      </div>
                                    </div>
                                  </div>
                                );
                              });
                            })()}
                          </div>

                          {/* Floating / Sticky Add Member Action */}
                          <div className="pt-2">
                            <button
                              onClick={() => {
                                setModalMemberName('');
                                setModalMemberPhone('');
                                setModalMemberNotes('');
                                setModalFeedback(null);
                                setShowAddMemberModal(true);
                              }}
                              className="w-full py-3 bg-[#D4AF37] hover:bg-[#E5C158] text-slate-950 font-bold text-xs rounded-2xl flex items-center justify-center gap-2 shadow-lg shadow-amber-500/20 transition btn-tactile"
                            >
                              <Plus className="w-4 h-4" />
                              <span>+ إضافة مشترك جديد في جيم الديب</span>
                            </button>
                          </div>
                        </div>
                      )}

                      {/* SUB-VIEW 2: PLANS */}
                      {dashboardTab === 'plans' && (
                        <div className="space-y-3">
                          <div className="flex items-center justify-between">
                            <span className={`text-xs font-bold ${isDark ? 'text-slate-200' : 'text-slate-800'}`}>باقات الاشتراك ({realPlans.length})</span>
                            <button
                              onClick={() => setShowAddPlanModal(true)}
                              className="px-3 py-1.5 bg-sky-500 hover:bg-sky-400 text-slate-950 font-bold text-xs rounded-xl flex items-center gap-1.5 shadow-md shadow-sky-500/20 transition btn-tactile"
                            >
                              <Plus className="w-3.5 h-3.5" />
                              <span>+ إضافة باقة جديدة</span>
                            </button>
                          </div>

                          <div className="space-y-1.5 max-h-[380px] overflow-y-auto">
                            {realPlans.length === 0 ? (
                              <div className={`text-xs text-center py-8 rounded-xl border ${
                                isDark ? 'bg-[#0F1626]/60 border-[#1E2B45] text-slate-400' : 'bg-white border-slate-200 text-slate-500 shadow-2xs'
                              }`}>
                                لا توجد باقات اشتراك مسجلة. اضغط أعلاه لإضافة أول باقة.
                              </div>
                            ) : (
                              realPlans.map(p => (
                                <div key={p.id} className={`p-3 rounded-xl border space-y-2 text-xs transition ${
                                  isDark ? 'bg-[#0F1626] border-[#1E2B45]' : 'bg-white border-slate-200 shadow-2xs'
                                }`}>
                                  <div className="flex items-center justify-between">
                                    <div>
                                      <div className={`font-bold text-sm ${isDark ? 'text-slate-100' : 'text-slate-900'}`}>{p.name}</div>
                                      <div className={`text-[10px] ${isDark ? 'text-slate-400' : 'text-slate-500'}`}>المدة: {p.duration_days} يوم</div>
                                    </div>
                                    <div className="text-right">
                                      <div className="font-bold text-[#D4AF37] text-sm font-mono tabular-nums">{p.price} ج.م</div>
                                      <span className={`text-[10px] px-1.5 py-0.5 rounded font-bold ${
                                        p.is_active ? 'bg-emerald-500/15 text-emerald-400 border border-emerald-500/30' : 'bg-rose-500/15 text-rose-400 border border-rose-500/30'
                                      }`}>
                                        {p.is_active ? 'مفعلة' : 'معطلة'}
                                      </span>
                                    </div>
                                  </div>

                                  <div className={`flex items-center justify-between pt-2 border-t ${isDark ? 'border-[#1E2B45]' : 'border-slate-100'}`}>
                                    <button
                                      type="button"
                                      onClick={() => handleTogglePlanActive(p)}
                                      className={`px-2 py-1 rounded-lg text-[10px] font-bold transition btn-tactile ${
                                        p.is_active
                                          ? isDark ? 'bg-[#162032] text-slate-300 hover:bg-[#1E2B45]' : 'bg-slate-100 text-slate-700 hover:bg-slate-200'
                                          : 'bg-emerald-500/20 text-emerald-400 hover:bg-emerald-500/30'
                                      }`}
                                    >
                                      {p.is_active ? 'تعطيل مؤقت' : 'تفعيل الباقة'}
                                    </button>

                                    <div className="flex items-center gap-1.5">
                                      <button
                                        type="button"
                                        onClick={() => setEditingPlan(p)}
                                        className={`px-2.5 py-1 rounded-lg text-xs font-bold flex items-center gap-1 transition btn-tactile ${
                                          isDark ? 'bg-[#162032] hover:bg-[#1E2B45] text-slate-200' : 'bg-slate-100 hover:bg-slate-200 text-slate-700'
                                        }`}
                                      >
                                        <Edit3 className="w-3 h-3 text-[#D4AF37]" />
                                        <span>تعديل</span>
                                      </button>
                                      <button
                                        type="button"
                                        onClick={() => handleDeletePlan(p.id, p.name)}
                                        className="px-2.5 py-1 bg-rose-500/15 hover:bg-rose-500/25 text-rose-400 rounded-lg text-xs font-bold flex items-center gap-1 transition btn-tactile"
                                      >
                                        <Trash2 className="w-3 h-3" />
                                        <span>حذف</span>
                                      </button>
                                    </div>
                                  </div>
                                </div>
                              ))
                            )}
                          </div>
                        </div>
                      )}

                      {/* SUB-VIEW 3: MEMBERSHIPS */}
                      {dashboardTab === 'memberships' && (
                        <div className="space-y-3">
                          <div className="flex items-center justify-between">
                            <span className={`text-xs font-bold ${isDark ? 'text-slate-200' : 'text-slate-800'}`}>الاشتراكات المسجلة ({realMemberships.length})</span>
                            <button
                              onClick={() => {
                                setMemMemberId(realMembers[0]?.id || '');
                                setMemPlanId(realPlans[0]?.id || '');
                                setShowAddMembershipModal(true);
                              }}
                              className="px-3 py-1.5 bg-[#D4AF37] hover:bg-[#E5C158] text-slate-950 font-bold text-xs rounded-xl flex items-center gap-1.5 shadow-md shadow-amber-500/20 transition btn-tactile"
                            >
                              <Plus className="w-3.5 h-3.5" />
                              <span>+ تسجيل اشتراك جديد</span>
                            </button>
                          </div>

                          <div className="space-y-2 max-h-[380px] overflow-y-auto">
                            {realMemberships.length === 0 ? (
                              <div className={`text-xs text-center py-8 rounded-xl border space-y-2 ${
                                isDark ? 'bg-[#0F1626]/60 border-[#1E2B45] text-slate-400' : 'bg-white border-slate-200 text-slate-500 shadow-2xs'
                              }`}>
                                <div>لا توجد اشتراكات مسجلة بعد.</div>
                                <button
                                  onClick={() => {
                                    setMemMemberId(realMembers[0]?.id || '');
                                    setMemPlanId(realPlans[0]?.id || '');
                                    setShowAddMembershipModal(true);
                                  }}
                                  className="text-[#D4AF37] font-bold hover:underline"
                                >
                                  تسجيل أول اشتراك الآن
                                </button>
                              </div>
                            ) : (
                              realMemberships.map(m => {
                                const member = realMembers.find(x => x.id === m.member_id);
                                const plan = realPlans.find(x => x.id === m.plan_id);
                                const isExpired = new Date(m.end_date) < new Date();

                                return (
                                  <div key={m.id} className={`p-3 rounded-xl border space-y-2 text-xs transition ${
                                    isDark ? 'bg-[#0F1626] border-[#1E2B45]' : 'bg-white border-slate-200 shadow-2xs'
                                  }`}>
                                    <div className="flex items-center justify-between">
                                      <div>
                                        <div className={`font-bold text-sm ${isDark ? 'text-slate-100' : 'text-slate-900'}`}>{member?.full_name || 'عضو جيم'}</div>
                                        <div className={`text-[10px] ${isDark ? 'text-slate-400' : 'text-slate-500'}`}>
                                          الباقة: {plan?.name || 'مخصصة'} • من {m.start_date} إلى {m.end_date}
                                        </div>
                                      </div>
                                      <div className="text-right">
                                        <div className="font-bold text-[#D4AF37] text-sm font-mono tabular-nums">{m.price} ج.م</div>
                                        <span className={`text-[9px] px-1.5 py-0.5 rounded font-bold ${
                                          isExpired ? 'bg-rose-500/15 text-rose-400' : 'bg-emerald-500/15 text-emerald-400'
                                        }`}>
                                          {isExpired ? 'منتهي' : 'ساري'}
                                        </span>
                                      </div>
                                    </div>

                                    <div className={`flex items-center justify-end gap-1.5 pt-2 border-t ${isDark ? 'border-[#1E2B45]' : 'border-slate-100'}`}>
                                      <button
                                        type="button"
                                        onClick={() => setEditingMembership(m)}
                                        className={`px-2.5 py-1 rounded-lg text-xs font-bold flex items-center gap-1 transition btn-tactile ${
                                          isDark ? 'bg-[#162032] hover:bg-[#1E2B45] text-slate-200' : 'bg-slate-100 hover:bg-slate-200 text-slate-700'
                                        }`}
                                      >
                                        <Edit3 className="w-3 h-3 text-[#D4AF37]" />
                                        <span>تعديل الاشتراك</span>
                                      </button>
                                      <button
                                        type="button"
                                        onClick={() => handleDeleteMembership(m.id)}
                                        className="px-2.5 py-1 bg-rose-500/15 hover:bg-rose-500/25 text-rose-400 rounded-lg text-xs font-bold flex items-center gap-1 transition btn-tactile"
                                      >
                                        <Trash2 className="w-3 h-3" />
                                        <span>إلغاء</span>
                                      </button>
                                    </div>
                                  </div>
                                );
                              })
                            )}
                          </div>
                        </div>
                      )}

                      {/* SUB-VIEW 4: PAYMENTS */}
                      {dashboardTab === 'payments' && (
                        <div className="space-y-3">
                          <div className="flex items-center justify-between">
                            <div>
                              <span className={`text-xs font-bold ${isDark ? 'text-slate-200' : 'text-slate-800'}`}>سجل الإيرادات والمدفوعات</span>
                              <div className="text-[10px] text-emerald-400 font-bold font-mono tabular-nums">
                                الإجمالي: {realPayments.reduce((acc, p) => acc + Number(p.amount || 0), 0)} ج.م
                              </div>
                            </div>
                            <button
                              onClick={() => setShowAddPaymentModal(true)}
                              className="px-3 py-1.5 bg-emerald-500 hover:bg-emerald-400 text-slate-950 font-bold text-xs rounded-xl flex items-center gap-1.5 shadow-md shadow-emerald-500/20 transition btn-tactile"
                            >
                              <Plus className="w-3.5 h-3.5" />
                              <span>+ تسجيل دفعة</span>
                            </button>
                          </div>

                          <div className="space-y-2 max-h-[360px] overflow-y-auto">
                            {realPayments.length === 0 ? (
                              <div className={`text-xs text-center py-8 rounded-xl border ${
                                isDark ? 'bg-[#0F1626]/60 border-[#1E2B45] text-slate-400' : 'bg-white border-slate-200 text-slate-500 shadow-2xs'
                              }`}>
                                لا توجد مدفوعات مسجلة بعد.
                              </div>
                            ) : (
                              realPayments.map(p => (
                                <div key={p.id} className={`p-3 rounded-xl border space-y-2 text-xs transition ${
                                  isDark ? 'bg-[#0F1626] border-[#1E2B45]' : 'bg-white border-slate-200 shadow-2xs'
                                }`}>
                                  <div className="flex items-center justify-between">
                                    <div>
                                      <div className="font-bold text-emerald-400 text-base font-mono tabular-nums">{p.amount} ج.م</div>
                                      <div className={`text-[10px] ${isDark ? 'text-slate-400' : 'text-slate-500'}`}>
                                        {p.notes || 'إيصال سداد نقدي'} • {p.paid_at ? new Date(p.paid_at).toLocaleDateString('ar-EG') : 'اليوم'}
                                      </div>
                                    </div>
                                    <div className="text-right">
                                      <span className="text-[10px] px-2 py-0.5 rounded-lg bg-emerald-500/10 text-emerald-400 font-bold border border-emerald-500/20">
                                        {p.payment_method === 'cash' ? 'كاش نقدي' : p.payment_method === 'vodafone_cash' ? 'فودافون كاش' : p.payment_method === 'instapay' ? 'إنستاباي' : 'بطاقة بنكية'}
                                      </span>
                                    </div>
                                  </div>

                                  <div className={`flex items-center justify-end gap-1.5 pt-2 border-t ${isDark ? 'border-[#1E2B45]' : 'border-slate-100'}`}>
                                    <button
                                      type="button"
                                      onClick={() => setEditingPayment(p)}
                                      className={`px-2.5 py-1 rounded-lg text-xs font-bold flex items-center gap-1 transition btn-tactile ${
                                        isDark ? 'bg-[#162032] hover:bg-[#1E2B45] text-slate-200' : 'bg-slate-100 hover:bg-slate-200 text-slate-700'
                                      }`}
                                    >
                                      <Edit3 className="w-3 h-3 text-[#D4AF37]" />
                                      <span>تعديل الإيصال</span>
                                    </button>
                                    <button
                                      type="button"
                                      onClick={() => handleDeletePayment(p.id, Number(p.amount))}
                                      className="px-2.5 py-1 bg-rose-500/15 hover:bg-rose-500/25 text-rose-400 rounded-lg text-xs font-bold flex items-center gap-1 transition btn-tactile"
                                    >
                                      <Trash2 className="w-3 h-3" />
                                      <span>حذف الدفعة</span>
                                    </button>
                                  </div>
                                </div>
                              ))
                            )}
                          </div>
                        </div>
                      )}

                      {/* SUB-VIEW 6: SETTINGS */}
                      {dashboardTab === 'settings' && (
                        <div className="space-y-3.5 max-h-[440px] overflow-y-auto pr-0.5">
                          {/* 1. GYM INFORMATION */}
                          <div className={`p-3.5 rounded-xl border space-y-2.5 transition ${
                            isDark ? 'bg-[#0F1626] border-[#1E2B45]' : 'bg-white border-slate-200 shadow-2xs'
                          }`}>
                            <div className={`flex items-center justify-between pb-2 border-b ${isDark ? 'border-[#1E2B45]' : 'border-slate-100'}`}>
                              <div className="flex items-center gap-2">
                                <Building2 className="w-4 h-4 text-[#D4AF37]" />
                                <h4 className={`font-bold text-xs ${isDark ? 'text-slate-100' : 'text-slate-900'}`}>بيانات الصالة الرياضية (Gym Information)</h4>
                              </div>
                              <button
                                type="button"
                                onClick={() => setEditingGymInfo({
                                  name: gym?.name || 'جيم الديب',
                                  phone: gym?.phone || '',
                                  currency: gym?.currency || 'EGP'
                                })}
                                className="px-2.5 py-1 bg-[#D4AF37] hover:bg-[#E5C158] text-slate-950 font-bold text-xs rounded-lg flex items-center gap-1 transition btn-tactile"
                              >
                                <Edit3 className="w-3 h-3" />
                                <span>تعديل بيانات الجيم</span>
                              </button>
                            </div>

                            <div className="space-y-1.5 text-xs">
                              <div className={`flex justify-between py-1 border-b ${isDark ? 'border-[#1E2B45]/60' : 'border-slate-100'}`}>
                                <span className={isDark ? 'text-slate-400' : 'text-slate-500'}>اسم الصالة (العربي):</span>
                                <span className={`font-bold ${isDark ? 'text-slate-200' : 'text-slate-900'}`}>{gym?.name || 'جيم الديب'}</span>
                              </div>
                              <div className={`flex justify-between py-1 border-b ${isDark ? 'border-[#1E2B45]/60' : 'border-slate-100'}`}>
                                <span className={isDark ? 'text-slate-400' : 'text-slate-500'}>اسم الصالة (English):</span>
                                <span className={`font-mono ${isDark ? 'text-slate-200' : 'text-slate-900'}`}>Gym ElDeeb</span>
                              </div>
                              <div className={`flex justify-between py-1 border-b ${isDark ? 'border-[#1E2B45]/60' : 'border-slate-100'}`}>
                                <span className={isDark ? 'text-slate-400' : 'text-slate-500'}>رقم هاتف الجيم:</span>
                                <span className={`font-mono ${isDark ? 'text-slate-200' : 'text-slate-900'}`}>{gym?.phone || 'غير مسجل'}</span>
                              </div>
                              <div className={`flex justify-between py-1 border-b ${isDark ? 'border-[#1E2B45]/60' : 'border-slate-100'}`}>
                                <span className={isDark ? 'text-slate-400' : 'text-slate-500'}>العملة المعتمدة:</span>
                                <span className="font-bold text-[#D4AF37]">{gym?.currency || 'EGP'}</span>
                              </div>
                              <div className="flex justify-between py-1">
                                <span className={isDark ? 'text-slate-400' : 'text-slate-500'}>معرف الجيم (gym_id):</span>
                                <span className="font-mono text-[10px] text-slate-500 truncate max-w-[150px]">{gym?.id || profile?.gym_id || 'غير متوفر'}</span>
                              </div>
                            </div>

                            {/* Database Schema Compliance Notice */}
                            <div className={`p-2 rounded-lg border text-[10px] space-y-1 ${
                              isDark ? 'bg-[#080C14] border-[#1E2B45] text-slate-400' : 'bg-slate-50 border-slate-200 text-slate-600'
                            }`}>
                              <div className="text-[#D4AF37] font-bold flex items-center gap-1">
                                <AlertCircle className="w-3 h-3" />
                                <span>تنبيه مخطط قاعدة البيانات (Database Schema):</span>
                              </div>
                              <p>
                                جدول <code className="text-[#D4AF37]">gyms</code> في قاعدة بيانات Supabase الحالية لا يحتوي على عمود للعنوان/الموقع الجغرافي. تم الالتزام بالمخطط الرسمي وعدم اختلاق أعمدة غير موجودة.
                              </p>
                              <p>
                                معرف الجيم (<code className="text-[#D4AF37]">gym_id</code>) ورتبة الحساب (<code className="text-[#D4AF37]">role</code>) محمية وغير قابلة للتعديل للحفاظ على عزل البيانات وقواعد RLS.
                              </p>
                            </div>
                          </div>

                          {/* 2. MY PROFILE */}
                          <div className={`p-3.5 rounded-xl border space-y-2.5 transition ${
                            isDark ? 'bg-[#0F1626] border-[#1E2B45]' : 'bg-white border-slate-200 shadow-2xs'
                          }`}>
                            <div className={`flex items-center justify-between pb-2 border-b ${isDark ? 'border-[#1E2B45]' : 'border-slate-100'}`}>
                              <div className="flex items-center gap-2">
                                <UserIcon className="w-4 h-4 text-emerald-400" />
                                <h4 className={`font-bold text-xs ${isDark ? 'text-slate-100' : 'text-slate-900'}`}>الملف الشخصي للكابتن (My Profile)</h4>
                              </div>
                              <button
                                type="button"
                                onClick={() => setEditingProfile({
                                  full_name: profile?.full_name || ''
                                })}
                                className={`px-2.5 py-1 font-bold text-xs rounded-lg flex items-center gap-1 transition btn-tactile ${
                                  isDark ? 'bg-[#162032] hover:bg-[#1E2B45] text-slate-200' : 'bg-slate-100 hover:bg-slate-200 text-slate-800'
                                }`}
                              >
                                <Edit3 className="w-3 h-3 text-emerald-400" />
                                <span>تعديل الاسم</span>
                              </button>
                            </div>

                            <div className="space-y-1.5 text-xs">
                              <div className={`flex justify-between py-1 border-b ${isDark ? 'border-[#1E2B45]/60' : 'border-slate-100'}`}>
                                <span className={isDark ? 'text-slate-400' : 'text-slate-500'}>الاسم الكامل:</span>
                                <span className={`font-bold ${isDark ? 'text-slate-200' : 'text-slate-900'}`}>{profile?.full_name || 'كابتن الصالة'}</span>
                              </div>
                              <div className={`flex justify-between py-1 border-b ${isDark ? 'border-[#1E2B45]/60' : 'border-slate-100'}`}>
                                <span className={isDark ? 'text-slate-400' : 'text-slate-500'}>البريد الإلكتروني:</span>
                                <span className={`font-mono ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>{currentUser?.email || session?.user?.email || 'غير متوفر'}</span>
                              </div>
                              <div className={`flex justify-between py-1 border-b ${isDark ? 'border-[#1E2B45]/60' : 'border-slate-100'} items-center`}>
                                <span className={isDark ? 'text-slate-400' : 'text-slate-500'}>الرتبة / الصلاحية:</span>
                                <span className="text-[10px] px-2 py-0.5 rounded bg-amber-500/10 text-amber-300 font-bold border border-amber-500/20 flex items-center gap-1">
                                  <Lock className="w-2.5 h-2.5" />
                                  <span>{profile?.role === 'owner' ? 'مالك الصالة الرياضية (Owner)' : 'مدرب معتمد (Coach)'}</span>
                                </span>
                              </div>
                              <div className="flex justify-between py-1 items-center">
                                <span className={isDark ? 'text-slate-400' : 'text-slate-500'}>معرف الحساب (User ID):</span>
                                <span className="font-mono text-[10px] text-slate-500 truncate max-w-[150px]">{profile?.id || currentUser?.id || 'غير متوفر'}</span>
                              </div>
                            </div>
                          </div>

                          {/* 3. APPEARANCE & LANGUAGE */}
                          <div className={`p-3.5 rounded-xl border space-y-2.5 transition ${
                            isDark ? 'bg-[#0F1626] border-[#1E2B45]' : 'bg-white border-slate-200 shadow-2xs'
                          }`}>
                            <div className={`flex items-center gap-2 pb-2 border-b ${isDark ? 'border-[#1E2B45]' : 'border-slate-100'}`}>
                              <Globe className="w-4 h-4 text-sky-400" />
                              <h4 className={`font-bold text-xs ${isDark ? 'text-slate-100' : 'text-slate-900'}`}>المظهر واللغة (Appearance & Language)</h4>
                            </div>

                            <div className="space-y-2 text-xs">
                              <div className={`flex items-center justify-between p-2 rounded-lg border ${
                                isDark ? 'bg-[#080C14] border-[#1E2B45]' : 'bg-slate-50 border-slate-200'
                              }`}>
                                <div className="flex items-center gap-2">
                                  <Moon className="w-3.5 h-3.5 text-[#D4AF37]" />
                                  <span className={isDark ? 'text-slate-300' : 'text-slate-700'}>مظهر التطبيق:</span>
                                </div>
                                <button
                                  type="button"
                                  onClick={() => {
                                    const nextTheme = appTheme === 'dark' ? 'light' : 'dark';
                                    setAppTheme(nextTheme);
                                    setGlobalToast({ type: 'success', message: `تم تفعيل المظهر: ${nextTheme === 'dark' ? 'الداكن الذهبي (جيم الديب)' : 'الفاتح'}` });
                                    setTimeout(() => setGlobalToast(null), 3000);
                                  }}
                                  className={`px-2.5 py-1 font-bold text-xs rounded-lg transition btn-tactile ${
                                    isDark ? 'bg-[#162032] hover:bg-[#1E2B45] text-[#D4AF37]' : 'bg-white border border-slate-300 text-slate-800'
                                  }`}
                                >
                                  {appTheme === 'dark' ? 'الداكن الذهبي (نشط)' : 'الوضع الفاتح'}
                                </button>
                              </div>

                              <div className={`flex items-center justify-between p-2 rounded-lg border ${
                                isDark ? 'bg-[#080C14] border-[#1E2B45]' : 'bg-slate-50 border-slate-200'
                              }`}>
                                <div className="flex items-center gap-2">
                                  <Globe className="w-3.5 h-3.5 text-sky-400" />
                                  <span className={isDark ? 'text-slate-300' : 'text-slate-700'}>لغة واجهة التطبيق:</span>
                                </div>
                                <button
                                  type="button"
                                  onClick={() => {
                                    const nextLang = appLanguage === 'ar' ? 'en' : 'ar';
                                    setAppLanguage(nextLang);
                                    setGlobalToast({ type: 'success', message: `اللغة الحالية: ${nextLang === 'ar' ? 'العربية (جيم الديب)' : 'English (Gym ElDeeb)'}` });
                                    setTimeout(() => setGlobalToast(null), 3000);
                                  }}
                                  className={`px-2.5 py-1 font-bold text-xs rounded-lg transition btn-tactile ${
                                    isDark ? 'bg-[#162032] hover:bg-[#1E2B45] text-sky-300' : 'bg-white border border-slate-300 text-slate-800'
                                  }`}
                                >
                                  {appLanguage === 'ar' ? 'العربية (مفعلة)' : 'English (Active)'}
                                </button>
                              </div>
                            </div>
                          </div>

                          {/* 4. SYNC STATUS */}
                          <div className={`p-3.5 rounded-xl border space-y-2.5 transition ${
                            isDark ? 'bg-[#0F1626] border-[#1E2B45]' : 'bg-white border-slate-200 shadow-2xs'
                          }`}>
                            <div className={`flex items-center justify-between pb-2 border-b ${isDark ? 'border-[#1E2B45]' : 'border-slate-100'}`}>
                              <div className="flex items-center gap-2">
                                <RefreshCw className="w-4 h-4 text-emerald-400" />
                                <h4 className={`font-bold text-xs ${isDark ? 'text-slate-100' : 'text-slate-900'}`}>حالة المزامنة والربط السحابي</h4>
                              </div>
                              <button
                                type="button"
                                onClick={triggerManualSync}
                                className="px-2.5 py-1 bg-emerald-500/20 hover:bg-emerald-500/30 text-emerald-400 border border-emerald-500/40 font-bold text-xs rounded-lg flex items-center gap-1 transition btn-tactile"
                              >
                                <RefreshCw className="w-3 h-3" />
                                <span>مزامنة فورية الآن</span>
                              </button>
                            </div>

                            <div className="space-y-1.5 text-xs">
                              <div className={`flex justify-between py-1 border-b ${isDark ? 'border-[#1E2B45]/60' : 'border-slate-100'} items-center`}>
                                <span className={isDark ? 'text-slate-400' : 'text-slate-500'}>حالة الاتصال بالإنترنت:</span>
                                <span className={`text-[10px] px-2 py-0.5 rounded-full font-bold ${
                                  isOnline ? 'bg-emerald-500/15 text-emerald-400 border border-emerald-500/30' : 'bg-rose-500/15 text-rose-400 border border-rose-500/30'
                                }`}>
                                  {isOnline ? 'متصل بالشبكة (Online)' : 'غير متصل (Offline Cache Active)'}
                                </span>
                              </div>
                              <div className={`flex justify-between py-1 border-b ${isDark ? 'border-[#1E2B45]/60' : 'border-slate-100'}`}>
                                <span className={isDark ? 'text-slate-400' : 'text-slate-500'}>الجداول المتزامنة:</span>
                                <span className={`font-mono text-[11px] ${isDark ? 'text-slate-200' : 'text-slate-800'}`}>members, plans, memberships, payments</span>
                              </div>
                              <div className="flex justify-between py-1">
                                <span className={isDark ? 'text-slate-400' : 'text-slate-500'}>قواعد أمان RLS:</span>
                                <span className="text-emerald-400 font-bold text-[11px]">مفعلة وصارمة لكل استعلام</span>
                              </div>
                            </div>
                          </div>

                          {/* 5. LOGOUT ACTION */}
                          <div className="pt-1">
                            <button
                              type="button"
                              onClick={() => setShowLogoutConfirm(true)}
                              className="w-full py-2.5 bg-rose-500/15 hover:bg-rose-500/25 text-rose-400 border border-rose-500/30 font-bold text-xs rounded-xl flex items-center justify-center gap-2 transition btn-tactile"
                            >
                              <LogOut className="w-4 h-4" />
                              <span>تسجيل خروج آمن من الجلسة</span>
                            </button>
                          </div>
                        </div>
                      )}

                      </div>

                      {/* 3. FIXED BOTTOM NAVIGATION DOCK (Thumb Ergonomics) */}
                      <div className={`sticky bottom-0 z-40 border-t px-2 py-2 backdrop-blur-xl transition-colors ${
                        isDark ? 'bg-[#0A0F1A]/95 border-[#1A253A]' : 'bg-white/95 border-slate-200 shadow-lg'
                      }`}>
                        <div className="grid grid-cols-5 gap-1 items-center">
                          {[
                            { id: 'overview', label: 'الرئيسية', icon: LayoutDashboard },
                            { id: 'members', label: 'الأعضاء', icon: Users, badge: realMembers.filter(m => m.is_active).length },
                            { id: 'plans', label: 'الباقات', icon: Dumbbell },
                            { id: 'payments', label: 'المالية', icon: CreditCard },
                            { id: 'settings', label: 'الإعدادات', icon: Settings },
                          ].map(t => {
                            const IconComponent = t.icon;
                            const isSelected = dashboardTab === t.id;

                            return (
                              <button
                                key={t.id}
                                onClick={() => setDashboardTab(t.id as any)}
                                className={`flex flex-col items-center justify-center py-1.5 px-1 rounded-xl transition relative btn-tactile ${
                                  isSelected
                                    ? isDark ? 'text-[#D4AF37] font-black' : 'text-slate-950 font-black'
                                    : isDark ? 'text-slate-400 hover:text-slate-200' : 'text-slate-500 hover:text-slate-800'
                                }`}
                              >
                                {isSelected && (
                                  <div className="absolute inset-0 bg-[#D4AF37]/15 rounded-xl border border-[#D4AF37]/30 pointer-events-none" />
                                )}
                                <div className="relative">
                                  <IconComponent className={`w-5 h-5 transition-transform ${isSelected ? 'scale-110 text-[#D4AF37]' : ''}`} />
                                  {t.badge !== undefined && t.badge > 0 && (
                                    <span className="absolute -top-1.5 -left-2 text-[8px] font-bold px-1 rounded-full bg-emerald-500 text-slate-950 font-mono">
                                      {t.badge}
                                    </span>
                                  )}
                                </div>
                                <span className={`text-[10px] mt-1 truncate max-w-full ${isSelected ? 'text-[#D4AF37] font-bold' : ''}`}>
                                  {t.label}
                                </span>
                              </button>
                            );
                          })}
                        </div>
                      </div>
                    </div>
                  )}

                  {/* ========================================================= */}
                  {/* --- REAL INTERACTIVE MODALS (PHONE SIMULATOR) --- */}
                  {/* ========================================================= */}

                  {/* GLOBAL TOAST NOTIFICATION */}
                  {globalToast && (
                    <div className="absolute top-4 left-4 right-4 z-50 bg-emerald-500 text-slate-950 px-3.5 py-2.5 rounded-xl font-bold text-xs shadow-2xl flex items-center justify-between border border-emerald-400 animate-slideDown">
                      <div className="flex items-center gap-2">
                        <CheckCircle className="w-4 h-4" />
                        <span>{globalToast.message}</span>
                      </div>
                      <button onClick={() => setGlobalToast(null)} className="text-slate-950/70 hover:text-slate-950">
                        ✕
                      </button>
                    </div>
                  )}

                  {/* 1. ADD MEMBER MODAL */}
                  {showAddMemberModal && (
                    <div className="absolute inset-0 bg-slate-950/85 backdrop-blur-sm z-50 flex items-center justify-center p-3 animate-fadeIn">
                      <div className={`border rounded-2xl w-full max-w-sm p-4 space-y-3 shadow-2xl transition ${
                        isDark ? 'bg-[#0F1626] border-[#1E2B45]' : 'bg-white border-slate-200 shadow-xl'
                      }`}>
                        <div className={`flex items-center justify-between pb-2 border-b ${isDark ? 'border-[#1E2B45]' : 'border-slate-100'}`}>
                          <div className="flex items-center gap-2">
                            <div className="w-7 h-7 rounded-lg bg-[#D4AF37]/20 text-[#D4AF37] flex items-center justify-center font-bold">
                              <Users className="w-4 h-4" />
                            </div>
                            <h4 className={`font-bold text-xs ${isDark ? 'text-slate-100' : 'text-slate-900'}`}>إضافة عضو جديد في جيم الديب</h4>
                          </div>
                          <button
                            onClick={() => {
                              setShowAddMemberModal(false);
                              setModalFeedback(null);
                            }}
                            className={`p-1 rounded-lg transition ${
                              isDark ? 'hover:bg-[#162032] text-slate-400 hover:text-slate-200' : 'hover:bg-slate-100 text-slate-500 hover:text-slate-800'
                            }`}
                          >
                            <X className="w-4 h-4" />
                          </button>
                        </div>

                        {modalFeedback && (
                          <div className={`p-2 rounded-xl text-xs font-bold ${
                            modalFeedback.type === 'error' ? 'bg-rose-500/15 border border-rose-500/30 text-rose-400' : 'bg-emerald-500/15 border border-emerald-500/30 text-emerald-400'
                          }`}>
                            {modalFeedback.message}
                          </div>
                        )}

                        <form onSubmit={handleSaveMember} className="space-y-2.5">
                          <div>
                            <label className={`block text-[11px] font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>الاسم الكامل *</label>
                            <input
                              type="text"
                              required
                              placeholder="مثال: كابتن أحمد حسن"
                              value={modalMemberName}
                              onChange={e => setModalMemberName(e.target.value)}
                              className={`w-full border rounded-xl px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] transition ${
                                isDark ? 'bg-[#080C14] border-[#1E2B45] text-slate-100 placeholder-slate-500' : 'bg-slate-50 border-slate-300 text-slate-900 placeholder-slate-400'
                              }`}
                            />
                          </div>

                          <div>
                            <label className={`block text-[11px] font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>رقم الهاتف (مصر)</label>
                            <input
                              type="tel"
                              placeholder="01012345678 أو 011xxxxxxxx"
                              value={modalMemberPhone}
                              onChange={e => setModalMemberPhone(e.target.value)}
                              className={`w-full border rounded-xl px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] font-mono transition ${
                                isDark ? 'bg-[#080C14] border-[#1E2B45] text-slate-100 placeholder-slate-500' : 'bg-slate-50 border-slate-300 text-slate-900 placeholder-slate-400'
                              }`}
                            />
                          </div>

                          <div>
                            <label className={`block text-[11px] font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>تاريخ الانضمام</label>
                            <input
                              type="date"
                              value={modalMemberJoinDate}
                              onChange={e => setModalMemberJoinDate(e.target.value)}
                              className={`w-full border rounded-xl px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] transition ${
                                isDark ? 'bg-[#080C14] border-[#1E2B45] text-slate-100' : 'bg-slate-50 border-slate-300 text-slate-900'
                              }`}
                            />
                          </div>

                          <div>
                            <label className={`block text-[11px] font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>ملاحظات الكابتن</label>
                            <textarea
                              rows={2}
                              placeholder="حالة بدنية، هدف التدريب، جهة اتصال..."
                              value={modalMemberNotes}
                              onChange={e => setModalMemberNotes(e.target.value)}
                              className={`w-full border rounded-xl px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] transition ${
                                isDark ? 'bg-[#080C14] border-[#1E2B45] text-slate-100 placeholder-slate-500' : 'bg-slate-50 border-slate-300 text-slate-900 placeholder-slate-400'
                              }`}
                            />
                          </div>

                          <div className={`flex gap-2 pt-2 border-t ${isDark ? 'border-[#1E2B45]' : 'border-slate-100'}`}>
                            <button
                              type="button"
                              onClick={() => {
                                setShowAddMemberModal(false);
                                setModalFeedback(null);
                              }}
                              disabled={isModalSaving}
                              className={`w-1/3 py-2 rounded-xl font-bold text-xs transition btn-tactile ${
                                isDark ? 'bg-[#162032] hover:bg-[#1E2B45] text-slate-300' : 'bg-slate-100 hover:bg-slate-200 text-slate-700'
                              }`}
                            >
                              إلغاء
                            </button>
                            <button
                              type="submit"
                              disabled={isModalSaving || !modalMemberName.trim()}
                              className="w-2/3 py-2 bg-[#D4AF37] hover:bg-[#E5C158] text-slate-950 font-bold text-xs rounded-xl flex items-center justify-center gap-1.5 shadow-md shadow-amber-500/20 disabled:opacity-50 transition btn-tactile"
                            >
                              {isModalSaving ? (
                                <RefreshCw className="w-3.5 h-3.5 animate-spin" />
                              ) : (
                                <>
                                  <Check className="w-3.5 h-3.5" />
                                  <span>حفظ العضو الآن</span>
                                </>
                              )}
                            </button>
                          </div>
                        </form>
                      </div>
                    </div>
                  )}

                  {/* 2. EDIT MEMBER MODAL */}
                  {editingMember && (
                    <div className="absolute inset-0 bg-slate-950/85 backdrop-blur-sm z-50 flex items-center justify-center p-3 animate-fadeIn">
                      <div className={`border rounded-2xl w-full max-w-sm p-4 space-y-3 shadow-2xl transition ${
                        isDark ? 'bg-[#0F1626] border-[#1E2B45]' : 'bg-white border-slate-200 shadow-xl'
                      }`}>
                        <div className={`flex items-center justify-between pb-2 border-b ${isDark ? 'border-[#1E2B45]' : 'border-slate-100'}`}>
                          <h4 className={`font-bold text-xs ${isDark ? 'text-slate-100' : 'text-slate-900'}`}>تعديل بيانات: {editingMember.full_name}</h4>
                          <button
                            onClick={() => setEditingMember(null)}
                            className={`p-1 rounded-lg transition ${
                              isDark ? 'hover:bg-[#162032] text-slate-400 hover:text-slate-200' : 'hover:bg-slate-100 text-slate-500 hover:text-slate-800'
                            }`}
                          >
                            <X className="w-4 h-4" />
                          </button>
                        </div>

                        <div className="space-y-2.5">
                          <div>
                            <label className={`block text-[11px] font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>الاسم الكامل</label>
                            <input
                              type="text"
                              value={editingMember.full_name}
                              onChange={e => setEditingMember({ ...editingMember, full_name: e.target.value })}
                              className={`w-full border rounded-xl px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] transition ${
                                isDark ? 'bg-[#080C14] border-[#1E2B45] text-slate-100' : 'bg-slate-50 border-slate-300 text-slate-900'
                              }`}
                            />
                          </div>

                          <div>
                            <label className={`block text-[11px] font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>رقم الهاتف</label>
                            <input
                              type="tel"
                              value={editingMember.phone || ''}
                              onChange={e => setEditingMember({ ...editingMember, phone: e.target.value })}
                              className={`w-full border rounded-xl px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] font-mono transition ${
                                isDark ? 'bg-[#080C14] border-[#1E2B45] text-slate-100' : 'bg-slate-50 border-slate-300 text-slate-900'
                              }`}
                            />
                          </div>

                          <div>
                            <label className={`block text-[11px] font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>تاريخ الانضمام</label>
                            <input
                              type="date"
                              value={editingMember.join_date ? editingMember.join_date.substring(0, 10) : ''}
                              onChange={e => setEditingMember({ ...editingMember, join_date: e.target.value })}
                              className={`w-full border rounded-xl px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] transition ${
                                isDark ? 'bg-[#080C14] border-[#1E2B45] text-slate-100' : 'bg-slate-50 border-slate-300 text-slate-900'
                              }`}
                            />
                          </div>

                          <div>
                            <label className={`block text-[11px] font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>ملاحظات</label>
                            <textarea
                              rows={2}
                              value={editingMember.notes || ''}
                              onChange={e => setEditingMember({ ...editingMember, notes: e.target.value })}
                              className={`w-full border rounded-xl px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] transition ${
                                isDark ? 'bg-[#080C14] border-[#1E2B45] text-slate-100' : 'bg-slate-50 border-slate-300 text-slate-900'
                              }`}
                            />
                          </div>

                          <div className={`flex items-center justify-between p-2 rounded-xl border text-xs ${
                            isDark ? 'bg-[#080C14] border-[#1E2B45]' : 'bg-slate-50 border-slate-200'
                          }`}>
                            <span className={isDark ? 'text-slate-300' : 'text-slate-700'}>حالة العضو الرياضية:</span>
                            <button
                              type="button"
                              onClick={() => setEditingMember({ ...editingMember, is_active: !editingMember.is_active })}
                              className={`px-3 py-1 rounded-lg font-bold transition btn-tactile ${
                                editingMember.is_active
                                  ? 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/40'
                                  : 'bg-rose-500/20 text-rose-400 border border-rose-500/40'
                              }`}
                            >
                              {editingMember.is_active ? 'نشط ومفعل' : 'متوقف / مجمد'}
                            </button>
                          </div>

                          <div className={`flex gap-2 pt-2 border-t ${isDark ? 'border-[#1E2B45]' : 'border-slate-100'}`}>
                            <button
                              type="button"
                              onClick={() => setEditingMember(null)}
                              className={`w-1/3 py-2 rounded-xl font-bold text-xs transition btn-tactile ${
                                isDark ? 'bg-[#162032] hover:bg-[#1E2B45] text-slate-300' : 'bg-slate-100 hover:bg-slate-200 text-slate-700'
                              }`}
                            >
                              إلغاء
                            </button>
                            <button
                              type="button"
                              onClick={handleSaveEditedMember}
                              disabled={isModalSaving || !editingMember.full_name?.trim()}
                              className="w-2/3 py-2 bg-[#D4AF37] hover:bg-[#E5C158] text-slate-950 font-bold text-xs rounded-xl transition btn-tactile"
                            >
                              حفظ التعديلات
                            </button>
                          </div>
                        </div>
                      </div>
                    </div>
                  )}

                  {/* 3. MEMBER DETAILS BOTTOM SHEET (LUXURY PROFILE EXPERIENCE) */}
                  {selectedMemberForDetails && (
                    <div className="absolute inset-0 bg-slate-950/85 backdrop-blur-sm z-50 flex items-end justify-center animate-fadeIn">
                      <div className={`border-t border-x rounded-t-3xl w-full p-4.5 space-y-4 shadow-2xl max-h-[90%] overflow-y-auto transition ${
                        isDark ? 'bg-[#0D1424] border-[#1F2E4A]' : 'bg-white border-slate-200'
                      }`}>
                        {/* Drag Handle Bar */}
                        <div className={`w-12 h-1.5 rounded-full mx-auto ${isDark ? 'bg-slate-700' : 'bg-slate-300'}`} />

                        {/* Profile Hero Header */}
                        <div className="flex items-center justify-between pb-3 border-b border-slate-800">
                          <div className="flex items-center gap-3">
                            <div className="w-14 h-14 rounded-2xl bg-gradient-to-br from-[#D4AF37] to-[#8C6D18] p-[2px] shadow-lg shadow-amber-500/20">
                              <div className={`w-full h-full rounded-[14px] flex items-center justify-center font-black text-xl ${
                                isDark ? 'bg-[#080C14] text-[#D4AF37]' : 'bg-slate-900 text-white'
                              }`}>
                                {selectedMemberForDetails.full_name ? selectedMemberForDetails.full_name[0] : 'ع'}
                              </div>
                            </div>
                            <div>
                              <div className="flex items-center gap-2">
                                <h3 className={`font-black text-base ${isDark ? 'text-slate-100' : 'text-slate-900'}`}>
                                  {selectedMemberForDetails.full_name}
                                </h3>
                                <span className={`text-[10px] px-2 py-0.5 rounded-full font-bold flex items-center gap-1 ${
                                  selectedMemberForDetails.is_active
                                    ? 'bg-emerald-500/15 text-emerald-400 border border-emerald-500/30'
                                    : 'bg-rose-500/15 text-rose-400 border border-rose-500/30'
                                }`}>
                                  <span className={`w-1.5 h-1.5 rounded-full ${selectedMemberForDetails.is_active ? 'bg-emerald-400' : 'bg-rose-400'}`} />
                                  <span>{selectedMemberForDetails.is_active ? 'مشترك نشط' : 'متوقف'}</span>
                                </span>
                              </div>
                              <p className={`text-xs mt-0.5 ${isDark ? 'text-slate-400' : 'text-slate-500'}`}>
                                عضو منذ: {selectedMemberForDetails.join_date || 'اليوم'}
                              </p>
                            </div>
                          </div>

                          <button
                            onClick={() => setSelectedMemberForDetails(null)}
                            className={`p-1.5 rounded-xl transition ${
                              isDark ? 'hover:bg-[#162032] text-slate-400 hover:text-white' : 'hover:bg-slate-100 text-slate-500 hover:text-slate-900'
                            }`}
                          >
                            <X className="w-5 h-5" />
                          </button>
                        </div>

                        {/* Direct Contact CTAs */}
                        {selectedMemberForDetails.phone && (
                          <div className="grid grid-cols-2 gap-2">
                            <button
                              onClick={() => openWhatsappChat(selectedMemberForDetails.phone, selectedMemberForDetails.full_name)}
                              className="py-2.5 px-3 bg-[#25D366] hover:bg-[#20bd5a] text-slate-950 font-bold text-xs rounded-xl flex items-center justify-center gap-1.5 shadow-md shadow-emerald-500/20 transition btn-tactile"
                            >
                              <MessageSquare className="w-4 h-4" />
                              <span>واتساب فوري</span>
                            </button>
                            <a
                              href={`tel:${selectedMemberForDetails.phone}`}
                              className={`py-2.5 px-3 rounded-xl font-bold text-xs flex items-center justify-center gap-1.5 border transition btn-tactile ${
                                isDark ? 'bg-[#151F33] hover:bg-[#1E2B45] text-slate-200 border-[#1E2B45]' : 'bg-slate-100 hover:bg-slate-200 text-slate-800 border-slate-200'
                              }`}
                            >
                              <Phone className="w-4 h-4 text-sky-400" />
                              <span>اتصال هاتفي</span>
                            </a>
                          </div>
                        )}

                        {/* Subscriptions & Plan Breakdown */}
                        <div className="space-y-2">
                          <div className="flex items-center justify-between">
                            <span className={`text-xs font-bold ${isDark ? 'text-slate-200' : 'text-slate-800'}`}>تفاصيل باقة الاشتراك</span>
                            <button
                              onClick={() => {
                                setMemMemberId(selectedMemberForDetails.id);
                                setMemPlanId(realPlans[0]?.id || '');
                                setSelectedMemberForDetails(null);
                                setShowAddMembershipModal(true);
                              }}
                              className="text-xs text-[#D4AF37] font-bold hover:underline"
                            >
                              + تجديد / تمديد الاشتراك
                            </button>
                          </div>

                          {realMemberships.filter(m => m.member_id === selectedMemberForDetails.id).length === 0 ? (
                            <div className={`p-4 rounded-xl border text-center text-xs space-y-1 ${
                              isDark ? 'bg-[#080C14] border-[#1E2B45] text-slate-400' : 'bg-slate-50 border-slate-200 text-slate-500'
                            }`}>
                              <div>لا يوجد اشتراك ساري مسجل لهذا العضو.</div>
                              <button
                                onClick={() => {
                                  setMemMemberId(selectedMemberForDetails.id);
                                  setMemPlanId(realPlans[0]?.id || '');
                                  setSelectedMemberForDetails(null);
                                  setShowAddMembershipModal(true);
                                }}
                                className="text-xs text-[#D4AF37] font-bold underline"
                              >
                                اضغط هنا لربط العضو بباقة فوراً
                              </button>
                            </div>
                          ) : (
                            realMemberships.filter(m => m.member_id === selectedMemberForDetails.id).map(mem => {
                              const plan = realPlans.find(p => p.id === mem.plan_id);
                              const isExpired = new Date(mem.end_date) < new Date();
                              const daysLeft = Math.ceil((new Date(mem.end_date).getTime() - new Date().getTime()) / (1000 * 60 * 60 * 24));

                              return (
                                <div
                                  key={mem.id}
                                  className={`p-3.5 rounded-2xl border space-y-2 ${
                                    isDark ? 'bg-[#080C14] border-[#1E2B45]' : 'bg-slate-50 border-slate-200'
                                  }`}
                                >
                                  <div className="flex items-center justify-between">
                                    <div>
                                      <div className={`font-bold text-sm ${isDark ? 'text-slate-100' : 'text-slate-900'}`}>
                                        {plan?.name || 'اشتراك مخصص'}
                                      </div>
                                      <div className={`text-[10px] ${isDark ? 'text-slate-400' : 'text-slate-500'}`}>
                                        من: {mem.start_date} • إلى: {mem.end_date}
                                      </div>
                                    </div>
                                    <div className="text-right">
                                      <div className="font-bold text-[#D4AF37] font-mono tabular-nums text-sm">
                                        {mem.price} ج.م
                                      </div>
                                      <span className={`text-[9px] px-2 py-0.5 rounded-full font-bold ${
                                        isExpired
                                          ? 'bg-rose-500/15 text-rose-400'
                                          : daysLeft <= 7
                                            ? 'bg-amber-500/15 text-amber-300 animate-pulse'
                                            : 'bg-emerald-500/15 text-emerald-400'
                                      }`}>
                                        {isExpired ? 'منتهي الصلاحية' : `${daysLeft} يوم متبقي`}
                                      </span>
                                    </div>
                                  </div>
                                </div>
                              );
                            })
                          )}
                        </div>

                        {/* Action Buttons */}
                        <div className={`grid grid-cols-2 gap-2 pt-2 border-t ${isDark ? 'border-[#1E2B45]' : 'border-slate-100'}`}>
                          <button
                            onClick={() => {
                              setEditingMember(selectedMemberForDetails);
                              setSelectedMemberForDetails(null);
                            }}
                            className={`py-2.5 rounded-xl font-bold text-xs transition flex items-center justify-center gap-1.5 btn-tactile ${
                              isDark ? 'bg-[#162032] hover:bg-[#1E2B45] text-slate-200' : 'bg-slate-100 hover:bg-slate-200 text-slate-800'
                            }`}
                          >
                            <Edit3 className="w-4 h-4 text-[#D4AF37]" />
                            <span>تعديل بيانات العضو</span>
                          </button>
                          <button
                            onClick={() => handleDeleteMember(selectedMemberForDetails.id, selectedMemberForDetails.full_name)}
                            className="py-2.5 bg-rose-500/15 hover:bg-rose-500/25 text-rose-400 border border-rose-500/30 rounded-xl font-bold text-xs transition flex items-center justify-center gap-1.5 btn-tactile"
                          >
                            <Trash2 className="w-4 h-4" />
                            <span>حذف العضو</span>
                          </button>
                        </div>
                      </div>
                    </div>
                  )}

                  {/* 4. ADD PLAN MODAL */}
                  {showAddPlanModal && (
                    <div className="absolute inset-0 bg-slate-950/85 backdrop-blur-sm z-50 flex items-center justify-center p-3 animate-fadeIn">
                      <div className={`border rounded-2xl w-full max-w-sm p-4 space-y-3 shadow-2xl transition ${
                        isDark ? 'bg-[#0F1626] border-[#1E2B45]' : 'bg-white border-slate-200 shadow-xl'
                      }`}>
                        <div className={`flex items-center justify-between pb-2 border-b ${isDark ? 'border-[#1E2B45]' : 'border-slate-100'}`}>
                          <h4 className={`font-bold text-xs ${isDark ? 'text-slate-100' : 'text-slate-900'}`}>إضافة باقة اشتراك جديدة</h4>
                          <button onClick={() => setShowAddPlanModal(false)} className={`p-1 transition ${isDark ? 'text-slate-400 hover:text-slate-200' : 'text-slate-500 hover:text-slate-800'}`}>
                            <X className="w-4 h-4" />
                          </button>
                        </div>

                        <div className="space-y-2.5">
                          <div>
                            <label className={`block text-[11px] font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>اسم الباقة *</label>
                            <input
                              type="text"
                              placeholder="مثال: باقة شهري - جيم وحديد"
                              value={newPlanName}
                              onChange={e => setNewPlanName(e.target.value)}
                              className={`w-full border rounded-xl px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] transition ${
                                isDark ? 'bg-[#080C14] border-[#1E2B45] text-slate-100 placeholder-slate-500' : 'bg-slate-50 border-slate-300 text-slate-900 placeholder-slate-400'
                              }`}
                            />
                          </div>

                          <div className="grid grid-cols-2 gap-2">
                            <div>
                              <label className={`block text-[11px] font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>المدة بالأيام</label>
                              <input
                                type="number"
                                value={newPlanDays}
                                onChange={e => setNewPlanDays(e.target.value)}
                                className={`w-full border rounded-xl px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] font-mono transition ${
                                  isDark ? 'bg-[#080C14] border-[#1E2B45] text-slate-100' : 'bg-slate-50 border-slate-300 text-slate-900'
                                }`}
                              />
                            </div>
                            <div>
                              <label className={`block text-[11px] font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>السعر (ج.م)</label>
                              <input
                                type="number"
                                value={newPlanPrice}
                                onChange={e => setNewPlanPrice(e.target.value)}
                                className={`w-full border rounded-xl px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] font-mono transition ${
                                  isDark ? 'bg-[#080C14] border-[#1E2B45] text-slate-100' : 'bg-slate-50 border-slate-300 text-slate-900'
                                }`}
                              />
                            </div>
                          </div>

                          <div className={`flex gap-2 pt-2 border-t ${isDark ? 'border-[#1E2B45]' : 'border-slate-100'}`}>
                            <button
                              type="button"
                              onClick={() => setShowAddPlanModal(false)}
                              className={`w-1/3 py-2 rounded-xl font-bold text-xs transition btn-tactile ${
                                isDark ? 'bg-[#162032] text-slate-300 hover:bg-[#1E2B45]' : 'bg-slate-100 text-slate-700 hover:bg-slate-200'
                              }`}
                            >
                              إلغاء
                            </button>
                            <button
                              type="button"
                              onClick={handleSavePlan}
                              disabled={isModalSaving || !newPlanName.trim()}
                              className="w-2/3 py-2 bg-sky-500 hover:bg-sky-400 text-slate-950 font-bold text-xs rounded-xl transition btn-tactile"
                            >
                              حفظ الباقة
                            </button>
                          </div>
                        </div>
                      </div>
                    </div>
                  )}

                  {/* 5. ADD MEMBERSHIP MODAL */}
                  {showAddMembershipModal && (
                    <div className="absolute inset-0 bg-slate-950/85 backdrop-blur-sm z-50 flex items-center justify-center p-3 animate-fadeIn">
                      <div className={`border rounded-2xl w-full max-w-sm p-4 space-y-3 shadow-2xl transition ${
                        isDark ? 'bg-[#0F1626] border-[#1E2B45]' : 'bg-white border-slate-200 shadow-xl'
                      }`}>
                        <div className={`flex items-center justify-between pb-2 border-b ${isDark ? 'border-[#1E2B45]' : 'border-slate-100'}`}>
                          <h4 className={`font-bold text-xs ${isDark ? 'text-slate-100' : 'text-slate-900'}`}>تسجيل اشتراك جديد</h4>
                          <button onClick={() => setShowAddMembershipModal(false)} className={`p-1 transition ${isDark ? 'text-slate-400 hover:text-slate-200' : 'text-slate-500 hover:text-slate-800'}`}>
                            <X className="w-4 h-4" />
                          </button>
                        </div>

                        <div className="space-y-2.5">
                          <div>
                            <label className={`block text-[11px] font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>اختيار العضو *</label>
                            <select
                              value={memMemberId}
                              onChange={e => setMemMemberId(e.target.value)}
                              className={`w-full border rounded-xl px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] transition ${
                                isDark ? 'bg-[#080C14] border-[#1E2B45] text-slate-100' : 'bg-slate-50 border-slate-300 text-slate-900'
                              }`}
                            >
                              <option value="">اختر العضو...</option>
                              {realMembers.map(m => (
                                <option key={m.id} value={m.id}>{m.full_name} ({m.phone || 'بدون هاتف'})</option>
                              ))}
                            </select>
                          </div>

                          <div>
                            <label className={`block text-[11px] font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>اختيار الباقة *</label>
                            <select
                              value={memPlanId}
                              onChange={e => {
                                setMemPlanId(e.target.value);
                                const p = realPlans.find(x => x.id === e.target.value);
                                if (p) {
                                  setMemPrice(String(p.price));
                                  const d = new Date(memStartDate);
                                  d.setDate(d.getDate() + p.duration_days);
                                  setMemEndDate(d.toISOString().substring(0, 10));
                                }
                              }}
                              className={`w-full border rounded-xl px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] transition ${
                                isDark ? 'bg-[#080C14] border-[#1E2B45] text-slate-100' : 'bg-slate-50 border-slate-300 text-slate-900'
                              }`}
                            >
                              <option value="">اختر باقة الاشتراك...</option>
                              {realPlans.map(p => (
                                <option key={p.id} value={p.id}>{p.name} - {p.price} ج.م ({p.duration_days} يوم)</option>
                              ))}
                            </select>
                          </div>

                          <div className="grid grid-cols-2 gap-2">
                            <div>
                              <label className={`block text-[11px] font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>تاريخ البدء</label>
                              <input
                                type="date"
                                value={memStartDate}
                                onChange={e => setMemStartDate(e.target.value)}
                                className={`w-full border rounded-xl px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] transition ${
                                  isDark ? 'bg-[#080C14] border-[#1E2B45] text-slate-100' : 'bg-slate-50 border-slate-300 text-slate-900'
                                }`}
                              />
                            </div>
                            <div>
                              <label className={`block text-[11px] font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>تاريخ الانتهاء</label>
                              <input
                                type="date"
                                value={memEndDate}
                                onChange={e => setMemEndDate(e.target.value)}
                                className={`w-full border rounded-xl px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] transition ${
                                  isDark ? 'bg-[#080C14] border-[#1E2B45] text-slate-100' : 'bg-slate-50 border-slate-300 text-slate-900'
                                }`}
                              />
                            </div>
                          </div>

                          <div>
                            <label className={`block text-[11px] font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>سعر الاشتراك (ج.م)</label>
                            <input
                              type="number"
                              value={memPrice}
                              onChange={e => setMemPrice(e.target.value)}
                              className={`w-full border rounded-xl px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] font-mono transition ${
                                isDark ? 'bg-[#080C14] border-[#1E2B45] text-[#D4AF37]' : 'bg-slate-50 border-slate-300 text-slate-900 font-bold'
                              }`}
                            />
                          </div>

                          <label className={`flex items-center gap-2 p-2 rounded-xl border cursor-pointer transition ${
                            isDark ? 'bg-[#080C14] border-[#1E2B45]' : 'bg-slate-50 border-slate-200'
                          }`}>
                            <input
                              type="checkbox"
                              checked={memRecordPayment}
                              onChange={e => setMemRecordPayment(e.target.checked)}
                              className="rounded text-[#D4AF37] accent-[#D4AF37]"
                            />
                            <span className={`text-[11px] font-bold ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>تسجيل دفعة إيراد نقدية فوراً في الخزينة</span>
                          </label>

                          <div className={`flex gap-2 pt-2 border-t ${isDark ? 'border-[#1E2B45]' : 'border-slate-100'}`}>
                            <button
                              type="button"
                              onClick={() => setShowAddMembershipModal(false)}
                              className={`w-1/3 py-2 rounded-xl font-bold text-xs transition btn-tactile ${
                                isDark ? 'bg-[#162032] text-slate-300 hover:bg-[#1E2B45]' : 'bg-slate-100 text-slate-700 hover:bg-slate-200'
                              }`}
                            >
                              إلغاء
                            </button>
                            <button
                              type="button"
                              onClick={handleSaveMembership}
                              disabled={isModalSaving || !memMemberId || !memPlanId}
                              className="w-2/3 py-2 bg-[#D4AF37] hover:bg-[#E5C158] text-slate-950 font-bold text-xs rounded-xl transition btn-tactile"
                            >
                              تفعيل الاشتراك
                            </button>
                          </div>
                        </div>
                      </div>
                    </div>
                  )}

                  {/* 6. ADD PAYMENT MODAL */}
                  {showAddPaymentModal && (
                    <div className="absolute inset-0 bg-slate-950/85 backdrop-blur-sm z-50 flex items-center justify-center p-3 animate-fadeIn">
                      <div className={`border rounded-2xl w-full max-w-sm p-4 space-y-3 shadow-2xl transition ${
                        isDark ? 'bg-[#0F1626] border-[#1E2B45]' : 'bg-white border-slate-200 shadow-xl'
                      }`}>
                        <div className={`flex items-center justify-between pb-2 border-b ${isDark ? 'border-[#1E2B45]' : 'border-slate-100'}`}>
                          <h4 className={`font-bold text-xs ${isDark ? 'text-slate-100' : 'text-slate-900'}`}>تسجيل دفعة إيراد جديدة</h4>
                          <button onClick={() => setShowAddPaymentModal(false)} className={`p-1 transition ${isDark ? 'text-slate-400 hover:text-slate-200' : 'text-slate-500 hover:text-slate-800'}`}>
                            <X className="w-4 h-4" />
                          </button>
                        </div>

                        <div className="space-y-2.5">
                          <div>
                            <label className={`block text-[11px] font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>المبلغ المستلم (ج.م) *</label>
                            <input
                              type="number"
                              required
                              placeholder="350"
                              value={newPaymentAmount}
                              onChange={e => setNewPaymentAmount(e.target.value)}
                              className={`w-full border rounded-xl px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] font-mono font-bold text-emerald-400 transition ${
                                isDark ? 'bg-[#080C14] border-[#1E2B45]' : 'bg-slate-50 border-slate-300'
                              }`}
                            />
                          </div>

                          <div>
                            <label className={`block text-[11px] font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>طريقة الدفع</label>
                            <select
                              value={newPaymentMethod}
                              onChange={e => setNewPaymentMethod(e.target.value)}
                              className={`w-full border rounded-xl px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] transition ${
                                isDark ? 'bg-[#080C14] border-[#1E2B45] text-slate-100' : 'bg-slate-50 border-slate-300 text-slate-900'
                              }`}
                            >
                              <option value="cash">كاش نقدي</option>
                              <option value="vodafone_cash">فودافون كاش / محفظة ذكية</option>
                              <option value="instapay">إنستاباي (InstaPay)</option>
                              <option value="card">بطاقة بنكية / فيزا</option>
                            </select>
                          </div>

                          <div>
                            <label className={`block text-[11px] font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>ملاحظات / اسم العضو</label>
                            <input
                              type="text"
                              placeholder="مثال: اشتراك شهر مارس - كابتن محمد"
                              value={newPaymentNotes}
                              onChange={e => setNewPaymentNotes(e.target.value)}
                              className={`w-full border rounded-xl px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] transition ${
                                isDark ? 'bg-[#080C14] border-[#1E2B45] text-slate-100 placeholder-slate-500' : 'bg-slate-50 border-slate-300 text-slate-900 placeholder-slate-400'
                              }`}
                            />
                          </div>

                          <div className={`flex gap-2 pt-2 border-t ${isDark ? 'border-[#1E2B45]' : 'border-slate-100'}`}>
                            <button
                              type="button"
                              onClick={() => setShowAddPaymentModal(false)}
                              className={`w-1/3 py-2 rounded-xl font-bold text-xs transition btn-tactile ${
                                isDark ? 'bg-[#162032] text-slate-300 hover:bg-[#1E2B45]' : 'bg-slate-100 text-slate-700 hover:bg-slate-200'
                              }`}
                            >
                              إلغاء
                            </button>
                            <button
                              type="button"
                              onClick={handleSavePayment}
                              disabled={isModalSaving || !newPaymentAmount}
                              className="w-2/3 py-2 bg-emerald-500 hover:bg-emerald-400 text-slate-950 font-bold text-xs rounded-xl transition btn-tactile"
                            >
                              حفظ وإصدار إيصال
                            </button>
                          </div>
                        </div>
                      </div>
                    </div>
                  )}

                  {/* 7. EDIT PLAN MODAL */}
                  {editingPlan && (
                    <div className="absolute inset-0 bg-slate-950/85 backdrop-blur-sm z-50 flex items-center justify-center p-3 animate-fadeIn">
                      <div className={`border rounded-2xl w-full max-w-sm p-4 space-y-3 shadow-2xl transition ${
                        isDark ? 'bg-[#0F1626] border-[#1E2B45]' : 'bg-white border-slate-200 shadow-xl'
                      }`}>
                        <div className={`flex items-center justify-between pb-2 border-b ${isDark ? 'border-[#1E2B45]' : 'border-slate-100'}`}>
                          <h4 className={`font-bold text-xs ${isDark ? 'text-slate-100' : 'text-slate-900'}`}>تعديل باقة الاشتراك</h4>
                          <button onClick={() => setEditingPlan(null)} className={`p-1 transition ${isDark ? 'text-slate-400 hover:text-slate-200' : 'text-slate-500 hover:text-slate-800'}`}>
                            <X className="w-4 h-4" />
                          </button>
                        </div>

                        <div className="space-y-2.5">
                          <div>
                            <label className={`block text-[11px] font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>اسم الباقة *</label>
                            <input
                              type="text"
                              value={editingPlan.name}
                              onChange={e => setEditingPlan({ ...editingPlan, name: e.target.value })}
                              className={`w-full border rounded-xl px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] transition ${
                                isDark ? 'bg-[#080C14] border-[#1E2B45] text-slate-100' : 'bg-slate-50 border-slate-300 text-slate-900'
                              }`}
                            />
                          </div>

                          <div className="grid grid-cols-2 gap-2">
                            <div>
                              <label className={`block text-[11px] font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>المدة (أيام)</label>
                              <input
                                type="number"
                                value={editingPlan.duration_days}
                                onChange={e => setEditingPlan({ ...editingPlan, duration_days: e.target.value })}
                                className={`w-full border rounded-xl px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] font-mono transition ${
                                  isDark ? 'bg-[#080C14] border-[#1E2B45] text-slate-100' : 'bg-slate-50 border-slate-300 text-slate-900'
                                }`}
                              />
                            </div>
                            <div>
                              <label className={`block text-[11px] font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>السعر (ج.م)</label>
                              <input
                                type="number"
                                value={editingPlan.price}
                                onChange={e => setEditingPlan({ ...editingPlan, price: e.target.value })}
                                className={`w-full border rounded-xl px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] font-mono text-[#D4AF37] font-bold transition ${
                                  isDark ? 'bg-[#080C14] border-[#1E2B45]' : 'bg-slate-50 border-slate-300'
                                }`}
                              />
                            </div>
                          </div>

                          <div className={`flex items-center justify-between p-2 rounded-xl border text-xs ${
                            isDark ? 'bg-[#080C14] border-[#1E2B45]' : 'bg-slate-50 border-slate-200'
                          }`}>
                            <span className={isDark ? 'text-slate-300' : 'text-slate-700'}>حالة تفعيل الباقة:</span>
                            <button
                              type="button"
                              onClick={() => setEditingPlan({ ...editingPlan, is_active: !editingPlan.is_active })}
                              className={`px-3 py-1 rounded-lg font-bold transition btn-tactile ${
                                editingPlan.is_active
                                  ? 'bg-emerald-500/20 text-emerald-400 border border-emerald-500/40'
                                  : 'bg-rose-500/20 text-rose-400 border border-rose-500/40'
                              }`}
                            >
                              {editingPlan.is_active ? 'مفعلة ونشطة' : 'معطلة'}
                            </button>
                          </div>

                          <div className={`flex gap-2 pt-2 border-t ${isDark ? 'border-[#1E2B45]' : 'border-slate-100'}`}>
                            <button
                              type="button"
                              onClick={() => setEditingPlan(null)}
                              className={`w-1/3 py-2 rounded-xl font-bold text-xs transition btn-tactile ${
                                isDark ? 'bg-[#162032] text-slate-300 hover:bg-[#1E2B45]' : 'bg-slate-100 text-slate-700 hover:bg-slate-200'
                              }`}
                            >
                              إلغاء
                            </button>
                            <button
                              type="button"
                              onClick={handleSaveEditedPlan}
                              disabled={isModalSaving || !editingPlan.name?.trim()}
                              className="w-2/3 py-2 bg-sky-500 hover:bg-sky-400 text-slate-950 font-bold text-xs rounded-xl transition btn-tactile"
                            >
                              حفظ التعديلات
                            </button>
                          </div>
                        </div>
                      </div>
                    </div>
                  )}

                  {/* 8. EDIT MEMBERSHIP MODAL */}
                  {editingMembership && (
                    <div className="absolute inset-0 bg-slate-950/85 backdrop-blur-sm z-50 flex items-center justify-center p-3 animate-fadeIn">
                      <div className={`border rounded-2xl w-full max-w-sm p-4 space-y-3 shadow-2xl transition ${
                        isDark ? 'bg-[#0F1626] border-[#1E2B45]' : 'bg-white border-slate-200 shadow-xl'
                      }`}>
                        <div className={`flex items-center justify-between pb-2 border-b ${isDark ? 'border-[#1E2B45]' : 'border-slate-100'}`}>
                          <h4 className={`font-bold text-xs ${isDark ? 'text-slate-100' : 'text-slate-900'}`}>تعديل بيانات الاشتراك</h4>
                          <button onClick={() => setEditingMembership(null)} className={`p-1 transition ${isDark ? 'text-slate-400 hover:text-slate-200' : 'text-slate-500 hover:text-slate-800'}`}>
                            <X className="w-4 h-4" />
                          </button>
                        </div>

                        <div className="space-y-2.5">
                          <div>
                            <label className={`block text-[11px] font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>خطة / باقة الاشتراك</label>
                            <select
                              value={editingMembership.plan_id || ''}
                              onChange={e => {
                                const p = realPlans.find(x => x.id === e.target.value);
                                setEditingMembership({
                                  ...editingMembership,
                                  plan_id: e.target.value,
                                  price: p ? p.price : editingMembership.price
                                });
                              }}
                              className={`w-full border rounded-xl px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] transition ${
                                isDark ? 'bg-[#080C14] border-[#1E2B45] text-slate-100' : 'bg-slate-50 border-slate-300 text-slate-900'
                              }`}
                            >
                              <option value="">اختر باقة...</option>
                              {realPlans.map(p => (
                                <option key={p.id} value={p.id}>{p.name} - {p.price} ج.م</option>
                              ))}
                            </select>
                          </div>

                          <div className="grid grid-cols-2 gap-2">
                            <div>
                              <label className={`block text-[11px] font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>تاريخ البدء</label>
                              <input
                                type="date"
                                value={editingMembership.start_date?.substring(0, 10)}
                                onChange={e => setEditingMembership({ ...editingMembership, start_date: e.target.value })}
                                className={`w-full border rounded-xl px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] transition ${
                                  isDark ? 'bg-[#080C14] border-[#1E2B45] text-slate-100' : 'bg-slate-50 border-slate-300 text-slate-900'
                                }`}
                              />
                            </div>
                            <div>
                              <label className={`block text-[11px] font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>تاريخ الانتهاء</label>
                              <input
                                type="date"
                                value={editingMembership.end_date?.substring(0, 10)}
                                onChange={e => setEditingMembership({ ...editingMembership, end_date: e.target.value })}
                                className={`w-full border rounded-xl px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] transition ${
                                  isDark ? 'bg-[#080C14] border-[#1E2B45] text-slate-100' : 'bg-slate-50 border-slate-300 text-slate-900'
                                }`}
                              />
                            </div>
                          </div>

                          <div>
                            <label className={`block text-[11px] font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>سعر الاشتراك (ج.م)</label>
                            <input
                              type="number"
                              value={editingMembership.price}
                              onChange={e => setEditingMembership({ ...editingMembership, price: e.target.value })}
                              className={`w-full border rounded-xl px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] font-mono text-[#D4AF37] font-bold transition ${
                                isDark ? 'bg-[#080C14] border-[#1E2B45]' : 'bg-slate-50 border-slate-300'
                              }`}
                            />
                          </div>

                          <div>
                            <label className={`block text-[11px] font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>حالة الاشتراك</label>
                            <select
                              value={editingMembership.status || 'active'}
                              onChange={e => setEditingMembership({ ...editingMembership, status: e.target.value })}
                              className={`w-full border rounded-xl px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] transition ${
                                isDark ? 'bg-[#080C14] border-[#1E2B45] text-slate-100' : 'bg-slate-50 border-slate-300 text-slate-900'
                              }`}
                            >
                              <option value="active">ساري وفعال (Active)</option>
                              <option value="expired">منتهي (Expired)</option>
                              <option value="cancelled">ملغي (Cancelled)</option>
                            </select>
                          </div>

                          <div className={`flex gap-2 pt-2 border-t ${isDark ? 'border-[#1E2B45]' : 'border-slate-100'}`}>
                            <button
                              type="button"
                              onClick={() => setEditingMembership(null)}
                              className={`w-1/3 py-2 rounded-xl font-bold text-xs transition btn-tactile ${
                                isDark ? 'bg-[#162032] text-slate-300 hover:bg-[#1E2B45]' : 'bg-slate-100 text-slate-700 hover:bg-slate-200'
                              }`}
                            >
                              إلغاء
                            </button>
                            <button
                              type="button"
                              onClick={handleSaveEditedMembership}
                              disabled={isModalSaving}
                              className="w-2/3 py-2 bg-[#D4AF37] hover:bg-[#E5C158] text-slate-950 font-bold text-xs rounded-xl transition btn-tactile"
                            >
                              تحديث الاشتراك
                            </button>
                          </div>
                        </div>
                      </div>
                    </div>
                  )}

                  {/* 9. EDIT PAYMENT MODAL */}
                  {editingPayment && (
                    <div className="absolute inset-0 bg-slate-950/85 backdrop-blur-sm z-50 flex items-center justify-center p-3 animate-fadeIn">
                      <div className={`border rounded-2xl w-full max-w-sm p-4 space-y-3 shadow-2xl transition ${
                        isDark ? 'bg-[#0F1626] border-[#1E2B45]' : 'bg-white border-slate-200 shadow-xl'
                      }`}>
                        <div className={`flex items-center justify-between pb-2 border-b ${isDark ? 'border-[#1E2B45]' : 'border-slate-100'}`}>
                          <h4 className={`font-bold text-xs ${isDark ? 'text-slate-100' : 'text-slate-900'}`}>تعديل الدفعة المالية</h4>
                          <button onClick={() => setEditingPayment(null)} className={`p-1 transition ${isDark ? 'text-slate-400 hover:text-slate-200' : 'text-slate-500 hover:text-slate-800'}`}>
                            <X className="w-4 h-4" />
                          </button>
                        </div>

                        <div className="space-y-2.5">
                          <div>
                            <label className={`block text-[11px] font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>المبلغ (ج.م) *</label>
                            <input
                              type="number"
                              required
                              value={editingPayment.amount}
                              onChange={e => setEditingPayment({ ...editingPayment, amount: e.target.value })}
                              className={`w-full border rounded-xl px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] font-mono font-bold text-emerald-400 transition ${
                                isDark ? 'bg-[#080C14] border-[#1E2B45]' : 'bg-slate-50 border-slate-300'
                              }`}
                            />
                          </div>

                          <div>
                            <label className={`block text-[11px] font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>طريقة السداد</label>
                            <select
                              value={editingPayment.payment_method || 'cash'}
                              onChange={e => setEditingPayment({ ...editingPayment, payment_method: e.target.value })}
                              className={`w-full border rounded-xl px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] transition ${
                                isDark ? 'bg-[#080C14] border-[#1E2B45] text-slate-100' : 'bg-slate-50 border-slate-300 text-slate-900'
                              }`}
                            >
                              <option value="cash">كاش نقدي</option>
                              <option value="vodafone_cash">فودافون كاش / محفظة</option>
                              <option value="instapay">إنستاباي (InstaPay)</option>
                              <option value="card">بطاقة بنكية / فيزا</option>
                            </select>
                          </div>

                          <div>
                            <label className={`block text-[11px] font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>تاريخ ووقت السداد</label>
                            <input
                              type="datetime-local"
                              value={editingPayment.paid_at ? new Date(editingPayment.paid_at).toISOString().slice(0, 16) : ''}
                              onChange={e => setEditingPayment({ ...editingPayment, paid_at: new Date(e.target.value).toISOString() })}
                              className={`w-full border rounded-xl px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] transition ${
                                isDark ? 'bg-[#080C14] border-[#1E2B45] text-slate-100' : 'bg-slate-50 border-slate-300 text-slate-900'
                              }`}
                            />
                          </div>

                          <div>
                            <label className={`block text-[11px] font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>ملاحظات الإيصال</label>
                            <input
                              type="text"
                              value={editingPayment.notes || ''}
                              onChange={e => setEditingPayment({ ...editingPayment, notes: e.target.value })}
                              className={`w-full border rounded-xl px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] transition ${
                                isDark ? 'bg-[#080C14] border-[#1E2B45] text-slate-100 placeholder-slate-500' : 'bg-slate-50 border-slate-300 text-slate-900 placeholder-slate-400'
                              }`}
                            />
                          </div>

                          <div className={`flex gap-2 pt-2 border-t ${isDark ? 'border-[#1E2B45]' : 'border-slate-100'}`}>
                            <button
                              type="button"
                              onClick={() => setEditingPayment(null)}
                              className={`w-1/3 py-2 rounded-xl font-bold text-xs transition btn-tactile ${
                                isDark ? 'bg-[#162032] text-slate-300 hover:bg-[#1E2B45]' : 'bg-slate-100 text-slate-700 hover:bg-slate-200'
                              }`}
                            >
                              إلغاء
                            </button>
                            <button
                              type="button"
                              onClick={handleSaveEditedPayment}
                              disabled={isModalSaving || !editingPayment.amount}
                              className="w-2/3 py-2 bg-emerald-500 hover:bg-emerald-400 text-slate-950 font-bold text-xs rounded-xl transition btn-tactile"
                            >
                              حفظ التعديل
                            </button>
                          </div>
                        </div>
                      </div>
                    </div>
                  )}

                  {/* 10. EDIT GYM INFO MODAL */}
                  {editingGymInfo && (
                    <div className="absolute inset-0 bg-slate-950/85 backdrop-blur-sm z-50 flex items-center justify-center p-3 animate-fadeIn">
                      <div className={`border rounded-2xl w-full max-w-sm p-4 space-y-3 shadow-2xl transition ${
                        isDark ? 'bg-[#0F1626] border-[#1E2B45]' : 'bg-white border-slate-200 shadow-xl'
                      }`}>
                        <div className={`flex items-center justify-between pb-2 border-b ${isDark ? 'border-[#1E2B45]' : 'border-slate-100'}`}>
                          <h4 className={`font-bold text-xs ${isDark ? 'text-slate-100' : 'text-slate-900'}`}>تعديل بيانات الصالة الرياضية</h4>
                          <button onClick={() => setEditingGymInfo(null)} className={`p-1 transition ${isDark ? 'text-slate-400 hover:text-slate-200' : 'text-slate-500 hover:text-slate-800'}`}>
                            <X className="w-4 h-4" />
                          </button>
                        </div>

                        <div className="space-y-2.5">
                          <div>
                            <label className={`block text-[11px] font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>اسم الصالة *</label>
                            <input
                              type="text"
                              required
                              value={editingGymInfo.name}
                              onChange={e => setEditingGymInfo({ ...editingGymInfo, name: e.target.value })}
                              className={`w-full border rounded-xl px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] font-bold text-[#D4AF37] transition ${
                                isDark ? 'bg-[#080C14] border-[#1E2B45]' : 'bg-slate-50 border-slate-300'
                              }`}
                            />
                            <p className={`text-[10px] mt-0.5 ${isDark ? 'text-slate-500' : 'text-slate-400'}`}>
                              الاسم المعتمد: جيم الديب (Gym ElDeeb)
                            </p>
                          </div>

                          <div>
                            <label className={`block text-[11px] font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>رقم هاتف الصالة</label>
                            <input
                              type="tel"
                              placeholder="مثال: 01012345678"
                              value={editingGymInfo.phone || ''}
                              onChange={e => setEditingGymInfo({ ...editingGymInfo, phone: e.target.value })}
                              className={`w-full border rounded-xl px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] font-mono transition ${
                                isDark ? 'bg-[#080C14] border-[#1E2B45] text-slate-100 placeholder-slate-500' : 'bg-slate-50 border-slate-300 text-slate-900 placeholder-slate-400'
                              }`}
                            />
                          </div>

                          <div>
                            <label className={`block text-[11px] font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>العملة المعتمدة</label>
                            <input
                              type="text"
                              value={editingGymInfo.currency}
                              onChange={e => setEditingGymInfo({ ...editingGymInfo, currency: e.target.value })}
                              className={`w-full border rounded-xl px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] font-bold transition ${
                                isDark ? 'bg-[#080C14] border-[#1E2B45] text-slate-100' : 'bg-slate-50 border-slate-300 text-slate-900'
                              }`}
                            />
                          </div>

                          <div className={`p-2 rounded-xl border text-[10px] space-y-1 ${
                            isDark ? 'bg-[#080C14] border-[#1E2B45] text-slate-400' : 'bg-slate-50 border-slate-200 text-slate-600'
                          }`}>
                            <div className="text-[#D4AF37] font-bold">تنبيه مخطط قاعدة البيانات (Schema):</div>
                            <div>• جدول gyms لا يحتوي على حقل للعنوان في المخطط الحالي، تم الالتزام بالمخطط.</div>
                            <div>• معرف الصالة gym_id ورتب الحسابات محمية ولا يمكن تعديلها.</div>
                          </div>

                          <div className={`flex gap-2 pt-2 border-t ${isDark ? 'border-[#1E2B45]' : 'border-slate-100'}`}>
                            <button
                              type="button"
                              onClick={() => setEditingGymInfo(null)}
                              className={`w-1/3 py-2 rounded-xl font-bold text-xs transition btn-tactile ${
                                isDark ? 'bg-[#162032] text-slate-300 hover:bg-[#1E2B45]' : 'bg-slate-100 text-slate-700 hover:bg-slate-200'
                              }`}
                            >
                              إلغاء
                            </button>
                            <button
                              type="button"
                              onClick={handleSaveGymInfo}
                              disabled={isModalSaving || !editingGymInfo.name?.trim()}
                              className="w-2/3 py-2 bg-[#D4AF37] hover:bg-[#E5C158] text-slate-950 font-bold text-xs rounded-xl transition btn-tactile"
                            >
                              حفظ بيانات الجيم
                            </button>
                          </div>
                        </div>
                      </div>
                    </div>
                  )}

                  {/* 11. EDIT PROFILE MODAL */}
                  {editingProfile && (
                    <div className="absolute inset-0 bg-slate-950/85 backdrop-blur-sm z-50 flex items-center justify-center p-3 animate-fadeIn">
                      <div className={`border rounded-2xl w-full max-w-sm p-4 space-y-3 shadow-2xl transition ${
                        isDark ? 'bg-[#0F1626] border-[#1E2B45]' : 'bg-white border-slate-200 shadow-xl'
                      }`}>
                        <div className={`flex items-center justify-between pb-2 border-b ${isDark ? 'border-[#1E2B45]' : 'border-slate-100'}`}>
                          <h4 className={`font-bold text-xs ${isDark ? 'text-slate-100' : 'text-slate-900'}`}>تعديل الملف الشخصي</h4>
                          <button onClick={() => setEditingProfile(null)} className={`p-1 transition ${isDark ? 'text-slate-400 hover:text-slate-200' : 'text-slate-500 hover:text-slate-800'}`}>
                            <X className="w-4 h-4" />
                          </button>
                        </div>

                        <div className="space-y-2.5">
                          <div>
                            <label className={`block text-[11px] font-bold mb-1 ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>الاسم الكامل *</label>
                            <input
                              type="text"
                              required
                              value={editingProfile.full_name}
                              onChange={e => setEditingProfile({ ...editingProfile, full_name: e.target.value })}
                              className={`w-full border rounded-xl px-3 py-2 text-xs focus:outline-none focus:ring-2 focus:ring-[#D4AF37]/40 focus:border-[#D4AF37] font-bold transition ${
                                isDark ? 'bg-[#080C14] border-[#1E2B45] text-slate-100' : 'bg-slate-50 border-slate-300 text-slate-900'
                              }`}
                            />
                          </div>

                          <div className={`space-y-1.5 p-2 rounded-xl border text-xs ${
                            isDark ? 'bg-[#080C14] border-[#1E2B45]' : 'bg-slate-50 border-slate-200'
                          }`}>
                            <div className="flex justify-between items-center text-[11px]">
                              <span className={isDark ? 'text-slate-400' : 'text-slate-500'}>رتبة الحساب (Role):</span>
                              <span className="px-2 py-0.5 rounded bg-amber-500/10 text-amber-300 font-bold flex items-center gap-1">
                                <Lock className="w-2.5 h-2.5" />
                                <span>{profile?.role === 'owner' ? 'مالك (Owner)' : 'مدرب (Coach)'}</span>
                              </span>
                            </div>
                            <div className="flex justify-between items-center text-[11px]">
                              <span className={isDark ? 'text-slate-400' : 'text-slate-500'}>معرف الجيم (Gym ID):</span>
                              <span className="font-mono text-[10px] text-slate-500 truncate max-w-[130px]">{profile?.gym_id || 'غير متوفر'}</span>
                            </div>
                            <p className="text-[10px] text-slate-500 pt-1">
                              * رتبة الحساب ومعرف الجيم ثابتة ومحمية من قبل نظام Supabase RLS.
                            </p>
                          </div>

                          <div className={`flex gap-2 pt-2 border-t ${isDark ? 'border-[#1E2B45]' : 'border-slate-100'}`}>
                            <button
                              type="button"
                              onClick={() => setEditingProfile(null)}
                              className={`w-1/3 py-2 rounded-xl font-bold text-xs transition btn-tactile ${
                                isDark ? 'bg-[#162032] text-slate-300 hover:bg-[#1E2B45]' : 'bg-slate-100 text-slate-700 hover:bg-slate-200'
                              }`}
                            >
                              إلغاء
                            </button>
                            <button
                              type="button"
                              onClick={handleSaveProfile}
                              disabled={isModalSaving || !editingProfile.full_name?.trim()}
                              className="w-2/3 py-2 bg-emerald-500 hover:bg-emerald-400 text-slate-950 font-bold text-xs rounded-xl transition btn-tactile"
                            >
                              حفظ الاسم
                            </button>
                          </div>
                        </div>
                      </div>
                    </div>
                  )}

                  {/* 12. LOGOUT CONFIRMATION MODAL */}
                  {showLogoutConfirm && (
                    <div className="absolute inset-0 bg-slate-950/85 backdrop-blur-sm z-50 flex items-center justify-center p-3 animate-fadeIn">
                      <div className={`border rounded-2xl w-full max-w-sm p-4 space-y-3 shadow-2xl text-center transition ${
                        isDark ? 'bg-[#0F1626] border-[#1E2B45]' : 'bg-white border-slate-200 shadow-xl'
                      }`}>
                        <div className="w-10 h-10 rounded-full bg-rose-500/20 text-rose-400 flex items-center justify-center mx-auto">
                          <LogOut className="w-5 h-5" />
                        </div>
                        <h4 className={`font-bold text-sm ${isDark ? 'text-slate-100' : 'text-slate-900'}`}>تأكيد تسجيل الخروج</h4>
                        <p className={`text-xs ${isDark ? 'text-slate-400' : 'text-slate-500'}`}>
                          هل تريد تأكيد تسجيل الخروج من جلسة كابتن جيم الديب الحالية؟
                        </p>
                        <div className="flex gap-2 pt-2">
                          <button
                            type="button"
                            onClick={() => setShowLogoutConfirm(false)}
                            className={`w-1/2 py-2 rounded-xl font-bold text-xs transition btn-tactile ${
                              isDark ? 'bg-[#162032] text-slate-300 hover:bg-[#1E2B45]' : 'bg-slate-100 text-slate-700 hover:bg-slate-200'
                            }`}
                          >
                            تراجع
                          </button>
                          <button
                            type="button"
                            onClick={() => {
                              setShowLogoutConfirm(false);
                              handleRealSignOut();
                            }}
                            className="w-1/2 py-2 bg-rose-500 hover:bg-rose-400 text-slate-950 font-bold text-xs rounded-xl transition btn-tactile"
                          >
                            تأكيد الخروج
                          </button>
                        </div>
                      </div>
                    </div>
                  )}
                </div>

                {/* Bottom Device Home Bar */}
                <div className={`py-2 flex justify-center transition-colors ${isDark ? 'bg-[#0F1626]' : 'bg-slate-100'}`}>
                  <div className={`w-32 h-1 rounded-full ${isDark ? 'bg-slate-700' : 'bg-slate-300'}`} />
                </div>
              </div>
            </div>
          </div>
        )}

        {/* TAB 2: FLUTTER CODE EXPLORER */}
        {activeTab === 'code' && (
          <div className="grid grid-cols-1 lg:grid-cols-12 gap-6 items-start">
            <div className={`lg:col-span-4 border rounded-2xl p-4 shadow-lg space-y-3 transition ${
              isDark ? 'bg-[#0F1626] border-[#1E2B45]' : 'bg-white border-slate-200 shadow-sm'
            }`}>
              <h3 className={`font-bold text-sm flex items-center gap-2 ${isDark ? 'text-slate-200' : 'text-slate-900'}`}>
                <FolderTree className="w-4 h-4 text-[#D4AF37]" />
                <span>ملفات مشروع فلاتر (Phase 2)</span>
              </h3>
              <p className={`text-xs ${isDark ? 'text-slate-400' : 'text-slate-500'}`}>
                أكواد تطبيق فلاتر المحدثة ببروتوكولات المصادقة الحقيقية لـ Supabase Auth و Edge Function.
              </p>

              <div className="space-y-1 pt-2">
                {Object.keys(FLUTTER_FILES).map(fileName => {
                  const info = FLUTTER_FILES[fileName];
                  const isSelected = selectedFile === fileName;
                  return (
                    <button
                      key={fileName}
                      onClick={() => setSelectedFile(fileName)}
                      className={`w-full text-right p-2.5 rounded-xl text-xs transition flex items-center justify-between btn-tactile ${
                        isSelected
                          ? 'bg-[#D4AF37]/20 text-[#D4AF37] border border-[#D4AF37]/40 font-bold'
                          : isDark
                            ? 'bg-[#162032]/60 hover:bg-[#162032] text-slate-300 border border-transparent'
                            : 'bg-slate-50 hover:bg-slate-100 text-slate-700 border border-transparent'
                      }`}
                    >
                      <div className="flex items-center gap-2 truncate">
                        <FileCode className="w-4 h-4 text-[#D4AF37] shrink-0" />
                        <span className="font-mono truncate">{fileName}</span>
                      </div>
                      <span className={`text-[10px] px-1.5 py-0.5 rounded ${isDark ? 'bg-slate-800 text-slate-300' : 'bg-slate-200 text-slate-700'}`}>
                        {info.category}
                      </span>
                    </button>
                  );
                })}
              </div>
            </div>

            <div className={`lg:col-span-8 border rounded-2xl p-5 shadow-lg space-y-4 transition ${
              isDark ? 'bg-[#0F1626] border-[#1E2B45]' : 'bg-white border-slate-200 shadow-sm'
            }`}>
              <div className={`flex items-center justify-between pb-3 border-b ${isDark ? 'border-[#1E2B45]' : 'border-slate-100'}`}>
                <div>
                  <h4 className="font-mono text-sm font-bold text-[#D4AF37]">{selectedFile}</h4>
                  <p className={`text-xs mt-0.5 ${isDark ? 'text-slate-400' : 'text-slate-500'}`}>{FLUTTER_FILES[selectedFile]?.description}</p>
                </div>
                <button
                  onClick={handleCopyCode}
                  className={`px-3 py-1.5 border rounded-xl text-xs flex items-center gap-1.5 transition btn-tactile ${
                    isDark ? 'bg-[#162032] hover:bg-[#1E2B45] border-[#1E2B45] text-slate-200' : 'bg-slate-100 hover:bg-slate-200 border-slate-300 text-slate-800'
                  }`}
                >
                  {copied ? <Check className="w-3.5 h-3.5 text-emerald-400" /> : <Copy className="w-3.5 h-3.5" />}
                  <span>{copied ? 'تم النسخ!' : 'نسخ الكود'}</span>
                </button>
              </div>

              <pre className={`p-4 rounded-xl text-xs font-mono overflow-x-auto max-h-[560px] border leading-relaxed text-left ${
                isDark ? 'bg-[#080C14] text-slate-200 border-[#1E2B45]' : 'bg-slate-900 text-slate-100 border-slate-800'
              }`} dir="ltr">
                <code>{FLUTTER_FILES[selectedFile]?.code}</code>
              </pre>
            </div>
          </div>
        )}

        {/* TAB 3: RLS & EDGE FUNCTION AUDIT */}
        {activeTab === 'schema' && (
          <div className={`border rounded-2xl p-6 shadow-lg space-y-6 transition ${
            isDark ? 'bg-[#0F1626] border-[#1E2B45]' : 'bg-white border-slate-200 shadow-sm'
          }`}>
            <div className={`flex items-center justify-between border-b pb-4 ${isDark ? 'border-[#1E2B45]' : 'border-slate-100'}`}>
              <div>
                <h3 className={`text-base font-bold flex items-center gap-2 ${isDark ? 'text-slate-100' : 'text-slate-900'}`}>
                  <Shield className="w-5 h-5 text-emerald-400" />
                  <span>معايير الأمان المطبقة في جيم الديب</span>
                </h3>
                <p className={`text-xs mt-1 ${isDark ? 'text-slate-400' : 'text-slate-500'}`}>
                  الالتزام التام بقواعد Supabase RLS وعدم استخدام أي مفاتيح سرية في جهة العميل.
                </p>
              </div>
              <span className="text-xs font-mono text-emerald-400 bg-emerald-500/10 px-3 py-1 rounded-full border border-emerald-500/30 font-bold">
                Zero Client Escalation
              </span>
            </div>

            <div className="space-y-4">
              <div className={`p-4 rounded-xl border space-y-2 ${
                isDark ? 'bg-[#080C14] border-[#1E2B45]' : 'bg-slate-50 border-slate-200'
              }`}>
                <h4 className="font-bold text-sm text-[#D4AF37] flex items-center gap-2">
                  <Lock className="w-4 h-4" />
                  <span>دورة التحقق عبر Edge Function (join-gym):</span>
                </h4>
                <p className={`text-xs leading-relaxed ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>
                  يتم استدعاء الرابط التالي عند إدخال كود الدعوة:
                  <br />
                  <code className={`px-2 py-0.5 rounded text-[#D4AF37] font-mono text-[11px] inline-block my-1 ${isDark ? 'bg-[#0F1626]' : 'bg-white border border-slate-200'}`}>
                    POST https://rpwcjfayhdwbsnecomnk.supabase.co/functions/v1/join-gym
                  </code>
                  <br />
                  مع الترويسة: <code className={`px-1.5 py-0.5 rounded font-mono text-[11px] ${isDark ? 'bg-[#0F1626] text-slate-300' : 'bg-white text-slate-700 border border-slate-200'}`}>Authorization: Bearer &lt;access_token&gt;</code>
                  <br />
                  وجسم الطلب: <code className={`px-1.5 py-0.5 rounded font-mono text-[11px] ${isDark ? 'bg-[#0F1626] text-slate-300' : 'bg-white text-slate-700 border border-slate-200'}`}>{"{ \"full_name\": \"...\", \"invite_code\": \"...\" }"}</code>
                </p>
                <div className={`text-[11px] pt-1 ${isDark ? 'text-slate-400' : 'text-slate-500'}`}>
                  تقوم الدالة السحابية بالتحقق من جدول <code className="text-[#D4AF37]">gym_invites</code>، والتأكد من عدم انتهاء الصلاحية أو تجاوز <code className="text-[#D4AF37]">max_uses</code>، ثم تقوم بربط المستخدم بالجيم ومنحه صلاحيات المالك المشترك أو المدرب في جدول <code className="text-[#D4AF37]">profiles</code> على السيرفر مباشرة.
                </div>
              </div>

              <div className={`p-4 rounded-xl border space-y-2 ${
                isDark ? 'bg-[#080C14] border-[#1E2B45]' : 'bg-slate-50 border-slate-200'
              }`}>
                <h4 className={`font-bold text-sm flex items-center gap-2 ${isDark ? 'text-slate-200' : 'text-slate-900'}`}>
                  <Building2 className="w-4 h-4 text-emerald-400" />
                  <span>قواعد RLS وعزل البيانات:</span>
                </h4>
                <ul className={`text-xs space-y-1.5 list-disc list-inside ${isDark ? 'text-slate-300' : 'text-slate-700'}`}>
                  <li>المدرب والمالك لا يمكنهم رؤية بيانات إلا الجيم الخاص بهم (<code className="text-[#D4AF37]">gym_id</code>).</li>
                  <li>تعديل البروفايل من جهة العميل مقتصر حصراً على الاسم الكامل (<code className="text-[#D4AF37]">full_name</code>).</li>
                  <li>العميل ممنوع تماماً من تعديل <code className="text-[#D4AF37]">role</code> أو <code className="text-[#D4AF37]">gym_id</code>.</li>
                  <li>التسجيل الجديد لا يمنح أي مستخدم رتبة مالك تلقائياً.</li>
                </ul>
              </div>
            </div>
          </div>
        )}
      </main>

      {/* Footer */}
      <footer className={`border-t py-3 px-6 text-center text-xs transition ${
        isDark ? 'border-[#1E2B45]/80 bg-[#080C14]/90 text-slate-500' : 'border-slate-200 bg-white text-slate-500'
      }`}>
        جيم الديب (Gym ElDeeb) • نظام إدارة الجيم الرياضي المتكامل
      </footer>
    </div>
  );
}
