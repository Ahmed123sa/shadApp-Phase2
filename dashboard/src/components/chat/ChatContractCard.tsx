'use client';

type Clause = { id: number; content: string; type: string; sort_order: number };
type Contract = {
  id: number; title: string; value: string | null; start_date: string | null; end_date: string | null;
  status: string; clauses: Clause[];
};

export default function ChatContractCard({ contract, clientType, onAction }: { contract: Contract; clientType?: string; onAction?: (id: number, action: string) => void }) {
  const statusBadge = (s: string) => {
    const m: Record<string, string> = {
      draft: 'bg-zinc-700/30 text-zinc-400', sent: 'bg-blue-900/30 text-blue-400',
      client_approved: 'bg-green-900/30 text-green-400', client_rejected: 'bg-red-900/30 text-red-400',
      company_approved: 'bg-purple-900/30 text-purple-400', completed: 'bg-emerald-900/30 text-emerald-400',
      archived: 'bg-zinc-700/30 text-zinc-400',
    };
    const l: Record<string, string> = {
      draft: 'مسودة', sent: 'مرسل', client_approved: 'تمت موافقة العميل',
      client_rejected: 'رفض العميل', company_approved: 'تمت موافقة الشركة',
      completed: 'مكتمل', archived: 'مؤرشف',
    };
    return <span className={`px-2 py-0.5 rounded-full text-xs ${m[s] || 'bg-zinc-700/30 text-zinc-400'}`}>{l[s] || s}</span>;
  };

  return (
    <div className="border border-[var(--color-card-border)] rounded-xl bg-[var(--color-card)] overflow-hidden">
      <div className="bg-[var(--color-card-border)] px-4 py-2 border-b border-[var(--color-card-border)] flex items-center justify-between">
        <span className="text-xs font-bold text-[var(--color-gold)]">عقد خدمة</span>
        {statusBadge(contract.status)}
      </div>
      <div className="p-4 space-y-2">
        <h4 className="font-bold text-[var(--color-foreground)]">{contract.title}</h4>
        {contract.value && <p className="text-sm text-[var(--color-text-secondary)]">{contract.value} SAR</p>}
        {clientType === 'business' && <p className="text-xs text-[var(--color-text-disabled)]">قيمة العقد غير شاملة الضريبة</p>}
        {(contract.start_date || contract.end_date) && (
          <p className="text-xs text-[var(--color-text-disabled)]">
            {contract.start_date && contract.end_date
              ? `من ${contract.start_date} إلى ${contract.end_date}`
              : contract.start_date
              ? `يبدأ من ${contract.start_date}`
              : `ينتهي في ${contract.end_date}`}
          </p>
        )}
        {contract.clauses?.length > 0 && (
          <div className="mt-2 space-y-1 border-t border-[var(--color-card-border)] pt-2">
            {contract.clauses.map((cl) => (
              <p key={cl.id} className="text-xs text-[var(--color-text-secondary)] pr-2 border-r-2 border-[var(--color-card-border)]">{cl.content}</p>
            ))}
          </div>
        )}
      </div>
      {onAction && contract.status === 'draft' && (
        <div className="px-4 pb-3 flex gap-2 flex-wrap">
          <button onClick={() => onAction(contract.id, 'send')} className="text-xs bg-[var(--color-primary)] text-white px-3 py-1 rounded-lg hover:bg-[var(--color-primary-dark)]">إرسال للعميل</button>
        </div>
      )}
      {onAction && contract.status === 'company_approved' && (
        <div className="px-4 pb-3 flex gap-2 flex-wrap">
          <button onClick={() => onAction(contract.id, 'archive')} className="text-xs bg-zinc-500 text-white px-3 py-1 rounded-lg hover:bg-zinc-600">أرشفة</button>
        </div>
      )}
    </div>
  );
}
