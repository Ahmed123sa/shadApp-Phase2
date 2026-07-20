'use client';

import { useEffect, useState } from 'react';
import api from '@/lib/api';
import Link from 'next/link';
import { BarChart, Bar, XAxis, YAxis, Tooltip, ResponsiveContainer, AreaChart, Area, Cell } from 'recharts';
import DashboardStatCard from '@/components/dashboard/DashboardStatCard';

const STATUS_LABELS: Record<string, string> = {
  draft: 'مسودة', sent: 'مرسل', client_approved: 'موافقة عميل', client_rejected: 'رفض عميل',
  company_approved: 'موافقة شركة', completed: 'مكتمل', archived: 'مؤرشف',
};

const STATUS_COLORS: Record<string, string> = {
  draft: '#71717a', sent: '#3b82f6', client_approved: '#22c55e', client_rejected: '#ef4444',
  company_approved: '#a855f7', completed: '#10b981', archived: '#6b7280',
};

const SUMMARY_CONFIG: Record<string, { label: string; icon: string; color?: string }> = {
  total_clients: { label: 'إجمالي العملاء', icon: '👥', color: 'crimson' },
  active_workspaces: { label: 'مساحات العمل النشطة', icon: '🏢', color: 'blue' },
  pending_payments: { label: 'المدفوعات المعلقة', icon: '💳', color: 'gold' },
  pending_approvals: { label: 'الموافقات المعلقة', icon: '⏳', color: 'red' },
  recent_logins: { label: 'تسجيلات الدخول اليوم', icon: '🔑', color: 'green' },
};

