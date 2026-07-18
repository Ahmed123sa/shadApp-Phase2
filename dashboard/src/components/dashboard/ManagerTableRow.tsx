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
  avatar_url?: string | null;
  managed_clients_count: number;
  pending_count?: number;
}

export default function ManagerTableRow({ manager, index }: { manager: Manager; index: number }) {
  const c = avatarColors[index % avatarColors.length];
  const initials = manager.name?.slice(0, 2) || '؟';
  const pending = manager.pending_count ?? 0;
  const badge = badgeStatus[pending] || { bg: 'var(--gold-soft)', color: 'var(--color-gold)' };

  return (
    <tr className="row-slide" style={{ animationDelay: `${(index + 1) * 50}ms` }}>
      <td>
        <div className="flex items-center gap-2">
          <div className="w-[26px] h-[26px] rounded-full flex items-center justify-center text-[9.5px] font-bold flex-shrink-0" style={{ background: c.bg, border: `1px solid ${c.border}`, color: c.text }}>
            {initials}
          </div>
          <div className="text-[11.5px] font-bold">{manager.name}</div>
        </div>
      </td>
      <td className="text-[11px] text-[var(--color-text-secondary)]">{manager.managed_clients_count}</td>
      <td>
        <span className="px-2 py-0.5 rounded-full text-[9.5px] font-semibold" style={{ background: badge.bg, color: badge.color }}>
          {pending}
        </span>
      </td>
    </tr>
  );
}
