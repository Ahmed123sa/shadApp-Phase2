'use client';

import { useEffect, useState } from 'react';
import api from '@/lib/api';
import { getUser } from '@/lib/auth';

const ACTION_LABELS: Record<string, string> = {
  'contract.created': 'إنشاء عقد',
  'contract.sent': 'إرسال عقد',
  'contract.client_approved': 'موافقة العميل على العقد',
  'contract.client_rejected': 'رفض العميل للعقد',
  'contract.edit_requested': 'طلب تعديل العقد',
  'contract.company_approved': 'اعتماد الشركة للعقد',
  'contract.completed': 'إكمال العقد',
  'contract.archived': 'أرشفة العقد',
  'workspace.created': 'إنشاء مساحة عمل',
  'workspace.activated': 'تفعيل مساحة العمل',
  'payment.submitted': 'تقديم دفعة',
  'payment.approved': 'اعتماد دفعة',
  'payment.rejected': 'رفض دفعة',
  'approval.created': 'إنشاء طلب موافقة',
  'approval.approved': 'الموافقة على الطلب',
  'approval.rejected': 'رفض الطلب',
  'approval.edit_requested': 'طلب تعديل الموافقة',
  'file.uploaded': 'رفع ملف',
  'file.approved': 'الموافقة على الملف',
  'file.rejected': 'رفض الملف',
  'login': 'تسجيل دخول',
  'meeting.created': 'إنشاء اجتماع',
  'client.created': 'إنشاء عميل',
  'client.deleted': 'حذف عميل',
};

const ACTION_BADGE_COLORS: Record<string, string> = {
  'contract.': 'bg-blue-900/30 text-blue-400',
  'payment.': 'bg-yellow-900/30 text-yellow-400',
  'approval.': 'bg-green-900/30 text-green-400',
  'workspace.': 'bg-purple-900/30 text-purple-400',
  'file.': 'bg-zinc-700/30 text-zinc-400',
  'login': 'bg-white/10 text-white',
  'client.': 'bg-red-900/30 text-red-400',
  'meeting.': 'bg-blue-900/30 text-blue-400',
};

function getActionBadgeColor(action: string): string {
  for (const [prefix, color] of Object.entries(ACTION_BADGE_COLORS)) {
    if (action.startsWith(prefix)) return color;
  }
  return 'bg-zinc-700/30 text-zinc-400';
}

function resolveClientName(log: any): string {
  const auditable = log.auditable;
  if (!auditable) return '—';

  const type = log.auditable_type || '';
  if (type.includes('Client')) return auditable.company_name || '—';
  if (type.includes('Contract') || type.includes('Payment') || type.includes('Meeting') || type.includes('Approval') || type.includes('FileEntry')) {
    return auditable.workspace?.client?.company_name || '—';
  }
  if (type.includes('Workspace')) return auditable.client?.company_name || '—';
  return '—';
}

function formatDateTime(dateStr: string): string {
  if (!dateStr) return '—';
  const d = new Date(dateStr);
  const date = d.toLocaleDateString('ar-SA', { year: 'numeric', month: 'short', day: 'numeric' });
  const time = d.toLocaleTimeString('ar-SA', { hour: '2-digit', minute: '2-digit' });
  return `${date} ${time}`;
}

