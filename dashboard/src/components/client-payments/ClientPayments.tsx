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
  const [currency, setCurrency] = useState('SAR');
  const [methodType, setMethodType] = useState('');
  const [proofFile, setProofFile] = useState<File | null>(null);
  const [saving, setSaving] = useState(false);
  const [editingPayment, setEditingPayment] = useState<any | null>(null);

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

  const startEdit = (p: any) => {
    setEditingPayment(p);
    setAmount(String(p.amount));
    setCurrency(p.currency || 'SAR');
    setMethodType(p.method_type);
    setProofFile(null);
  };

  const cancelEdit = () => {
    setEditingPayment(null);
    setAmount('');
    setCurrency('SAR');
    setMethodType('');
    setProofFile(null);
  };

  const submit = async () => {
    if (!amount || !methodType) return;
    setSaving(true);
    const form = new FormData();
    form.append('amount', amount);
    form.append('currency', currency);
    form.append('method_type', methodType);
    if (proofFile) form.append('proof_file', proofFile);
    if (editingPayment) {
      form.append('_method', 'PUT');
    }
    const url = editingPayment
      ? `/workspaces/${wsId}/payments/${editingPayment.id}`
      : `/workspaces/${wsId}/payments`;
    const { data } = await api.post(url, form).catch(() => ({ data: null }));
    if (data) {
      if (editingPayment) {
        setPayments((prev) => prev.map((p) => p.id === editingPayment.id ? data.payment : p));
      } else {
        setPayments((prev) => [...prev, data.payment]);
      }
      cancelEdit();
    }
    setSaving(false);
  };

  if (loading) return <LoadingSkeleton />;
  if (error) return <p className="text-sm text-red-500 text-center py-8">{error}</p>;

  const pendingPayment = payments.find((p) => p.status === 'pending');
  const showPaymentForm = pendingPayment || payableContract;

  const approvedPayments = payments.filter(p => p.status === 'approved');
  const totalPaid = approvedPayments.reduce((s, p) => s + Number(p.amount), 0);
  const grandTotal = payableContract ? Number(payableContract.value) : payments.reduce((s, p) => s + Number(p.amount), 0);
  const contractCurrency = payableContract?.currency || 'SAR';
  const remaining = grandTotal - totalPaid;
  const isFullyPaid = totalPaid >= grandTotal && grandTotal > 0;
  const progress = grandTotal > 0 ? Math.min(totalPaid / grandTotal, 1) : 0;

  const installmentLabels = ['الأولى', 'الثانية', 'الثالثة', 'الرابعة', 'الخامسة', 'السادسة', 'السابعة', 'الثامنة', 'التاسعة', 'العاشرة'];
  const installmentName = (i: number) => i < installmentLabels.length ? `دفعة ${installmentLabels[i]}` : `دفعة ${i + 1}`;

  return (
    <div className="space-y-3">
      {/* إجمالي المدفوع */}
      <div className="bg-[#0d0d0d] border border-[var(--color-card-border)] rounded-xl p-4">
        {isFullyPaid ? (
          <>
            <div className="flex items-center gap-2 mb-2">
              <span className="text-[var(--color-success)] text-lg">✅</span>
              <p className="text-sm font-bold text-[var(--color-success)]">تم الدفع بالكامل</p>
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
            <div className={`h-full rounded-full transition-all ${isFullyPaid ? 'bg-[var(--color-success)]' : 'bg-[var(--color-gold)]'}`} style={{ width: `${progress * 100}%` }} />
          </div>
        </div>
      </div>

      {/* طرق الدفع المتاحة */}
      {methods.length > 0 && (
        <div className="bg-[var(--color-card)] border border-[var(--color-card-border)] rounded-xl p-4">
          <p className="text-sm font-medium mb-2">طرق الدفع المتاحة:</p>
          <div className="flex flex-wrap gap-2">
            {methods.map((m) => (
              <span key={m} className="px-3 py-1 bg-[var(--color-primary)]/20 text-[var(--color-primary)] rounded-full text-xs font-medium">
                {methodLabels[m] || m}
              </span>
            ))}
          </div>
        </div>
      )}

      {/* تنبيه بوجود عقد معتمد يتطلب الدفع */}
      {!pendingPayment && payableContract && (
        <div className="bg-[var(--color-card)] border border-[var(--color-gold)]/30 rounded-xl p-4">
          <p className="text-sm text-[var(--color-gold)] font-medium">
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
            <select value={currency} onChange={(e) => setCurrency(e.target.value)}
              className="border border-[var(--color-input-border)] rounded-lg px-4 py-2 text-sm w-full bg-[var(--color-input-fill)] text-[var(--color-foreground)]">
              <option value="SAR">ريال سعودي (SAR)</option><option value="USD">دولار أمريكي (USD)</option><option value="EUR">يورو (EUR)</option>
              <option value="AED">درهم إماراتي (AED)</option><option value="EGP">جنيه مصري (EGP)</option><option value="KWD">دينار كويتي (KWD)</option>
              <option value="QAR">ريال قطري (QAR)</option><option value="BHD">دينار بحريني (BHD)</option><option value="OMR">ريال عماني (OMR)</option>
            </select>
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
            <div className="flex gap-2">
              <button onClick={submit} disabled={saving || !amount || !methodType}
                className="flex-1 bg-[var(--color-primary)] text-white rounded-lg py-2.5 text-sm font-medium hover:bg-[var(--color-primary-dark)] disabled:opacity-50">
                {saving ? 'جاري الحفظ...' : editingPayment ? 'تحديث' : 'إرسال إثبات الدفع'}
              </button>
              {editingPayment && (
                <button onClick={cancelEdit} type="button"
                  className="bg-[var(--color-input-fill)] px-4 py-2.5 rounded-lg text-sm hover:bg-[var(--color-card-border)]">
                  إلغاء
                </button>
              )}
            </div>
          </div>
        </div>
      )}

      {/* قائمة المدفوعات السابقة أو رسالة عدم وجود مدفوعات */}
      {payments.length === 0 && !pendingPayment && !payableContract
        ? <EmptyState message="لا توجد مدفوعات" />
        : payments.map((p, idx) => {
          const linkedContract = p.contract;
          const isPending = p.status === 'pending';
          return (
          <div key={p.id} className={`border rounded-lg p-4 flex justify-between items-center ${isPending ? 'border-[var(--color-gold)]' : 'border-[var(--color-card-border)]'}`}>
            <div>
              <div className="flex items-center gap-2">
                <span className="text-xs text-[var(--color-gold)] font-medium">{installmentName(idx)}</span>
                <p className="font-medium">{p.amount} {p.currency || 'SAR'}</p>
              </div>
              <p className="text-xs text-[var(--color-text-disabled)]">{methodLabels[p.method_type] || p.method_type}</p>
              {linkedContract && <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">📄 {linkedContract.title}</p>}
              {p.proof_file_url && (
                <a href={`${(process.env.NEXT_PUBLIC_API_URL?.replace('/api', '') || 'http://localhost:8000')}/storage/${p.proof_file_url.replace(/^\/?storage\//, '')}`}
                  target="_blank" rel="noopener noreferrer"
                  className="text-xs text-[var(--color-gold)] hover:underline">📎 عرض الإثبات</a>
              )}
            </div>
            <div className="flex items-center gap-2">
              {p.status === 'pending' && (
                <button onClick={() => startEdit(p)}
                  className="text-xs text-[var(--color-gold)] hover:underline">✏️ تعديل</button>
              )}
              <span className={`px-2.5 py-0.5 rounded-full text-xs font-medium ${
                p.status === 'approved' ? 'bg-green-900/30 text-green-400' :
                p.status === 'rejected' ? 'bg-red-900/30 text-red-400' :
                'bg-[var(--color-gold)]/20 text-[var(--color-gold)]'
              }`}>
                {p.status === 'approved' ? 'مقبول' : p.status === 'rejected' ? 'مرفوض' : 'قيد المراجعة'}
              </span>
            </div>
          </div>
          );
        })}
    </div>
  );
}
