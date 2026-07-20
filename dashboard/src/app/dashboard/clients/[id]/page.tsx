'use client';

import { useEffect, useState } from 'react';
import api from '@/lib/api';
import { getUser } from '@/lib/auth';
import { useParams, useSearchParams } from 'next/navigation';
import Link from 'next/link';
import type { Client } from '@/types';
import { LoadingSkeleton } from '@/components/ui/LoadingSkeleton';
import { EmptyState } from '@/components/ui/EmptyState';
import { ConfirmDialog } from '@/components/ui/ConfirmDialog';
import { StatusBadge } from '@/components/ui/StatusBadge';
import { ClientTypeBadge } from '@/components/ui/ClientTypeBadge';
import ChatTab from '@/components/chat/ChatTab';
import FilesTab from '@/components/files/FilesTab';
import ContractsTab from '@/components/contracts/ContractsTab';
import PaymentsTab from '@/components/payments/PaymentsTab';
import ApprovalsTab from '@/components/approvals/ApprovalsTab';
import MeetingsTab from '@/components/meetings/MeetingsTab';
import CalendarTab from '@/components/calendar/CalendarTab';
import NoWorkspace from '@/components/workspace/NoWorkspace';

const FILE_BASE = process.env.NEXT_PUBLIC_API_URL?.replace('/api', '') || 'http://localhost:8000';

function resolveFileUrl(url: string): string {
  if (!url) return '';
  if (url.startsWith('http')) return url;
  return `${FILE_BASE}/storage/${url.replace(/^\/?storage\//, '')}`;
}

const TABS = ['المحادثة', 'الملفات', 'العقود', 'المدفوعات', 'الموافقات', 'الاجتماعات', 'التقويم'] as const;
type Tab = (typeof TABS)[number];

export default function ClientWorkspace() {
  const { id } = useParams();
  const searchParams = useSearchParams();
  const [client, setClient] = useState<Client | null>(null);
  const [activeTab, setActiveTab] = useState<Tab>('المحادثة');

  useEffect(() => {
    const t = searchParams.get('tab');
    if (t && (TABS as readonly string[]).includes(t)) {
      setActiveTab(t as Tab);
    }
  }, [searchParams]);
  const [loading, setLoading] = useState(true);
  const [deleteConfirm, setDeleteConfirm] = useState(false);

  const load = () => api.get(`/clients/${id}`).then(({ data }) => { setClient(data.client); }).catch(() => {}).finally(() => setLoading(false));
  useEffect(() => { load(); }, [id]);

  const deleteClient = async () => {
    await api.delete(`/clients/${id}`).catch(() => {});
    window.location.href = '/dashboard/clients';
  };

  if (loading) return <div className="py-20"><LoadingSkeleton message="جاري تحميل مساحة العمل..." /></div>;
  if (!client) return <EmptyState message="العميل غير موجود" />;

  const isSA = getUser()?.role === 'super_admin';
  const wsId = client.workspace?.id;

  return (
    <div className="space-y-6">
      <div className="bg-[var(--color-card)] rounded-xl border border-[var(--color-card-border)] p-5 border-r-2 border-r-[var(--color-primary)]">
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="w-12 h-12 rounded-full bg-[var(--color-input-fill)] overflow-hidden border-2 border-[var(--color-card-border)] flex-shrink-0">
              {client.avatar_url ? (
                <img src={resolveFileUrl(client.avatar_url)} alt="" className="w-full h-full object-cover" />
              ) : (
                <div className="w-full h-full flex items-center justify-center text-lg text-[var(--color-text-disabled)]">
                  {client.company_name?.[0] || '?'}
                </div>
              )}
            </div>
            <div>
              <div className="flex items-center gap-2">
                <h2 className="text-xl font-bold">{client.company_name}</h2>
                <ClientTypeBadge clientType={client.client_type} />
              </div>
              <p className="text-sm text-[var(--color-text-secondary)]">{client.contact_person} • {client.email}{client.country ? ` • ${client.country}` : ''}{client.industry ? ` • ${client.industry}` : ''}</p>
            </div>
          </div>
          <div className="flex items-center gap-2">
            {!isSA && <Link href={`/dashboard/clients/${id}/settings`} className="inline-flex items-center justify-center w-8 h-8 rounded-lg hover:bg-[var(--color-card-border)] transition-colors text-[var(--color-text-secondary)] hover:text-[var(--color-foreground)]" title="إعدادات">⚙️</Link>}
            {!isSA && <button onClick={() => setDeleteConfirm(true)} className="inline-flex items-center justify-center w-8 h-8 rounded-lg hover:bg-red-900/30 transition-colors text-[var(--color-text-secondary)] hover:text-red-400" title="حذف">🗑️</button>}
            <StatusBadge status={client.workspace?.status === 'active' ? 'active' : 'inactive'} />
            <span className={`px-2.5 py-1 rounded-full text-xs ${client.signed_at ? 'bg-purple-900/30 text-purple-400' : 'bg-[var(--color-input-fill)] text-[var(--color-text-secondary)]'}`}>
              {client.signed_at ? 'تم التوقيع ✅' : 'لم يتم التوقيع'}
            </span>
          </div>
        </div>
      </div>

      <div className="bg-[var(--color-card)] rounded-xl border border-[var(--color-card-border)] overflow-hidden">
        <div className="flex border-b border-[var(--color-card-border)] overflow-x-auto">
          {TABS.map((tab) => (
            <button key={tab} onClick={() => setActiveTab(tab)}
              className={`px-5 py-3 text-sm whitespace-nowrap border-b-2 transition ${activeTab === tab ? 'border-[var(--color-primary)] text-[var(--color-primary)] font-medium' : 'border-transparent text-[var(--color-text-disabled)] hover:text-[var(--color-foreground)]'}`}>
              {tab}
            </button>
          ))}
        </div>
        <div className="p-5">
          {wsId ? <TabContent tab={activeTab} wsId={wsId} client={client} onClientRefresh={load} /> :
            <NoWorkspace client={client} />}
        </div>
      </div>

      <ConfirmDialog
        open={deleteConfirm}
        title="حذف العميل"
        message="حذف العميل نهائياً؟ لا يمكن التراجع عن هذا الإجراء."
        confirmLabel="حذف"
        cancelLabel="إلغاء"
        variant="danger"
        onConfirm={deleteClient}
        onCancel={() => setDeleteConfirm(false)}
      />
    </div>
  );
}

function TabContent({ tab, wsId, client, onClientRefresh }: { tab: Tab; wsId: number; client: Client; onClientRefresh?: () => void }) {
  const wsActive = client.workspace?.status === 'active';
  switch (tab) {
    case 'المحادثة': return <ChatTab wsId={wsId} wsActive={wsActive} clientType={client.client_type} />;
    case 'الملفات': return <FilesTab wsId={wsId} />;
    case 'العقود': return <ContractsTab wsId={wsId} clientType={client.client_type} />;
    case 'المدفوعات': return <PaymentsTab wsId={wsId} client={client} onWorkspaceUpdate={onClientRefresh} />;
    case 'الموافقات': return <ApprovalsTab wsId={wsId} />;
    case 'الاجتماعات': return <MeetingsTab wsId={wsId} />;
    case 'التقويم': return <CalendarTab wsId={wsId} />;
  }
}
