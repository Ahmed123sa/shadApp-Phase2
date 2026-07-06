'use client';

import { useEffect, useState } from 'react';
import api from '@/lib/api';
import { getUser } from '@/lib/auth';
import type { Client } from '@/types';
import { LoadingSkeleton } from '@/components/ui/LoadingSkeleton';
import { EmptyState } from '@/components/ui/EmptyState';

const FILE_BASE = process.env.NEXT_PUBLIC_API_URL?.replace('/api', '') || 'http://localhost:8000';
function resolveFileUrl(url: string): string {
  if (!url) return '';
  if (url.startsWith('http')) return url;
  return `${FILE_BASE}/storage/${url.replace(/^\/?storage\//, '')}`;
}

export default function PaymentsTab({ wsId, client, onWorkspaceUpdate }: { wsId: number; client: Client; onWorkspaceUpdate?: (ws: any) => void }) {
  const [payments, setPayments] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const user = getUser();
  const canReview = user?.role === 'super_admin';

  useEffect(() => {
    const load = () => api.get(`/workspaces/${wsId}/payments`).then(({ data }) => {
      setPayments(data.payments?.data || data.payments || []);
    }).catch(() => {});
    load().finally(() => setLoading(false));
    const interval = setInterval(load, 30000);
    return () => clearInterval(interval);
  }, [wsId]);

  const methodLabels: Record<string, string> = {
    bank_transfer: 'تحويل بنكي', swift: 'SWIFT', corporate_account: 'حساب شركة',
    instapay: 'Instapay', vodafone_cash: 'فودافون كاش', mobile_wallet: 'محفظة موبايل',
  };

  const reviewPayment = async (pid: number, action: string) => {
    const { data } = await api.post(`/payments/${pid}/review`, { action }).catch(() => ({ data: null }));
    if (data?.payment) {
      setPayments((prev) => prev.map((p) => p.id === pid ? data.payment : p));
      if (data?.workspace && onWorkspaceUpdate) onWorkspaceUpdate(data.workspace);
    }
  };

  if (loading) return <LoadingSkeleton />;

  return (
    <div className="space-y-4">
      <p className="text-xs text-[var(--color-text-disabled)]">نسبة العميل: {client?.client_type === 'individual' ? 'فردي' : 'شركة'}</p>
      {payments.length === 0 ? <EmptyState message="لا توجد مدفوعات" /> : null}
      {payments.map((p) => (
        <div key={p.id} className="border border-[var(--color-card-border)] rounded-lg p-4 flex justify-between items-center">
          <div>
            <span className="font-medium">{p.amount} ر.س</span>
            <span className="text-xs text-[var(--color-text-disabled)] mr-3">{methodLabels[p.method_type] || p.method_type}</span>
            {p.proof_file_url && <a href={resolveFileUrl(p.proof_file_url)} target="_blank" className="text-xs text-blue-500 mr-2 hover:underline">📎 الإثبات</a>}
          </div>
          <div className="flex items-center gap-2">
            <span className={`px-2 py-0.5 rounded-full text-xs ${p.status === 'approved' ? 'bg-green-900/30 text-green-400' : p.status === 'rejected' ? 'bg-red-900/30 text-red-400' : 'bg-yellow-900/30 text-yellow-400'}`}>
              {p.status === 'approved' ? 'مقبول' : p.status === 'rejected' ? 'مرفوض' : 'معلق'}
            </span>
            {p.status === 'pending' && canReview && (
              <div className="flex gap-1">
                <button onClick={() => reviewPayment(p.id, 'approved')} className="text-xs bg-emerald-600 text-white px-3 py-1.5 rounded-lg hover:bg-emerald-700">قبول</button>
              </div>
            )}
          </div>
        </div>
      ))}
    </div>
  );
}
