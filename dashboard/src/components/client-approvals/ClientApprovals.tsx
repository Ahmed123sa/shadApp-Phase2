'use client';

import { useEffect, useState } from 'react';
import api from '@/lib/api';
import { LoadingSkeleton } from '@/components/ui/LoadingSkeleton';
import { EmptyState } from '@/components/ui/EmptyState';
import { ConfirmDialog } from '@/components/ui/ConfirmDialog';

export default function ClientApprovals({ wsId, clientId }: { wsId: number; clientId: number }) {
  const [approvals, setApprovals] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [respondTarget, setRespondTarget] = useState<{ id: number; action: string } | null>(null);

  useEffect(() => {
    api.get(`/workspaces/${wsId}/approvals`)
      .then(({ data }) => setApprovals(data.approvals || []))
      .catch(() => setError('فشل تحميل طلبات الموافقة'))
      .finally(() => setLoading(false));
  }, [wsId]);

  const respond = async () => {
    if (!respondTarget) return;
    const { data } = await api.post(`/approvals/${respondTarget.id}/respond`, { action: respondTarget.action }).catch(() => ({ data: null }));
    if (data) {
      setApprovals((prev) => prev.map((a) => a.id === respondTarget.id ? data.approval : a));
    }
    setRespondTarget(null);
  };

  if (loading) return <LoadingSkeleton />;
  if (error) return <p className="text-sm text-red-500 text-center py-8">{error}</p>;

  const statusColors: Record<string, string> = {
    approved: 'bg-emerald-100 text-emerald-700',
    pending: 'bg-yellow-100 text-yellow-700',
    rejected: 'bg-red-100 text-red-700',
    edit_requested: 'bg-amber-100 text-amber-700',
  };
  const statusLabels: Record<string, string> = {
    approved: '✅ تمت الموافقة',
    pending: '⏳ قيد الانتظار',
    rejected: '❌ مرفوض',
    edit_requested: '✎ طلب تعديل',
  };

  return (
    <div className="space-y-3">
      {approvals.length === 0 ? <EmptyState message="لا توجد طلبات موافقة" /> : null}
      {approvals.map((a) => (
        <div key={a.id} className="border rounded-lg p-4">
          <div className="flex justify-between items-start">
            <div>
              <h4 className="font-medium">{a.title}</h4>
              {a.description && <p className="text-xs text-zinc-500 mt-0.5">{a.description}</p>}
              <p className="text-xs text-zinc-400 mt-0.5">المرجع: {a.reference_no}</p>
            </div>
            <span className={`px-2.5 py-0.5 rounded-full text-xs font-medium ${statusColors[a.status] || ''}`}>
              {statusLabels[a.status] || a.status}
            </span>
          </div>

          {a.files && a.files.length > 0 && (
            <div className="mt-2 flex flex-wrap gap-1">
              {a.files.map((f: any) => (
                <a key={f.id} href={`/storage/${f.file_url}`} target="_blank" rel="noopener noreferrer"
                  className="text-xs text-blue-600 underline bg-blue-50 px-2 py-0.5 rounded">
                  📎 {f.name || 'ملف'}
                </a>
              ))}
            </div>
          )}

          {a.certificate?.pdf_url && (
            <div className="mt-2 text-xs text-blue-600">
              📄 <a href={`/storage/${a.certificate.pdf_url}`} target="_blank" rel="noopener noreferrer" className="hover:underline">شهادة الموافقة</a>
            </div>
          )}

          {a.status === 'pending' && (
            <div className="mt-3 flex gap-2">
              <button onClick={() => setRespondTarget({ id: a.id, action: 'approved' })}
                className="text-xs bg-emerald-600 text-white px-3 py-1.5 rounded-lg hover:bg-emerald-700">✔ موافقة</button>
              <button onClick={() => setRespondTarget({ id: a.id, action: 'rejected' })}
                className="text-xs bg-red-600 text-white px-3 py-1.5 rounded-lg hover:bg-red-700">✘ رفض</button>
              <button onClick={() => setRespondTarget({ id: a.id, action: 'edit_requested' })}
                className="text-xs bg-amber-600 text-white px-3 py-1.5 rounded-lg hover:bg-amber-700">طلب تعديل</button>
            </div>
          )}
        </div>
      ))}

      <ConfirmDialog
        open={!!respondTarget}
        title={respondTarget?.action === 'approved' ? 'موافقة' : respondTarget?.action === 'rejected' ? 'رفض' : 'طلب تعديل'}
        message={
          respondTarget?.action === 'approved'
            ? 'سيتم استخدام توقيعك الإلكتروني المحفوظ. هل أنت متأكد؟'
            : respondTarget?.action === 'rejected'
            ? 'تأكيد رفض هذا الطلب؟'
            : 'تأكيد طلب تعديل هذا الطلب؟'
        }
        confirmLabel="تأكيد"
        cancelLabel="إلغاء"
        variant={respondTarget?.action === 'rejected' ? 'danger' : 'default'}
        onConfirm={respond}
        onCancel={() => setRespondTarget(null)}
      />
    </div>
  );
}
