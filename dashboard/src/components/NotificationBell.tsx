'use client';

import { useEffect, useState, useRef } from 'react';
import { useRouter } from 'next/navigation';
import api from '@/lib/api';
import { subscribeToNotifications, disconnectEcho } from '@/lib/echo';
import { showToast } from './ToastNotification';

export default function NotificationBell() {
  const router = useRouter();
  const [open, setOpen] = useState(false);
  const [notifications, setNotifications] = useState<any[]>([]);
  const [unread, setUnread] = useState(0);
  const lastIdRef = useRef<string | null>(null);
  const ref = useRef<HTMLDivElement>(null);

  const load = () => {
    api.get('/notifications').then(({ data }) => {
      const items = data.notifications || [];
      // Show toast for the newest notification if it arrived via WebSocket
      if (items.length > 0) {
        const newest = items[0];
        if (newest.id !== lastIdRef.current && !newest.read_at) {
          const href = getHref(newest);
          showToast({
            id: newest.id,
            title: newest.data?.title || '',
            message: newest.data?.message || '',
            href,
          });
        }
        lastIdRef.current = items[0]?.id || null;
      }
      setNotifications(items);
      setUnread(data.unread_count || 0);
    }).catch(() => {});
  };

  useEffect(() => {
    load();
    const unsubscribe = subscribeToNotifications(() => { load(); });
    const interval = setInterval(load, 300000);
    const close = (e: MouseEvent) => { if (ref.current && !ref.current.contains(e.target as Node)) setOpen(false); };
    document.addEventListener('mousedown', close);
    return () => { clearInterval(interval); if (unsubscribe) unsubscribe(); disconnectEcho(); document.removeEventListener('mousedown', close); };
  }, []);

  const markRead = (id: string) => {
    api.post(`/notifications/${id}/read`).then(() => { load(); }).catch(() => {});
  };

  const notificationTab: Record<string, string> = {
    chat: 'المحادثة',
    contract_sent: 'العقود',
    contract_client_approved: 'العقود',
    contract_client_signed: 'العقود',
    contract_company_approved: 'العقود',
    contract_completed: 'العقود',
    contract_reminder: 'العقود',
    payment_created: 'المدفوعات',
    payment_reviewed: 'المدفوعات',
    workspace_activated: 'المدفوعات',
    approval_requested: 'الموافقات',
    approval_responded: 'الموافقات',
    meeting_reminder: 'الاجتماعات',
  };

  const getHref = (n: any) => {
    const d = n.data;
    const clientId = d?.client_id || d?.workspace_id;
    if (!clientId) return '#';
    const tab = notificationTab[d?.type] || '';
    return tab ? `/dashboard/clients/${clientId}?tab=${encodeURIComponent(tab)}` : `/dashboard/clients/${clientId}`;
  };

  return (
    <div ref={ref} className="relative">
      <button onClick={() => setOpen(!open)} className="relative p-2 text-[var(--color-text-secondary)] hover:text-[var(--color-foreground)] transition">
        <span className="text-lg">🔔</span>
        {unread > 0 && (
          <span className="absolute -top-0.5 -right-0.5 bg-[var(--color-primary)] text-white text-[10px] w-4 h-4 flex items-center justify-center rounded-full font-bold">{unread}</span>
        )}
      </button>

      {open && (
        <div className="absolute left-0 top-full mt-2 w-80 bg-[var(--color-card)] border border-[var(--color-card-border)] z-50 max-h-96 overflow-y-auto">
          <div className="p-3 border-b border-[var(--color-card-border)] flex justify-between items-center">
            <h3 className="text-sm font-bold">الإشعارات</h3>
            <button onClick={() => { notifications.forEach((n) => { if (!n.read_at) markRead(n.id); }); }} className="text-xs text-[var(--color-gold)] hover:underline">تحديد الكل كمقروء</button>
          </div>
          {notifications.length === 0 ? (
            <p className="text-xs text-[var(--color-text-disabled)] p-4 text-center">لا توجد إشعارات</p>
          ) : (
            notifications.map((n) => (
              <a key={n.id} href={getHref(n)} onClick={(e) => { if (!n.read_at) markRead(n.id); const href = getHref(n); if (href !== '#') { e.preventDefault(); router.push(href); } }}
                className={`block p-3 border-b border-[var(--color-card-border)] last:border-0 hover:bg-[var(--color-card-border)] transition ${n.read_at ? '' : 'bg-[var(--color-primary)]/10'}`}>
                <p className="text-xs font-medium">{n.data?.title || ''}</p>
                <p className="text-xs text-[var(--color-text-secondary)] mt-0.5">{n.data?.message || ''}</p>
                <p className="text-[10px] text-[var(--color-text-disabled)] mt-1">{new Date(n.created_at).toLocaleDateString('ar-SA')}</p>
              </a>
            ))
          )}
        </div>
      )}
    </div>
  );
}
