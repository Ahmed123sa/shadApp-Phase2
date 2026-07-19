'use client';

import { useEffect, useState, useCallback } from 'react';
import { useTranslations, useLocale } from 'next-intl';
import { useSearchParams, useRouter } from 'next/navigation';
import api from '@/lib/api';
import { getUser } from '@/lib/auth';
import Link from 'next/link';
import DashboardStatCard from '@/components/dashboard/DashboardStatCard';
import ActivityFeed, { ActivityItem } from '@/components/dashboard/ActivityFeed';
import ManagerTableRow from '@/components/dashboard/ManagerTableRow';

type Client = {
  id: number; company_name: string; contact_person: string; email: string;
  status: string; contract_value: string; payment_status: string; signed_at: string | null;
  avatar_url?: string | null;
  workspace: { id: number; status: string } | null;
  latest_contract?: { id: number; status: string; value: string } | null;
  updated_at: string;
};

type Contract = {
  id: number; title: string; status: string; contract_type?: string; value: string; currency: string;
  created_at?: string;
  workspace?: { id: number; client?: { company_name: string; id: number } };
};

type Payment = {
  id: number; amount: string; currency: string; method_type: string; status: string;
  workspace?: { id: number; client?: { company_name: string; id: number } };
  contract?: { title: string; id: number } | null;
  created_at: string;
};

type Meeting = {
  id: number; title: string; scheduled_at: string; duration_minutes: number;
  status: string; notes?: string;
  workspace?: { id: number; client?: { company_name: string; id: number } };
  contract?: { id: number } | null;
  created_at: string;
};

type FileFile = {
  id: number; name: string; type: string; size: number; file_url: string; status: string;
  workspace?: { id: number; client?: { company_name: string; id: number } };
  uploaded_by?: { name: string } | null;
  created_at: string;
};

type Manager = {
  id: number; name: string; email: string; avatar_url: string | null;
  managed_clients_count: number;
  pending_count?: number;
  clients?: Client[];
};

type Approval = {
  id: number; title: string; description: string; status: string;
  workspace?: { id: number; client?: { company_name: string; id: number } };
  created_at: string;
};

type PaginatedResponse<T> = { data: T[]; current_page: number; last_page: number; per_page: number; total: number };

const FILE_BASE = process.env.NEXT_PUBLIC_API_URL?.replace('/api', '') || 'http://localhost:8000';

function resolveFileUrl(url: string): string {
  if (!url) return '';
  if (url.startsWith('http')) return url;
  return `${FILE_BASE}/storage/${url.replace(/^\/?storage\//, '')}`;
}

function timeAgo(dateStr: string, locale: string): string {
  if (!dateStr) return '';
  const diff = Date.now() - new Date(dateStr).getTime();
  const mins = Math.floor(diff / 60000);
  if (mins < 1) return locale === 'ar' ? 'الآن' : 'just now';
  if (mins < 60) return locale === 'ar' ? `منذ ${mins} دقيقة` : `${mins}m ago`;
  const hrs = Math.floor(mins / 60);
  if (hrs < 24) return locale === 'ar' ? `منذ ${hrs} ساعة` : `${hrs}h ago`;
  const days = Math.floor(hrs / 24);
  return locale === 'ar' ? `منذ ${days} يوم` : `${days}d ago`;
}

function formatDate(dateStr: string, locale: string): string {
  if (!dateStr) return '';
  return new Date(dateStr).toLocaleDateString(locale === 'ar' ? 'ar-SA' : 'en-US', {
    year: 'numeric', month: 'short', day: 'numeric',
  });
}

function formatTime(dateStr: string, locale: string): string {
  if (!dateStr) return '';
  return new Date(dateStr).toLocaleTimeString(locale === 'ar' ? 'ar-SA' : 'en-US', {
    hour: '2-digit', minute: '2-digit',
  });
}

function formatFileSize(bytes: number, locale: string): string {
  if (!bytes) return '0 B';
  const units = locale === 'ar' ? ['بايت', 'ك.ب', 'م.ب', 'ج.ب'] : ['B', 'KB', 'MB', 'GB'];
  let idx = 0;
  let size = bytes;
  while (size >= 1024 && idx < units.length - 1) { size /= 1024; idx++; }
  return `${size.toFixed(idx > 0 ? 1 : 0)} ${units[idx]}`;
}

