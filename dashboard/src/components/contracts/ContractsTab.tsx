'use client';

import { useEffect, useState } from 'react';
import api from '@/lib/api';
import { getUser } from '@/lib/auth';
import { StatusBadge } from '@/components/ui/StatusBadge';
import ContractStatusStepper from '@/components/ui/ContractStatusStepper';
import { LoadingSkeleton } from '@/components/ui/LoadingSkeleton';
import { EmptyState } from '@/components/ui/EmptyState';

export default function ContractsTab({ wsId, clientType }: { wsId: number; clientType?: string }) {
  const [contracts, setContracts] = useState<any[]>([]);
  const [templates, setTemplates] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [showForm, setShowForm] = useState(false);
  const [form, setForm] = useState({ title: '', value: '', currency: 'SAR', start_date: '', end_date: '' });
  const [selectedOptional, setSelectedOptional] = useState<Record<number, boolean>>({});
  const [customClauses, setCustomClauses] = useState<string[]>([]);
  const [error, setError] = useState('');
  const [newCustom, setNewCustom] = useState('');
  const [approveSig, setApproveSig] = useState<{ id: number; signature: string } | null>(null);
  const [savedUserSig, setSavedUserSig] = useState<{ data: string; type: string } | null>(null);
  const [useSavedSig, setUseSavedSig] = useState(false);
  const [requiredDocs, setRequiredDocs] = useState<string[]>([]);
  const [newReqDoc, setNewReqDoc] = useState('');

  const FILE_BASE = process.env.NEXT_PUBLIC_API_URL?.replace('/api', '') || 'http://localhost:8000';
  const resolveFileUrl = (url: string) => {
    if (!url) return '';
    if (url.startsWith('http')) return url;
    return `${FILE_BASE}/storage/${url.replace(/^\/?storage\//, '')}`;
  };

  useEffect(() => {
    Promise.all([
      api.get(`/workspaces/${wsId}/contracts`).then(({ data }) => setContracts(data.contracts?.data || data.contracts || [])),
      api.get('/contract-clause-templates').then(({ data }) => setTemplates(data.templates || [])),
    ]).catch((err) => { console.error('ContractsTab: GET /workspaces/${wsId}/contracts failed', err); setError('فشل تحميل العقود'); }).finally(() => setLoading(false));
  }, [wsId]);

  const user = getUser();
  const isSA = user?.role === 'super_admin';

  const fixedTemplates = templates.filter((t: any) => t.type === 'fixed');
  const optionalTemplates = templates.filter((t: any) => t.type === 'optional');

  const create = async () => {
    if (!form.title) return;
    const clauses: any[] = [];
    fixedTemplates.forEach((t: any) => clauses.push({ content: t.content, type: 'fixed' }));
    optionalTemplates.forEach((t: any) => { if (selectedOptional[t.id]) clauses.push({ content: t.content, type: 'optional' }); });
    customClauses.forEach((c) => clauses.push({ content: c, type: 'custom' }));

    const required_documents = requiredDocs.map((name) => ({ name }));

    const { data } = await api.post(`/workspaces/${wsId}/contracts`, { ...form, clauses, required_documents }).catch(() => ({ data: null }));
    if (data) { setContracts((prev) => [...prev, data.contract]); setShowForm(false); setForm({ title: '', value: '', currency: 'SAR', start_date: '', end_date: '' }); setSelectedOptional({}); setCustomClauses([]); setNewCustom(''); setRequiredDocs([]); setNewReqDoc(''); }
  };

  const toggleOptional = (id: number) => setSelectedOptional((prev) => ({ ...prev, [id]: !prev[id] }));

  const addCustom = () => {
    const trimmed = newCustom.trim();
    if (trimmed) { setCustomClauses((prev) => [...prev, trimmed]); setNewCustom(''); }
  };

  const removeCustom = (idx: number) => setCustomClauses((prev) => prev.filter((_, i) => i !== idx));

  const doAction = async (id: number, action: string) => {
    const { data } = await api.post(`/contracts/${id}/${action}`).catch(() => ({ data: null }));
    if (data) setContracts((prev) => prev.map((c) => c.id === id ? data.contract : c));
  };

  const openApproveSig = async (contractId: number) => {
    setUseSavedSig(false);
    setApproveSig({ id: contractId, signature: '' });
    setSavedUserSig(null);
    try {
      const { data } = await api.get('/auth/me');
      if (data.user?.signature_data) {
        setSavedUserSig({ data: data.user.signature_data, type: data.user.signature_type || 'text' });
      }
    } catch {}
  };

  const doCompanyApprove = async () => {
    if (!approveSig) return;
    const payload = useSavedSig ? { use_saved_signature: true } : { signature: approveSig.signature };
    const { data } = await api.post(`/contracts/${approveSig.id}/company-approve`, payload).catch(() => ({ data: null }));
    if (data) setContracts((prev) => prev.map((c) => c.id === approveSig.id ? data.contract : c));
    setApproveSig(null);
    setSavedUserSig(null);
  };

  if (loading) return <LoadingSkeleton />;
  if (error) return <p className="text-sm text-red-400 text-center py-8">{error}</p>;
  if (isSA && contracts.length === 0) return <EmptyState message="لا توجد عقود" />;

  return (
    <div className="space-y-3">
      {!isSA && <button onClick={() => setShowForm(!showForm)} className="text-sm text-[var(--color-gold)] hover:underline">+ عقد جديد</button>}
      {!isSA && showForm && (
        <div className="space-y-2 border border-[var(--color-card-border)] rounded-lg p-4 bg-[var(--color-card-border)]">
          <input value={form.title} onChange={(e) => setForm({ ...form, title: e.target.value })} placeholder="عنوان العقد" className="border border-[var(--color-input-border)] rounded-lg px-3 py-2 text-sm w-full bg-[var(--color-input-fill)] text-[var(--color-foreground)]" />
          <div className="flex gap-2">
            <input value={form.value} onChange={(e) => setForm({ ...form, value: e.target.value })} type="number" placeholder="القيمة" className="border border-[var(--color-input-border)] rounded-lg px-3 py-2 text-sm w-28 bg-[var(--color-input-fill)] text-[var(--color-foreground)]" />
            <select value={form.currency} onChange={(e) => setForm({ ...form, currency: e.target.value })} className="border border-[var(--color-input-border)] rounded-lg px-3 py-2 text-sm w-24 bg-[var(--color-input-fill)] text-[var(--color-foreground)]">
              <option value="SAR">SAR</option><option value="USD">USD</option><option value="EUR">EUR</option>
              <option value="AED">AED</option><option value="EGP">EGP</option><option value="KWD">KWD</option>
              <option value="QAR">QAR</option><option value="BHD">BHD</option><option value="OMR">OMR</option>
            </select>
            <input value={form.start_date} onChange={(e) => setForm({ ...form, start_date: e.target.value })} type="date" className="border border-[var(--color-input-border)] rounded-lg px-3 py-2 text-sm flex-1 bg-[var(--color-input-fill)] text-[var(--color-foreground)]" />
            <input value={form.end_date} onChange={(e) => setForm({ ...form, end_date: e.target.value })} type="date" className="border border-[var(--color-input-border)] rounded-lg px-3 py-2 text-sm flex-1 bg-[var(--color-input-fill)] text-[var(--color-foreground)]" />
          </div>
          {fixedTemplates.length > 0 && (
            <div className="border border-[var(--color-card-border)] rounded p-3 bg-[var(--color-card)]">
              <h4 className="text-xs font-bold text-[var(--color-text-secondary)] mb-2">بنود ثابتة (مضمنة)</h4>
              {fixedTemplates.map((t: any) => (
                <label key={t.id} className="flex items-start gap-2 text-xs text-[var(--color-text-secondary)] py-1">
                  <input type="checkbox" checked disabled className="mt-0.5" />
                  <span>{t.content}</span>
                </label>
              ))}
            </div>
          )}
          {optionalTemplates.length > 0 && (
            <div className="border border-[var(--color-card-border)] rounded p-3 bg-[var(--color-card)]">
              <h4 className="text-xs font-bold text-[var(--color-text-secondary)] mb-2">بنود اختيارية</h4>
              {optionalTemplates.map((t: any) => (
                <label key={t.id} className="flex items-start gap-2 text-xs text-[var(--color-text-secondary)] py-1 cursor-pointer hover:text-[var(--color-gold)]">
                  <input type="checkbox" checked={!!selectedOptional[t.id]} onChange={() => toggleOptional(t.id)} className="mt-0.5" />
                  <span>{t.content}</span>
                </label>
              ))}
            </div>
          )}
          <div className="border border-[var(--color-card-border)] rounded p-3 bg-[var(--color-card)]">
            <h4 className="text-xs font-bold text-[var(--color-text-secondary)] mb-2">بنود مخصصة</h4>
            <div className="flex gap-2 mb-2">
              <input value={newCustom} onChange={(e) => setNewCustom(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && addCustom()} placeholder="اكتب بنداً..." className="border border-[var(--color-input-border)] rounded px-3 py-2 text-sm flex-1 bg-[var(--color-input-fill)] text-[var(--color-foreground)]" />
              <button onClick={addCustom} className="bg-[var(--color-primary)] text-white px-3 py-2 rounded-lg text-xs hover:bg-[var(--color-primary-dark)]">إضافة</button>
            </div>
            {customClauses.map((c, i) => (
              <div key={i} className="flex items-start gap-2 text-xs text-[var(--color-text-secondary)] py-1">
                <span className="text-blue-500 mt-0.5">•</span>
                <span className="flex-1">{c}</span>
                <button onClick={() => removeCustom(i)} className="text-red-400 hover:text-red-600 text-xs">✕</button>
              </div>
            ))}
          </div>
          <div className="border border-[var(--color-card-border)] rounded p-3 bg-[var(--color-card)]">
            <h4 className="text-xs font-bold text-[var(--color-text-secondary)] mb-2">المستندات المطلوبة من العميل</h4>
            <div className="flex gap-2 mb-2">
              <input value={newReqDoc} onChange={(e) => setNewReqDoc(e.target.value)} onKeyDown={(e) => { if (e.key === 'Enter') { const t = newReqDoc.trim(); if (t) { setRequiredDocs((prev) => [...prev, t]); setNewReqDoc(''); } } }} placeholder="اسم المستند..." className="border border-[var(--color-input-border)] rounded px-3 py-2 text-sm flex-1 bg-[var(--color-input-fill)] text-[var(--color-foreground)]" />
              <button onClick={() => { const t = newReqDoc.trim(); if (t) { setRequiredDocs((prev) => [...prev, t]); setNewReqDoc(''); } }} className="bg-amber-600 text-white px-3 py-2 rounded-lg text-xs hover:bg-amber-700">إضافة</button>
            </div>
            {requiredDocs.map((d, i) => (
              <div key={i} className="flex items-start gap-2 text-xs text-[var(--color-text-secondary)] py-1">
                <span className="text-amber-500 mt-0.5">📎</span>
                <span className="flex-1">{d}</span>
                <button onClick={() => setRequiredDocs((prev) => prev.filter((_, j) => j !== i))} className="text-red-400 hover:text-red-600 text-xs">✕</button>
              </div>
            ))}
          </div>
          <button onClick={create} className="bg-[var(--color-primary)] text-white px-4 py-2 rounded-lg text-sm hover:bg-[var(--color-primary-dark)]">حفظ</button>
        </div>
      )}
      {contracts.length === 0 ? <EmptyState message="لا توجد عقود" /> : null}
      {contracts.map((c) => (
        <div key={c.id} className="border border-[var(--color-card-border)] rounded-lg p-4">
          <div className="flex justify-between items-start">
            <div><h4 className="font-medium">{c.title}</h4>
              {c.value ? <p className="text-xs text-[var(--color-text-secondary)]">{c.value} ر.س{c.start_date ? ` • من ${c.start_date}` : ''}{c.end_date ? ` إلى ${c.end_date}` : ''}</p> : ''}
              {clientType === 'business' && <p className="text-xs text-[var(--color-text-disabled)]">قيمة العقد غير شاملة الضريبة المضافة</p>}
              {c.required_documents?.length > 0 && <p className="text-xs text-amber-600 mt-0.5">📎 {c.required_documents.length} مستند مطلوب</p>}
            </div>
            <div className="flex items-center gap-2">
              <span className={`px-2 py-0.5 rounded-full text-[9px] font-semibold ${
                c.contract_type === 'main' || c.contract_type === null
                  ? 'bg-[var(--color-gold-soft)] text-[var(--color-gold)] border border-[var(--color-gold-border)]'
                  : 'bg-blue-900/30 text-blue-400'
              }`}>
                {c.contract_type === 'main' || c.contract_type === null ? 'أساسي' : 'إضافي'}
              </span>
              <StatusBadge status={c.status} />
            </div>
          </div>
          <ContractStatusStepper status={c.status} compact />
          {c.clauses?.length > 0 && (
            <div className="mt-2 space-y-1">
              {c.clauses.map((cl: any) => (
                <p key={cl.id} className="text-xs text-[var(--color-text-secondary)] pr-2 border-r-2 border-[var(--color-card-border)]">{cl.content}</p>
              ))}
            </div>
          )}
          <div className="mt-2 flex gap-2 flex-wrap">
            {!isSA && c.status === 'draft' && <button onClick={() => doAction(c.id, 'send')} className="text-xs text-[var(--color-gold)] hover:underline">إرسال</button>}
            {!isSA && c.status === 'edit_requested' && <button onClick={() => doAction(c.id, 'send')} className="text-xs text-amber-600 hover:underline">إرسال بعد التعديل</button>}
            {c.status === 'client_approved' && (
              <>
                {c.pdf_url && <a href={c.pdf_url} target="_blank" rel="noopener noreferrer" className="text-xs text-emerald-600 hover:underline">📄 عرض العقد الموقع</a>}
                {isSA && (
                  <button onClick={() => openApproveSig(c.id)} className="text-xs bg-purple-600 text-white px-3 py-1.5 rounded-lg hover:bg-purple-700">اعتماد الشركة</button>
                )}
              </>
            )}
            {c.status === 'company_approved' && (
              <>
                {c.pdf_url && <a href={c.pdf_url} target="_blank" rel="noopener noreferrer" className="text-xs text-emerald-600 hover:underline">📄 تحميل العقد النهائي</a>}
                {!isSA && <button onClick={() => doAction(c.id, 'archive')} className="text-xs text-[var(--color-text-secondary)] hover:underline">أرشفة</button>}
              </>
            )}
            {c.status === 'completed' && (
              <>{c.pdf_url && <a href={c.pdf_url} target="_blank" rel="noopener noreferrer" className="text-xs text-emerald-600 hover:underline">📄 تحميل العقد النهائي</a>}</>
            )}
          </div>
        </div>
      ))}

      {approveSig && (
        <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/30" onClick={() => { setApproveSig(null); setSavedUserSig(null); setUseSavedSig(false); }}>
          <div className="bg-[var(--color-card)] border border-[var(--color-card-border)] rounded-xl shadow-xl p-6 max-w-sm w-full mx-4 space-y-4" onClick={(e) => e.stopPropagation()}>
            <h3 className="font-bold">اعتماد العقد من الشركة</h3>

            {savedUserSig && !useSavedSig ? (
              <div className="space-y-3">
                <p className="text-sm text-[var(--color-text-secondary)]">التوقيع المحفوظ:</p>
                {savedUserSig.type === 'text' ? (
                  <p className="text-lg font-[cursive] border border-[var(--color-card-border)] rounded-lg p-4 bg-[var(--color-card-border)] text-center">{savedUserSig.data}</p>
                ) : (
                  <img src={resolveFileUrl(savedUserSig.data)} alt="التوقيع المحفوظ" className="max-h-20 border border-[var(--color-card-border)] rounded-lg p-2 bg-[var(--color-card-border)] mx-auto" />
                )}
                <div className="flex gap-2">
                  <button onClick={() => setUseSavedSig(true)}
                    className="flex-1 bg-purple-600 text-white rounded-lg py-2.5 text-sm font-medium hover:bg-purple-700">استخدام التوقيع المحفوظ</button>
                  <button onClick={() => { setSavedUserSig(null); }}
                    className="flex-1 px-4 py-2.5 rounded-lg text-sm font-medium border border-[var(--color-card-border)] text-[var(--color-text-secondary)] hover:bg-[var(--color-card-border)]">كتابة توقيع جديد</button>
                </div>
              </div>
            ) : useSavedSig ? (
              <div className="space-y-3">
                <div className="bg-purple-50 border border-purple-200 rounded-lg p-4 text-center">
                  <p className="text-sm text-purple-700 font-medium">سيتم استخدام توقيعك المحفوظ</p>
                  {savedUserSig && (
                    savedUserSig.type === 'text' ? (
                      <p className="text-lg font-[cursive] mt-2 text-purple-900">{savedUserSig.data}</p>
                    ) : (
                      <img src={resolveFileUrl(savedUserSig.data)} alt="" className="max-h-16 mx-auto mt-2" />
                    )
                  )}
                </div>
              </div>
            ) : (
              <>
                <p className="text-xs text-[var(--color-text-secondary)]">اكتب اسمك كاملاً لتوقيع اعتماد العقد (الطرف الثاني)</p>
                <textarea value={approveSig.signature} onChange={(e) => setApproveSig({ ...approveSig, signature: e.target.value })}
                  className="border border-[var(--color-input-border)] rounded-lg px-4 py-3 text-lg font-medium w-full h-20 text-center bg-[var(--color-input-fill)] text-[var(--color-foreground)]"
                  placeholder="اكتب اسمك هنا..." />
              </>
            )}

            <div className="flex gap-2">
              <button onClick={doCompanyApprove} disabled={!useSavedSig && !savedUserSig && !approveSig.signature.trim()}
                className="flex-1 bg-purple-600 text-white rounded-lg py-2.5 text-sm font-medium hover:bg-purple-700 disabled:opacity-50">اعتماد وتوقيع</button>
              <button onClick={() => { setApproveSig(null); setSavedUserSig(null); setUseSavedSig(false); }}
                className="px-4 py-2.5 rounded-lg text-sm font-medium border border-[var(--color-card-border)] text-[var(--color-text-secondary)] hover:bg-[var(--color-card-border)]">إلغاء</button>
            </div>
          </div>
        </div>
      )}
    </div>
  );
}
