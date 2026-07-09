'use client';

import { useEffect, useState } from 'react';
import { useRouter, usePathname } from 'next/navigation';
import { useTranslations, useLocale } from 'next-intl';
import { isAuthenticated, getUser, logout } from '@/lib/auth';
import { setLocaleCookie } from '@/lib/locale';
import NotificationBell from '@/components/NotificationBell';
import ToastNotification from '@/components/ToastNotification';
import Link from 'next/link';

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const t = useTranslations('dashboard');
  const c = useTranslations('common');
  const locale = useLocale();
  const router = useRouter();
  const pathname = usePathname();
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [mounted, setMounted] = useState(false);
  const user = getUser();

  const navItems = [
    { href: '/dashboard', label: t('home'), icon: '📊' },
    { href: '/dashboard/clients', label: t('clients'), icon: '👥' },
    { href: '/dashboard/reports', label: t('reports'), icon: '📈' },
    { href: '/dashboard/settings', label: t('settings'), icon: '⚙️' },
  ];
  useEffect(() => {
    setMounted(true);
    if (typeof window !== 'undefined' && !isAuthenticated()) {
      router.push('/login');
    }
  }, [router]);

  if (user?.role === 'super_admin' && !navItems.find((i) => i.href === '/dashboard/account-managers')) {
    navItems.push({ href: '/dashboard/account-managers', label: t('account_managers'), icon: '👤' });
  }

  const switchLocale = () => {
    const next = locale === 'ar' ? 'en' : 'ar';
    setLocaleCookie(next);
    window.location.reload();
  };

  if (!mounted) return <div className="min-h-screen flex items-center justify-center text-[var(--color-text-secondary)]">{c('loading')}</div>;

  return (
    <div className="flex min-h-screen">
      <ToastNotification />
      <aside className={`fixed inset-y-0 right-0 z-50 w-64 bg-[var(--color-sidebar)] text-white transform transition-transform lg:relative lg:translate-x-0 ${sidebarOpen ? 'translate-x-0' : 'translate-x-full lg:translate-x-0'}`}>
        <div className="p-5 border-b border-white/20">
          <h2 className="text-lg font-bold" style={{ fontFamily: "'Playfair Display', serif" }}>{t('sidebar_title')}</h2>
          <p className="text-sm text-white/70 mt-1">{user?.name}</p>
        </div>

        <nav className="p-3 space-y-1">
          {navItems.map((item) => {
            const active = pathname === item.href || (item.href !== '/dashboard' && pathname.startsWith(item.href));
            return (
              <Link
                key={item.href}
                href={item.href}
                className={`flex items-center gap-3 px-4 py-2.5 rounded-lg text-sm transition-colors ${active ? 'bg-white/20 text-white' : 'text-white/70 hover:bg-white/15 hover:text-white'}`}
                onClick={() => setSidebarOpen(false)}
              >
                <span>{item.icon}</span>
                {item.label}
              </Link>
            );
          })}
        </nav>

        <div className="absolute bottom-0 left-0 right-0 border-t border-white/20">
          <button onClick={logout} className="flex items-center gap-2 text-sm text-white/60 hover:text-white w-full px-6 py-3">
            {c('logout')}
          </button>
        </div>
      </aside>

      <div className="flex-1 flex flex-col min-w-0">
        <header className="bg-[var(--color-card)] border-b border-[var(--color-card-border)] px-6 py-3 flex items-center justify-between lg:justify-end gap-3">
          <button className="lg:hidden p-2 text-[var(--color-foreground)]" onClick={() => setSidebarOpen(!sidebarOpen)}>
            <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
              <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
            </svg>
          </button>
          <div className="flex items-center gap-3">
            <NotificationBell />
            <button onClick={switchLocale} className="text-xs bg-[var(--color-input-fill)] hover:bg-[var(--color-input-border)] text-[var(--color-foreground)] px-3 py-1.5 rounded-lg transition-colors">
              {locale === 'ar' ? 'English' : 'العربية'}
            </button>
            <h1 className="text-lg font-semibold text-[var(--color-foreground)]">{navItems.find((i) => i.href === pathname)?.label || t('title')}</h1>
          </div>
        </header>

        <main className="flex-1 p-6 overflow-auto">{children}</main>
      </div>
    </div>
  );
}