export default function DashboardHome() {
  const t = useTranslations('dashboard');
  const locale = useLocale();
  const router = useRouter();
  const searchParams = useSearchParams();
  const isSA = getUser()?.role === 'super_admin';
  const view = searchParams.get('view') || '';

  const [clients, setClients] = useState<Client[]>([]);
  const [managers, setManagers] = useState<Manager[]>([]);
  const [allContracts, setAllContracts] = useState<Contract[]>([]);
  const [allPayments, setAllPayments] = useState<Payment[]>([]);
  const [allMeetings, setAllMeetings] = useState<Meeting[]>([]);
  const [pendingApprovals, setPendingApprovals] = useState<Approval[]>([]);
  const [unreadCount, setUnreadCount] = useState(0);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    if (isSA) {
      Promise.all([
        api.get('/account-managers').catch(() => ({ data: { managers: [] } })),
        api.get('/all-contracts?per_page=100').catch(() => ({ data: { contracts: { data: [] } } })),
        api.get('/all-payments?per_page=100').catch(() => ({ data: { payments: { data: [] } } })),
        api.get('/all-meetings?per_page=100').catch(() => ({ data: { meetings: { data: [] } } })),
        api.get('/approvals/pending').catch(() => ({ data: { approvals: [] } })),
        api.get('/notifications').catch(() => ({ data: { unread_count: 0 } })),
      ]).then(([managersRes, contractsRes, paymentsRes, meetingsRes, approvalsRes, notifRes]) => {
        setManagers(managersRes.data.managers || []);
        setAllContracts(contractsRes.data.contracts?.data || contractsRes.data.contracts || []);
        setAllPayments(paymentsRes.data.payments?.data || paymentsRes.data.payments || []);
        setAllMeetings(meetingsRes.data.meetings?.data || meetingsRes.data.meetings || []);
        setPendingApprovals(approvalsRes.data.approvals || []);
        setUnreadCount(notifRes.data.unread_count || 0);
      }).finally(() => setLoading(false));
    } else {
      Promise.all([
        api.get('/clients').catch(() => ({ data: { clients: { data: [] } } })),
        api.get('/all-contracts?per_page=100').catch(() => ({ data: { contracts: { data: [] } } })),
        api.get('/all-payments?per_page=100').catch(() => ({ data: { payments: { data: [] } } })),
        api.get('/all-meetings?per_page=100').catch(() => ({ data: { meetings: { data: [] } } })),
        api.get('/notifications').catch(() => ({ data: { unread_count: 0 } })),
      ]).then(([clientsRes, contractsRes, paymentsRes, meetingsRes, notifRes]) => {
        setClients(clientsRes.data.clients?.data || clientsRes.data.clients || []);
        setAllContracts(contractsRes.data.contracts?.data || contractsRes.data.contracts || []);
        setAllPayments(paymentsRes.data.payments?.data || paymentsRes.data.payments || []);
        setAllMeetings(meetingsRes.data.meetings?.data || meetingsRes.data.meetings || []);
        setUnreadCount(notifRes.data.unread_count || 0);
      }).finally(() => setLoading(false));
    }
  }, [isSA]);

  if (loading) return <div className="text-center py-20 text-[var(--color-text-secondary)]">{t('title')}</div>;

  if (isSA) {
    if (view === 'meetings' || view === 'payments' || view === 'files' || view === 'contracts') {
      return <SAListView t={t} locale={locale} view={view} clients={clients} allContracts={allContracts} allPayments={allPayments} managers={managers} />;
    }
    return <SAManagersView
      t={t} locale={locale} managers={managers} allContracts={allContracts}
      allPayments={allPayments} allMeetings={allMeetings} pendingApprovals={pendingApprovals} unreadCount={unreadCount}
    />;
  }

  if (view === 'meetings' || view === 'payments' || view === 'files' || view === 'contracts') {
    return <AMListView t={t} locale={locale} view={view} clients={clients} allContracts={allContracts} allPayments={allPayments} />;
  }

  return <AMView
    t={t} locale={locale} clients={clients} allContracts={allContracts}
    allPayments={allPayments} allMeetings={allMeetings} unreadCount={unreadCount}
  />;
}

