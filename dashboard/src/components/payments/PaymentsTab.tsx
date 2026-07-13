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
  const [contracts, setContracts] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const user = getUser();
  const canReview = user?.role === 'super_admin';

  useEffect(() => {
    const load = () => {
      Promise.all([
        api.get(`/workspaces/${wsId}/payments`),
        api.get(`/workspaces/${wsId}/contracts`),
      ]).then(([payRes, contRes]) => {
        setPayments(payRes.data.payments?.data || payRes.data.payments || []);
        const raw = contRes.data.contracts;
        setContracts(Array.isArray(raw) ? raw : (raw?.data || []));
      }).catch(() => {});
    };
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

  const payableContract = contracts.find((c: any) => c.status === 'company_approved' || c.status === 'completed');
  const contractValue = payableContract ? Number(payableContract.value) : 0;
  const contractCurrency = payableContract?.currency || 'SAR';
  const totalPaid = payments.filter(p => p.status === 'approved').reduce((s, p) => s + Number(p.amount), 0);
  const grandTotal = contractValue > 0 ? contractValue : payments.reduce((s, p) => s + Number(p.amount), 0);
  const remaining = grandTotal - totalPaid;
  const isFullyPaid = grandTotal > 0 && totalPaid >= grandTotal;
  const progress = grandTotal > 0 ? Math.min(totalPaid / grandTotal, 1) : 0;

  const installmentLabels = ['الأولى', 'الثانية', 'الثالثة', 'الرابعة', 'الخامسة', 'السادسة', 'السابعة', 'الثامنة', 'التاسعة', 'العاشرة'];
  const installmentName = (i: number) => i < installmentLabels.length ? `دفعة ${installmentLabels[i]}` : `دفعة ${i + 1}`;

  return (
    <div className="space-y-4">
      {/* ملخص الدفعات */}
      <div className="bg-[#0d0d0d] border border-[var(--color-card-border)] rounded-xl p-4">
        {isFullyPaid ? (
          <>
            <div className="flex items-center gap-2 mb-2">
              <span className="text-green-400 text-lg">✅</span>
              <p className="text-sm font-bold text-green-400">تم الدفع بالكامل</p>
            </div>
            <p className="text-2xl font-bold text-[var(--color-gold)]" style={{ fontFamily: "'Playfair Display', serif" }}>
              {totalPaid.toFixed(2)} {contractCurrency}
            </p>
          </>
        ) : (
          <>
            <p className="text-xs text-[var(--color-gold)] font-medium">إجمالي المدفوع</p>
            <p className="text-2xl font-bold text-[var(--color-gold)] mt-1" style={{ fontFamily: "'Playfair Display', serif" }}>
              {totalPaid.toFixed(2)} {contractCurrency}
            </p>
            <p className="text-xs text-[var(--color-text-disabled)] mt-0.5">
              من أصل {grandTotal.toFixed(2)} {contractCurrency} — متبقي {remaining.toFixed(2)}
            </p>
          </>
        )}
        <div className="mt-3">
          <div className="w-full h-1.5 bg-[var(--color-card-border)] rounded-full overflow-hidden">
            <div className={`h-full rounded-full transition-all ${isFullyPaid ? 'bg-green-500' : 'bg-[var(--color-gold)]'}`} style={{ width: `${progress * 100}%` }} />
          </div>
        </div>
      </div>

      <p className="text-xs text-[var(--color-text-disabled)]">نسبة العميل: {client?.client_type === 'individual' ? 'فردي' : 'شركة'}</p>
      {payments.length === 0 ? <EmptyState message="لا توجد مدفوعات" /> : null}
      {payments.map((p, idx) => (
        <div key={p.id} className="border border-[var(--color-card-border)] rounded-lg p-4 flex justify-between items-center">
          <div>
            <div className="flex items-center gap-2">
              <span className="text-xs text-[var(--color-gold)] font-medium">{installmentName(idx)}</span>
              <span className="font-medium">{p.amount} {p.currency || contractCurrency}</span>
            </div>
            <span className="text-xs text-[var(--color-text-disabled)] mr-3">{methodLabels[p.method_type] || p.method_type}</span>
            {p.contract?.title && <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">📄 {p.contract.title}</p>}
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
