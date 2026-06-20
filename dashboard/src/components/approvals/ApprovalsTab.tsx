'use client';

import { useEffect, useState, useRef } from 'react';
import api from '@/lib/api';
import { LoadingSkeleton } from '@/components/ui/LoadingSkeleton';
import { EmptyState } from '@/components/ui/EmptyState';

export default function ApprovalsTab({ wsId }: { wsId: number }) {
  const [approvals, setApprovals] = useState<any[]>([]);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [files, setFiles] = useState<File[]>([]);
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const fileRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    api.get(`/workspaces/${wsId}/approvals`).then(({ data }) => setApprovals(data.approvals || [])).catch(() => {}).finally(() => setLoading(false));
  }, [wsId]);

  const removeFile = (i: number) => setFiles((prev) => prev.filter((_, idx) => idx !== i));

  const sendApproval = async () => {
    if (!title || sending) return;
    setSending(true);
    const form = new FormData();
    form.append('title', title);
    if (description) form.append('description', description);
    files.forEach((f) => form.append('files[]', f));
    const { data } = await api.post(`/workspaces/${wsId}/approvals`, form).catch(() => ({ data: null }));
    if (data) { setApprovals((prev) => [data.approval, ...prev]); setTitle(''); setDescription(''); setFiles([]); }
    setSending(false);
  };

  if (loading) return <LoadingSkeleton />;

  return (
    <div className="space-y-4">
      <div className="space-y-2 border rounded-lg p-4 bg-zinc-50">
        <h3 className="font-medium text-sm text-zinc-700">طلب موافقة جديد</h3>
        <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="عنوان طلب الموافقة *" className="border rounded-lg px-3 py-2 text-sm w-full" />
        <textarea value={description} onChange={(e) => setDescription(e.target.value)} placeholder="الوصف (اختياري)" className="border rounded-lg px-3 py-2 text-sm w-full" rows={2} />

        <div className="flex items-center gap-2">
          <input type="file" ref={fileRef} multiple className="hidden" onChange={(e) => { if (e.target.files) setFiles((prev) => [...prev, ...Array.from(e.target.files!)]); }} />
          <button onClick={() => fileRef.current?.click()} className="text-sm text-blue-600 hover:underline">+ إرفاق ملفات</button>
          {files.length > 0 && (
            <div className="flex items-center gap-1">
              {files.map((f, i) => (
                <span key={i} className="text-xs bg-blue-100 text-blue-700 px-2 py-0.5 rounded flex items-center gap-1">
                  {f.name}
                  <button onClick={() => removeFile(i)} className="text-red-500 hover:text-red-700">&times;</button>
                </span>
              ))}
            </div>
          )}
        </div>

        <button onClick={sendApproval} disabled={sending || !title} className="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-blue-700 disabled:opacity-50">
          {sending ? 'جاري الإرسال...' : 'إرسال طلب موافقة'}
        </button>
      </div>

      {approvals.length === 0 ? <EmptyState message="لا توجد طلبات موافقة" /> : null}
      {approvals.map((a) => {
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
          <div key={a.id} className="border rounded-lg p-4">
            <div className="flex justify-between items-start">
              <div>
                <h4 className="font-medium">{a.title}</h4>
                {a.description && <p className="text-xs text-zinc-500 mt-0.5">{a.description}</p>}
                {a.reference_no && <p className="text-xs text-zinc-400 mt-0.5">مرجع: {a.reference_no}</p>}
              </div>
              <span className={`px-2 py-0.5 rounded-full text-xs ${statusColors[a.status] || 'bg-zinc-100 text-zinc-600'}`}>
                {statusLabels[a.status] || a.status}
              </span>
            </div>

            {/* Files */}
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

            {/* Certificate */}
            {a.certificate && (
              <div className="mt-2 text-xs text-blue-600">
                <a href={`/storage/${a.certificate.pdf_url}`} target="_blank" rel="noopener noreferrer">📄 تحميل شهادة الموافقة</a>
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}