function AMView({ t, locale, clients, allContracts, allPayments, allMeetings, unreadCount }: {
  t: any; locale: string; clients: Client[]; allContracts: Contract[];
  allPayments: Payment[]; allMeetings: Meeting[]; unreadCount: number;
}) {
  const router = useRouter();
  const totalClients = clients.length;
  const activeContracts = allContracts.filter(c => c.status === 'company_approved' || c.status === 'completed').length;
  const pendingContractsCount = allContracts.filter(c => c.status === 'sent' || c.status === 'client_approved').length;
  const pendingPaymentsCount = allPayments.filter(p => p.status === 'pending').length;

  const activityItems: ActivityItem[] = [];
  const approvedContracts = allContracts.filter(c => c.status === 'company_approved').slice(0, 2);
  approvedContracts.forEach(c => {
    activityItems.push({ color: 'green', text: `اعتُمد عقد <b>${c.workspace?.client?.company_name || 'عميل'}</b>`, time: timeAgo(c.created_at || new Date().toISOString(), locale) });
  });
  const pendingContracts = allContracts.filter(c => c.status === 'sent' || c.status === 'client_approved').slice(0, 2);
  pendingContracts.forEach(c => {
    activityItems.push({ color: 'red', text: `عقد <b>${c.workspace?.client?.company_name || 'عميل'}</b> بانتظار المراجعة`, time: timeAgo(c.created_at || new Date().toISOString(), locale) });
  });
  const recentPayments = allPayments.slice(0, 2);
  recentPayments.forEach(p => {
    activityItems.push({ color: 'gold', text: `دفعة <b>${Number(p.amount).toLocaleString()} ${p.currency || 'SAR'}</b> من <b>${p.workspace?.client?.company_name || 'عميل'}</b>`, time: timeAgo(p.created_at, locale) });
  });
  const recentMeetings = allMeetings.slice(0, 1);
  recentMeetings.forEach(m => {
    activityItems.push({ color: 'blue', text: `اجتماع <b>${m.title}</b> مع <b>${m.workspace?.client?.company_name || 'عميل'}</b>`, time: timeAgo(m.created_at || m.scheduled_at, locale) });
  });
  activityItems.sort((a, b) => 0).slice(0, 5);

  return (
    <div className="rounded-xl border border-[var(--border)] overflow-hidden" style={{ minHeight: '640px' }}>
      <div className="p-5">
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 mb-5">
          <DashboardStatCard label={t('my_clients')} value={totalClients} icon="👥" color="crimson" subtitle={`+2 ${t('subtitle_this_month')}`} />
          <DashboardStatCard label={t('active_contracts')} value={activeContracts} icon="📄" subtitle={`${pendingContractsCount} ${locale === 'ar' ? 'تنتظر رد' : 'awaiting response'}`} />
          <DashboardStatCard label={t('pending_payments')} value={pendingPaymentsCount} icon="💳" color="gold" subtitle={t('subtitle_needs_action')} />
          <DashboardStatCard label={t('unread_messages')} value={unreadCount} icon="💬" color="crimson" subtitle={t('subtitle_from_clients', { count: 3 })} />
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-[1.4fr_1fr] gap-3.5">
          <div className="bg-[var(--color-card-bg)] border border-[var(--border)] rounded-xl overflow-hidden">
            <div className="flex items-center justify-between px-4 py-3 border-b border-[var(--border)]">
              <span className="text-[12.5px] font-bold">{t('my_clients')}</span>
              <Link href="/dashboard/clients" className="text-[10.5px] text-[var(--color-gold)]">{t('view_all')}</Link>
            </div>
            <table className="w-full">
              <thead>
                <tr>
                  <th className="text-right text-[10px] text-[var(--color-text-secondary)] uppercase tracking-[0.5px] px-3.5 py-2 border-b border-[var(--border)]">{t('col_client')}</th>
                  <th className="text-right text-[10px] text-[var(--color-text-secondary)] uppercase tracking-[0.5px] px-3.5 py-2 border-b border-[var(--border)]">{t('col_status')}</th>
                  <th className="text-right text-[10px] text-[var(--color-text-secondary)] uppercase tracking-[0.5px] px-3.5 py-2 border-b border-[var(--border)]">{t('col_last_contact')}</th>
                </tr>
              </thead>
              <tbody>
                {clients.slice(0, 5).map((c, i) => (
                  <tr key={c.id} className="row-slide hover:bg-white/[0.025] cursor-pointer" style={{ animationDelay: `${(i + 1) * 50}ms` }}
                    onClick={() => router.push(`/dashboard/clients/${c.id}`)}>
                    <td className="px-3.5 py-2.5 border-b border-white/[0.04]">
                      <div className="flex items-center gap-2">
                        {c.avatar_url ? (
                          <img src={resolveFileUrl(c.avatar_url)} alt="" className="w-[26px] h-[26px] rounded-full object-cover border border-[var(--border)] flex-shrink-0" />
                        ) : (
                          <div className="w-[26px] h-[26px] rounded-full bg-[var(--color-crimson-soft)] border border-[var(--color-crimson-border)] flex items-center justify-center text-[9.5px] font-bold text-[var(--color-gold)] flex-shrink-0">
                            {c.company_name?.slice(0, 2) || '؟'}
                          </div>
                        )}
                        <div>
                          <div className="text-[11.5px] font-bold">{c.company_name}</div>
                          <div className="text-[9.5px] text-[var(--color-text-secondary)]">{c.contact_person}</div>
                        </div>
                      </div>
                    </td>
                    <td className="px-3.5 py-2.5 border-b border-white/[0.04]">
                      <StatusBadge status={c.workspace?.status || c.status} />
                    </td>
                    <td className="px-3.5 py-2.5 border-b border-white/[0.04] text-[10px] text-[var(--color-text-secondary)]">
                      {timeAgo(c.updated_at, locale)}
                    </td>
                  </tr>
                ))}
              </tbody>
            </table>
          </div>

          <div className="bg-[var(--color-card-bg)] border border-[var(--border)] rounded-xl overflow-hidden">
            <div className="px-4 py-3 border-b border-[var(--border)]">
              <span className="text-[12.5px] font-bold">{t('recent_activity')}</span>
            </div>
            <ActivityFeed items={activityItems} />
          </div>
        </div>
      </div>
    </div>
  );
}

