'use client';

export interface ActivityItem {
  color: 'green' | 'gold' | 'blue' | 'red';
  text: string;
  time: string;
}

const dotColors: Record<string, string> = {
  green: 'var(--color-green)',
  gold: 'var(--color-gold)',
  blue: 'var(--color-blue)',
  red: 'var(--color-red-accent)',
};

export default function ActivityFeed({ items }: { items: ActivityItem[] }) {
  if (items.length === 0) {
    return <p className="text-xs text-[var(--color-text-secondary)] text-center py-6">لا توجد نشاطات</p>;
  }
  return (
    <div>
      {items.map((item, i) => (
        <div key={i} className="flex items-start gap-2.5 px-3.5 py-2.5 border-b border-white/[0.04] last:border-0 row-slide" style={{ animationDelay: `${(i + 1) * 50}ms` }}>
          <div className="w-2 h-2 rounded-full mt-1.5 flex-shrink-0" style={{ background: dotColors[item.color] }} />
          <div>
            <div className="text-[11.5px] leading-relaxed" dangerouslySetInnerHTML={{ __html: item.text }} />
            <div className="text-[9.5px] text-[var(--color-text-secondary)] mt-0.5">{item.time}</div>
          </div>
        </div>
      ))}
    </div>
  );
}
