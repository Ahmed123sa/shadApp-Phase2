'use client';

import { useState } from 'react';
import api from '@/lib/api';
import { StatusBadge } from '@/components/ui/StatusBadge';
import ContractStatusStepper from '@/components/ui/ContractStatusStepper';

export default function ContractDetailModal({ contract, wsId, onClose, onAction, onUpload, clientType }: {
  contract: any;
  wsId: number;
  onClose: () => void;
  onAction: (action: string) => void;
  onUpload: () => void;
  clientType?: string;
}) {
  const canAct = contract.status === 'sent';
  const [uploading, setUploading] = useState<Record<number, boolean>>({});
  const [error, setError] = useState('');

  const uploadDoc = async (docId: number, file: File) => {
    setUploading((prev) => ({ ...prev, [docId]: true }));
    setError('');
    try {
      const form = new FormData();
      form.append('file', file);
      form.append('contract_id', String(contract.id));
      form.append('contract_required_document_id', String(docId));
      const { data } = await api.post(`/workspaces/${wsId}/files`, form);
      if (data) onUpload();
    } catch (e: any) {
      setError(e?.response?.data?.message || e?.message || 'فشل رفع المستند');
    } finally {
      setUploading((prev) => ({ ...prev, [docId]: false }));
    }
  };

  const docs = contract.required_documents || [];

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center bg-black/30" onClick={onClose}>
      <div className="bg-[var(--color-card)] rounded-xl shadow-xl p-6 max-w-lg w-full mx-4 max-h-[80vh] overflow-y-auto border border-[var(--color-card-border)]" onClick={(e) => e.stopPropagation()}>
        <div className="flex items-start justify-between mb-4">
          <div>
            <h3 className="text-lg font-bold">{contract.title}</h3>
            <StatusBadge status={contract.status} className="mt-1" />
          </div>
          <button onClick={onClose} className="text-[var(--color-text-disabled)] hover:text-[var(--color-text-secondary)] text-xl">&times;</button>
        </div>

        <ContractStatusStepper status={contract.status} />

        {contract.value > 0 && (
          <p className="text-sm text-[var(--color-text-secondary)] mb-1">القيمة: <span className="font-medium">{contract.value} ر.س</span></p>
        )}
        {clientType === 'business' && contract.value > 0 && (
          <p className="text-xs text-[var(--color-text-disabled)] mb-1">قيمة العقد غير شاملة الضريبة المضافة</p>
        )}
        {contract.start_date && (
          <p className="text-sm text-[var(--color-text-secondary)] mb-1">من: {contract.start_date}{contract.end_date ? ` إلى ${contract.end_date}` : ''}</p>
        )}

        {contract.clauses?.length > 0 && (
          <div className="mt-4 space-y-2">
            <h4 className="text-sm font-bold text-[var(--color-foreground)] mb-2">بنود العقد</h4>
            {contract.clauses.map((cl: any) => (
              <div key={cl.id} className="text-sm text-[var(--color-text-secondary)] pr-3 border-r-2 border-[var(--color-card-border)] py-1">
                {cl.content}
                <span className="text-xs text-[var(--color-text-disabled)] mr-2">
                  ({cl.type === 'fixed' ? 'ثابت' : cl.type === 'optional' ? 'اختياري' : 'مخصص'})
                </span>
              </div>
            ))}
          </div>
        )}

        {docs.length > 0 && (
          <div className="mt-4 space-y-2">
            <h4 className="text-sm font-bold text-[var(--color-foreground)] mb-2">المستندات المطلوبة</h4>
            {docs.map((doc: any) => {
              const file = doc.files?.[0];
              return (
                <div key={doc.id} className="flex items-center justify-between text-sm border border-[var(--color-card-border)] rounded-lg p-3">
                  <div>
                    <p className="font-medium">{doc.name}</p>
                    {file ? (
                      <div className="flex items-center gap-2 mt-1">
                        <span className={`px-2 py-0.5 rounded-full text-xs ${
                          file.status === 'approved' ? 'bg-green-900/30 text-green-400' :
                          file.status === 'rejected' ? 'bg-red-900/30 text-red-400' :
                          'bg-yellow-900/30 text-yellow-400'
                        }`}>
                          {file.status === 'approved' ? 'مقبول' : file.status === 'rejected' ? 'مرفوض' : 'قيد المراجعة'}
                        </span>
                        <span className="text-xs text-[var(--color-text-disabled)]">{file.name}</span>
                      </div>
                    ) : (
                      <p className="text-xs text-[var(--color-text-disabled)] mt-1">لم يتم رفع المستند بعد</p>
                    )}
                    {file?.status === 'rejected' && file.rejection_reason && (
                      <p className="text-xs text-red-500 mt-1">السبب: {file.rejection_reason}</p>
                    )}
                  </div>
                  <div>
                    {(!file || file.status === 'rejected') ? (
                      <label className={`inline-flex items-center gap-1 text-xs text-[var(--color-gold)] cursor-pointer hover:text-[var(--color-gold)] ${uploading[doc.id] ? 'opacity-50' : ''}`}>
                        <input type="file" className="hidden" disabled={uploading[doc.id]} onChange={(e) => { const f = e.target.files?.[0]; if (f) uploadDoc(doc.id, f); }} />
                        {uploading[doc.id] ? 'جاري الرفع...' : file ? 'رفع مستند جديد' : 'رفع المستند'}
                      </label>
                    ) : null}
                  </div>
                </div>
              );
            })}
            {error && <p className="text-red-500 text-sm mt-2">{error}</p>}
          </div>
        )}

        {canAct && (
          <div className="mt-6 flex gap-2">
            <button onClick={() => onAction('approved')}
              className="flex-1 bg-emerald-600 text-white px-4 py-2.5 rounded-lg text-sm font-medium hover:bg-emerald-700">
              ✔ موافقة
            </button>
            <button onClick={() => onAction('edit_requested')}
              className="flex-1 bg-amber-600 text-white px-4 py-2.5 rounded-lg text-sm font-medium hover:bg-amber-700">
              ✎ طلب تعديل
            </button>
          </div>
        )}

        {!canAct && contract.status !== 'draft' && contract.status !== 'archived' && (
          <p className="mt-4 text-sm text-[var(--color-text-disabled)] text-center">
            {contract.status === 'client_approved' ? 'تمت موافقتك على هذا العقد' :

             contract.status === 'edit_requested' ? 'قمت بطلب تعديل العقد' :
             contract.status === 'company_approved' ? 'تم اعتماد العقد من الشركة' :
             contract.status === 'completed' ? 'العقد مكتمل' : ''}
          </p>
        )}
      </div>
    </div>
  );
}