function SAManagersView({ t, locale, managers, allContracts, allPayments, allMeetings, pendingApprovals, unreadCount }: {
  t: any; locale: string; managers: Manager[]; allContracts: Contract[];
  allPayments: Payment[]; allMeetings: Meeting[]; pendingApprovals: Approval[]; unreadCount: number;
}) {
  const totalClients = managers.reduce((sum, m) => sum + (m.managed_clients_count || 0), 0);
  const activeContracts = allContracts.filter(c => c.status === 'company_approved' || c.status === 'completed').length;
  const monthlyRevenue = allPayments.reduce((sum, p) => sum + Number(p.amount || 0), 0);

  const activityItems: ActivityItem[] = [];
  const approvedContracts = allContracts.filter(c => c.status === 'company_approved').slice(0, 2);
  approvedContracts.forEach(c => {
    activityItems.push({ color: 'green', text: `عقد <b>${c.workspace?.client?.company_name || '#' + c.id}</b> اعتُمد`, time: timeAgo(c.created_at || new Date().toISOString(), locale) });
  });
  const clientApprovedContracts = allContracts.filter(c => c.status === 'client_approved').slice(0, 2);
  clientApprovedContracts.forEach(c => {
    activityItems.push({ color: 'gold', text: `عميل <b>${c.workspace?.client?.company_name || '#' + c.id}</b> وافق على العقد`, time: timeAgo(c.created_at || new Date().toISOString(), locale) });
  });
  const sentContracts = allContracts.filter(c => c.status === 'sent').slice(0, 1);
  sentContracts.forEach(c => {
    activityItems.push({ color: 'blue', text: `تم إرسال عقد <b>${c.workspace?.client?.company_name || '#' + c.id}</b>`, time: timeAgo(c.created_at || new Date().toISOString(), locale) });
  });
  const recentPayments = allPayments.slice(0, 2);
  recentPayments.forEach(p => {
    activityItems.push({ color: 'gold', text: `دفعة <b>${Number(p.amount).toLocaleString()} ${p.currency || 'SAR'}</b> من <b>${p.workspace?.client?.company_name || 'عميل'}</b>`, time: timeAgo(p.created_at, locale) });
  });
  const recentMeetings = allMeetings.slice(0, 2);
  recentMeetings.forEach(m => {
    activityItems.push({ color: 'blue', text: `اجتماع <b>${m.title}</b>${m.workspace?.client?.company_name ? ` مع <b>${m.workspace.client.company_name}</b>` : ''}`, time: timeAgo(m.created_at || m.scheduled_at, locale) });
  });

  const [expandedManager, setExpandedManager] = useState<number | null>(null);
  const [managerClients, setManagerClients] = useState<Client[]>([]);
  const [managerClientsLoading, setManagerClientsLoading] = useState(false);

  const toggleManager = async (managerId: number) => {
    if (expandedManager === managerId) {
      setExpandedManager(null);
      setManagerClients([]);
      return;
    }
    setExpandedManager(managerId);
    setManagerClientsLoading(true);
    try {
      const { data } = await api.get(`/account-managers/${managerId}`);
      setManagerClients(data.clients || []);
    } catch {
      setManagerClients([]);
    } finally {
      setManagerClientsLoading(false);
    }
  };

  return (
    <div className="rounded-xl border border-[var(--border)] overflow-hidden" style={{ minHeight: '640px' }}>
      <div className="p-5">
        <div className="grid grid-cols-2 lg:grid-cols-4 gap-3 mb-5">
          <DashboardStatCard label={t('total_clients')} value={totalClients} icon="👥" subtitle={`+6 ${t('subtitle_this_month')}`} />
          <DashboardStatCard label={t('active_contracts')} value={activeContracts} icon="📄" subtitle={`+3 ${t('subtitle_this_week')}`} />
          <DashboardStatCard label={t('monthly_revenue')} value={`${(monthlyRevenue / 1000).toFixed(0)}K`} icon="💰" color="gold" subtitle={`+12% ${locale === 'ar' ? 'عن الشهر السابق' : 'vs last month'}`} />
          <DashboardStatCard label={t('pending_approvals')} value={pendingApprovals.length} icon="⏳" color="red" subtitle={t('subtitle_urgent')} />
        </div>

        <div className="grid grid-cols-1 lg:grid-cols-[1.4fr_1fr] gap-3.5">
          <div className="bg-[var(--color-card-bg)] border border-[var(--border)] rounded-xl overflow-hidden">
            <div className="flex items-center justify-between px-4 py-3 border-b border-[var(--border)]">
              <span className="text-[12.5px] font-bold">{t('managers')}</span>
              <Link href="/dashboard/account-managers" className="text-[10.5px] text-[var(--color-gold)]">{t('manage')}</Link>
            </div>
            <table className="w-full">
              <thead>
                <tr>
                  <th className="text-right text-[10px] text-[var(--color-text-secondary)] uppercase tracking-[0.5px] px-3.5 py-2 border-b border-[var(--border)]">{t('col_manager')}</th>
                  <th className="text-right text-[10px] text-[var(--color-text-secondary)] uppercase tracking-[0.5px] px-3.5 py-2 border-b border-[var(--border)]">{t('col_clients')}</th>
                  <th className="text-right text-[10px] text-[var(--color-text-secondary)] uppercase tracking-[0.5px] px-3.5 py-2 border-b border-[var(--border)]">{t('col_pending')}</th>
                </tr>
              </thead>
              <tbody>
                {managers.map((m, i) => (
                  <ManagerTableRow
                    key={m.id} manager={m} index={i}
                    expanded={expandedManager === m.id}
                    onToggle={() => toggleManager(m.id)}
                  />
                ))}
              </tbody>
            </table>
            {expandedManager && (
              <div className="border-t border-[var(--border)] bg-white/[0.015]">
                {managerClientsLoading ? (
                  <div className="p-4 text-center text-[11px] text-[var(--color-text-secondary)]">{locale === 'ar' ? 'جاري تحميل العملاء...' : 'Loading clients...'}</div>
                ) : managerClients.length === 0 ? (
                  <div className="p-4 text-center text-[11px] text-[var(--color-text-secondary)]">{locale === 'ar' ? 'لا يوجد عملاء' : 'No clients'}</div>
                ) : (
                  <div className="divide-y divide-white/[0.04]">
                    {managerClients.map((c) => (
                      <Link
                        key={c.id}
                        href={c.workspace ? `/dashboard/clients/${c.id}` : '#'}
                        className="flex items-center gap-3 px-5 py-2.5 hover:bg-white/[0.03] transition-colors"
                      >
                        <div className="w-7 h-7 rounded-full bg-[var(--color-crimson-soft)] border border-[var(--color-crimson-border)] flex items-center justify-center text-[9px] font-bold text-[var(--color-gold)] flex-shrink-0">
                          {c.company_name?.slice(0, 2) || '?'}
                        </div>
                        <div className="flex-1 min-w-0">
                          <div className="text-[11.5px] font-bold truncate">{c.company_name}</div>
                          <div className="text-[9.5px] text-[var(--color-text-secondary)]">{c.contact_person}</div>
                        </div>
                        <StatusBadge status={c.workspace?.status || c.status} />
                      </Link>
                    ))}
                  </div>
                )}
              </div>
            )}
          </div>

          <div className="flex flex-col gap-3.5">
            {pendingApprovals.length > 0 && (
              <div className="bg-[var(--color-card-bg)] border border-[var(--border)] rounded-xl overflow-hidden">
                <div className="flex items-center justify-between px-4 py-3 border-b border-[var(--border)]">
                  <span className="text-[12.5px] font-bold">{t('pending_approvals')}</span>
                  <span className="text-[10.5px] text-[var(--color-text-secondary)]">{pendingApprovals.length}</span>
                </div>
                {pendingApprovals.slice(0, 4).map((a) => (
                  <Link
                    key={a.id}
                    href={a.workspace ? `/dashboard/clients/${a.workspace.client?.id}?tab=الموافقات` : '#'}
                    className="flex items-center gap-2.5 px-4 py-2.5 border-b border-white/[0.04] last:border-0 hover:bg-white/[0.025] transition-colors"
                  >
                    <div className="w-[3px] h-9 rounded-sm bg-[var(--color-gold)] flex-shrink-0" />
                    <div className="flex-1 min-w-0">
                      <div className="text-[12px] font-bold truncate">{a.title}</div>
                      <div className="text-[10px] text-[var(--color-text-secondary)] truncate">
                        {a.workspace?.client?.company_name || ''} — {timeAgo(a.created_at, locale)}
                      </div>
                    </div>
                    <span className="px-2 py-0.5 rounded-full text-[9px] font-semibold bg-[var(--color-gold-soft)] text-[var(--color-gold)] flex-shrink-0">
                      {locale === 'ar' ? 'انتظار' : 'Pending'}
                    </span>
                  </Link>
                ))}
              </div>
            )}

            <div className="bg-[var(--color-card-bg)] border border-[var(--border)] rounded-xl overflow-hidden flex-1">
              <div className="px-4 py-3 border-b border-[var(--border)]">
                <span className="text-[12.5px] font-bold">{t('recent_activity')}</span>
              </div>
              <ActivityFeed items={activityItems} />
            </div>
          </div>
        </div>
      </div>
    </div>
  );
}

