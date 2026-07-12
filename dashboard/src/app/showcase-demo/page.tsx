'use client';

import { useState } from 'react';
import { motion, AnimatePresence } from 'motion/react';

const SECTIONS = [
  { label: 'الرئيسية', group: 'main' },
  { label: 'إدارة', group: 'admin' },
  { label: 'النظام', group: 'system' },
];

const NAV_ITEMS = [
  { href: '#', label: 'لوحة التحكم', icon: '📊', section: 'main' },
  { href: '#', label: 'العملاء', icon: '👥', section: 'admin', badge: 24 },
  { href: '#', label: 'العقود', icon: '📄', section: 'admin', badge: 3 },
  { href: '#', label: 'المدفوعات', icon: '💰', section: 'admin' },
  { href: '#', label: 'الرسائل', icon: '💬', section: 'system', badge: 5 },
  { href: '#', label: 'التقارير', icon: '📈', section: 'system' },
  { href: '#', label: 'الإعدادات', icon: '⚙️', section: 'system' },
];

const containerVariants = {
  hidden: { opacity: 0 },
  visible: {
    opacity: 1,
    transition: { staggerChildren: 0.05, delayChildren: 0.2 },
  },
};

const itemVariants = {
  hidden: { x: 40, opacity: 0 },
  visible: {
    x: 0,
    opacity: 1,
    transition: { type: 'spring' as const, stiffness: 120, damping: 18 },
  },
};

const logoLetterVariants = {
  hidden: { y: -20, opacity: 0 },
  visible: (i: number) => ({
    y: 0,
    opacity: 1,
    transition: { delay: i * 0.12, type: 'spring' as const, stiffness: 150, damping: 12 },
  }),
};

