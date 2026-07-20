import { cn } from '@/lib/utils';

interface ClientTypeBadgeProps {
  clientType?: string | null;
  compact?: boolean;
}

export function ClientTypeBadge({ clientType, compact = false }: ClientTypeBadgeProps) {
  if (!clientType) return null;

  const isBusiness = clientType === 'business';
  const label = isBusiness ? 'شركة' : 'فريدي';

  return (
    <span
      className={cn(
        'inline-flex items-center gap-1 rounded-md font-medium',
        compact ? 'px-1.5 py-0.5 text-[10px]' : 'px-2 py-0.5 text-[11px]',
        isBusiness
          ? 'bg-[var(--color-gold)]/15 text-[var(--color-gold)]'
          : 'bg-[var(--color-card-border)] text-[var(--color-text-secondary)]',
      )}
    >
      {isBusiness ? '🏢' : '👤'}
      {label}
    </span>
  );
}
