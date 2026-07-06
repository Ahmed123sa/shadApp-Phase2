'use client';

import { useEffect, useState, useRef } from 'react';
import api from '@/lib/api';
import { subscribeToWorkspace } from '@/lib/echo';
import { LoadingSkeleton } from '@/components/ui/LoadingSkeleton';
import { EmptyState } from '@/components/ui/EmptyState';

const CLIENT_FILE_BASE = process.env.NEXT_PUBLIC_API_URL?.replace('/api', '') || 'http://localhost:8000';
function resolveFileUrl(url: string): string {
  if (!url) return '';
  if (url.startsWith('http')) return url;
  return `${CLIENT_FILE_BASE}/storage/${url.replace(/^\/?storage\//, '')}`;
}

export default function ClientChat({ wsId, wsActive }: { wsId: number; wsActive?: boolean }) {
  const [messages, setMessages] = useState<any[]>([]);
  const [text, setText] = useState('');
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');
  const [sendError, setSendError] = useState('');
  const [uploadFile, setUploadFile] = useState<File | null>(null);
  const [responding, setResponding] = useState<Record<number, boolean>>({});
  const fileRef = useRef<HTMLInputElement>(null);
  const bottomRef = useRef<HTMLDivElement>(null);

  const load = () => {
    api.get(`/workspaces/${wsId}/chat`)
      .then(({ data }) => { setMessages(data.messages || []); setError(''); })
      .catch(() => setError('فشل تحميل المحادثة'))
      .finally(() => setLoading(false));
  };

  useEffect(() => {
    load();
    const iv = setInterval(load, 60000);
    const unsub = subscribeToWorkspace(wsId, {
      onMessageSent: () => { load(); },
    });
    return () => { clearInterval(iv); if (unsub) unsub(); };
  }, [wsId]);

  useEffect(() => { bottomRef.current?.scrollIntoView({ behavior: 'smooth' }); }, [messages]);

  const send = async () => {
    if (!text.trim() && !uploadFile) return;
    setSendError('');
    const form = new FormData();
    if (text.trim()) form.append('message', text);
    if (uploadFile) form.append('file', uploadFile);
    try {
      const { data } = await api.post(`/workspaces/${wsId}/chat`, form);
      if (data?.message) { setMessages((prev) => [...prev, data.message]); setText(''); setUploadFile(null); if (fileRef.current) fileRef.current.value = ''; }
    } catch {
      setText('');
      setUploadFile(null);
      if (fileRef.current) fileRef.current.value = '';
      load();
    }
  };

  const respond = async (id: number, action: string) => {
    setResponding((prev) => ({ ...prev, [id]: true }));
    const { data } = await api.post(`/chat/${id}/respond`, { action }).catch(() => ({ data: null }));
    if (data) setMessages((prev) => prev.map((m) => m.id === id ? data.message : m));
    setResponding((prev) => ({ ...prev, [id]: false }));
  };

  const actionResultLabel: Record<string, string> = {
    approved: '✅ تمت الموافقة',
    edit_requested: '✎ تم طلب تعديل',
  };

  if (loading) return <LoadingSkeleton message="جاري تحميل المحادثة..." />;
  if (error) return <p className="text-sm text-red-500 text-center py-8">{error}</p>;

  if (!wsActive) {
    return (
      <div className="text-center py-10">
        <span className="text-4xl block mb-3">🔒</span>
        <p className="text-[var(--color-text-secondary)] text-sm">المحادثة غير متاحة — في انتظار تفعيل مساحة العمل بعد اكتمال الدفع</p>
      </div>
    );
  }

  return (
    <div className="space-y-4">
      <div className="h-72 overflow-y-auto space-y-3 border border-[var(--color-card-border)] rounded-lg p-3 bg-[var(--color-card-border)]">
        {messages.length === 0 ? <EmptyState message="لا توجد رسائل بعد" /> : null}
        {messages.map((m) => {
          const sentByClient = m.sender_type === 'App\\Models\\Client';
          const isPending = m.requires_action && !m.action_taken;
          const isResponded = m.action_taken;
          const approval = m.approval;
          return (
            <div key={m.id} className={`flex ${sentByClient ? 'justify-end' : 'justify-start'}`}>
              <div className="max-w-xs">
                <div className={`px-3 py-2 rounded-lg text-sm ${sentByClient ? 'bg-[var(--color-primary)] text-white' : 'bg-[var(--color-input-fill)] text-[var(--color-foreground)]'}`}>
                  <p className={`text-xs mb-0.5 ${sentByClient ? 'text-blue-200' : 'text-[var(--color-text-secondary)]'}`}>
                    {sentByClient ? 'أنت' : ((m.sender?.role === 'super_admin' ? 'مشرف' : 'مدير حساب') + ': ' + (m.sender?.name || ''))}
                  </p>
                  {m.type === 'file' && m.file_url && (
                    <div className="mb-1">
                      {m.file_url.match(/\.(jpg|jpeg|png|gif|webp|svg)$/i) ? (
                        <img src={resolveFileUrl(m.file_url)} alt="مرفق" className="max-w-full rounded-lg max-h-40" />
                      ) : (
                        <a href={resolveFileUrl(m.file_url)} target="_blank" rel="noopener noreferrer" className="text-[var(--color-gold)] underline text-xs">📎 عرض المرفق</a>
                      )}
                    </div>
                  )}
                  {m.message}
                  {isPending && <p className="text-xs text-red-500 mt-1 font-medium">🏷️ يتطلب موافقتك</p>}
                  {isResponded && <p className={`text-xs mt-1 font-medium ${m.action_result === 'approved' ? 'text-emerald-600' : m.action_result === 'rejected' ? 'text-red-600' : 'text-amber-600'}`}>{actionResultLabel[m.action_result || '']}</p>}
                  {approval?.certificate?.pdf_url && (
                    <a href={resolveFileUrl(approval.certificate.pdf_url)} target="_blank" rel="noopener noreferrer" className="text-xs text-[var(--color-gold)] underline block mt-1">📄 تحميل شهادة الموافقة</a>
                  )}
                </div>
                {isPending && (
                  <div className="flex gap-1 mt-1">
                    <button onClick={() => respond(m.id, 'approved')} disabled={responding[m.id]}
                      className="text-xs bg-emerald-600 text-white px-2 py-1 rounded hover:bg-emerald-700 disabled:opacity-50">✔ موافقة</button>
                    <button onClick={() => respond(m.id, 'edit_requested')} disabled={responding[m.id]}
                      className="text-xs bg-amber-600 text-white px-2 py-1 rounded hover:bg-amber-700 disabled:opacity-50">✎ تعديل</button>
                  </div>
                )}
              </div>
            </div>
          );
        })}
        <div ref={bottomRef} />
      </div>

      {sendError && <p className="text-xs text-red-500">{sendError}</p>}
      <div className="flex gap-2">
        <input type="file" ref={fileRef} className="hidden" onChange={(e) => setUploadFile(e.target.files?.[0] || null)} />
        <button onClick={() => fileRef.current?.click()} className="text-[var(--color-text-secondary)] hover:text-[var(--color-gold)] text-lg px-1" title="إرفاق ملف">📎</button>
        {uploadFile && <span className="text-xs text-[var(--color-gold)] self-center truncate max-w-24">{uploadFile.name}</span>}
        <input value={text} onChange={(e) => setText(e.target.value)}
          onKeyDown={(e) => e.key === 'Enter' && send()}
          className="flex-1 border border-[var(--color-input-border)] rounded-lg px-3 py-2 text-sm bg-[var(--color-input-fill)] text-[var(--color-foreground)] placeholder-[var(--color-text-disabled)]" placeholder="اكتب رسالة..." />
        <button onClick={send} className="bg-[var(--color-primary)] text-white px-4 py-2 rounded-lg text-sm hover:bg-[var(--color-primary-dark)]">إرسال</button>
      </div>
    </div>
  );
}