function AMListView({ t, locale, view, clients, allContracts, allPayments }: {
  t: any; locale: string; view: string; clients: Client[];
  allContracts: Contract[]; allPayments: Payment[];
}) {
  const router = useRouter();
  const [page, setPage] = useState(1);
  const [apiItems, setApiItems] = useState<any[]>([]);
  const [apiMeta, setApiMeta] = useState<{ lastPage: number; total: number } | null>(null);
  const [apiLoading, setApiLoading] = useState(false);

  const fetchPaginated = useCallback(async (viewType: string, pageNum: number) => {
    setApiLoading(true);
    try {
      let endpoint = '';
      if (viewType === 'meetings') endpoint = `/all-meetings?page=${pageNum}&per_page=10`;
      else if (viewType === 'payments') endpoint = `/all-payments?page=${pageNum}&per_page=10`;
      else if (viewType === 'files') endpoint = `/all-files?page=${pageNum}&per_page=10`;
      if (!endpoint) { setApiLoading(false); return; }

      const res = await api.get(endpoint);
      const key = viewType === 'meetings' ? 'meetings' : viewType === 'payments' ? 'payments' : 'files';
      const paginated: PaginatedResponse<any> = res.data[key] || { data: [], last_page: 1, total: 0 };
      setApiItems(paginated.data || []);
      setApiMeta({ lastPage: paginated.last_page, total: paginated.total });
    } catch {
      setApiItems([]);
      setApiMeta(null);
    } finally {
      setApiLoading(false);
    }
  }, []);

  useEffect(() => {
    setPage(1);
    if (view === 'meetings' || view === 'payments' || view === 'files') {
      fetchPaginated(view, 1);
    }
  }, [view, fetchPaginated]);

  useEffect(() => {
    if (view === 'meetings' || view === 'payments' || view === 'files') {
      fetchPaginated(view, page);
    }
  }, [page, view, fetchPaginated]);

  const isPaginated = view === 'meetings' || view === 'payments' || view === 'files';

  const staticViewConfig: Record<string, { title: string; icon: string; items: any[]; headers: string[]; getLink: (item: any) => string; renderRow: (item: any, locale: string) => React.ReactNode }> = {
    contracts: {
      title: t('contracts_nav'),
      icon: '📄',
      items: allContracts,
      headers: [t('col_client'), locale === 'ar' ? 'العنوان' : 'Title', locale === 'ar' ? 'النوع' : 'Type', t('col_value'), locale === 'ar' ? 'التاريخ' : 'Date', t('col_status')],
      getLink: (c: Contract) => `/dashboard/clients/${c.workspace?.client?.id}?tab=العقود`,
      renderRow: (c: Contract, loc: string) => (
        <>
          <td className="px-3.5 py-2.5 border-b border-white/[0.04]">
            <div className="flex items-center gap-2">
              <div className="w-7 h-7 rounded-full bg-[var(--color-crimson-soft)] border border-[var(--color-crimson-border)] flex items-center justify-center text-[9px] font-bold text-[var(--color-gold)] flex-shrink-0">
                {c.workspace?.client?.company_name?.slice(0, 2) || '?'}
              </div>
              <span className="text-[11.5px] font-bold truncate max-w-[120px]">{c.workspace?.client?.company_name || '—'}</span>
            </div>
          </td>
          <td className="px-3.5 py-2.5 border-b border-white/[0.04] text-[11px] text-[var(--color-text-secondary)] truncate max-w-[140px]">{c.title}</td>
          <td className="px-3.5 py-2.5 border-b border-white/[0.04]">
            <span className={`px-2 py-0.5 rounded-full text-[9px] font-semibold ${
              c.contract_type === 'main' || c.contract_type === null
                ? 'bg-[var(--color-gold-soft)] text-[var(--color-gold)] border border-[var(--color-gold-border)]'
                : 'bg-blue-900/30 text-blue-400'
            }`}>
              {c.contract_type === 'main' || c.contract_type === null ? (loc === 'ar' ? 'أساسي' : 'Main') : (loc === 'ar' ? 'إضافي' : 'Additional')}
            </span>
          </td>
          <td className="px-3.5 py-2.5 border-b border-white/[0.04] text-[11px] text-[var(--color-gold)]" style={{ fontFamily: "'Playfair Display', serif" }}>
            {Number(c.value).toLocaleString()} {c.currency}
          </td>
          <td className="px-3.5 py-2.5 border-b border-white/[0.04] text-[10px] text-[var(--color-text-secondary)]">{c.created_at ? formatDate(c.created_at, loc) : '—'}</td>
          <td className="px-3.5 py-2.5 border-b border-white/[0.04]"><StatusBadge status={c.status} /></td>
        </>
      ),
    },
  };

  const getDynamicConfig = (viewType: string, items: any[]): { title: string; icon: string; headers: string[]; getLink: (item: any) => string; renderRow: (item: any, locale: string) => React.ReactNode } | null => {
    if (viewType === 'meetings') return {
      title: t('meetings_nav'), icon: '📅',
      headers: [t('col_client'), locale === 'ar' ? 'العنوان' : 'Title', locale === 'ar' ? 'التاريخ والوقت' : 'Date & Time', locale === 'ar' ? 'المدة' : 'Duration', locale === 'ar' ? 'الحالة' : 'Status'],
      getLink: (m: Meeting) => `/dashboard/clients/${m.workspace?.client?.id}?tab=الاجتماعات`,
      renderRow: (m: Meeting, loc: string) => (
        <>
          <td className="px-3.5 py-2.5 border-b border-white/[0.04]">
            <div className="flex items-center gap-2">
              <div className="w-7 h-7 rounded-full bg-[var(--color-crimson-soft)] border border-[var(--color-crimson-border)] flex items-center justify-center text-[9px] font-bold text-[var(--color-gold)] flex-shrink-0">
                {m.workspace?.client?.company_name?.slice(0, 2) || '?'}
              </div>
              <span className="text-[11.5px] font-bold truncate max-w-[120px]">{m.workspace?.client?.company_name || '—'}</span>
            </div>
          </td>
          <td className="px-3.5 py-2.5 border-b border-white/[0.04] text-[11px] text-[var(--color-text-secondary)] truncate max-w-[140px]">{m.title}</td>
          <td className="px-3.5 py-2.5 border-b border-white/[0.04]">
            <div className="text-[11px]">{formatDate(m.scheduled_at, loc)}</div>
            <div className="text-[10px] text-[var(--color-text-secondary)]">{formatTime(m.scheduled_at, loc)}</div>
          </td>
          <td className="px-3.5 py-2.5 border-b border-white/[0.04] text-[11px] text-[var(--color-text-secondary)]">{m.duration_minutes} {locale === 'ar' ? 'دقيقة' : 'min'}</td>
          <td className="px-3.5 py-2.5 border-b border-white/[0.04]">
            <span className={`px-2 py-0.5 rounded-full text-[9.5px] font-semibold ${
              m.status === 'completed' ? 'bg-green-900/30 text-green-400' :
              m.status === 'cancelled' ? 'bg-red-900/30 text-red-400' :
              'bg-blue-900/30 text-blue-400'
            }`}>
              {m.status === 'completed' ? '✓ ' + (loc === 'ar' ? 'تم' : 'Done') :
               m.status === 'cancelled' ? '✕ ' + (loc === 'ar' ? 'ملغي' : 'Cancelled') :
               '● ' + (loc === 'ar' ? 'قادم' : 'Upcoming')}
            </span>
          </td>
        </>
      ),
    };
    if (viewType === 'payments') return {
      title: t('payments_nav'), icon: '💳',
      headers: [t('col_client'), locale === 'ar' ? 'العقد' : 'Contract', locale === 'ar' ? 'المبلغ' : 'Amount', locale === 'ar' ? 'الطريقة' : 'Method', locale === 'ar' ? 'التاريخ والوقت' : 'Date & Time', locale === 'ar' ? 'الحالة' : 'Status'],
      getLink: (p: Payment) => `/dashboard/clients/${p.workspace?.client?.id}?tab=المدفوعات`,
      renderRow: (p: Payment, loc: string) => (
        <>
          <td className="px-3.5 py-2.5 border-b border-white/[0.04]">
            <div className="flex items-center gap-2">
              <div className="w-7 h-7 rounded-full bg-[var(--color-gold-soft)] border border-[var(--color-gold-border)] flex items-center justify-center text-[9px] font-bold text-[var(--color-gold)] flex-shrink-0">
                {p.workspace?.client?.company_name?.slice(0, 2) || '?'}
              </div>
              <span className="text-[11.5px] font-bold truncate max-w-[120px]">{p.workspace?.client?.company_name || '—'}</span>
            </div>
          </td>
          <td className="px-3.5 py-2.5 border-b border-white/[0.04] text-[11px] text-[var(--color-text-secondary)] truncate max-w-[140px]">{p.contract?.title || '—'}</td>
          <td className="px-3.5 py-2.5 border-b border-white/[0.04] text-[11px] text-[var(--color-gold)]" style={{ fontFamily: "'Playfair Display', serif" }}>
            {Number(p.amount).toLocaleString()} {p.currency || 'SAR'}
          </td>
          <td className="px-3.5 py-2.5 border-b border-white/[0.04] text-[11px] text-[var(--color-text-secondary)]">{p.method_type}</td>
          <td className="px-3.5 py-2.5 border-b border-white/[0.04]">
            <div className="text-[11px]">{formatDate(p.created_at, loc)}</div>
            <div className="text-[10px] text-[var(--color-text-secondary)]">{formatTime(p.created_at, loc)}</div>
          </td>
          <td className="px-3.5 py-2.5 border-b border-white/[0.04]"><StatusBadge status={p.status} /></td>
        </>
      ),
    };
    if (viewType === 'files') return {
      title: t('files_nav'), icon: '📁',
      headers: [t('col_client'), locale === 'ar' ? 'الملف' : 'File', locale === 'ar' ? 'النوع' : 'Type', locale === 'ar' ? 'الحجم' : 'Size', locale === 'ar' ? 'التاريخ' : 'Date'],
      getLink: (f: FileFile) => `/dashboard/clients/${f.workspace?.client?.id}?tab=الملفات`,
      renderRow: (f: FileFile, loc: string) => (
        <>
          <td className="px-3.5 py-2.5 border-b border-white/[0.04]">
            <div className="flex items-center gap-2">
              <div className="w-7 h-7 rounded-full bg-[var(--color-crimson-soft)] border border-[var(--color-crimson-border)] flex items-center justify-center text-[9px] font-bold text-[var(--color-gold)] flex-shrink-0">
                {f.workspace?.client?.company_name?.slice(0, 2) || '?'}
              </div>
              <span className="text-[11.5px] font-bold truncate max-w-[120px]">{f.workspace?.client?.company_name || '—'}</span>
            </div>
          </td>
          <td className="px-3.5 py-2.5 border-b border-white/[0.04]">
            <div className="text-[11px] font-bold truncate max-w-[160px]">{f.name}</div>
            <div className="text-[10px] text-[var(--color-text-secondary)]">{f.uploaded_by?.name || ''}</div>
          </td>
          <td className="px-3.5 py-2.5 border-b border-white/[0.04] text-[11px] text-[var(--color-text-secondary)]">{f.type || '—'}</td>
          <td className="px-3.5 py-2.5 border-b border-white/[0.04] text-[11px] text-[var(--color-text-secondary)]">{formatFileSize(f.size, loc)}</td>
          <td className="px-3.5 py-2.5 border-b border-white/[0.04] text-[10px] text-[var(--color-text-secondary)]">{formatDate(f.created_at, loc)}</td>
        </>
      ),
    };
    return null;
  };

  const dynConfig = getDynamicConfig(view, apiItems);
  const statConfig = staticViewConfig[view];

  const items = isPaginated ? apiItems : (statConfig?.items || []);
  const lastPage = isPaginated ? (apiMeta?.lastPage || 1) : 1;
  const total = isPaginated ? (apiMeta?.total || 0) : (statConfig?.items.length || 0);
  const config = dynConfig || statConfig;
  if (!config) return null;

  return (
    <div className="rounded-xl border border-[var(--border)] overflow-hidden" style={{ minHeight: '640px' }}>
      <div className="p-5">
        <div className="bg-[var(--color-card-bg)] border border-[var(--border)] rounded-xl overflow-hidden">
          <div className="flex items-center justify-between px-4 py-3 border-b border-[var(--border)]">
            <div className="flex items-center gap-2">
              <span className="text-base">{config.icon}</span>
              <span className="text-[12.5px] font-bold">{config.title}</span>
              <span className="text-[10px] bg-[var(--color-card-border)] text-[var(--color-text-secondary)] px-2 py-0.5 rounded-full">{total}</span>
            </div>
            <Link href="/dashboard" className="text-[10.5px] text-[var(--color-gold)]">{locale === 'ar' ? 'العودة للرئيسية' : 'Back to Dashboard'}</Link>
          </div>
          {apiLoading ? (
            <div className="p-8 text-center text-sm text-[var(--color-text-secondary)]">{locale === 'ar' ? 'جاري التحميل...' : 'Loading...'}</div>
          ) : items.length === 0 ? (
            <div className="p-8 text-center text-sm text-[var(--color-text-secondary)]">
              {locale === 'ar' ? 'لا توجد بيانات' : 'No data'}
            </div>
          ) : (
            <>
              <table className="w-full">
                <thead>
                  <tr>
                    {config.headers.map((h: string, i: number) => (
                      <th key={i} className="text-right text-[10px] text-[var(--color-text-secondary)] uppercase tracking-[0.5px] px-3.5 py-2 border-b border-[var(--border)]">{h}</th>
                    ))}
                  </tr>
                </thead>
                <tbody>
                  {items.map((item: any, i: number) => (
                    <tr
                      key={item.id}
                      className="row-slide hover:bg-white/[0.025] cursor-pointer"
                      style={{ animationDelay: `${(i + 1) * 50}ms` }}
                      onClick={() => router.push(config.getLink(item))}
                    >
                      {config.renderRow(item, locale)}
                    </tr>
                  ))}
                </tbody>
              </table>
              {lastPage > 1 && (
                <div className="flex items-center justify-center gap-2 py-3 border-t border-[var(--border)]">
                  <button
                    disabled={page <= 1}
                    onClick={(e) => { e.stopPropagation(); setPage(p => p - 1); }}
                    className="px-3 py-1.5 rounded-lg text-[11px] border border-[var(--border)] text-[var(--color-text-secondary)] hover:bg-white/[0.04] disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
                  >
                    {locale === 'ar' ? 'السابق' : 'Previous'}
                  </button>
                  <span className="text-[11px] text-[var(--color-text-secondary)]">
                    {page} / {lastPage}
                  </span>
                  <button
                    disabled={page >= lastPage}
                    onClick={(e) => { e.stopPropagation(); setPage(p => p + 1); }}
                    className="px-3 py-1.5 rounded-lg text-[11px] border border-[var(--border)] text-[var(--color-text-secondary)] hover:bg-white/[0.04] disabled:opacity-30 disabled:cursor-not-allowed transition-colors"
                  >
                    {locale === 'ar' ? 'التالي' : 'Next'}
                  </button>
                </div>
              )}
            </>
          )}
        </div>
      </div>
    </div>
  );
}

