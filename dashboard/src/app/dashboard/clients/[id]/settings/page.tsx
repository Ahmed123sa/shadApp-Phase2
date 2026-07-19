'use client';

import { useEffect, useState, useRef } from 'react';
import { useParams, useRouter } from 'next/navigation';
import api from '@/lib/api';
import { LoadingSkeleton } from '@/components/ui/LoadingSkeleton';
import PasswordField from '@/components/ui/PasswordField';

const FILE_BASE = process.env.NEXT_PUBLIC_API_URL?.replace('/api', '') || 'http://localhost:8000';

function resolveFileUrl(url: string): string {
  if (!url) return '';
  if (url.startsWith('http')) return url;
  return `${FILE_BASE}/storage/${url.replace(/^\/?storage\//, '')}`;
}

export default function ClientSettingsPage() {
  const { id } = useParams();
  const router = useRouter();
  const [client, setClient] = useState<any>(null);
  const [loading, setLoading] = useState(true);
  const [saving, setSaving] = useState(false);
  const [success, setSuccess] = useState(false);
  const [error, setError] = useState('');
  const [avatar, setAvatar] = useState<File | null>(null);
  const [avatarPreview, setAvatarPreview] = useState('');
  const [form, setForm] = useState({
    company_name: '', contact_person: '', phone: '', email: '',
    country: '', industry: '', notes: '', date_of_birth: '', password: '',
  });
  const avatarInputRef = useRef<HTMLInputElement>(null);

  useEffect(() => {
    api.get(`/clients/${id}`).then(({ data }) => {
      const c = data.client;
      setClient(c);
      setForm({
        company_name: c.company_name || '',
        contact_person: c.contact_person || '',
        phone: c.phone || '',
        email: c.email || '',
        country: c.country || '',
        industry: c.industry || '',
        notes: c.notes || '',
        date_of_birth: c.date_of_birth || '',
        password: '',
      });
      if (c.avatar_url) setAvatarPreview(resolveFileUrl(c.avatar_url));
    }).catch(() => {}).finally(() => setLoading(false));
  }, [id]);

  const handleAvatarChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      setAvatar(file);
      setAvatarPreview(URL.createObjectURL(file));
    }
  };

  const save = async () => {
    setSaving(true);
    setSuccess(false);
    setError('');
    try {
      if (avatar) {
        const fd = new FormData();
        fd.append('avatar', avatar);
        fd.append('contact_person', form.contact_person);
        await api.post(`/clients/${id}/profile`, fd);
      }

      const payload: any = {
        company_name: form.company_name,
        contact_person: form.contact_person,
        phone: form.phone,
        country: form.country || null,
        industry: form.industry || null,
        notes: form.notes || null,
        date_of_birth: form.date_of_birth || null,
      };
      if (form.password) payload.password = form.password;
      await api.put(`/clients/${id}`, payload);

      setSuccess(true);
      setTimeout(() => setSuccess(false), 3000);
    } catch (err: any) {
      setError(err?.response?.data?.message || 'فشل حفظ التعديلات');
    } finally {
      setSaving(false);
    }
  };

  if (loading) return <div className="py-20"><LoadingSkeleton message="جاري تحميل..." /></div>;
  if (!client) return <div className="py-20 text-center text-[var(--color-text-secondary)]">العميل غير موجود</div>;

  return (
    <div className="max-w-2xl mx-auto space-y-6">
      <div className="flex items-center gap-3">
        <button onClick={() => router.back()} className="text-[var(--color-text-secondary)] hover:text-[var(--color-foreground)]">&larr; رجوع</button>
        <h1 className="text-xl font-bold">تعديل: {client.company_name}</h1>
      </div>

      {success && (
        <div className="bg-emerald-900/30 border border-emerald-800/30 rounded-xl p-4 text-emerald-400 text-sm">تم حفظ التعديلات بنجاح</div>
      )}
      {error && (
        <div className="bg-red-900/30 border border-red-800/30 rounded-xl p-4 text-red-400 text-sm">{error}</div>
      )}

      <div className="bg-[var(--color-card)] rounded-xl border border-[var(--color-card-border)] p-6 space-y-6">
        <div className="flex flex-col items-center gap-3">
          <div className="w-24 h-24 rounded-full bg-[var(--color-input-fill)] overflow-hidden border-2 border-[var(--color-card-border)]">
            {avatarPreview ? (
              <img src={avatarPreview} alt="" className="w-full h-full object-cover" />
            ) : (
              <div className="w-full h-full flex items-center justify-center text-3xl text-[var(--color-text-disabled)]">
                {client.company_name?.[0] || '?'}
              </div>
            )}
          </div>
          <button onClick={() => avatarInputRef.current?.click()} type="button"
            className="bg-[var(--color-input-fill)] hover:bg-[var(--color-card-border)] px-4 py-2 rounded-lg text-sm transition-colors">
            تغيير الصورة
          </button>
          <input ref={avatarInputRef} type="file" accept="image/*" className="hidden" onChange={handleAvatarChange} />
        </div>

        <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
          <div className="space-y-1">
            <label className="text-xs text-[var(--color-text-secondary)]">اسم الشركة</label>
            <input value={form.company_name} onChange={(e) => setForm({ ...form, company_name: e.target.value })}
              className="bg-[var(--color-input-fill)] border-[var(--color-input-border)] text-[var(--color-foreground)] rounded-lg px-4 py-2 text-sm w-full" />
          </div>
          <div className="space-y-1">
            <label className="text-xs text-[var(--color-text-secondary)]">الشخص المسؤول</label>
            <input value={form.contact_person} onChange={(e) => setForm({ ...form, contact_person: e.target.value })}
              className="bg-[var(--color-input-fill)] border-[var(--color-input-border)] text-[var(--color-foreground)] rounded-lg px-4 py-2 text-sm w-full" />
          </div>
          <div className="space-y-1">
            <label className="text-xs text-[var(--color-text-secondary)]">البريد الإلكتروني</label>
            <input value={form.email} disabled dir="ltr"
              className="border border-[var(--color-card-border)] rounded-lg px-4 py-2 text-sm w-full bg-[var(--color-card-border)] text-[var(--color-text-disabled)]" />
          </div>
          <div className="space-y-1">
            <label className="text-xs text-[var(--color-text-secondary)]">رقم الهاتف</label>
            <input value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })}
              className="bg-[var(--color-input-fill)] border-[var(--color-input-border)] text-[var(--color-foreground)] rounded-lg px-4 py-2 text-sm w-full" dir="ltr" />
          </div>
          <div className="space-y-1">
            <label className="text-xs text-[var(--color-text-secondary)]">البلد</label>
            <input value={form.country} onChange={(e) => setForm({ ...form, country: e.target.value })}
              className="bg-[var(--color-input-fill)] border-[var(--color-input-border)] text-[var(--color-foreground)] rounded-lg px-4 py-2 text-sm w-full" />
          </div>
          <div className="space-y-1">
            <label className="text-xs text-[var(--color-text-secondary)]">المجال</label>
            <input value={form.industry} onChange={(e) => setForm({ ...form, industry: e.target.value })}
              className="bg-[var(--color-input-fill)] border-[var(--color-input-border)] text-[var(--color-foreground)] rounded-lg px-4 py-2 text-sm w-full" />
          </div>
          <div className="space-y-1">
            <label className="text-xs text-[var(--color-text-secondary)]">تاريخ الميلاد</label>
            <input type="date" value={form.date_of_birth} onChange={(e) => setForm({ ...form, date_of_birth: e.target.value })}
              className="bg-[var(--color-input-fill)] border-[var(--color-input-border)] text-[var(--color-foreground)] rounded-lg px-4 py-2 text-sm w-full" />
          </div>
          <div className="space-y-1 md:col-span-2">
            <label className="text-xs text-[var(--color-text-secondary)]">ملاحظات</label>
            <textarea value={form.notes} onChange={(e) => setForm({ ...form, notes: e.target.value })}
              className="bg-[var(--color-input-fill)] border-[var(--color-input-border)] text-[var(--color-foreground)] rounded-lg px-4 py-2 text-sm w-full resize-none" rows={3} />
          </div>
        </div>

        <div className="border-t border-[var(--color-card-border)] pt-4">
          <PasswordField value={form.password} onChange={(v) => setForm({ ...form, password: v })} label="تغيير كلمة المرور" placeholder="اتركه فارغاً إذا لا تريد التغيير" opt />
        </div>

        <button onClick={save} disabled={saving}
          className="bg-[var(--color-primary)] text-white px-6 py-3 rounded-xl text-sm font-medium hover:bg-[var(--color-primary-dark)] disabled:opacity-50 w-full">
          {saving ? '...' : 'حفظ التعديلات'}
        </button>
      </div>
    </div>
  );
}
