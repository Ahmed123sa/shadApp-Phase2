'use client';

import { useEffect, useState } from 'react';
import { useRouter, usePathname } from 'next/navigation';
import { useTranslations, useLocale } from 'next-intl';
import { isAuthenticated, getUser, logout } from '@/lib/auth';
import { setLocaleCookie } from '@/lib/locale';
import NotificationBell from '@/components/NotificationBell';
import ToastNotification from '@/components/ToastNotification';
import Link from 'next/link';

const SECTIONS = [
  { label: 'الرئيسية', group: 'main' },
  { label: 'إدارة', group: 'admin' },
  { label: 'النظام', group: 'system' },
];

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const t = useTranslations('dashboard');
  const c = useTranslations('common');
  const locale = useLocale();
  const router = useRouter();
  const pathname = usePathname();
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [mounted, setMounted] = useState(false);
  const user = getUser();

  const allNavItems = [
    { href: '/dashboard', label: t('home'), icon: '📊', section: 'main' },
    { href: '/dashboard/clients', label: t('clients'), icon: '👥', section: 'admin' },
    { href: '/dashboard/reports', label: t('reports'), icon: '📈', section: 'system' },
    { href: '/dashboard/settings', label: t('settings'), icon: '⚙️', section: 'system' },
  ];

  useEffect(() => {
    setMounted(true);
    if (typeof window !== 'undefined' && !isAuthenticated()) {
      router.push('/login');
    }
  }, [router]);

  const navItems = [...allNavItems];

  if (user?.role === 'super_admin' && !navItems.find((i) => i.href === '/dashboard/account-managers')) {
    navItems.push({ href: '/dashboard/account-managers', label: t('account_managers'), icon: '👤', section: 'admin' });
  }

  const switchLocale = () => {
    const next = locale === 'ar' ? 'en' : 'ar';
    setLocaleCookie(next);
    window.location.reload();
  };

  const pageTitle = navItems.find((i) => i.href === pathname || (i.href !== '/dashboard' && pathname.startsWith(i.href)))?.label || t('title');

  if (!mounted) return <div className="min-h-screen flex items-center justify-center text-[var(--color-text-secondary)]">{c('loading')}</div>;

  return (
    <div className="flex min-h-screen">
      <ToastNotification />

      {/* Sidebar */}
      <aside className={`fixed inset-y-0 right-0 z-50 w-64 bg-[var(--color-sidebar)] text-white transform transition-transform lg:relative lg:translate-x-0 ${sidebarOpen ? 'translate-x-0' : 'translate-x-full lg:translate-x-0'}`}>
        {/* Logo */}
        <div className="px-5 py-6 border-b border-[var(--color-card-border)]">
          <div className="flex items-center gap-1.5">
            <span className="text-2xl italic font-bold tracking-wide" style={{ fontFamily: "'Playfair Display', serif" }}>d</span>
            <span className="text-2xl text-[var(--color-primary)]">.</span>
            <span className="text-sm font-semibold tracking-[0.2em] text-white/80">SHAD</span>
          </div>
        </div>

        {/* User info */}
        <div className="px-5 py-4 border-b border-[var(--color-card-border)]">
          <p className="text-sm font-medium text-white/90">{user?.name || 'مستخدم'}</p>
          <span className="inline-block mt-1 px-2 py-0.5 text-[10px] font-semibold tracking-wider bg-[var(--color-primary)] text-white rounded">
            {user?.role === 'super_admin' ? 'SUPER ADMIN' : 'ACCOUNT MANAGER'}
          </span>
        </div>

        {/* Nav */}
        <nav className="p-3 space-y-2">
          {SECTIONS.map((section) => {
            const items = navItems.filter((i) => i.section === section.group);
            if (items.length === 0) return null;
            return (
              <div key={section.group}>
                <p className="px-4 py-1 text-[10px] font-semibold tracking-widest text-white/40 uppercase">{section.label}</p>
                <div className="space-y-0.5">
                  {items.map((item) => {
                    const active = pathname === item.href || (item.href !== '/dashboard' && pathname.startsWith(item.href));
                    return (
                      <Link
                        key={item.href}
                        href={item.href}
                        className={`flex items-center gap-3 px-4 py-2.5 text-sm transition-all ${
                          active
                            ? 'text-white bg-white/5 border-r-2 border-[var(--color-primary)]'
                            : 'text-white/50 hover:text-white/80 hover:bg-white/5 border-r-2 border-transparent'
                        }`}
                        onClick={() => setSidebarOpen(false)}
                      >
                        <span className="text-base">{item.icon}</span>
                        {item.label}
                      </Link>
                    );
                  })}
                </div>
              </div>
            );
          })}
        </nav>

        {/* Logout */}
        <div className="absolute bottom-0 left-0 right-0 border-t border-[var(--color-card-border)]">
          <button onClick={logout} className="flex items-center gap-2 text-sm text-white/40 hover:text-white/80 w-full px-6 py-3 transition-colors">
            {c('logout')}
          </button>
        </div>
      </aside>

      {/* Main content */}
      <div className="flex-1 flex flex-col min-w-0">
        {/* Top bar */}
        <header className="bg-[#111111] border-b border-[var(--color-card-border)] px-6 py-3 flex items-center justify-between gap-3">
          <div className="flex items-center gap-4">
            <button className="lg:hidden p-2 text-[var(--color-foreground)]" onClick={() => setSidebarOpen(!sidebarOpen)}>
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
              </svg>
            </button>
            <h1 className="text-lg font-semibold text-[var(--color-foreground)]" style={{ fontFamily: "'Playfair Display', serif" }}>{pageTitle}</h1>
          </div>
          <div className="flex items-center gap-3">
            <div className="hidden md:flex items-center">
              <input
                placeholder="بحث..."
                className="w-48 border border-[var(--color-input-border)] rounded-lg px-3 py-1.5 text-sm bg-[var(--color-input-fill)] text-[var(--color-foreground)] placeholder-[var(--color-text-disabled)]"
              />
            </div>
            <NotificationBell />
            <button onClick={switchLocale} className="text-xs bg-[var(--color-input-fill)] hover:bg-[var(--color-input-border)] text-[var(--color-foreground)] px-3 py-1.5 rounded-lg transition-colors">
              {locale === 'ar' ? 'English' : 'العربية'}
            </button>
            <div className="w-8 h-8 rounded-full bg-[var(--color-input-fill)] border border-[var(--color-card-border)] flex items-center justify-center text-sm text-[var(--color-gold)]">
              {user?.name?.[0] || '?'}
            </div>
          </div>
        </header>

        <main className="flex-1 p-6 overflow-auto">{children}</main>
      </div>
    </div>
  );
}
