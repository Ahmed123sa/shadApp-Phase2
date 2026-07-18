'use client';

import { useEffect, useState } from 'react';
import { useRouter, usePathname, useSearchParams } from 'next/navigation';
import { useTranslations, useLocale } from 'next-intl';
import { isAuthenticated, getUser, logout } from '@/lib/auth';
import { setLocaleCookie } from '@/lib/locale';
import NotificationBell from '@/components/NotificationBell';
import ToastNotification from '@/components/ToastNotification';
import Link from 'next/link';

const FILE_BASE = process.env.NEXT_PUBLIC_API_URL?.replace('/api', '') || 'http://localhost:8000';
function resolveFileUrl(url: string): string {
  if (!url) return '';
  if (url.startsWith('http')) return url;
  return `${FILE_BASE}/storage/${url.replace(/^\/?storage\//, '')}`;
}

interface NavItem {
  href: string;
  label: string;
  icon: string;
  badge?: number;
  badgeColor?: string;
  exact?: boolean;
}

export default function DashboardLayout({ children }: { children: React.ReactNode }) {
  const t = useTranslations('dashboard');
  const c = useTranslations('common');
  const locale = useLocale();
  const router = useRouter();
  const pathname = usePathname();
  const searchParams = useSearchParams();
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [mounted, setMounted] = useState(false);
  const user = getUser();
  const isSA = user?.role === 'super_admin';

  const currentView = searchParams.get('view') || '';

  const amNavGroups = [
    {
      label: t('nav_group_main'),
      items: [
        { href: '/dashboard', label: t('home'), icon: '📊', exact: true },
        { href: '/dashboard/clients', label: t('my_clients'), icon: '👥' },
      ],
    },
    {
      label: t('nav_group_comm'),
      items: [
        { href: '/dashboard?view=contracts', label: t('contracts_nav'), icon: '📄' },
        { href: '/dashboard?view=meetings', label: t('meetings_nav'), icon: '📅' },
      ],
    },
    {
      label: t('nav_group_finance'),
      items: [
        { href: '/dashboard?view=payments', label: t('payments_nav'), icon: '💳' },
        { href: '/dashboard?view=files', label: t('files_nav'), icon: '📁' },
      ],
    },
    {
      label: t('nav_group_system'),
      items: [
        { href: '/dashboard/settings', label: t('settings'), icon: '⚙' },
      ],
    },
  ];

  const saNavGroups = [
    {
      label: t('nav_group_admin'),
      items: [
        { href: '/dashboard', label: t('home'), icon: '📊', exact: true },
        { href: '/dashboard/clients', label: t('all_clients'), icon: '👥' },
        { href: '/dashboard/reports', label: t('reports'), icon: '📈' },
      ],
    },
    {
      label: t('nav_group_team'),
      items: [
        { href: '/dashboard/account-managers', label: t('account_managers'), icon: '🧑‍💼' },
      ],
    },
    {
      label: t('nav_group_system'),
      items: [
        { href: '/dashboard/settings', label: t('settings'), icon: '⚙' },
      ],
    },
  ];

  const navGroups = isSA ? saNavGroups : amNavGroups;

  useEffect(() => {
    setMounted(true);
    if (typeof window !== 'undefined' && !isAuthenticated()) {
      router.push('/login');
    }
  }, [router]);

  const switchLocale = () => {
    const next = locale === 'ar' ? 'en' : 'ar';
    setLocaleCookie(next);
    window.location.reload();
  };

  const isActive = (item: NavItem) => {
    if (item.exact) return pathname === '/dashboard' && !currentView;
    const itemPath = item.href.split('?')[0];
    const itemView = new URL(item.href, 'http://localhost').searchParams.get('view') || '';
    if (itemView) return pathname === itemPath && currentView === itemView;
    return pathname === itemPath || (itemPath !== '/dashboard' && pathname.startsWith(itemPath));
  };

  const getPageTitle = () => {
    if (pathname === '/dashboard' && currentView) {
      const viewTitles: Record<string, string> = {
        contracts: t('contracts_nav'),
        messages: t('messages'),
        meetings: t('meetings_nav'),
        payments: t('payments_nav'),
        files: t('files_nav'),
      };
      return viewTitles[currentView] || t('title');
    }
    if (pathname === '/dashboard') return t('title');
    if (pathname.startsWith('/dashboard/clients')) return t('my_clients');
    if (pathname.startsWith('/dashboard/account-managers')) return t('account_managers');
    if (pathname.startsWith('/dashboard/reports')) return t('reports');
    if (pathname.startsWith('/dashboard/settings')) return t('settings');
    return t('title');
  };

  const currentDate = new Date().toLocaleDateString(locale === 'ar' ? 'ar-SA' : 'en-US', {
    weekday: 'long',
    year: 'numeric',
    month: 'long',
    day: 'numeric',
  });

  if (!mounted) return <div className="min-h-screen flex items-center justify-center text-[var(--color-text-secondary)]">{c('loading')}</div>;

  return (
    <div className="flex min-h-screen">
      <ToastNotification />

      {/* Sidebar */}
      <aside className={`fixed inset-y-0 right-0 z-50 w-[220px] bg-[var(--bg-dark,#0D0D0D)] border-l border-[var(--border)] flex flex-col transform transition-transform lg:relative lg:translate-x-0 ${sidebarOpen ? 'translate-x-0' : 'translate-x-full lg:translate-x-0'}`}>

        {/* Logo */}
        <div className="px-3.5 py-5 mb-4">
          <div className="flex items-center gap-1">
            <span className="text-[22px] italic font-bold" style={{ fontFamily: "'Playfair Display', serif" }}>d</span>
            <div className="w-1.5 h-1.5 rounded-full bg-[var(--color-primary)] mb-[-2px]" />
            <span className="text-[15px] tracking-[3px] text-[var(--color-gold)]" style={{ fontFamily: "'Playfair Display', serif" }}>SHAD</span>
          </div>
        </div>

        {/* User Card */}
        <div className="mx-3.5 mb-5 p-2.5 rounded-xl border border-[var(--border)] bg-white/[0.03] flex items-center gap-2.5">
          <div className="w-8 h-8 rounded-full bg-[var(--color-primary)] text-[var(--color-gold)] flex items-center justify-center text-xs font-bold border-[1.5px] border-[var(--color-gold)] overflow-hidden shrink-0">
            {user?.avatar_url ? (
              <img src={resolveFileUrl(user.avatar_url)} alt="" className="w-full h-full object-cover" />
            ) : (
              user?.name?.slice(0, 2) || '?'
            )}
          </div>
          <div>
            <div className="text-xs font-bold">{user?.name}</div>
            <div className="text-[10px] text-[var(--color-text-secondary)]">
              {isSA ? t('role_admin') : t('role_am')}
            </div>
            <span className="inline-block mt-0.5 px-1.5 py-px text-[8.5px] rounded-[10px] bg-[var(--color-crimson-soft)] text-[var(--color-primary)] border border-[var(--color-crimson-border)]">
              {isSA ? 'SUPER ADMIN' : 'ACCOUNT MANAGER'}
            </span>
          </div>
        </div>

        {/* Nav Groups */}
        <nav className="flex-1 px-2 overflow-y-auto">
          {navGroups.map((group) => (
            <div key={group.label} className="mb-4">
              <div className="text-[9.5px] text-[var(--color-text-muted)] uppercase tracking-[1.2px] mb-1.5 px-2">{group.label}</div>
              {group.items.map((item) => {
                const active = isActive(item);
                return (
                  <Link
                    key={item.href}
                    href={item.href}
                    className={`relative flex items-center gap-2 px-2.5 py-2.5 rounded-lg text-[12.5px] transition-all mb-0.5 ${
                      active
                        ? 'text-[var(--color-foreground)] bg-[var(--color-crimson-soft)] nav-item-active'
                        : 'text-[var(--color-text-secondary)] hover:bg-white/[0.04] hover:text-[var(--color-foreground)]'
                    }`}
                    onClick={() => setSidebarOpen(false)}
                  >
                    <span className="text-[13px]">{item.icon}</span>
                    <span>{item.label}</span>
                  </Link>
                );
              })}
            </div>
          ))}
        </nav>

        {/* Logout */}
        <div className="px-3.5 py-2.5">
          <button onClick={logout} className="text-[11px] text-[var(--color-text-muted)] hover:text-[var(--color-foreground)] transition-colors cursor-pointer w-full text-right">
            {t('logout')} →
          </button>
        </div>
      </aside>

      {/* Main content */}
      <div className="flex-1 flex flex-col min-w-0">
        {/* Topbar */}
        <header className="bg-[rgba(13,13,13,0.9)] border-b border-[var(--border)] px-5 py-3 flex items-center justify-between">
          <div className="flex items-center gap-4">
            <button className="lg:hidden p-2 text-[var(--color-foreground)]" onClick={() => setSidebarOpen(!sidebarOpen)}>
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
              </svg>
            </button>
            <h2 className="text-lg font-bold" style={{ fontFamily: "'Playfair Display', serif" }}>
              {getPageTitle()}
              <span className="text-[11px] text-[var(--color-text-secondary)] font-normal mr-3" style={{ fontFamily: 'Tajawal' }}>
                {currentDate}
              </span>
            </h2>
          </div>
          <div className="flex items-center gap-3.5">
            <input
              placeholder={t('search_placeholder')}
              className="bg-white/[0.04] border border-[var(--border)] rounded-full px-3.5 py-1.5 text-[11.5px] text-[var(--color-text-secondary)] w-[150px]"
              style={{ fontFamily: 'Tajawal' }}
            />
            <NotificationBell />
            <button onClick={switchLocale} className="text-[10.5px] text-[var(--color-text-secondary)] hover:text-[var(--color-gold)] transition-colors">
              {locale === 'ar' ? 'English' : 'العربية'}
            </button>
            <div className="w-[30px] h-[30px] rounded-full bg-[var(--color-primary)] text-[var(--color-gold)] flex items-center justify-center text-[10px] font-bold border-[1.5px] border-[var(--color-gold)] overflow-hidden shrink-0">
              {user?.avatar_url ? (
                <img src={resolveFileUrl(user.avatar_url)} alt="" className="w-full h-full object-cover" />
              ) : (
                user?.name?.[0] || '?'
              )}
            </div>
          </div>
        </header>

        <main className="flex-1 p-5 overflow-auto">{children}</main>
      </div>
    </div>
  );
}
