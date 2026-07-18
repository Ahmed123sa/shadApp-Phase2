'use client';

interface DashboardStatCardProps {
  label: string;
  value: number | string;
  icon: string;
  color?: 'default' | 'gold' | 'crimson' | 'red';
  subtitle?: string;
}

const colorMap = {
  default: { val: '', bar: 'var(--color-primary)' },
  gold: { val: 'var(--color-gold)', bar: 'var(--color-gold)' },
  crimson: { val: 'var(--color-primary)', bar: 'var(--color-primary)' },
  red: { val: 'var(--color-red-accent)', bar: 'var(--color-red-accent)' },
};

export default function DashboardStatCard({ label, value, icon, color = 'default', subtitle }: DashboardStatCardProps) {
  const c = colorMap[color] || colorMap.default;
  return (
    <div className="bg-[var(--color-card-bg)] border border-[var(--border)] rounded-xl p-3.5 stat-card-hover">
      <div className="flex items-center justify-between mb-2">
        <span className="text-[11px] text-[var(--color-text-secondary)]">{label}</span>
        <div className="w-7 h-7 rounded-lg bg-[var(--color-gold-soft)] flex items-center justify-center text-[13px]">{icon}</div>
      </div>
      <div className="text-[22px] font-bold" style={{ fontFamily: "'Playfair Display', serif", color: c.val || undefined }}>
        {value}
      </div>
      <div className="h-[2.5px] w-[45%] rounded-[3px] mt-2" style={{ background: c.bar }} />
      {subtitle && <div className="text-[9.5px] text-[var(--color-text-secondary)] mt-1">{subtitle}</div>}
    </div>
  );
}