export default function ReportsPage() {
  const [reports, setReports] = useState<any>(null);
  const [loading, setLoading] = useState(true);

  useEffect(() => {
    api.get('/reports').then(({ data }) => setReports(data)).catch(() => {}).finally(() => setLoading(false));
  }, []);

  if (loading) return <div className="text-center py-20 text-[var(--color-text-secondary)]">جاري التحميل...</div>;

  const contractsData = reports?.contracts_by_status
    ? Object.entries(reports.contracts_by_status).map(([status, count]) => ({
        status: STATUS_LABELS[status] || status,
        count,
        fill: STATUS_COLORS[status] || '#71717a',
      }))
    : [];

  const paymentsData = reports?.payments_by_month
    ? Object.entries(reports.payments_by_month).map(([month, amount]) => ({ month, amount }))
    : [];

  const approvalStats = reports?.approval_stats || { approved: 0, rejected: 0, pending: 0 };
  const totalApprovals = approvalStats.approved + approvalStats.rejected + approvalStats.pending;
  const approvalData = [
    { name: 'مقبول', value: approvalStats.approved, fill: '#22c55e' },
    { name: 'مرفوض', value: approvalStats.rejected, fill: '#ef4444' },
    { name: 'معلق', value: approvalStats.pending, fill: '#eab308' },
  ];

  const summaryKeys = Object.keys(SUMMARY_CONFIG).filter(k => reports?.[k] !== undefined);

  return (
    <div className="space-y-5">
      <div className="flex items-center justify-between">
        <h2 className="text-xl font-bold" style={{ fontFamily: "'Playfair Display', serif" }}>التقارير</h2>
        <Link href="/dashboard/audit-log" className="text-xs text-[var(--color-gold)] hover:underline">عرض سجل التدقيق ←</Link>
      </div>

      {summaryKeys.length > 0 && (
        <div className="grid grid-cols-2 lg:grid-cols-5 gap-3">
          {summaryKeys.map((key) => {
            const config = SUMMARY_CONFIG[key];
            return (
              <DashboardStatCard
                key={key}
                label={config.label}
                value={reports[key]}
                icon={config.icon}
                color={config.color as any}
              />
            );
          })}
        </div>
      )}

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-5">
        {contractsData.length > 0 && (
          <div className="bg-[var(--color-card)] rounded-xl border border-[var(--color-card-border)] p-5">
            <h3 className="font-bold text-sm mb-4">العقود حسب الحالة</h3>
            <ResponsiveContainer width="100%" height={250}>
              <BarChart data={contractsData} layout="vertical" margin={{ left: 10, right: 20 }}>
                <XAxis type="number" allowDecimals={false} tick={{ fontSize: 11, fill: '#a1a1aa' }} />
                <YAxis dataKey="status" type="category" width={100} tick={{ fontSize: 11, fill: '#a1a1aa' }} />
                <Tooltip
                  contentStyle={{ background: '#1c1c1c', border: '1px solid #333', borderRadius: 8, fontSize: 12 }}
                  labelStyle={{ color: '#fff' }}
                  formatter={(value: any) => [`${value} عقد`, 'العدد']}
                />
                <Bar dataKey="count" radius={[0, 4, 4, 0]} name="العدد">
                  {contractsData.map((entry, idx) => (
                    <Cell key={idx} fill={entry.fill} />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </div>
        )}

        {paymentsData.length > 0 && (
          <div className="bg-[var(--color-card)] rounded-xl border border-[var(--color-card-border)] p-5">
            <h3 className="font-bold text-sm mb-4">المدفوعات حسب الشهر</h3>
            <ResponsiveContainer width="100%" height={250}>
              <AreaChart data={paymentsData} margin={{ top: 5, right: 20, bottom: 5, left: 10 }}>
                <defs>
                  <linearGradient id="goldGradient" x1="0" y1="0" x2="0" y2="1">
                    <stop offset="5%" stopColor="#D4AF37" stopOpacity={0.3} />
                    <stop offset="95%" stopColor="#D4AF37" stopOpacity={0} />
                  </linearGradient>
                </defs>
                <XAxis dataKey="month" tick={{ fontSize: 11, fill: '#a1a1aa' }} />
                <YAxis tick={{ fontSize: 11, fill: '#a1a1aa' }} />
                <Tooltip
                  contentStyle={{ background: '#1c1c1c', border: '1px solid #333', borderRadius: 8, fontSize: 12 }}
                  labelStyle={{ color: '#fff' }}
                  formatter={(value: any) => [`${Number(value).toLocaleString()} ر.س`, 'المبلغ']}
                />
                <Area type="monotone" dataKey="amount" stroke="#D4AF37" strokeWidth={2} fill="url(#goldGradient)" name="المبلغ" />
              </AreaChart>
            </ResponsiveContainer>
          </div>
        )}

        {totalApprovals > 0 && (
          <div className="bg-[var(--color-card)] rounded-xl border border-[var(--color-card-border)] p-5">
            <h3 className="font-bold text-sm mb-4">إحصائيات الموافقات</h3>
            <div className="flex items-center justify-center gap-8">
              <div className="relative">
                <svg width="160" height="160" viewBox="0 0 160 160">
                  {approvalData.map((segment, i) => {
                    const radius = 60;
                    const circumference = 2 * Math.PI * radius;
                    const pct = totalApprovals > 0 ? segment.value / totalApprovals : 0;
                    const offset = approvalData.slice(0, i).reduce((sum, s) => sum + (totalApprovals > 0 ? s.value / totalApprovals : 0), 0);
                    return (
                      <circle
                        key={i}
                        cx="80" cy="80" r={radius}
                        fill="none"
                        stroke={segment.fill}
                        strokeWidth="20"
                        strokeDasharray={`${pct * circumference} ${circumference}`}
                        strokeDashoffset={`${-offset * circumference}`}
                        transform="rotate(-90 80 80)"
                      />
                    );
                  })}
                </svg>
                <div className="absolute inset-0 flex flex-col items-center justify-center">
                  <span className="text-2xl font-bold" style={{ fontFamily: "'Playfair Display', serif" }}>{totalApprovals}</span>
                  <span className="text-[10px] text-[var(--color-text-secondary)]">إجمالي</span>
                </div>
              </div>
              <div className="space-y-3">
                {approvalData.map((segment) => (
                  <div key={segment.name} className="flex items-center gap-2">
                    <div className="w-3 h-3 rounded-full" style={{ background: segment.fill }} />
                    <span className="text-xs text-[var(--color-text-secondary)]">{segment.name}</span>
                    <span className="text-xs font-bold">{segment.value}</span>
                  </div>
                ))}
              </div>
            </div>
          </div>
        )}
      </div>
    </div>
  );
}
