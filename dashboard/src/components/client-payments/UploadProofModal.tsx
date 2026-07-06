'use client';

import { useState } from 'react';
import api from '@/lib/api';

export default function UploadProofModal({ wsId, availableMethods, onClose, onCreated }: {
  wsId: number;
  availableMethods: string[];
  onClose: () => void;
  onCreated: (payment: any) => void;
}) {
  const [amount, setAmount] = useState('');
  const [currency, setCurrency] = useState('SAR');
  const [methodType, setMethodType] = useState('');
  const [proofFile, setProofFile] = useState<File | null>(null);
  const [saving, setSaving] = useState(false);

  const methodLabels: Record<string, string> = {
    bank_transfer: 'تحويل بنكي', swift: 'SWIFT', corporate_account: 'حساب شركة',
    instapay: 'Instapay', vodafone_cash: 'فودافون كاش', mobile_wallet: 'محفظة موبايل',
  };

  const submit = async () => {
    if (!amount || !methodType) return;
    setSaving(true);
    const form = new FormData();
    form.append('amount', amount);
    form.append('currency', currency);
    form.append('method_type', methodType);
    if (proofFile) form.append('proof_file', proofFile);
    const { data } = await api.post(`/workspaces/${wsId}/payments`, form).catch(() => ({ data: null }));
    if (data) onCreated(data.payment);
    setSaving(false);
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/30" onClick={onClose}>
      <div className="bg-[var(--color-card)] rounded-xl shadow-xl p-6 max-w-md w-full mx-4 space-y-4 border border-[var(--color-card-border)]" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-center justify-between">
          <h3 className="font-bold">رفع إثبات دفع</h3>
          <button onClick={onClose} className="text-[var(--color-text-disabled)] hover:text-[var(--color-text-secondary)] text-xl">&times;</button>
        </div>

        <input value={amount} onChange={(e) => setAmount(e.target.value)} type="number" placeholder="المبلغ"
          className="border border-[var(--color-input-border)] rounded-lg px-4 py-2 text-sm w-full bg-[var(--color-input-fill)] text-[var(--color-foreground)] placeholder-[var(--color-text-disabled)]" />

        <select value={currency} onChange={(e) => setCurrency(e.target.value)} className="border border-[var(--color-input-border)] rounded-lg px-4 py-2 text-sm w-full bg-[var(--color-input-fill)] text-[var(--color-foreground)]">
          <option value="SAR">ريال سعودي (SAR)</option><option value="USD">دولار أمريكي (USD)</option><option value="EUR">يورو (EUR)</option>
          <option value="AED">درهم إماراتي (AED)</option><option value="EGP">جنيه مصري (EGP)</option><option value="KWD">دينار كويتي (KWD)</option>
          <option value="QAR">ريال قطري (QAR)</option><option value="BHD">دينار بحريني (BHD)</option><option value="OMR">ريال عماني (OMR)</option>
        </select>

        <select value={methodType} onChange={(e) => setMethodType(e.target.value)} className="border border-[var(--color-input-border)] rounded-lg px-4 py-2 text-sm w-full bg-[var(--color-input-fill)] text-[var(--color-foreground)]">
          <option value="">طريقة الدفع</option>
          {availableMethods.map((m) => <option key={m} value={m}>{methodLabels[m] || m}</option>)}
        </select>

        <label className="flex items-center gap-2 text-sm text-[var(--color-gold)] cursor-pointer hover:text-[var(--color-gold)]">
          <input type="file" accept="image/*,.pdf" className="hidden" onChange={(e) => setProofFile(e.target.files?.[0] || null)} />
          <span className="border border-blue-200 rounded-lg px-4 py-2">{proofFile ? proofFile.name : '+ اختيار ملف الإثبات'}</span>
        </label>

        <button onClick={submit} disabled={saving || !amount || !methodType}
          className="w-full bg-[var(--color-primary)] text-white rounded-lg py-2.5 text-sm font-medium hover:bg-[var(--color-primary-dark)] disabled:opacity-50">
          {saving ? 'جاري الحفظ...' : 'إرسال'}
        </button>
      </div>
    </div>
  );
}
