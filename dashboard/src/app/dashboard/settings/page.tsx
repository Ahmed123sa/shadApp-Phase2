'use client';

import { useEffect, useState, useRef } from 'react';
import api from '@/lib/api';
import { getUser, logout } from '@/lib/auth';
import { useTranslations } from 'next-intl';

const FILE_BASE = process.env.NEXT_PUBLIC_API_URL?.replace('/api', '') || 'http://localhost:8000';

function resolveFileUrl(url: string): string {
  if (!url) return '';
  if (url.startsWith('http')) return url;
  return `${FILE_BASE}/storage/${url.replace(/^\/?storage\//, '')}`;
}

export default function SettingsPage() {
  const t = useTranslations('settings');
  const [user, setUser] = useState(getUser());
  const isAM = user?.role === 'account_manager';
  const [officialEmail, setOfficialEmail] = useState('');
  const [displayName, setDisplayName] = useState('');
  const [avatar, setAvatar] = useState<File | null>(null);
  const [avatarPreview, setAvatarPreview] = useState('');
  const [signatureType, setSignatureType] = useState<'draw' | 'type' | 'upload' | null>(null);
  const [typedSignature, setTypedSignature] = useState('');
  const [uploadedSignatureFile, setUploadedSignatureFile] = useState<File | null>(null);
  const [uploadedSignaturePreview, setUploadedSignaturePreview] = useState('');
  const [savedSignature, setSavedSignature] = useState<{ data: string; type: string } | null>(null);
  const [saving, setSaving] = useState(false);
  const [savingSig, setSavingSig] = useState(false);
  const [deletingSig, setDeletingSig] = useState(false);
  const [success, setSuccess] = useState(false);
  const [sigSuccess, setSigSuccess] = useState(false);
  const [taxPercentage, setTaxPercentage] = useState('15');
  const [savingTax, setSavingTax] = useState(false);
  const [taxSuccess, setTaxSuccess] = useState(false);
  const canvasRef = useRef<HTMLCanvasElement>(null);
  const avatarInputRef = useRef<HTMLInputElement>(null);
  const sigUploadInputRef = useRef<HTMLInputElement>(null);
  const [isDrawing, setIsDrawing] = useState(false);

  useEffect(() => {
    api.get('/auth/me').then(({ data }) => {
      const u = data.user;
      setUser(u);
      setOfficialEmail(u.official_email || '');
      setDisplayName(u.name || '');
      if (u.avatar_url) setAvatarPreview(resolveFileUrl(u.avatar_url));
      if (u.signature_data) {
        setSavedSignature({ data: u.signature_data, type: u.signature_type || 'text' });
      }
      localStorage.setItem('user', JSON.stringify(u));
    }).catch(() => {});
    if (!isAM) {
      api.get('/settings').then(({ data }) => {
        const v = data.settings?.corporate_tax_percentage?.value;
        if (v !== undefined) setTaxPercentage(String(v));
      }).catch(() => {});
    }
  }, []);

  const handleAvatarChange = (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (file) {
      setAvatar(file);
      setAvatarPreview(URL.createObjectURL(file));
    }
  };

  const saveProfile = async () => {
    setSaving(true);
    setSuccess(false);
    try {
      const form = new FormData();
      if (avatar) form.append('avatar', avatar);
      form.append('name', displayName);
      if (!isAM) form.append('official_email', officialEmail);
      const { data } = await api.post('/auth/me', form);
      setUser(data.user);
      if (data.user?.avatar_url) setAvatarPreview(resolveFileUrl(data.user.avatar_url));
      localStorage.setItem('user', JSON.stringify(data.user));
      setSuccess(true);
      setTimeout(() => setSuccess(false), 3000);
    } catch {
      // ignore
    } finally {
      setSaving(false);
    }
  };

  const drawSignature = (e: React.MouseEvent<HTMLCanvasElement>) => {
    if (!isDrawing) return;
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    const rect = canvas.getBoundingClientRect();
    ctx.lineWidth = 2;
    ctx.lineCap = 'round';
    ctx.strokeStyle = '#000';
    ctx.lineTo(e.clientX - rect.left, e.clientY - rect.top);
    ctx.stroke();
    ctx.beginPath();
    ctx.moveTo(e.clientX - rect.left, e.clientY - rect.top);
  };

  const startDraw = () => {
    setIsDrawing(true);
    const canvas = canvasRef.current;
    if (canvas) {
      const ctx = canvas.getContext('2d');
      if (ctx) ctx.beginPath();
    }
  };

  const stopDraw = () => {
    setIsDrawing(false);
    const canvas = canvasRef.current;
    if (canvas) {
      const ctx = canvas.getContext('2d');
      if (ctx) ctx.beginPath();
    }
  };

  const clearCanvas = () => {
    const canvas = canvasRef.current;
    if (!canvas) return;
    const ctx = canvas.getContext('2d');
    if (!ctx) return;
    ctx.clearRect(0, 0, canvas.width, canvas.height);
  };

  const getCanvasData = (): string | null => {
    const canvas = canvasRef.current;
    if (!canvas) return null;
    return canvas.toDataURL('image/png');
  };

  const saveSignature = async () => {
    setSavingSig(true);
    setSigSuccess(false);
    try {
      const form = new FormData();
      if (signatureType === 'draw') {
        const canvas = canvasRef.current;
        if (!canvas) return;
        const blob = await new Promise<Blob | null>(resolve => canvas.toBlob(resolve, 'image/png'));
        if (!blob) return;
        form.append('signature_image', blob, 'signature.png');
      } else if (signatureType === 'type') {
        form.append('signature', typedSignature);
      } else if (signatureType === 'upload' && uploadedSignatureFile) {
        form.append('signature_image', uploadedSignatureFile);
      }
      const { data } = await api.post('/auth/sign', form);
      if (data.user?.signature_data) {
        setSavedSignature({ data: data.user.signature_data, type: data.user.signature_type || 'image' });
        localStorage.setItem('user', JSON.stringify(data.user));
        setSigSuccess(true);
        setTimeout(() => setSigSuccess(false), 3000);
      }
      setSignatureType(null);
      setTypedSignature('');
      setUploadedSignatureFile(null);
      setUploadedSignaturePreview('');
    } catch {
      // ignore
    } finally {
      setSavingSig(false);
    }
  };

  const deleteSignature = async () => {
    if (!confirm('هل أنت متأكد من حذف التوقيع؟')) return;
    setDeletingSig(true);
    try {
      await api.delete('/auth/sign');
      setSavedSignature(null);
    } catch {
      // ignore
    } finally {
      setDeletingSig(false);
    }
  };

  const saveTax = async () => {
    const val = parseFloat(taxPercentage);
    if (isNaN(val) || val < 0 || val > 100) return;
    setSavingTax(true);
    setTaxSuccess(false);
    try {
      await api.put('/settings', { key: 'corporate_tax_percentage', value: val });
      setTaxSuccess(true);
      setTimeout(() => setTaxSuccess(false), 3000);
    } catch {
      // ignore
    } finally {
      setSavingTax(false);
    }
  };

  return (
    <div className="max-w-2xl mx-auto space-y-8">
      <h1 className="text-2xl font-bold">{t('title')}</h1>

      {success && (
        <div className="bg-emerald-50 border border-emerald-200 rounded-xl p-4 text-emerald-700 text-sm">{t('saved')}</div>
      )}
      {sigSuccess && (
        <div className="bg-emerald-50 border border-emerald-200 rounded-xl p-4 text-emerald-700 text-sm">{t('saved')}</div>
      )}

      <div className="bg-[var(--color-card)] rounded-xl border border-[var(--color-card-border)] p-6 space-y-4">
        <h2 className="text-lg font-semibold">{t('avatar')}</h2>
        <div className="flex items-center gap-4">
          <div className="w-20 h-20 rounded-full bg-[var(--color-input-fill)] overflow-hidden border-2 border-zinc-200">
            {avatarPreview ? (
              <img src={avatarPreview} alt="" className="w-full h-full object-cover" />
            ) : (
              <div className="w-full h-full flex items-center justify-center text-2xl text-[var(--color-text-disabled)]">
                {user?.name?.[0] || '?'}
              </div>
            )}
          </div>
          <button onClick={() => avatarInputRef.current?.click()} type="button"
            className="bg-[var(--color-input-fill)] hover:bg-[var(--color-card-border)] px-4 py-2 rounded-lg text-sm transition-colors">
            {t('change_avatar')}
          </button>
          <input ref={avatarInputRef} type="file" accept="image/*" className="hidden" onChange={handleAvatarChange} />
        </div>
      </div>

      <div className="bg-[var(--color-card)] rounded-xl border border-[var(--color-card-border)] p-6 space-y-4">
        <h2 className="text-lg font-semibold">{t('name')}</h2>
        <input value={displayName} onChange={(e) => setDisplayName(e.target.value)}
          className="border border-[var(--color-input-border)] bg-[var(--color-input-fill)] text-[var(--color-foreground)] rounded-lg px-4 py-2 text-sm w-full" placeholder={t('name')} />
      </div>

      {!isAM && <div className="bg-[var(--color-card)] rounded-xl border border-[var(--color-card-border)] p-6 space-y-4">
        <h2 className="text-lg font-semibold">{t('official_email')}</h2>
        <p className="text-xs text-[var(--color-text-secondary)]">{t('official_email_hint')}</p>
        <input value={officialEmail} onChange={(e) => setOfficialEmail(e.target.value)}
          className="border border-[var(--color-input-border)] bg-[var(--color-input-fill)] text-[var(--color-foreground)] rounded-lg px-4 py-2 text-sm w-full" type="email" placeholder={t('official_email')} dir="ltr" />
      </div>}

      {!isAM && <div className="bg-[var(--color-card)] rounded-xl border border-[var(--color-card-border)] p-6 space-y-4">
        <h2 className="text-lg font-semibold">{t('signature')}</h2>
        <p className="text-xs text-[var(--color-text-secondary)]">{t('signature_hint')}</p>

        {savedSignature ? (
          <div className="space-y-3">
            <p className="text-sm font-medium text-[var(--color-text-secondary)]">{t('saved_signature')}</p>
            {savedSignature.type === 'text' ? (
              <p className="text-lg font-[cursive] border border-[var(--color-card-border)] rounded-lg p-4 bg-[var(--color-card-border)] text-center">{savedSignature.data}</p>
            ) : (
              <img src={resolveFileUrl(savedSignature.data)} alt="التوقيع المحفوظ" className="max-h-20 border border-[var(--color-card-border)] rounded-lg p-2 bg-[var(--color-card-border)]" />
            )}
            <button onClick={deleteSignature} disabled={deletingSig}
              className="text-red-600 hover:text-red-700 text-xs underline disabled:opacity-50">
              {deletingSig ? '...' : 'حذف التوقيع'}
            </button>
          </div>
        ) : (
          <p className="text-sm text-amber-600">{t('saved_signature')}</p>
        )}

        <div className="flex gap-2 flex-wrap">
          <button onClick={() => { setSignatureType('draw'); setTypedSignature(''); setUploadedSignatureFile(null); setUploadedSignaturePreview(''); }}
            className={`px-4 py-2 rounded-lg text-sm border border-[var(--color-card-border)] transition-colors ${signatureType === 'draw' ? 'bg-blue-100 border-blue-300 text-blue-700' : 'hover:bg-[var(--color-card-border)]'}`}>
            {t('draw_signature')}
          </button>
          <button onClick={() => { setSignatureType('type'); setUploadedSignatureFile(null); setUploadedSignaturePreview(''); }}
            className={`px-4 py-2 rounded-lg text-sm border border-[var(--color-card-border)] transition-colors ${signatureType === 'type' ? 'bg-blue-100 border-blue-300 text-blue-700' : 'hover:bg-[var(--color-card-border)]'}`}>
            {t('type_signature')}
          </button>
          <button onClick={() => { setSignatureType('upload'); setTypedSignature(''); }}
            className={`px-4 py-2 rounded-lg text-sm border border-[var(--color-card-border)] transition-colors ${signatureType === 'upload' ? 'bg-blue-100 border-blue-300 text-blue-700' : 'hover:bg-[var(--color-card-border)]'}`}>
            {t('upload_signature')}
          </button>
        </div>

        {signatureType === 'draw' && (
          <div className="space-y-2">
            <canvas ref={canvasRef} width={400} height={150}
              onMouseDown={startDraw} onMouseMove={drawSignature} onMouseUp={stopDraw} onMouseLeave={stopDraw}
              className="border border-[var(--color-card-border)] rounded-lg w-full cursor-crosshair bg-[var(--color-card)]" />
            <button onClick={clearCanvas} className="text-xs text-[var(--color-text-secondary)] hover:text-red-500">مسح</button>
          </div>
        )}

        {signatureType === 'type' && (
          <input value={typedSignature} onChange={(e) => setTypedSignature(e.target.value)}
            className="border border-[var(--color-input-border)] bg-[var(--color-input-fill)] text-[var(--color-foreground)] rounded-lg px-4 py-3 text-lg font-[cursive] w-full text-center"
            placeholder="اكتب اسمك كاملاً" />
        )}

        {signatureType === 'upload' && (
          <div className="space-y-2">
            <button onClick={() => sigUploadInputRef.current?.click()} type="button"
              className="bg-[var(--color-input-fill)] hover:bg-[var(--color-card-border)] px-4 py-2 rounded-lg text-sm inline-block transition-colors">
              {t('upload_signature')}
            </button>
            <input ref={sigUploadInputRef} type="file" accept="image/*" className="hidden" onChange={(e) => {
              const file = e.target.files?.[0];
              if (file) { setUploadedSignatureFile(file); setUploadedSignaturePreview(URL.createObjectURL(file)); }
            }} />
            {uploadedSignaturePreview && (
              <img src={uploadedSignaturePreview} alt="" className="max-h-20 border border-[var(--color-card-border)] rounded-lg p-2" />
            )}
          </div>
        )}

        {signatureType && (
          <button onClick={saveSignature} disabled={savingSig}
            className="bg-purple-600 text-white px-6 py-2 rounded-lg text-sm hover:bg-purple-700 disabled:opacity-50">
            {savingSig ? '...' : t('save')}
          </button>
        )}
      </div>}

      {!isAM && <div className="bg-[var(--color-card)] rounded-xl border border-[var(--color-card-border)] p-6 space-y-4">
        <h2 className="text-lg font-semibold">إعدادات النظام</h2>
        <p className="text-xs text-[var(--color-text-secondary)]">النسبة المئوية للضريبة المضافة على قيمة العقود للعملاء من نوع شركات</p>
        {taxSuccess && (
          <div className="bg-emerald-50 border border-emerald-200 rounded-lg p-3 text-emerald-700 text-sm">تم حفظ نسبة الضريبة</div>
        )}
        <div className="flex items-center gap-3">
          <div className="flex-1">
            <label className="text-sm text-[var(--color-text-secondary)] mb-1 block">نسبة الضريبة (%)</label>
            <input type="number" min="0" max="100" step="0.5" value={taxPercentage}
              onChange={(e) => setTaxPercentage(e.target.value)}
              className="border border-[var(--color-input-border)] bg-[var(--color-input-fill)] text-[var(--color-foreground)] rounded-lg px-4 py-2 text-sm w-full" />
          </div>
          <span className="text-[var(--color-text-secondary)] mt-5">%</span>
          <button onClick={saveTax} disabled={savingTax}
            className="bg-[var(--color-primary)] text-white px-6 py-2 rounded-lg text-sm hover:bg-[var(--color-primary-dark)] disabled:opacity-50 mt-5">
            {savingTax ? '...' : 'حفظ'}
          </button>
        </div>
      </div>}

      <button onClick={saveProfile} disabled={saving}
        className="bg-[var(--color-primary)] text-white px-8 py-3 rounded-xl text-sm font-medium hover:bg-[var(--color-primary-dark)] disabled:opacity-50 w-full">
        {saving ? '...' : t('save')}
      </button>
    </div>
  );
}