export default function ShowcaseDemoPage() {
  const [sidebarOpen, setSidebarOpen] = useState(false);
  const [active, setActive] = useState(0);

  return (
    <div className="flex min-h-screen bg-[var(--color-background)] text-[var(--color-foreground)]">
      {/* Overlay for mobile */}
      <AnimatePresence>
        {sidebarOpen && (
          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            exit={{ opacity: 0 }}
            className="fixed inset-0 z-40 bg-black/50 lg:hidden"
            onClick={() => setSidebarOpen(false)}
          />
        )}
      </AnimatePresence>

      {/* Sidebar */}
      <motion.aside
        initial={{ x: 300 }}
        animate={{ x: sidebarOpen ? 0 : 300 }}
        transition={{ type: 'spring', stiffness: 200, damping: 25 }}
        className="fixed inset-y-0 right-0 z-50 w-64 bg-[var(--color-sidebar)] text-white lg:relative lg:translate-x-0 lg:right-0 lg:flex lg:flex-col"
        style={{ x: 0 }}
      >
        {/* Logo */}
        <div className="px-5 py-6 border-b border-[var(--color-card-border)] overflow-hidden">
          <div className="flex items-center gap-1.5">
            {['d', '.', 'S', 'H', 'A', 'D'].map((letter, i) => (
              <motion.span
                key={i}
                custom={i}
                variants={logoLetterVariants}
                initial="hidden"
                animate="visible"
                className={i === 1 ? 'text-[var(--color-primary)]' : i === 0 ? 'text-2xl italic font-bold tracking-wide' : 'text-sm font-semibold tracking-[0.2em] text-white/80'}
                style={i === 0 ? { fontFamily: "'Playfair Display', serif" } : i > 1 ? { fontFamily: "'Playfair Display', serif" } : {}}
              >
                {letter}
              </motion.span>
            ))}
          </div>
        </div>

        {/* User info */}
        <motion.div
          initial={{ height: 0, opacity: 0 }}
          animate={{ height: 'auto', opacity: 1 }}
          transition={{ delay: 0.5, type: 'spring', stiffness: 100, damping: 20 }}
          className="px-5 py-4 border-b border-[var(--color-card-border)] overflow-hidden"
        >
          <p className="text-sm font-medium text-white/90">أحمد السيد</p>
          <motion.span
            initial={{ scale: 0 }}
            animate={{ scale: 1 }}
            transition={{ delay: 0.7, type: 'spring', stiffness: 200 }}
            className="inline-block mt-1 px-2 py-0.5 text-[10px] font-semibold tracking-wider bg-[var(--color-primary)] text-white rounded"
          >
            ACCOUNT MANAGER
          </motion.span>
        </motion.div>

        {/* Nav */}
        <nav className="p-3 space-y-2 flex-1 overflow-y-auto">
          {SECTIONS.map((section, si) => {
            const items = NAV_ITEMS.filter((i) => i.section === section.group);
            if (items.length === 0) return null;
            return (
              <motion.div
                key={section.group}
                variants={containerVariants}
                initial="hidden"
                animate="visible"
              >
                <motion.p
                  variants={itemVariants}
                  className="px-4 py-1 text-[10px] font-semibold tracking-widest text-white/40 uppercase"
                >
                  {section.label}
                </motion.p>
                <div className="space-y-0.5">
                  {items.map((item, ii) => {
                    const idx = NAV_ITEMS.indexOf(item);
                    const isActive = active === idx;
                    return (
                      <motion.div key={item.label} variants={itemVariants}>
                        <motion.button
                          whileHover={{ x: -4 }}
                          whileTap={{ scale: 0.97 }}
                          onClick={() => setActive(idx)}
                          className={`flex items-center gap-3 w-full px-4 py-2.5 text-sm transition-colors relative ${
                            isActive
                              ? 'text-white'
                              : 'text-white/50 hover:text-white/80'
                          }`}
                        >
                          {isActive && (
                            <motion.span
                              layoutId="activeTab"
                              className="absolute right-0 top-1 bottom-1 w-0.5 bg-[var(--color-primary)] rounded-full"
                              transition={{ type: 'spring', stiffness: 300, damping: 25 }}
                            />
                          )}
                          <motion.span
                            whileHover={{ rotate: [0, -10, 10, 0] }}
                            transition={{ duration: 0.3 }}
                            className="text-base"
                          >
                            {item.icon}
                          </motion.span>
                          {item.label}
                          {item.badge && (
                            <motion.span
                              initial={{ scale: 0 }}
                              animate={{ scale: 1 }}
                              transition={{ delay: 1 + idx * 0.05, type: 'spring' }}
                              className="mr-auto bg-[var(--color-primary)] text-white text-[10px] font-bold px-1.5 py-0.5 rounded-full min-w-[18px] text-center"
                            >
                              {item.badge}
                            </motion.span>
                          )}
                        </motion.button>
                      </motion.div>
                    );
                  })}
                </div>
              </motion.div>
            );
          })}
        </nav>

        {/* Logout */}
        <motion.div
          initial={{ y: 30, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ delay: 1.2 }}
          className="border-t border-[var(--color-card-border)]"
        >
          <button className="flex items-center gap-2 text-sm text-white/40 hover:text-white/80 w-full px-6 py-3 transition-colors">
            تسجيل الخروج
          </button>
        </motion.div>
      </motion.aside>

      {/* Main */}
      <div className="flex-1 flex flex-col min-w-0">
        {/* Top bar */}
        <motion.header
          initial={{ y: -80, opacity: 0 }}
          animate={{ y: 0, opacity: 1 }}
          transition={{ type: 'spring', stiffness: 150, damping: 18 }}
          className="sticky top-0 z-30 bg-[#111111]/80 backdrop-blur-xl border-b border-[var(--color-card-border)] px-6 py-3 flex items-center justify-between gap-3"
        >
          <div className="flex items-center gap-4">
            <motion.button
              whileHover={{ scale: 1.1 }}
              whileTap={{ scale: 0.9 }}
              className="lg:hidden p-2 text-[var(--color-foreground)]"
              onClick={() => setSidebarOpen(!sidebarOpen)}
            >
              <svg className="w-6 h-6" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M4 6h16M4 12h16M4 18h16" />
              </svg>
            </motion.button>
            <motion.h1
              initial={{ opacity: 0, x: -20 }}
              animate={{ opacity: 1, x: 0 }}
              transition={{ delay: 0.3, type: 'spring' }}
              className="text-lg font-semibold"
              style={{ fontFamily: "'Playfair Display', serif" }}
            >
              لوحة التحكم
            </motion.h1>
          </div>

          <motion.div
            initial={{ opacity: 0 }}
            animate={{ opacity: 1 }}
            transition={{ delay: 0.6 }}
            className="flex items-center gap-3"
          >
            {/* Search */}
            <motion.div
              initial={{ width: 120 }}
              whileFocus={{ width: 240 }}
              transition={{ type: 'spring', stiffness: 200, damping: 25 }}
              className="hidden md:flex items-center"
            >
              <motion.input
                placeholder="بحث..."
                whileFocus={{ borderColor: 'var(--color-primary)' }}
                className="w-full border border-[var(--color-input-border)] rounded-lg px-3 py-1.5 text-sm bg-[var(--color-input-fill)] text-[var(--color-foreground)] placeholder-[var(--color-text-disabled)] outline-none transition-colors"
              />
            </motion.div>

            {/* Notification bell */}
            <motion.button
              whileHover={{ rotate: [0, -15, 15, -5, 0] }}
              transition={{ duration: 0.4 }}
              className="relative w-8 h-8 flex items-center justify-center"
            >
              <svg className="w-5 h-5 text-[var(--color-text-secondary)]" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M15 17h5l-1.405-1.405A2.032 2.032 0 0118 14.158V11a6.002 6.002 0 00-4-5.659V5a2 2 0 10-4 0v.341C7.67 6.165 6 8.388 6 11v3.159c0 .538-.214 1.055-.595 1.436L4 17h5m6 0v1a3 3 0 11-6 0v-1m6 0H9" />
              </svg>
              <motion.span
                initial={{ scale: 0 }}
                animate={{ scale: 1 }}
                transition={{ delay: 1.5, type: 'spring' }}
                className="absolute -top-0.5 -right-0.5 w-2.5 h-2.5 bg-[var(--color-primary)] rounded-full"
              />
            </motion.button>

            {/* Locale toggle */}
            <motion.button
              whileHover={{ scale: 1.05 }}
              whileTap={{ scale: 0.95 }}
              className="text-xs bg-[var(--color-input-fill)] hover:bg-[var(--color-input-border)] text-[var(--color-foreground)] px-3 py-1.5 rounded-lg transition-colors"
            >
              English
            </motion.button>

            {/* Avatar */}
            <motion.div
              initial={{ scale: 0 }}
              animate={{ scale: 1 }}
              transition={{ delay: 0.8, type: 'spring', stiffness: 200 }}
              className="w-8 h-8 rounded-full bg-[var(--color-input-fill)] border border-[var(--color-card-border)] flex items-center justify-center text-sm text-[var(--color-gold)] overflow-hidden"
            >
              <motion.span
                whileHover={{ rotate: 360 }}
                transition={{ duration: 0.6 }}
              >
                أ
              </motion.span>
            </motion.div>
          </motion.div>
        </motion.header>

        {/* Content */}
        <main className="flex-1 p-6 overflow-auto">
          <motion.div
            initial={{ opacity: 0, y: 40 }}
            animate={{ opacity: 1, y: 0 }}
            transition={{ delay: 0.4, type: 'spring', stiffness: 100, damping: 20 }}
          >
            <h2 className="text-2xl font-bold mb-2" style={{ fontFamily: "'Playfair Display', serif" }}>مرحباً بعودتك، أحمد</h2>
            <p className="text-[var(--color-text-secondary)] mb-8">إليك ملخص نشاطك اليوم</p>

            {/* Stats cards */}
            <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-4 gap-4 mb-8">
              {[
                { label: 'العملاء', value: '24', change: '+4 هذا الشهر', icon: '👥' },
                { label: 'العقود', value: '8', change: '+2 جديد', icon: '📄' },
                { label: 'الإيرادات', value: '48,200 SAR', change: 'هذا الشهر', icon: '💰' },
                { label: 'بانتظار', value: '3', change: 'يتطلب تصرف', icon: '⏳' },
              ].map((stat, i) => (
                <motion.div
                  key={stat.label}
                  initial={{ opacity: 0, y: 30 }}
                  animate={{ opacity: 1, y: 0 }}
                  transition={{ delay: 0.6 + i * 0.1, type: 'spring', stiffness: 100, damping: 16 }}
                  whileHover={{ y: -4, transition: { type: 'spring', stiffness: 300 } }}
                  className="bg-[var(--color-card)] border border-[var(--color-card-border)] rounded-xl p-5 cursor-pointer"
                >
                  <div className="flex items-center justify-between mb-3">
                    <span className="text-2xl">{stat.icon}</span>
                    <motion.span
                      initial={{ width: 0 }}
                      animate={{ width: 24 }}
                      transition={{ delay: 1 + i * 0.1 }}
                      className="h-1 bg-[var(--color-primary)] rounded-full"
                    />
                  </div>
                  <p className="text-2xl font-bold" style={{ fontFamily: "'Playfair Display', serif" }}>{stat.value}</p>
                  <p className="text-xs text-[var(--color-text-secondary)] mt-1">{stat.label}</p>
                  <p className="text-xs text-[var(--color-gold)] mt-0.5">{stat.change}</p>
                </motion.div>
              ))}
            </div>

            {/* Recent clients table */}
            <motion.div
              initial={{ opacity: 0, y: 20 }}
              animate={{ opacity: 1, y: 0 }}
              transition={{ delay: 1.2 }}
              className="bg-[var(--color-card)] border border-[var(--color-card-border)] rounded-xl overflow-hidden"
            >
              <div className="flex items-center justify-between px-5 py-4 border-b border-[var(--color-card-border)]">
                <h3 className="font-semibold">آخر العملاء</h3>
                <button className="text-xs text-[var(--color-gold)] hover:underline">عرض الكل ←</button>
              </div>
              <div className="overflow-x-auto">
                <table className="w-full text-sm">
                  <thead>
                    <tr className="border-b border-[var(--color-card-border)] text-[var(--color-text-disabled)] text-xs">
                      {['العميل', 'العقد', 'المبلغ', 'الحالة', 'التاريخ'].map((h, i) => (
                        <motion.th
                          key={h}
                          initial={{ opacity: 0, y: -10 }}
                          animate={{ opacity: 1, y: 0 }}
                          transition={{ delay: 1.3 + i * 0.05 }}
                          className="text-right px-5 py-3 font-medium"
                        >
                          {h}
                        </motion.th>
                      ))}
                    </tr>
                  </thead>
                  <tbody>
                    {[
                      { name: 'سعد العمري', initial: 'سع', contract: 'خدمات سنوية', amount: '12,500 SAR', status: 'مكتمل', date: '28 يونيو' },
                      { name: 'نورا المحمد', initial: 'نم', contract: 'استشارات', amount: '8,000 SAR', status: 'بانتظار الدفع', date: '25 يونيو' },
                      { name: 'خالد الرشيد', initial: 'خر', contract: 'تسويق رقمي', amount: '5,500 SAR', status: 'قيد المراجعة', date: '20 يونيو' },
                    ].map((row, i) => (
                      <motion.tr
                        key={row.name}
                        initial={{ opacity: 0, x: -20 }}
                        animate={{ opacity: 1, x: 0 }}
                        transition={{ delay: 1.5 + i * 0.1, type: 'spring', stiffness: 100 }}
                        className="border-b border-[var(--color-card-border)] last:border-b-0 hover:bg-white/5 transition-colors"
                      >
                        <td className="px-5 py-3">
                          <div className="flex items-center gap-2">
                            <div className="w-7 h-7 rounded-full bg-[var(--color-primary)]/20 flex items-center justify-center text-xs text-[var(--color-gold)] font-bold">
                              {row.initial}
                            </div>
                            {row.name}
                          </div>
                        </td>
                        <td className="px-5 py-3 text-[var(--color-text-secondary)]">{row.contract}</td>
                        <td className="px-5 py-3 text-[var(--color-gold)]" style={{ fontFamily: "'Playfair Display', serif" }}>{row.amount}</td>
                        <td className="px-5 py-3">
                          <span className={`px-2 py-0.5 rounded-full text-xs font-medium ${
                            row.status === 'مكتمل' ? 'bg-green-900/30 text-green-400' :
                            row.status === 'بانتظار الدفع' ? 'bg-[var(--color-gold)]/20 text-[var(--color-gold)]' :
                            'bg-blue-900/30 text-blue-400'
                          }`}>{row.status}</span>
                        </td>
                        <td className="px-5 py-3 text-[var(--color-text-disabled)]">{row.date}</td>
                      </motion.tr>
                    ))}
                  </tbody>
                </table>
              </div>
            </motion.div>
          </motion.div>
        </main>
      </div>
    </div>
  );
}
