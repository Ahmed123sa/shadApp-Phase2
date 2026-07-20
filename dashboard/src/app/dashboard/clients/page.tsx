'use client';

import { useEffect, useState } from 'react';
import api from '@/lib/api';
import { getUser } from '@/lib/auth';
import Link from 'next/link';
import { StatusBadge } from '@/components/ui/StatusBadge';
import { ClientTypeBadge } from '@/components/ui/ClientTypeBadge';
import PasswordField from '@/components/ui/PasswordField';

export default function ClientsPage() {
  const [clients, setClients] = useState<any[]>([]);
  const [loading, setLoading] = useState(true);
  const [showCreate, setShowCreate] = useState(false);
  const [form, setForm] = useState({ company_name: '', contact_person: '', email: '', phone: '', password: '', notes: '', date_of_birth: '', send_email: true });
  const [newCreds, setNewCreds] = useState<any>(null);
  const [createError, setCreateError] = useState('');
  const [avatarFile, setAvatarFile] = useState<File | null>(null);
  const [avatarPreview, setAvatarPreview] = useState('');

  const [page, setPage] = useState(1);
  const [totalPages, setTotalPages] = useState(1);

  const fetchClients = (p: number) => {
    api.get(`/clients?page=${p}&per_page=30`).then(({ data }) => {
      setClients(data.clients?.data || data.clients || []);
      setTotalPages(data.clients?.last_page || 1);
    }).catch(() => {}).finally(() => setLoading(false));
  };

  useEffect(() => { fetchClients(1); }, []);

  const createClient = async (e: React.FormEvent) => {
    e.preventDefault();
    setCreateError('');
    try {
      const { data } = await api.post('/clients', form);
      if (data.client?.id && avatarFile) {
        try {
          const fd = new FormData();
          fd.append('avatar', avatarFile);
          await api.post(`/clients/${data.client.id}/profile`, fd);
        } catch (_) {}
      }
      setClients((prev) => [data.client, ...prev]);
      setNewCreds(data.credentials);
      setShowCreate(false);
      setForm({ company_name: '', contact_person: '', email: '', phone: '', password: '', notes: '', date_of_birth: '', send_email: true });
      setAvatarFile(null);
      setAvatarPreview('');
    } catch (err: any) {
      setCreateError(err?.response?.data?.message || 'فشل إنشاء العميل');
    }
  };

  const deleteClient = async (id: number) => {
    if (!confirm('حذف العميل؟')) return;
    const { data } = await api.delete(`/clients/${id}`).catch(() => ({ data: null }));
    if (data) setClients((prev) => prev.filter((c) => c.id !== id));
  };

  if (loading) return <div className="text-center py-20 text-[var(--color-text-secondary)]">جاري التحميل...</div>;

  const isSA = getUser()?.role === 'super_admin';

  return (
    <div>
      <div className="flex items-center justify-between mb-6">
        <h2 className="text-xl font-semibold">العملاء</h2>
        {!isSA && <button onClick={() => setShowCreate(true)} className="bg-[var(--color-primary)] text-white px-4 py-2 rounded-lg text-sm font-medium hover:bg-[var(--color-primary-dark)]">
          + عميل جديد
        </button>}
      </div>

      {newCreds && (
        <div className="bg-green-900/30 border border-green-900/30 rounded-xl p-4 mb-4">
          <p className="text-green-400 font-medium mb-2">تم إنشاء العميل بنجاح</p>
          <p className="text-sm text-green-400">البريد: {newCreds.email}</p>
          <p className="text-sm text-green-400">كلمة المرور: {newCreds.password}</p>
        </div>
      )}

      {showCreate && (
        <form onSubmit={createClient} className="bg-[var(--color-card)] rounded-xl border border-[var(--color-card-border)] p-6 mb-6 space-y-4">
          {createError && <div className="bg-red-900/30 text-red-400 text-sm p-3 rounded-lg">{createError}</div>}
          <div className="flex items-center gap-4 mb-2">
            <div className="w-20 h-20 rounded-full bg-[var(--color-card-border)] border-2 border-dashed border-[var(--color-card-border)] flex items-center justify-center overflow-hidden shrink-0">
              {avatarPreview ? (
                <img src={avatarPreview} alt="" className="w-full h-full object-cover" />
              ) : (
                <span className="text-2xl text-[var(--color-text-muted)]">👤</span>
              )}
            </div>
            <div>
              <label className="block text-sm font-medium mb-1">صورة العميل (اختياري)</label>
              <input type="file" accept="image/*" className="text-sm text-[var(--color-text-secondary)] file:mr-2 file:py-1 file:px-3 file:rounded-lg file:border-0 file:text-sm file:bg-[var(--color-card-border)] file:text-[var(--color-foreground)] hover:file:bg-[var(--color-input-fill)]" onChange={(e) => { const f = e.target.files?.[0]; if (f) { setAvatarFile(f); setAvatarPreview(URL.createObjectURL(f)); } }} />
            </div>
          </div>
          <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
            <input className="border border-[var(--color-card-border)] rounded-lg px-4 py-2 text-sm" placeholder="اسم الشركة" value={form.company_name} onChange={(e) => setForm({ ...form, company_name: e.target.value })} required />
            <input className="border border-[var(--color-card-border)] rounded-lg px-4 py-2 text-sm" placeholder="الشخص المسؤول" value={form.contact_person} onChange={(e) => setForm({ ...form, contact_person: e.target.value })} required />
            <input className="border border-[var(--color-card-border)] rounded-lg px-4 py-2 text-sm" type="email" placeholder="البريد الإلكتروني" value={form.email} onChange={(e) => setForm({ ...form, email: e.target.value })} required dir="ltr" />
            <input className="border border-[var(--color-card-border)] rounded-lg px-4 py-2 text-sm" placeholder="رقم الهاتف" value={form.phone} onChange={(e) => setForm({ ...form, phone: e.target.value })} required />
            <input className="border border-[var(--color-card-border)] rounded-lg px-4 py-2 text-sm" placeholder="ملاحظات" value={form.notes} onChange={(e) => setForm({ ...form, notes: e.target.value })} />
            <input className="border border-[var(--color-card-border)] rounded-lg px-4 py-2 text-sm" type="date" placeholder="تاريخ الميلاد" value={form.date_of_birth} onChange={(e) => setForm({ ...form, date_of_birth: e.target.value })} />
            <PasswordField value={form.password} onChange={(v) => setForm({ ...form, password: v })} label="كلمة المرور (اختياري)" placeholder="اتركه فارغاً للإنشاء التلقائي" showStrength={false} showRequirements={false} opt />
          </div>
          <label className="flex items-center gap-2 text-sm text-[var(--color-foreground)] cursor-pointer">
            <input type="checkbox" checked={form.send_email} onChange={(e) => setForm({ ...form, send_email: e.target.checked })} className="rounded" />
            إرسال بيانات الدخول إلى البريد الإلكتروني للعميل
          </label>
          <div className="flex gap-2">
            <button type="submit" className="bg-[var(--color-primary)] text-white px-6 py-2 rounded-lg text-sm font-medium hover:bg-[var(--color-primary-dark)]">إنشاء</button>
            <button type="button" onClick={() => setShowCreate(false)} className="bg-[var(--color-input-fill)] px-6 py-2 rounded-lg text-sm hover:bg-[var(--color-card-border)]">إلغاء</button>
          </div>
        </form>
      )}

      <div className="bg-[var(--color-card)] rounded-xl border border-[var(--color-card-border)] overflow-hidden">
        <table className="w-full text-sm">
          <thead className="bg-[var(--color-card-border)] border-b border-[var(--color-card-border)]">
            <tr>
              <th className="text-right p-4 font-medium">Company</th>
              <th className="text-right p-4 font-medium">Type</th>
              <th className="text-right p-4 font-medium">Contact Person</th>
              <th className="text-right p-4 font-medium">Status</th>
              <th className="text-right p-4 font-medium">Workspace</th>
              <th className="text-left p-4 font-medium"></th>
            </tr>
          </thead>
          <tbody>
            {clients.map((client) => (
              <tr key={client.id} className="border-b border-[var(--color-card-border)] hover:bg-[var(--color-card-border)]">
                <td className="p-4">
                  <Link href={`/dashboard/clients/${client.id}`} className="text-[var(--color-gold)] hover:underline font-medium">{client.company_name}</Link>
                </td>
                <td className="p-4"><ClientTypeBadge clientType={client.client_type} /></td>
                <td className="p-4 text-[var(--color-text-secondary)]">{client.contact_person}</td>
                <td className="p-4">
                  <span className={`px-2 py-1 rounded-full text-xs ${client.status === 'active' ? 'bg-green-900/30 text-green-400' : 'bg-zinc-700/30 text-zinc-400'}`}>{client.status}</span>
                </td>
                <td className="p-4">{client.workspace ? (client.workspace.status === 'active' ? '🟢 نشط' : '⏳ غير مفعل') : '—'}</td>
                <td className="p-4 text-left whitespace-nowrap">
                  {!isSA && <Link href={`/dashboard/clients/${client.id}/settings`} className="inline-flex items-center justify-center w-8 h-8 rounded-lg hover:bg-[var(--color-card-border)] transition-colors text-[var(--color-text-secondary)] hover:text-[var(--color-foreground)]" title="إعدادات">⚙️</Link>}
                  {!isSA && <button onClick={() => deleteClient(client.id)} className="inline-flex items-center justify-center w-8 h-8 rounded-lg hover:bg-red-900/30 transition-colors text-[var(--color-text-secondary)] hover:text-red-400" title="حذف">🗑️</button>}
                </td>
              </tr>
            ))}
          </tbody>
        </table>
        {totalPages > 1 && (
          <div className="flex items-center justify-center gap-2 p-4 border-t border-[var(--color-card-border)]">
            <button onClick={() => { const p = page - 1; setPage(p); fetchClients(p); }} disabled={page <= 1}
              className="px-3 py-1.5 text-sm rounded border border-[var(--color-card-border)] hover:bg-[var(--color-card-border)] disabled:opacity-50">السابق</button>
            <span className="text-sm text-[var(--color-text-secondary)]">الصفحة {page} من {totalPages}</span>
            <button onClick={() => { const p = page + 1; setPage(p); fetchClients(p); }} disabled={page >= totalPages}
              className="px-3 py-1.5 text-sm rounded border border-[var(--color-card-border)] hover:bg-[var(--color-card-border)] disabled:opacity-50">التالي</button>
          </div>
        )}
      </div>
    </div>
  );
}
