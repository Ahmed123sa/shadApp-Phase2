'use client';

import { useEffect, useState } from 'react';
import { useRouter, useSearchParams } from 'next/navigation';
import { isClientAuthenticated, getClient, clientLogout } from '@/lib/client-auth';
import api from '@/lib/api';
import { LoadingSkeleton } from '@/components/ui/LoadingSkeleton';
import ClientContracts from '@/components/client-contracts/ClientContracts';
import ClientPayments from '@/components/client-payments/ClientPayments';
import ClientApprovals from '@/components/client-approvals/ClientApprovals';
import ClientChat from '@/components/client-chat/ClientChat';
import ClientFiles from '@/components/client-files/ClientFiles';
import ClientMeetings from '@/components/client-meetings/ClientMeetings';
import ClientSignature from '@/components/client-signature/ClientSignature';
import ClientSubUsers from '@/components/client-subusers/ClientSubUsers';
import StagesStepper from '@/components/client-dashboard/StagesStepper';
import Link from 'next/link';

const TABS = [
  'العقود', 'المدفوعات', 'الموافقات', 'الشات', 'الملفات', 'الاجتماعات', 'التوقيع', 'المستخدمين',
] as const;
type Tab = (typeof TABS)[number];

export default function ClientDashboardPage() {
  const router = useRouter();
  const searchParams = useSearchParams();
  const [mounted, setMounted] = useState(false);
  const [client, setClient] = useState<any>(null);
  const [workspace, setWorkspace] = useState<any>(null);
  const [activeTab, setActiveTab] = useState<Tab>('العقود');

  useEffect(() => {
    const t = searchParams.get('tab');
    if (t && (TABS as readonly string[]).includes(t)) {
      setActiveTab(t as Tab);
    }
  }, [searchParams]);
  const [loading, setLoading] = useState(true);
  const [fetchKey, setFetchKey] = useState(0);
  const session = getClient();

  useEffect(() => {
    setMounted(true);
    if (typeof window !== 'undefined' && !isClientAuthenticated()) {
      router.push('/client-login');
    }
  }, [router]);

  useEffect(() => {
    if (!session?.id) return;
    api.get(`/clients/${session.id}`).then(({ data }) => {
      setClient(data.client);
      const ws = data.client.workspace;
      if (ws?.id) {
        api.get(`/workspaces/${ws.id}`).then(({ data: wsData }) => setWorkspace(wsData.workspace)).catch(() => {});
      }
    }).catch(() => {}).finally(() => setLoading(false));
  }, [session?.id, fetchKey]);

  // Periodic workspace refresh — must be before any early return
  useEffect(() => {
    const id = workspace?.id;
    if (!id) return;
    const interval = setInterval(() => {
      api.get(`/workspaces/${id}`).then(({ data }) => setWorkspace(data.workspace)).catch(() => {});
    }, 10000);
    return () => clearInterval(interval);
  }, [workspace?.id]);

  if (!mounted) return <div className="min-h-screen flex items-center justify-center text-[var(--color-text-secondary)]">جاري التحميل...</div>;
  if (loading) return <div className="min-h-screen flex items-center justify-center"><LoadingSkeleton message="جاري تحميل بيانات العميل..." /></div>;
  if (!session || !client) return null;

  const hasSigned = !!client.signed_at;
  const wsId = workspace?.id;
  const wsActive = workspace?.status === 'active';
  const workspaceExists = !!wsId;

  if (!hasSigned) {
    return (
      <div className="min-h-screen bg-[var(--color-background)]">
        <header className="bg-[var(--color-card)] border-b border-[var(--color-card-border)] px-6 py-4 flex items-center justify-between">
          <h1 className="text-lg font-bold">ShadApp</h1>
          <div className="flex items-center gap-3">
            <button onClick={clientLogout} className="text-xs bg-[var(--color-input-fill)] hover:bg-[var(--color-card-border)] px-3 py-1.5 rounded-lg">تسجيل خروج</button>
          </div>
        </header>
        <main className="max-w-2xl mx-auto p-6 space-y-6">
          <div className="bg-[var(--color-card)] rounded-2xl border border-[var(--color-card-border)] p-8 text-center">
            <div className="text-5xl mb-4">👋</div>
            <h2 className="text-2xl font-bold mb-2">مرحباً بك في ShadApp</h2>
            <p className="text-[var(--color-text-secondary)] mb-6">خطوة بسيطة للبدء — سجل توقيعك الإلكتروني</p>

            <div className="space-y-3 text-right max-w-md mx-auto">
              <div className="flex items-center gap-3 p-3 bg-emerald-50 rounded-lg">
                <span className="text-emerald-600 text-lg">✅</span>
                <span className="text-sm text-emerald-700 font-medium">تم إنشاء حسابك بنجاح</span>
              </div>
              <div className="flex items-center gap-3 p-3 bg-amber-50 rounded-lg border-2 border-amber-300">
                <span className="text-amber-600 text-lg">📝</span>
                <span className="text-sm text-amber-700 font-medium">سجل توقيعك الإلكتروني — مطلوب أولاً</span>
              </div>
              <div className="flex items-center gap-3 p-3 bg-[var(--color-card-border)] rounded-lg text-[var(--color-text-disabled)]">
                <span className="text-lg">⏳</span>
                <span className="text-sm">انتظار تفعيل مساحة العمل (بعد إصدار العقد)</span>
              </div>
            </div>
          </div>

          <ClientSignature clientId={session.id} clientData={client} onSigned={() => setFetchKey((k) => k + 1)} />
        </main>
      </div>
    );
  }

  if (!workspaceExists) {
    return (
      <div className="min-h-screen bg-[var(--color-background)]">
        <header className="bg-[var(--color-card)] border-b border-[var(--color-card-border)] px-6 py-4 flex items-center justify-between">
          <h1 className="text-lg font-bold">ShadApp</h1>
          <div className="flex items-center gap-3">
            <span className="text-sm text-[var(--color-text-secondary)]">{session.company_name}</span>
            <button onClick={clientLogout} className="text-xs bg-[var(--color-input-fill)] hover:bg-[var(--color-card-border)] px-3 py-1.5 rounded-lg">تسجيل خروج</button>
          </div>
        </header>
        <main className="max-w-2xl mx-auto p-6 space-y-6">
          <div className="bg-[var(--color-card)] rounded-2xl border border-[var(--color-card-border)] p-8 text-center">
            <div className="text-5xl mb-4">🎉</div>
            <h2 className="text-xl font-bold mb-2">تم تسجيل توقيعك بنجاح</h2>
            <div className="space-y-3 text-right max-w-md mx-auto mt-6">
              <div className="flex items-center gap-3 p-3 bg-emerald-50 rounded-lg">
                <span className="text-emerald-600 text-lg">✅</span>
                <span className="text-sm text-emerald-700 font-medium">التوقيع الإلكتروني</span>
              </div>
              <div className="flex items-center gap-3 p-3 bg-blue-50 rounded-lg border-2 border-blue-300">
                <span className="text-blue-600 text-lg">⏳</span>
                <span className="text-sm text-blue-700 font-medium">بانتظار إنشاء مساحة العمل — سيقوم مديرك بإنشاء العقد قريباً</span>
              </div>
            </div>
            <p className="text-sm text-[var(--color-text-disabled)] mt-6">ستصلك إشعارات عند توفر العقد</p>
          </div>
        </main>
      </div>
    );
  }

  return (
    <div className="min-h-screen bg-[var(--color-background)]">
      <header className="bg-[var(--color-card)] border-b border-[var(--color-card-border)] px-6 py-4 flex items-center justify-between">
        <h1 className="text-lg font-bold">ShadApp</h1>
          <div className="flex items-center gap-3">
            <span className="text-sm text-[var(--color-text-secondary)]">{session.company_name}</span>
            <Link href="/client-dashboard/settings" className="text-xs bg-[var(--color-input-fill)] hover:bg-[var(--color-card-border)] px-3 py-1.5 rounded-lg transition-colors">⚙️</Link>
            <button onClick={clientLogout} className="text-xs bg-[var(--color-input-fill)] hover:bg-[var(--color-card-border)] px-3 py-1.5 rounded-lg">
              تسجيل خروج
            </button>
          </div>
        </header>

      <main className="max-w-5xl mx-auto p-6 space-y-6">
        <StagesStepper client={client} workspace={workspace} onStageClick={(tab) => setActiveTab(tab as Tab)} />

        {workspace?.payments?.some((p: any) => p.status === 'approved') && !wsActive && (
          <div className="bg-emerald-50 border border-emerald-200 rounded-xl p-4 text-center">
            <p className="text-emerald-700 font-medium">✅ تم قبول الدفع — سيتم تفعيل مساحة العمل فور اكتمال الإجراءات</p>
          </div>
        )}

        <div className="grid grid-cols-2 md:grid-cols-4 gap-4">
          <div className="bg-[var(--color-card)] rounded-xl border border-[var(--color-card-border)] p-4 text-center">
            <p className="text-2xl font-bold text-blue-600">{workspace?.contracts?.length || 0}</p>
            <p className="text-xs text-[var(--color-text-secondary)] mt-1">العقود</p>
          </div>
          <div className="bg-[var(--color-card)] rounded-xl border border-[var(--color-card-border)] p-4 text-center">
            <p className="text-2xl font-bold text-emerald-600">{workspace?.payments?.length || 0}</p>
            <p className="text-xs text-[var(--color-text-secondary)] mt-1">المدفوعات</p>
          </div>
          <div className="bg-[var(--color-card)] rounded-xl border border-[var(--color-card-border)] p-4 text-center">
            <p className="text-2xl font-bold text-purple-600">{workspace?.approvals?.length || 0}</p>
            <p className="text-xs text-[var(--color-text-secondary)] mt-1">الموافقات</p>
          </div>
          <div className="bg-[var(--color-card)] rounded-xl border border-[var(--color-card-border)] p-4 text-center">
            <p className={`text-2xl font-bold ${wsActive ? 'text-emerald-600' : 'text-[var(--color-text-disabled)]'}`}>
              {wsActive ? '🟢' : '⏳'}
            </p>
            <p className="text-xs text-[var(--color-text-secondary)] mt-1">مساحة العمل</p>
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
                <TabContent tab={activeTab} wsId={wsId} clientId={session.id} clientData={client} wsActive={wsActive} onGoToPayments={() => setActiveTab('المدفوعات')} />
          </div>
        </div>
      </main>
    </div>
  );
}

function TabContent({ tab, wsId, clientId, clientData, wsActive, onGoToPayments }: { tab: Tab; wsId: number; clientId: number; clientData: any; wsActive?: boolean; onGoToPayments?: () => void }) {
  switch (tab) {
    case 'العقود': return <ClientContracts wsId={wsId} onGoToPayments={onGoToPayments} />;
    case 'المدفوعات': return <ClientPayments wsId={wsId} />;
    case 'الموافقات': return <ClientApprovals wsId={wsId} clientId={clientId} />;
    case 'الشات': return <ClientChat wsId={wsId} wsActive={wsActive} />;
    case 'الملفات': return <ClientFiles wsId={wsId} />;
    case 'الاجتماعات': return <ClientMeetings wsId={wsId} />;
    case 'التوقيع': return <ClientSignature clientId={clientId} clientData={clientData} onSigned={() => {}} />;
    case 'المستخدمين': return <ClientSubUsers clientId={clientId} />;
  }
}
