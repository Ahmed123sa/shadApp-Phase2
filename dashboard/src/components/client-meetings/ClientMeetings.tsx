'use client';

import { useEffect, useState } from 'react';
import api from '@/lib/api';
import { StatusBadge } from '@/components/ui/StatusBadge';
import { LoadingSkeleton } from '@/components/ui/LoadingSkeleton';
import { EmptyState } from '@/components/ui/EmptyState';

export default function ClientMeetings({ wsId }: { wsId: number }) {
  const [meetings, setMeetings] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    api.get(`/workspaces/${wsId}/meetings`)
      .then(({ data }) => setMeetings(data.meetings?.data || data.meetings || []))
      .catch(() => setError('فشل تحميل الاجتماعات'))
      .finally(() => setLoading(false));
  }, [wsId]);

  const formatDate = (d: string) => {
    try { return new Date(d).toLocaleDateString('ar-SA', { weekday: 'short', year: 'numeric', month: 'short', day: 'numeric', hour: '2-digit', minute: '2-digit' }); }
    catch { return d; }
  };

  if (loading) return <LoadingSkeleton />;
  if (error) return <p className="text-sm text-red-500 text-center py-8">{error}</p>;

  return (
    <div className="space-y-3">
      {meetings.length === 0 ? <EmptyState message="لا توجد اجتماعات" /> : null}
      {meetings.map((m) => (
        <div key={m.id} className="border border-[var(--color-card-border)] rounded-lg p-4">
          <div className="flex justify-between items-start">
            <div>
              <h4 className="font-medium">{m.title}</h4>
              <p className="text-xs text-[var(--color-text-disabled)] mt-0.5">
                {formatDate(m.scheduled_at)} • {m.duration_minutes} دقيقة
              </p>
              {m.notes && <p className="text-xs text-[var(--color-text-disabled)] mt-0.5">{m.notes}</p>}
            </div>
            <StatusBadge status={m.status} />
          </div>
          {m.status === 'scheduled' && m.link && (
            <div className="mt-3">
              <a href={m.link} target="_blank" rel="noopener noreferrer"
                className="inline-flex items-center gap-1.5 text-xs bg-[var(--color-primary)] text-white px-4 py-2 rounded-lg hover:bg-[var(--color-primary-dark)]">
                🎥 انضمام إلى الاجتماع
              </a>
            </div>
          )}
          {m.passcode && (
            <p className="text-xs text-[var(--color-text-disabled)] mt-1">رمز الدخول: {m.passcode}</p>
          )}
        </div>
      ))}
    </div>
  );
}
