'use client';

import { useEffect, useState } from 'react';
import api from '@/lib/api';
import { StatusBadge } from '@/components/ui/StatusBadge';
import ContractStatusStepper from '@/components/ui/ContractStatusStepper';
import { LoadingSkeleton } from '@/components/ui/LoadingSkeleton';
import { EmptyState } from '@/components/ui/EmptyState';
import { ConfirmDialog } from '@/components/ui/ConfirmDialog';
import ContractDetailModal from './ContractDetailModal';

export default function ClientContracts({ wsId, clientType, onGoToPayments }: { wsId: number; clientType?: string; onGoToPayments?: () => void }) {
  const [contracts, setContracts] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [viewContract, setViewContract] = useState<any>(null);
  const [confirmAction, setConfirmAction] = useState<{ id: number; action: string } | null>(null);

  const load = () => {
    setLoading(true);
    api.get(`/workspaces/${wsId}/contracts`)
      .then(({ data }) => {
        const list = data.contracts?.data ?? data.contracts ?? [];
        const arr = Array.isArray(list) ? list : [];
        setContracts(arr);
        setViewContract((prev: any) => prev ? arr.find((c: any) => c.id === prev.id) || prev : prev);
      })
      .catch(() => setError('فشل تحميل العقود'))
      .finally(() => setLoading(false));
  };

  useEffect(() => { load(); }, [wsId]);

  const doAction = async (id: number, action: string) => {
    const { data } = await api.post(`/contracts/${id}/client-action`, { action }).catch(() => ({ data: null }));
    if (data) {
      setContracts((prev) => Array.isArray(prev) ? prev.map((c) => c.id === id ? data.contract : c) : prev);
      setViewContract(null);
    }
    setConfirmAction(null);
  };

  if (loading) return <LoadingSkeleton />;
  if (error) return <p className="text-sm text-red-500 text-center py-8">{error}</p>;

  return (
    <div className="space-y-3">
      {contracts.length === 0 ? <EmptyState message="لا توجد عقود" /> : null}
      {contracts.map((c) => (
        <div key={c.id} className="border border-[var(--color-card-border)] rounded-lg p-4">
          <div className="flex justify-between items-start">
            <div>
              <h4 className="font-medium">{c.title}</h4>
              {c.value > 0 && <p className="text-xs text-[var(--color-text-secondary)]">{c.value} ر.س</p>}
              {c.required_documents?.length > 0 && <p className="text-xs text-amber-600 mt-0.5">📎 {c.required_documents.length} مستند مطلوب</p>}
            </div>
            <StatusBadge status={c.status} />
          </div>
          <ContractStatusStepper status={c.status} compact />
          <div className="mt-2 flex gap-2">
            <button onClick={() => setViewContract(c)} className="text-xs text-[var(--color-gold)] hover:underline">
              عرض التفاصيل
            </button>
            {c.status === 'sent' && (
              <>
                <button onClick={() => setConfirmAction({ id: c.id, action: 'approved' })}
                  className="text-xs text-emerald-600 hover:underline">✔ موافقة</button>
                <button onClick={() => setConfirmAction({ id: c.id, action: 'edit_requested' })}
                  className="text-xs text-amber-600 hover:underline">✎ طلب تعديل</button>
              </>
            )}
            {c.status === 'company_approved' && (
              <div className="mt-2 space-y-1">
                <p className="text-xs text-emerald-600">✅ تم اعتماد العقد من الشركة</p>
                {c.pdf_url && (
                  <a href={c.pdf_url} target="_blank" rel="noopener noreferrer"
                    className="text-xs text-emerald-600 hover:underline block">📄 تحميل العقد النهائي</a>
                )}
                {onGoToPayments && (
                  <button onClick={onGoToPayments}
                    className="text-xs bg-[var(--color-primary)] text-white px-3 py-1.5 rounded-lg hover:bg-[var(--color-primary-dark)] mt-1">
                    💳 انتقال إلى الدفع
                  </button>
                )}
              </div>
            )}
          </div>
        </div>
      ))}

      {viewContract && (
        <ContractDetailModal
          contract={viewContract}
          wsId={wsId}
          clientType={clientType}
          onClose={() => setViewContract(null)}
          onAction={(action) => setConfirmAction({ id: viewContract.id, action })}
          onUpload={load}
        />
      )}

      <ConfirmDialog
        open={!!confirmAction}
        title={confirmAction?.action === 'approved' ? 'موافقة على العقد' : 'طلب تعديل العقد'}
        message={confirmAction?.action === 'approved' ? 'تأكيد الموافقة على هذا العقد؟' : 'تأكيد طلب تعديل هذا العقد؟'}
        confirmLabel={confirmAction?.action === 'approved' ? 'موافقة' : 'طلب تعديل'}
        cancelLabel="إلغاء"
        variant="default"
        onConfirm={() => confirmAction && doAction(confirmAction.id, confirmAction.action)}
        onCancel={() => setConfirmAction(null)}
      />
    </div>
  );
}
