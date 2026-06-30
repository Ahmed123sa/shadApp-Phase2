'use client';

import { useEffect, useState } from 'react';
import api from '@/lib/api';
import { LoadingSkeleton } from '@/components/ui/LoadingSkeleton';
import { EmptyState } from '@/components/ui/EmptyState';

export default function ClientPayments({ wsId }: { wsId: number }) {
  const [payments, setPayments] = useState<any[]>([]);
  const [methods, setMethods] = useState<string[]>([]);
  const [payableContract, setPayableContract] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [amount, setAmount] = useState('');
  const [methodType, setMethodType] = useState('');
  const [proofFile, setProofFile] = useState<File | null>(null);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    const loadAll = async () => {
      try {
        const [payRes, contRes] = await Promise.all([
          api.get(`/workspaces/${wsId}/payments`),
          api.get(`/workspaces/${wsId}/contracts`),
        ]);
        const payData = payRes.data;
        setPayments(payData.payments || []);
        setMethods(payData.available_methods || []);

        const contracts = contRes.data.contracts?.data ?? contRes.data.contracts ?? [];
        const payable = contracts.find((c: any) =>
          c.status === 'company_approved' || c.status === 'completed'
        );
        if (payable) {
          setPayableContract(payable);
          if (!payData.payments?.length) setAmount(String(payable.value));
        }
      } catch (e) {
        console.error(e);
        setError('فشل تحميل المدفوعات');
      }
    };
    loadAll().finally(() => setLoading(false));
    const interval = setInterval(loadAll, 30000);
    return () => clearInterval(interval);
  }, [wsId]);

  const methodLabels: Record<string, string> = {
    bank_transfer: 'تحويل بنكي', swift: 'SWIFT', corporate_account: 'حساب شركة',
    instapay: 'Instapay', vodafone_cash: 'فودافون كاش', mobile_wallet: 'محفظة موبايل',
  };

  const submit = async () => {
    if (!amount || !methodType) return;
    setSaving(true);
    const form = new FormData();
    form.append('amount', amount);
    form.append('method_type', methodType);
    if (proofFile) form.append('proof_file', proofFile);
    const { data } = await api.post(`/workspaces/${wsId}/payments`, form).catch(() => ({ data: null }));
    if (data) {
      setPayments((prev) => [...prev, data.payment]);
      setAmount('');
      setMethodType('');
      setProofFile(null);
    }
    setSaving(false);
  };

  if (loading) return <LoadingSkeleton />;
  if (error) return <p className="text-sm text-red-500 text-center py-8">{error}</p>;

  const pendingPayment = payments.find((p) => p.status === 'pending');
  const showPaymentForm = pendingPayment || payableContract;

  return (
    <div className="space-y-3">
      {/* طرق الدفع المتاحة */}
      {methods.length > 0 && (
        <div className="bg-[var(--color-card)] border border-[var(--color-card-border)] rounded-xl p-4">
          <p className="text-sm font-medium mb-2">طرق الدفع المتاحة:</p>
          <div className="flex flex-wrap gap-2">
            {methods.map((m) => (
              <span key={m} className="px-3 py-1 bg-blue-900/30 text-blue-400 rounded-full text-xs">
                {methodLabels[m] || m}
              </span>
            ))}
          </div>
        </div>
      )}

      {/* تنبيه بوجود عقد معتمد يتطلب الدفع */}
      {!pendingPayment && payableContract && (
        <div className="bg-amber-900/30 border border-amber-200 rounded-xl p-4">
          <p className="text-sm text-amber-700 font-medium">
            💳 عقد "{payableContract.title}" معتمد — المبلغ: {payableContract.value} ر.س
          </p>
        </div>
      )}

      {/* نموذج إرسال الدفع */}
      {showPaymentForm && (
        <div className="bg-blue-900/30 border border-blue-200 rounded-xl p-5 space-y-4">
          <div className="flex items-start gap-3">
            <span className="text-2xl">💳</span>
            <div>
              {pendingPayment ? (
                <p className="font-medium text-blue-800">مطلوب دفع مبلغ {pendingPayment.amount} ر.س</p>
              ) : (
                <p className="font-medium text-blue-800">
                  إتمام الدفع للعقد "{payableContract?.title || ''}"
                </p>
              )}
              <p className="text-xs text-[var(--color-gold)] mt-0.5">يرجى رفع إثبات الدفع بعد تحويل المبلغ</p>
            </div>
          </div>
          <div className="space-y-3">
            <input value={amount} onChange={(e) => setAmount(e.target.value)} type="number" placeholder="المبلغ"
              className="border border-[var(--color-input-border)] rounded-lg px-4 py-2 text-sm w-full bg-[var(--color-input-fill)] text-[var(--color-foreground)] placeholder-[var(--color-text-disabled)]" />
            <select value={methodType} onChange={(e) => setMethodType(e.target.value)}
              className="border border-[var(--color-input-border)] rounded-lg px-4 py-2 text-sm w-full bg-[var(--color-input-fill)] text-[var(--color-foreground)]">
              <option value="">طريقة الدفع</option>
              {methods.map((m) => <option key={m} value={m}>{methodLabels[m] || m}</option>)}
            </select>
            <label className="flex items-center gap-2 text-sm text-[var(--color-gold)] cursor-pointer hover:text-[var(--color-gold)]">
              <input type="file" accept="image/*,.pdf" className="hidden"
                onChange={(e) => setProofFile(e.target.files?.[0] || null)} />
              <span className="border border-blue-200 rounded-lg px-4 py-2 bg-[var(--color-card)]">
                {proofFile ? proofFile.name : '+ اختيار ملف الإثبات'}
              </span>
            </label>
            <button onClick={submit} disabled={saving || !amount || !methodType}
              className="w-full bg-[var(--color-primary)] text-white rounded-lg py-2.5 text-sm font-medium hover:bg-[var(--color-primary-dark)] disabled:opacity-50">
              {saving ? 'جاري الحفظ...' : 'إرسال إثبات الدفع'}
            </button>
          </div>
        </div>
      )}

      {/* قائمة المدفوعات السابقة أو رسالة عدم وجود مدفوعات */}
      {payments.length === 0 && !pendingPayment && !payableContract
        ? <EmptyState message="لا توجد مدفوعات" />
        : payments.map((p) => {
          const linkedContract = p.contract;
          return (
          <div key={p.id} className="border border-[var(--color-card-border)] rounded-lg p-4 flex justify-between items-center">
            <div>
              <p className="font-medium">{p.amount} ر.س</p>
              <p className="text-xs text-[var(--color-text-disabled)]">{methodLabels[p.method_type] || p.method_type}</p>
              {linkedContract && <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">📄 {linkedContract.title}</p>}
              {p.proof_file_url && (
                <a href={p.proof_file_url} target="_blank" rel="noopener noreferrer"
                  className="text-xs text-[var(--color-gold)] hover:underline">📎 عرض الإثبات</a>
              )}
            </div>
            <span className={`px-2.5 py-0.5 rounded-full text-xs font-medium ${
              p.status === 'approved' ? 'bg-green-900/30 text-green-400' :
              p.status === 'rejected' ? 'bg-red-900/30 text-red-400' :
              'bg-yellow-900/30 text-yellow-400'
            }`}>
              {p.status === 'approved' ? 'مقبول' : p.status === 'rejected' ? 'مرفوض' : 'قيد المراجعة'}
            </span>
          </div>
          );
        })}
    </div>
  );
}
