'use client';

import { useEffect, useState, useCallback } from 'react';
import { useRouter } from 'next/navigation';

export interface ToastItem {
  id: string;
  title: string;
  message: string;
  href?: string;
}

let addToastExternal: (item: ToastItem) => void = () => {};

function playNotificationSound() {
  try {
    const ctx = new (window.AudioContext || (window as any).webkitAudioContext)();
    const g = ctx.createGain();
    g.connect(ctx.destination);
    g.gain.value = 0.15;

    const o = ctx.createOscillator();
    o.type = 'sine';
    o.frequency.setValueAtTime(880, ctx.currentTime);
    o.frequency.setValueAtTime(1100, ctx.currentTime + 0.08);
    o.connect(g);
    o.start(ctx.currentTime);
    o.stop(ctx.currentTime + 0.18);
  } catch {
    // Audio not available — fail silently
  }
}

export function showToast(item: ToastItem) {
  playNotificationSound();
  addToastExternal(item);
}

export default function ToastNotification() {
  const router = useRouter();
  const [toasts, setToasts] = useState<ToastItem[]>([]);

  const removeToast = useCallback((id: string) => {
    setToasts((prev) => prev.filter((t) => t.id !== id));
  }, []);

  useEffect(() => {
    addToastExternal = (item: ToastItem) => {
      const id = item.id + Date.now();
      setToasts((prev) => [...prev.slice(-2), { ...item, id }]);
      setTimeout(() => removeToast(id), 5000);
    };
    return () => { addToastExternal = () => {}; };
  }, [removeToast]);

  if (toasts.length === 0) return null;

  return (
    <div className="fixed top-4 right-4 z-[100] flex flex-col gap-2 max-w-sm w-full pointer-events-none">
      {toasts.map((t) => (
        <div
          key={t.id}
          onClick={() => { if (t.href && t.href !== '#') { router.push(t.href); } removeToast(t.id); }}
          className="pointer-events-auto bg-[var(--color-card)] border border-[var(--color-card-border)] rounded-xl shadow-2xl p-4 cursor-pointer hover:bg-[var(--color-card-border)] transition-all animate-slide-in"
        >
          <div className="flex items-start justify-between gap-2">
            <div className="min-w-0">
              <p className="text-sm font-semibold truncate">{t.title}</p>
              <p className="text-xs text-[var(--color-text-secondary)] mt-0.5 line-clamp-2">{t.message}</p>
            </div>
            <button
              onClick={(e) => { e.stopPropagation(); removeToast(t.id); }}
              className="text-[var(--color-text-disabled)] hover:text-[var(--color-foreground)] text-lg leading-none shrink-0"
            >
              ×
            </button>
          </div>
        </div>
      ))}
      <style>{`
        @keyframes slideIn {
          from { transform: translateX(100%); opacity: 0; }
          to { transform: translateX(0); opacity: 1; }
        }
        .animate-slide-in { animation: slideIn 0.3s ease-out; }
      `}</style>
    </div>
  );
}
