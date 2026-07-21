'use client';

import { useEffect, useState } from 'react';
import api from '@/lib/api';
import { getUser } from '@/lib/auth';
import type { Client } from '@/types';
import { LoadingSkeleton } from '@/components/ui/LoadingSkeleton';
import { EmptyState } from '@/components/ui/EmptyState';

type ScheduleForm = { amount: string; due_date: string; installment_label: string };

const FILE_BASE = process.env.NEXT_PUBLIC_API_URL?.replace('/api', '') || 'http://localhost:8000';
function resolveFileUrl(url: string | string[]): string {
  if (!url) return '';
  const raw = Array.isArray(url) ? (url[0] || '') : url;
  if (!raw) return '';
  if (raw.startsWith('http')) return raw;
  return `${FILE_BASE}/storage/${raw.replace(/^\/?storage\//, '')}`;
}

export default function PaymentsTab({ wsId, client, onWorkspaceUpdate }: { wsId: number; client: Client; onWorkspaceUpdate?: (ws: any) => void }) {
  const [payments, setPayments] = useState<any[]>([]);
  const [contracts, setContracts] = useState<any[]>([]);
  const [taxSummary, setTaxSummary] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [showSchedule, setShowSchedule] = useState(false);
  const [scheduleForm, setScheduleForm] = useState<ScheduleForm>({ amount: '', due_date: '', installment_label: '' });
  const [installments, setInstallments] = useState<ScheduleForm[]>([]);
  const user = getUser();
  const canReview = user?.role === 'super_admin';
  const isSA = user?.role === 'super_admin';

  useEffect(() => {
    const load = () => {
      return Promise.all([
        api.get(`/workspaces/${wsId}/payments`),
        api.get(`/workspaces/${wsId}/contracts`),
      ]).then(([payRes, contRes]) => {
        setPayments(payRes.data.payments?.data || payRes.data.payments || []);
        setTaxSummary(payRes.data.tax_summary || null);
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

  const addInstallment = () => {
    if (!scheduleForm.amount || !scheduleForm.due_date) return;
    setInstallments((prev) => [...prev, { ...scheduleForm, installment_label: scheduleForm.installment_label || `القسط ${prev.length + 1}` }]);
    setScheduleForm({ amount: '', due_date: '', installment_label: '' });
  };

  const removeInstallment = (idx: number) => setInstallments((prev) => prev.filter((_, i) => i !== idx));

  const submitSchedule = async () => {
    if (installments.length === 0) return;
    try {
      await api.post(`/workspaces/${wsId}/payments/schedule`, { installments });
      setShowSchedule(false);
      setInstallments([]);
      const { data: payRes } = await api.get(`/workspaces/${wsId}/payments`);
      setPayments(payRes.payments?.data || payRes.payments || []);
    } catch { }
  };

  const deleteSchedule = async (pid: number) => {
    if (!confirm('هل أنت متأكد من مسح هذا القسط؟')) return;
    try {
      await api.delete(`/payments/${pid}/schedule`);
      setPayments((prev) => prev.filter((p) => p.id !== pid));
    } catch { }
  };

  if (loading) return <LoadingSkeleton />;

  const payableContracts = contracts.filter((c: any) => c.status === 'company_approved' || c.status === 'completed');
  const contractValue = payableContracts.reduce((s, c) => s + Number(c.value), 0);
  const contractCurrency = payableContracts.length > 0 ? (payableContracts[0]?.currency || 'SAR') : 'SAR';
  const totalPaid = payments.filter(p => p.status === 'approved').reduce((s, p) => s + Number(p.amount), 0);
  const grandTotal = taxSummary?.grand_total != null ? Number(taxSummary.grand_total) : (contractValue > 0 ? contractValue : payments.reduce((s, p) => s + Number(p.amount), 0));
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
            {taxSummary && taxSummary.tax_percentage > 0 && (
              <p className="text-xs text-[var(--color-text-disabled)] mt-0.5">
                القيمة: {Number(taxSummary.contracts_total).toFixed(2)} + ضريبة {taxSummary.tax_percentage}% = {Number(taxSummary.tax_amount).toFixed(2)} {contractCurrency}
              </p>
            )}
          </>
        )}
        <div className="mt-3">
          <div className="w-full h-1.5 bg-[var(--color-card-border)] rounded-full overflow-hidden">
            <div className={`h-full rounded-full transition-all ${isFullyPaid ? 'bg-green-500' : 'bg-[var(--color-gold)]'}`} style={{ width: `${progress * 100}%` }} />
          </div>
        </div>
      </div>

      <p className="text-xs text-[var(--color-text-disabled)]">نسبة العميل: {client?.client_type === 'individual' ? 'فردي' : 'شركة'}</p>
      {isSA && (
        <button onClick={() => setShowSchedule(true)} className="px-4 py-2 bg-[var(--color-gold)] text-black text-sm font-medium rounded-lg hover:opacity-90 transition-opacity">
          جدولة دفعات
        </button>
      )}
      {payments.length === 0 ? <EmptyState message="لا توجد مدفوعات" /> : null}
      {payments.map((p, idx) => {
        const isPending = p.status === 'pending';
        const isApproved = p.status === 'approved';
        const isScheduled = p.status === 'scheduled';
        const isOverdue = p.status === 'overdue';
        const isManagerScheduled = p.requested_by_manager === true;
        const statusColor = isApproved ? 'text-green-400' : isPending ? 'text-yellow-400' : isOverdue ? 'text-red-400' : isScheduled ? 'text-yellow-400' : 'text-[var(--color-text-disabled)]';
        const statusDot = isApproved ? 'bg-green-400' : isPending ? 'bg-yellow-400' : isOverdue ? 'bg-red-400' : isScheduled ? 'bg-yellow-400' : 'bg-gray-500';
        const statusText = isApproved ? 'تمت الموافقة' : isPending ? 'قيد الانتظار' : isOverdue ? 'متأخر' : isScheduled ? 'مجدول' : p.status;

        return (
          <div key={p.id} className={`border rounded-xl overflow-hidden ${isPending ? 'border-[var(--color-gold)]' : 'border-[var(--color-card-border)]'}`}>
            {/* ── القسم العلوي ── */}
            <div className="px-5 pt-5 pb-4">
              <p className="text-xs text-[var(--color-gold)] font-medium">{installmentName(idx)}</p>
              <p className="text-2xl font-bold text-[var(--color-text-primary)] mt-1" style={{ fontFamily: "'Playfair Display', serif" }}>{p.amount} <span className="text-sm font-normal text-[var(--color-text-disabled)]">{p.currency || contractCurrency}</span></p>
              <div className="flex items-center gap-1.5 mt-2">
                <span className={`w-1.5 h-1.5 rounded-full ${statusDot}`}></span>
                <span className={`text-xs font-medium ${statusColor}`}>{statusText}</span>
              </div>
              {p.due_date && (
                <div className="flex items-center gap-1.5 mt-1">
                  <span className={`text-xs ${isOverdue ? 'text-red-400' : 'text-[var(--color-text-secondary)]'}`}>
                    📅 الاستحقاق: {p.due_date}
                  </span>
                </div>
              )}
            </div>

            {/* ── الفاصل ── */}
            <div className="h-px bg-[var(--color-card-border)]"></div>

            {/* ── القسم السفلي ── */}
            <div className="px-5 py-4 space-y-2">
              {p.method_type && (
                <div className="flex items-center gap-2">
                  <span className="text-xs">💳</span>
                  <span className="text-xs text-[var(--color-text-secondary)]">{methodLabels[p.method_type] || p.method_type}</span>
                </div>
              )}
              {p.contract?.title && (
                <div className="flex items-center gap-2">
                  <span className="text-xs">📄</span>
                  <span className="text-xs text-[var(--color-text-secondary)]">{p.contract.title}</span>
                </div>
              )}
              {p.proof_file_url && (
                <div className="flex items-center gap-2">
                  <span className="text-xs">📎</span>
                  <a href={resolveFileUrl(p.proof_file_url)} target="_blank" className="text-xs text-[var(--color-gold)] hover:underline">عرض إثبات الدفع</a>
                </div>
              )}
              {isPending && canReview && (
                <div className="pt-2">
                  <button onClick={() => reviewPayment(p.id, 'approved')} className="w-full text-sm bg-emerald-600 text-white py-2 rounded-lg hover:bg-emerald-700 font-medium">اعتماد</button>
                </div>
              )}
              {isManagerScheduled && (isScheduled || isOverdue) && isSA && (
                <div className="pt-2 flex gap-2">
                  <button onClick={() => deleteSchedule(p.id)} className="flex-1 text-sm bg-red-600/20 text-red-400 py-2 rounded-lg hover:bg-red-600/30 font-medium">مسح</button>
                </div>
              )}
            </div>
          </div>
        );
      })}
      {showSchedule && (
        <div className="fixed inset-0 z-50 bg-black/60 flex items-center justify-center p-4" onClick={() => setShowSchedule(false)}>
          <div className="bg-[#1a1a1a] border border-[var(--color-card-border)] rounded-2xl p-6 w-full max-w-md max-h-[90vh] overflow-y-auto" onClick={(e) => e.stopPropagation()}>
            <div className="flex items-center justify-between mb-4">
              <h3 className="text-lg font-bold text-[var(--color-text-primary)]">جدولة دفعات</h3>
              <button onClick={() => setShowSchedule(false)} className="text-[var(--color-text-secondary)] hover:text-white">✕</button>
            </div>
            <div className="space-y-3">
              <div>
                <label className="text-xs text-[var(--color-text-secondary)] mb-1 block">المبلغ *</label>
                <input type="number" value={scheduleForm.amount} onChange={(e) => setScheduleForm({ ...scheduleForm, amount: e.target.value })} className="w-full bg-[var(--color-card)] border border-[var(--color-card-border)] rounded-lg px-3 py-2 text-sm text-[var(--color-text-primary)]" placeholder="0.00" />
              </div>
              <div>
                <label className="text-xs text-[var(--color-text-secondary)] mb-1 block">الوصف (اختياري)</label>
                <input type="text" value={scheduleForm.installment_label} onChange={(e) => setScheduleForm({ ...scheduleForm, installment_label: e.target.value })} className="w-full bg-[var(--color-card)] border border-[var(--color-card-border)] rounded-lg px-3 py-2 text-sm text-[var(--color-text-primary)]" placeholder="مثال: القسط الأول" />
              </div>
              <div>
                <label className="text-xs text-[var(--color-text-secondary)] mb-1 block">تاريخ الاستحقاق *</label>
                <input type="date" value={scheduleForm.due_date} onChange={(e) => setScheduleForm({ ...scheduleForm, due_date: e.target.value })} className="w-full bg-[var(--color-card)] border border-[var(--color-card-border)] rounded-lg px-3 py-2 text-sm text-[var(--color-text-primary)]" />
              </div>
              <button onClick={addInstallment} className="w-full text-sm border border-[var(--color-gold)] text-[var(--color-gold)] py-2 rounded-lg hover:bg-[var(--color-gold)]/10">+ إضافة قسط</button>
              {installments.length > 0 && (
                <div className="space-y-2 max-h-40 overflow-y-auto">
                  {installments.map((inst, i) => (
                    <div key={i} className="flex items-center justify-between bg-[var(--color-card)] border border-[var(--color-card-border)] rounded-lg px-3 py-2">
                      <div>
                        <p className="text-xs text-[var(--color-text-primary)]">{inst.installment_label}</p>
                        <p className="text-[10px] text-[var(--color-text-secondary)]">{inst.amount} SAR — {inst.due_date}</p>
                      </div>
                      <button onClick={() => removeInstallment(i)} className="text-red-400 hover:text-red-300 text-xs">مسح</button>
                    </div>
                  ))}
                </div>
              )}
              <button onClick={submitSchedule} disabled={installments.length === 0} className="w-full text-sm bg-[var(--color-gold)] text-black py-2.5 rounded-lg font-medium hover:opacity-90 disabled:opacity-40">
                جدولة ({installments.length} أقساط)
              </button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
