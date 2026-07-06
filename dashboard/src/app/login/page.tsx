'use client';

import { useState } from 'react';
import { login } from '@/lib/auth';
import Link from 'next/link';
import { useRouter } from 'next/navigation';

export default function LoginPage() {
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [loading, setLoading] = useState(false);
  const [visible, setVisible] = useState(false);
  const router = useRouter();

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setError('');
    setLoading(true);

    try {
      await login(email, password);
      router.push('/dashboard');
    } catch (err: any) {
      const msg = err?.response?.data?.message || err?.response?.data?.errors?.email?.[0] || 'بيانات الدخول غير صحيحة';
      setError(msg);
    } finally {
      setLoading(false);
    }
  };

  return (
    <div className="min-h-screen flex items-center justify-center bg-[#1A1A1A] px-4" dir="rtl">
      <div className="w-full max-w-md bg-[#1E1E1E] rounded-2xl shadow-2xl p-8 border border-[#D4AF37]/20 relative overflow-hidden">
        <div className="absolute top-0 right-0 w-32 h-32 bg-[#941414]/20 rounded-full -translate-y-1/2 translate-x-1/2" />
        <div className="absolute bottom-0 left-0 w-24 h-24 bg-[#D4AF37]/10 rounded-full translate-y-1/2 -translate-x-1/2" />

        <div className="relative">
          <div className="flex justify-center mb-4">
            <img src="/logo.jpg" alt="ShadApp" className="w-20 h-20 rounded-2xl object-cover shadow-lg" />
          </div>
          <h1 className="text-2xl font-bold text-center mb-1 text-white" style={{ fontFamily: "'Playfair Display', serif" }}>ShadApp</h1>
          <p className="text-[#D4AF37] text-center text-sm mb-6" style={{ fontFamily: "'Playfair Display', serif" }}>Shorter Road.</p>

          <form onSubmit={handleSubmit} className="space-y-4">
            {error && (
              <div className="bg-[#941414]/20 text-[#D4AF37] text-sm p-3 rounded-lg border border-[#941414]/30">{error}</div>
            )}

            <div>
              <label className="block text-sm font-medium text-white/80 mb-1">البريد الإلكتروني</label>
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="w-full border border-white/10 rounded-lg px-4 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-[#D4AF37] bg-white/5 text-white placeholder-white/30"
                required
                dir="ltr"
              />
            </div>

            <div>
              <label className="block text-sm font-medium text-white/80 mb-1">كلمة المرور</label>
              <div className="relative">
                <input
                  type={visible ? 'text' : 'password'}
                  value={password}
                  onChange={(e) => setPassword(e.target.value)}
                  className="w-full border border-white/10 rounded-lg px-4 py-2 text-sm focus:outline-none focus:ring-2 focus:ring-[#D4AF37] bg-white/5 text-white placeholder-white/30 pe-10"
                  required
                  dir="ltr"
                  autoComplete="new-password"
                />
                <button
                  type="button"
                  onClick={() => setVisible(!visible)}
                  className="absolute top-1/2 -translate-y-1/2 end-0 flex items-center px-3 text-white/40 hover:text-white/60 h-10"
                  tabIndex={-1}
                >
                  {visible ? (
                    <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                      <path strokeLinecap="round" strokeLinejoin="round" d="M3.98 8.223A10.477 10.477 0 001.934 12C3.226 16.338 7.244 19.5 12 19.5c.993 0 1.953-.138 2.863-.395M6.228 6.228A10.45 10.45 0 0112 4.5c4.756 0 8.773 3.162 10.065 7.498a10.523 10.523 0 01-4.293 5.774M6.228 6.228L3 3m3.228 3.228l3.65 3.65m7.894 7.894L21 21m-3.228-3.228l-3.65-3.65m0 0a3 3 0 10-4.243-4.243m4.242 4.242L9.88 9.88" />
                    </svg>
                  ) : (
                    <svg className="w-4 h-4" fill="none" viewBox="0 0 24 24" stroke="currentColor" strokeWidth={2}>
                      <path strokeLinecap="round" strokeLinejoin="round" d="M2.036 12.322a1.012 1.012 0 010-.639C3.423 7.51 7.36 4.5 12 4.5c4.638 0 8.573 3.007 9.963 7.178.07.207.07.431 0 .639C20.577 16.49 16.64 19.5 12 19.5c-4.638 0-8.573-3.007-9.963-7.178z" />
                      <path strokeLinecap="round" strokeLinejoin="round" d="M15 12a3 3 0 11-6 0 3 3 0 016 0z" />
                    </svg>
                  )}
                </button>
              </div>
            </div>

            <button
              type="submit"
              disabled={loading}
              className="w-full bg-[#941414] text-white rounded-lg py-2.5 text-sm font-medium hover:bg-[#7a1010] disabled:opacity-50 transition-colors"
            >
              {loading ? 'جاري تسجيل الدخول...' : 'تسجيل الدخول'}
            </button>
          </form>

          <p className="text-center text-sm text-white/50 mt-6">
            <Link href="/client-login" className="text-[#D4AF37] hover:underline">تسجيل دخول العميل</Link>
          </p>
        </div>
      </div>
    </div>
  );
}
