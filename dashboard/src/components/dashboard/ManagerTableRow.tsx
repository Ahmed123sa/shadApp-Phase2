'use client';

const avatarColors = [
  { bg: 'var(--color-crimson-soft)', border: 'var(--color-crimson-border)', text: 'var(--color-gold)' },
  { bg: 'var(--color-gold-soft)', border: 'var(--color-gold-border)', text: 'var(--color-gold)' },
  { bg: 'rgba(133,183,235,.14)', border: 'rgba(133,183,235,.3)', text: 'var(--color-blue)' },
];

const badgeStatus: Record<number, { bg: string; color: string }> = {
  0: { bg: 'rgba(151,196,89,.14)', color: 'var(--color-green)' },
};

interface Manager {
  id: number;
  name: string;
  email?: string;
  avatar_url?: string | null;
  managed_clients_count: number;
  pending_count?: number;
}

const FILE_BASE = process.env.NEXT_PUBLIC_API_URL?.replace('/api', '') || 'http://localhost:8000';
function resolveFileUrl(url: string): string {
  if (!url) return '';
  if (url.startsWith('http')) return url;
  return `${FILE_BASE}/storage/${url.replace(/^\/?storage\//, '')}`;
}

export default function ManagerTableRow({ manager, index, expanded, onToggle }: {
  manager: Manager; index: number; expanded?: boolean; onToggle?: () => void;
}) {
  const c = avatarColors[index % avatarColors.length];
  const initials = manager.name?.slice(0, 2) || '؟';
  const pending = manager.pending_count ?? 0;
  const badge = badgeStatus[pending] || { bg: 'var(--gold-soft)', color: 'var(--color-gold)' };

  return (
    <tr
      className="row-slide cursor-pointer hover:bg-white/[0.025] transition-colors"
      style={{ animationDelay: `${(index + 1) * 50}ms` }}
      onClick={onToggle}
    >
      <td className="px-3.5 py-2.5">
        <div className="flex items-center gap-2">
          <div className={`w-7 h-7 rounded-full flex items-center justify-center text-[9.5px] font-bold flex-shrink-0 overflow-hidden ${expanded ? 'ring-2 ring-[var(--color-gold)]' : ''}`}
            style={{ background: c.bg, border: `1px solid ${c.border}`, color: c.text }}>
            {manager.avatar_url ? (
              <img src={resolveFileUrl(manager.avatar_url)} alt="" className="w-full h-full object-cover" />
            ) : (
              initials
            )}
          </div>
          <div className="flex-1 min-w-0">
            <div className="text-[11.5px] font-bold truncate">{manager.name}</div>
            {manager.email && <div className="text-[9.5px] text-[var(--color-text-secondary)] truncate">{manager.email}</div>}
          </div>
          <svg className={`w-3.5 h-3.5 text-[var(--color-text-secondary)] transition-transform flex-shrink-0 ${expanded ? 'rotate-90' : ''}`} fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2.5}>
            <path strokeLinecap="round" strokeLinejoin="round" d="M9 5l7 7-7 7" />
          </svg>
        </div>
      </td>
      <td className="px-3.5 py-2.5 text-[11px] text-[var(--color-text-secondary)]">{manager.managed_clients_count}</td>
      <td className="px-3.5 py-2.5">
        <span className="px-2 py-0.5 rounded-full text-[9.5px] font-semibold" style={{ background: badge.bg, color: badge.color }}>
          {pending}
        </span>
      </td>
    </tr>
  );
}