function SAListView({ t, locale, view, clients, allContracts, allPayments, managers }: {
  t: any; locale: string; view: string; clients: Client[];
  allContracts: Contract[]; allPayments: Payment[]; managers: Manager[];
}) {
  return <AMListView t={t} locale={locale} view={view} clients={clients} allContracts={allContracts} allPayments={allPayments} />;
}

function StatusBadge({ status }: { status: string }) {
  const colors: Record<string, string> = {
    active: 'bg-green-900/30 text-green-400',
    pending: 'bg-yellow-900/30 text-yellow-400',
    sent: 'bg-blue-900/30 text-blue-400',
    client_approved: 'bg-green-900/30 text-green-400',
    company_approved: 'bg-purple-900/30 text-purple-400',
    completed: 'bg-emerald-900/30 text-emerald-400',
    draft: 'bg-zinc-700/30 text-zinc-400',
    inactive: 'bg-zinc-700/30 text-zinc-500',
    approved: 'bg-green-900/30 text-green-400',
    rejected: 'bg-red-900/30 text-red-400',
  };
  const labels: Record<string, string> = {
    active: 'مفعّل', pending: 'بانتظار الدفع', sent: 'مرسل',
    client_approved: 'بانتظار الموافقة', company_approved: 'معتمد',
    completed: 'مكتمل', draft: 'مسودة', inactive: 'غير مفعل',
    approved: 'مقبول', rejected: 'مرفوض',
  };
  return (
    <span className={`px-2 py-0.5 rounded-full text-[9.5px] font-semibold ${colors[status] || 'bg-zinc-700/30 text-zinc-400'}`}>
      {labels[status] || status}
    </span>
  );
}
