'use client';

import { useEffect, useState, useRef } from 'react';
import api from '@/lib/api';
import ChatContractCard from '@/components/chat/ChatContractCard';
import ContractBuilder from '@/components/chat/ContractBuilder';
import { LoadingSkeleton } from '@/components/ui/LoadingSkeleton';
import { EmptyState } from '@/components/ui/EmptyState';

export default function ChatTab({ wsId }: { wsId: number }) {
  const [messages, setMessages] = useState<any[]>([]);
  const [contracts, setContracts] = useState<any[]>([]);
  const [text, setText] = useState('');
  const [loading, setLoading] = useState(true);
  const [showBuilder, setShowBuilder] = useState(false);
  const [uploadFile, setUploadFile] = useState<File | null>(null);
  const fileRef = useRef<HTMLInputElement>(null);
  const bottomRef = useRef<HTMLDivElement>(null);

  const load = () => {
    Promise.all([
      api.get(`/workspaces/${wsId}/chat`).then(({ data }) => setMessages(data.messages || [])),
      api.get(`/workspaces/${wsId}/contracts`).then(({ data }) => setContracts(data.contracts || [])),
    ]).catch(() => {}).finally(() => setLoading(false));
  };

  useEffect(() => { load(); const iv = setInterval(load, 5000); return () => clearInterval(iv); }, [wsId]);

  useEffect(() => { bottomRef.current?.scrollIntoView({ behavior: 'smooth' }); }, [messages]);

  const send = async () => {
    if (!text.trim() && !uploadFile) return;
    const form = new FormData();
    if (text.trim()) form.append('message', text);
    if (uploadFile) form.append('file', uploadFile);
    const { data } = await api.post(`/workspaces/${wsId}/chat`, form).catch(() => ({ data: null }));
    if (data) { setMessages((prev) => [...prev, data.message]); setText(''); setUploadFile(null); if (fileRef.current) fileRef.current.value = ''; }
  };

  const toggleAction = async (id: number) => {
    const { data } = await api.patch(`/chat/${id}/require-action`).catch(() => ({ data: null }));
    if (data) setMessages((prev) => prev.map((m) => m.id === id ? data.message : m));
  };

  const doContractAction = async (id: number, action: string) => {
    const { data } = await api.post(`/contracts/${id}/${action}`).catch(() => ({ data: null }));
    if (data) setContracts((prev) => prev.map((c) => c.id === id ? data.contract : c));
  };

  const onContractCreated = (contract: any) => {
    setContracts((prev) => [contract, ...prev]);
    setShowBuilder(false);
  };

  if (loading) return <LoadingSkeleton message="جاري تحميل المحادثة..." />;

  const actionResultLabel: Record<string, string> = {
    approved: '✅ تمت الموافقة',
    rejected: '❌ تم الرفض',
    edit_requested: '✎ طلب تعديل',
  };

  return (
    <div className="space-y-4">
      {!showBuilder ? (
        <button onClick={() => setShowBuilder(true)} className="text-sm text-blue-600 hover:underline font-medium">
          + إرسال عقد خدمة إضافية
        </button>
      ) : (
        <ContractBuilder wsId={wsId} onCreated={onContractCreated} onCancel={() => setShowBuilder(false)} />
      )}

      <div className="h-72 overflow-y-auto space-y-3 border rounded-lg p-3 bg-zinc-50">
        {contracts.length > 0 && contracts.map((c) => (
          <ChatContractCard key={`contract-${c.id}`} contract={c} onAction={doContractAction} />
        ))}
        {messages.length === 0 && contracts.length === 0 ? <EmptyState message="لا توجد رسائل بعد" /> : null}
        {messages.map((m) => {
          const isClient = m.sender_type === 'App\\Models\\Client';
          const approval = m.approval;
          const isPending = m.requires_action && !m.action_taken;
          const isResponded = m.action_taken;
          return (
          <div key={m.id} className={`flex ${isClient ? 'justify-end' : 'justify-start'}`}>
            <div className="max-w-xs">
              <div className={`px-3 py-2 rounded-lg text-sm ${isClient ? 'bg-zinc-200 text-zinc-800' : 'bg-blue-100 text-blue-900'}`}>
                <p className="text-xs text-zinc-500 mb-0.5">{isClient ? (m.sender?.name || 'العميل') : (m.sender?.name || 'المدير')}</p>
                {m.type === 'file' && m.file_url && (
                  <div className="mb-1">
                    {m.file_url.match(/\.(jpg|jpeg|png|gif|webp|svg)$/i) ? (
                      <img src={m.file_url} alt="مرفق" className="max-w-full rounded-lg max-h-40" />
                    ) : (
                      <a href={m.file_url} target="_blank" rel="noopener noreferrer" className="text-blue-600 underline text-xs">📎 عرض المرفق</a>
                    )}
                  </div>
                )}
                {m.message}
                {isPending && <p className="text-xs text-red-500 mt-1 font-medium">🏷️ طلب موافقة — قيد الانتظار</p>}
                {isResponded && <p className={`text-xs mt-1 font-medium ${m.action_result === 'approved' ? 'text-emerald-600' : m.action_result === 'rejected' ? 'text-red-600' : 'text-amber-600'}`}>{actionResultLabel[m.action_result || '']}</p>}
                {approval?.certificate?.pdf_url && (
                  <a href={`/storage/${approval.certificate.pdf_url}`} target="_blank" rel="noopener noreferrer" className="text-xs text-blue-600 underline block mt-1">📄 تحميل شهادة الموافقة</a>
                )}
              </div>
              {!isClient && !m.action_taken && (
                <button onClick={() => toggleAction(m.id)} className={`text-xs mt-0.5 ${m.requires_action ? 'text-red-500' : 'text-zinc-400'} hover:underline`}>
                  {m.requires_action ? 'إلغاء طلب الموافقة' : 'طلب موافقة العميل'}
                </button>
              )}
            </div>
          </div>
          );
        })}
        <div ref={bottomRef} />
      </div>

      <div className="flex gap-2">
        <input type="file" ref={fileRef} className="hidden" onChange={(e) => setUploadFile(e.target.files?.[0] || null)} />
        <button onClick={() => fileRef.current?.click()} className="text-zinc-500 hover:text-blue-600 text-lg px-1" title="إرفاق ملف">📎</button>
        {uploadFile && <span className="text-xs text-blue-600 self-center truncate max-w-24">{uploadFile.name}</span>}
        <input value={text} onChange={(e) => setText(e.target.value)} onKeyDown={(e) => e.key === 'Enter' && send()}
          className="flex-1 border rounded-lg px-3 py-2 text-sm" placeholder="اكتب رسالة..." />
        <button onClick={send} className="bg-blue-600 text-white px-4 py-2 rounded-lg text-sm hover:bg-blue-700">إرسال</button>
      </div>
    </div>
  );
}