export default function AuditLogPage() {
  const [logs, setLogs] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);
  const [filters, setFilters] = useState({ action: '', user_id: '', date_from: '', date_to: '' });
  const [users, setUsers] = useState<any[]>([]);
  const isSA = getUser()?.role === 'super_admin';

  const fetchLogs = (p: number) => {
    setLoading(true);
    const params = new URLSearchParams();
    Object.entries(filters).forEach(([key, value]) => { if (value) params.set(key, value); });
    params.set('page', String(p));
    api.get(`/audit-logs?${params.toString()}`).then((res) => {
      const paginated = res.data?.logs;
      setLogs(paginated?.data || []);
      setTotalPages(paginated?.last_page || 1);
    }).catch(() => {}).finally(() => setLoading(false));
  };

  useEffect(() => {
    fetchLogs(1);
    setPage(1);
    api.get('/users').then(({ data }) => setUsers(Array.isArray(data) ? data : data.users || [])).catch(() => {});
  }, []);

  const applyFilters = () => { setPage(1); fetchLogs(1); };

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <h2 className="text-xl font-bold" style={{ fontFamily: "'Playfair Display', serif" }}>سجل التدقيق</h2>
        <span className="text-xs text-[var(--color-text-secondary)]">{logs.length} سجل</span>
      </div>

      <div className="flex gap-2 items-center flex-wrap">
        <select value={filters.action} onChange={(e) => setFilters({ ...filters, action: e.target.value })}
          className="bg-white/[0.04] border border-[var(--border)] rounded-lg px-3 py-2 text-sm text-[var(--color-foreground)]">
          <option value="">كل الأحداث</option>
          {Object.entries(ACTION_LABELS).map(([key, label]) => (
            <option key={key} value={key}>{label}</option>
          ))}
        </select>
        <select value={filters.user_id} onChange={(e) => setFilters({ ...filters, user_id: e.target.value })}
          className="bg-white/[0.04] border border-[var(--border)] rounded-lg px-3 py-2 text-sm text-[var(--color-foreground)]">
          <option value="">كل المستخدمين</option>
          {users.map((u: any) => (
            <option key={u.id} value={u.id}>{u.name}</option>
          ))}
        </select>
        <input type="date" value={filters.date_from} onChange={(e) => setFilters({ ...filters, date_from: e.target.value })}
          className="bg-white/[0.04] border border-[var(--border)] rounded-lg px-3 py-2 text-sm text-[var(--color-foreground)]" />
        <input type="date" value={filters.date_to} onChange={(e) => setFilters({ ...filters, date_to: e.target.value })}
          className="bg-white/[0.04] border border-[var(--border)] rounded-lg px-3 py-2 text-sm text-[var(--color-foreground)]" />
        <button onClick={applyFilters}
          className="bg-[var(--color-primary)] text-white px-4 py-2 rounded-lg text-sm hover:bg-[var(--color-primary-dark)] transition-colors">
          تطبيق
        </button>
      </div>

      <div className="bg-[var(--color-card)] rounded-xl border border-[var(--color-card-border)] overflow-hidden">
        {loading ? (
          <div className="p-8 text-center text-sm text-[var(--color-text-secondary)]">جاري التحميل...</div>
        ) : logs.length === 0 ? (
          <div className="p-8 text-center text-sm text-[var(--color-text-secondary)]">لا توجد سجلات</div>
        ) : (
          <>
            <table className="w-full text-sm">
              <thead className="bg-[var(--color-card-border)] border-b border-[var(--color-card-border)]">
                <tr>
                  <th className="text-right p-3 font-medium text-xs">التاريخ</th>
                  <th className="text-right p-3 font-medium text-xs">المستخدم</th>
                  <th className="text-right p-3 font-medium text-xs">الحدث</th>
                  {isSA && <th className="text-right p-3 font-medium text-xs">العميل</th>}
                </tr>
              </thead>
              <tbody>
                {logs.map((log) => (
                  <tr key={log.id} className="border-b border-[var(--color-card-border)] last:border-0 hover:bg-[var(--color-card-border)]">
                    <td className="p-3 text-xs text-[var(--color-text-secondary)] whitespace-nowrap">
                      {formatDateTime(log.created_at)}
                    </td>
                    <td className="p-3">
                      <div className="flex items-center gap-2">
                        <div className="w-6 h-6 rounded-full bg-[var(--color-input-fill)] flex items-center justify-center text-[9px] font-bold text-[var(--color-text-secondary)] flex-shrink-0">
                          {log.user?.name?.slice(0, 2) || '?'}
                        </div>
                        <span className="text-xs font-medium">{log.user?.name || '—'}</span>
                      </div>
                    </td>
                    <td className="p-3">
                      <span className={`px-2 py-0.5 rounded-full text-[10px] font-semibold ${getActionBadgeColor(log.action)}`}>
                        {ACTION_LABELS[log.action] || log.action}
                      </span>
                    </td>
                    {isSA && (
                      <td className="p-3 text-xs text-[var(--color-text-secondary)]">
                        {resolveClientName(log)}
                      </td>
                    )}
                  </tr>
                ))}
              </tbody>
            </table>
            {totalPages > 1 && (
              <div className="flex items-center justify-center gap-2 p-3 border-t border-[var(--color-card-border)]">
                <button onClick={() => { const p = page - 1; setPage(p); fetchLogs(p); }} disabled={page <= 1}
                  className="px-3 py-1.5 text-xs rounded border border-[var(--color-card-border)] hover:bg-[var(--color-card-border)] disabled:opacity-40 transition-colors">السابق</button>
                <span className="text-xs text-[var(--color-text-secondary)]">الصفحة {page} من {totalPages}</span>
                <button onClick={() => { const p = page + 1; setPage(p); fetchLogs(p); }} disabled={page >= totalPages}
                  className="px-3 py-1.5 text-xs rounded border border-[var(--color-card-border)] hover:bg-[var(--color-card-border)] disabled:opacity-40 transition-colors">التالي</button>
              </div>
            )}
          </>
        )}
      </div>
    </div>
  );
}
