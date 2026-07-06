'use client';

import { useEffect, useState, useRef } from 'react';
import api from '@/lib/api';
import { getUser } from '@/lib/auth';
import { LoadingSkeleton } from '@/components/ui/LoadingSkeleton';
import { EmptyState } from '@/components/ui/EmptyState';

const APPROVALS_BASE = process.env.NEXT_PUBLIC_API_URL?.replace('/api', '') || 'http://localhost:8000';
function resolveFileUrl(url: string): string {
  if (!url) return '';
  if (url.startsWith('http')) return url;
  return `${APPROVALS_BASE}/storage/${url.replace(/^\/?storage\//, '')}`;
}

export default function ApprovalsTab({ wsId }: { wsId: number }) {
  const isSA = getUser()?.role === 'super_admin';
  const [approvals, setApprovals] = useState<any[]>([]);
  const [title, setTitle] = useState('');
  const [description, setDescription] = useState('');
  const [files, setFiles] = useState<File[]>([]);
  const [loading, setLoading] = useState(true);
  const [sending, setSending] = useState(false);
  const [error, setError] = useState('');
  const fileRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    api.get(`/workspaces/${wsId}/approvals`).then(({ data }) => setApprovals(data.approvals?.data || data.approvals || [])).catch((err) => { console.error('ApprovalsTab: GET /workspaces/${wsId}/approvals failed', err); setError('فشل تحميل طلبات الموافقة'); }).finally(() => setLoading(false));
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
  if (error) return <p className="text-sm text-red-400 text-center py-8">{error}</p>;

  return (
    <div className="space-y-4">
      {!isSA && (
        <div className="space-y-2 border border-[var(--color-card-border)] rounded-lg p-4 bg-[var(--color-card-border)]">
          <h3 className="font-medium text-sm text-[var(--color-foreground)]">طلب موافقة جديد</h3>
          <input value={title} onChange={(e) => setTitle(e.target.value)} placeholder="عنوان طلب الموافقة *" className="border border-[var(--color-input-border)] rounded-lg px-3 py-2 text-sm w-full bg-[var(--color-input-fill)] text-[var(--color-foreground)]" />
          <textarea value={description} onChange={(e) => setDescription(e.target.value)} placeholder="الوصف (اختياري)" className="border border-[var(--color-input-border)] rounded-lg px-3 py-2 text-sm w-full bg-[var(--color-input-fill)] text-[var(--color-foreground)]" rows={2} />

          <div className="flex items-center gap-2">
            <input type="file" ref={fileRef} multiple className="hidden" onChange={(e) => { if (e.target.files) setFiles((prev) => [...prev, ...Array.from(e.target.files!)]); }} />
            <button onClick={() => fileRef.current?.click()} className="text-sm text-[var(--color-gold)] hover:underline">+ إرفاق ملفات</button>
            {files.length > 0 && (
              <div className="flex items-center gap-1">
                {files.map((f, i) => (
                  <span key={i} className="text-xs bg-blue-900/30 text-blue-400 px-2 py-0.5 rounded flex items-center gap-1">
                    {f.name}
                    <button onClick={() => removeFile(i)} className="text-red-500 hover:text-red-700">&times;</button>
                  </span>
                ))}
              </div>
            )}
          </div>

          <button onClick={sendApproval} disabled={sending || !title} className="bg-[var(--color-primary)] text-white px-4 py-2 rounded-lg text-sm hover:bg-[var(--color-primary-dark)] disabled:opacity-50">
            {sending ? 'جاري الإرسال...' : 'إرسال طلب موافقة'}
          </button>
        </div>
      )}

      {approvals.length === 0 ? <EmptyState message="لا توجد طلبات موافقة" /> : null}
      {approvals.map((a) => {
        const statusColors: Record<string, string> = {
          approved: 'bg-emerald-900/30 text-emerald-400',
          pending: 'bg-yellow-900/30 text-yellow-400',
          rejected: 'bg-red-900/30 text-red-400',
          edit_requested: 'bg-amber-900/30 text-amber-400',
        };
        const statusLabels: Record<string, string> = {
          approved: '✅ تمت الموافقة',
          pending: '⏳ قيد الانتظار',
          rejected: '❌ مرفوض',
          edit_requested: '✎ طلب تعديل',
        };
        return (
          <div key={a.id} className="border border-[var(--color-card-border)] rounded-lg p-4">
            <div className="flex justify-between items-start">
              <div>
                <h4 className="font-medium">{a.title}</h4>
                {a.description && <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">{a.description}</p>}
                {a.reference_no && <p className="text-xs text-[var(--color-text-disabled)] mt-0.5">مرجع: {a.reference_no}</p>}
              </div>
              <span className={`px-2 py-0.5 rounded-full text-xs ${statusColors[a.status] || 'bg-zinc-700/30 text-zinc-400'}`}>
                {statusLabels[a.status] || a.status}
              </span>
            </div>

            {/* Files */}
            {a.files && a.files.length > 0 && (
              <div className="mt-2 flex flex-wrap gap-1">
                {a.files.map((f: any) => (
                  <a key={f.id} href={`/storage/${f.file_url}`} target="_blank" rel="noopener noreferrer"
                    className="text-xs text-[var(--color-gold)] underline bg-blue-900/30 px-2 py-0.5 rounded">
                    📎 {f.name || 'ملف'}
                  </a>
                ))}
              </div>
            )}

            {/* Certificate */}
            {a.certificate && (
              <div className="mt-2 text-xs text-[var(--color-gold)]">
                <a href={resolveFileUrl(a.certificate.pdf_url)} target="_blank" rel="noopener noreferrer">📄 تحميل شهادة الموافقة</a>
              </div>
            )}
          </div>
        );
      })}
    </div>
  );
}
