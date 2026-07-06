'use client';

import { useState } from 'react';

interface PasswordFieldProps {
  value: string;
  onChange: (value: string) => void;
  label?: string;
  placeholder?: string;
  showStrength?: boolean;
  showRequirements?: boolean;
  required?: boolean;
  opt?: boolean;
  className?: string;
  disabled?: boolean;
  name?: string;
}

export default function PasswordField({
  value,
  onChange,
  label,
  placeholder = 'أدخل كلمة المرور',
  showStrength = true,
  showRequirements = true,
  required = false,
  opt = false,
  className = '',
  disabled = false,
  name,
}: PasswordFieldProps) {
  const [visible, setVisible] = useState(false);

  const hasMinChars = value.length >= 8;
  const hasLetter = /[A-Za-z]/.test(value);
  const hasDigit = /[0-9]/.test(value);
  const strength = [hasMinChars, hasLetter, hasDigit].filter(Boolean).length;

  const strengthBar =
    strength <= 1 ? 'bg-red-500' : strength === 2 ? 'bg-yellow-500' : 'bg-green-500';
  const strengthLabel =
    strength <= 1 ? 'ضعيف' : strength === 2 ? 'متوسط' : 'قوي';
  const strengthColor =
    strength <= 1 ? 'text-red-600' : strength === 2 ? 'text-yellow-600' : 'text-green-600';

  return (
    <div className="space-y-1">
      {label && <label className="block text-xs text-[var(--color-text-secondary)]">{label}</label>}
      <div className="relative">
        <input
          type={visible ? 'text' : 'password'}
          value={value}
          onChange={(e) => onChange(e.target.value)}
          placeholder={placeholder}
          required={!opt ? required : false}
          disabled={disabled}
          name={name}
          dir="ltr"
          autoComplete="new-password"
          className={`rounded-lg px-4 py-2 text-sm w-full focus:outline-none focus:ring-2 focus:ring-[var(--color-gold)] pe-10 bg-[var(--color-input-fill)] border border-[var(--color-input-border)] text-[var(--color-foreground)] ${className}`}
        />
        <button
          type="button"
          onClick={() => setVisible(!visible)}
          className="absolute top-1/2 -translate-y-1/2 end-0 flex items-center px-3 text-[var(--color-text-disabled)] hover:text-[var(--color-text-secondary)] h-10"
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
      {showStrength && value.length > 0 && (
        <div className="space-y-1">
          <div className="h-1.5 bg-[var(--color-card-border)] rounded-full overflow-hidden">
            <div className={`h-full ${strengthBar} transition-all duration-300`} style={{ width: `${(strength / 3) * 100}%` }} />
          </div>
          <p className={`text-[11px] ${strengthColor}`}>{strengthLabel}</p>
        </div>
      )}
      <div className="space-y-0.5">
        <Req label="8 أحرف على الأقل" met={hasMinChars} />
        <Req label="حرف إنجليزي واحد" met={hasLetter} />
        <Req label="رقم واحد" met={hasDigit} />
      </div>
    </div>
  );
}

function Req({ label, met }: { label: string; met: boolean }) {
  return (
    <div className="flex items-center gap-1.5 text-[11px]">
      <span className={met ? 'text-green-600' : 'text-red-400'}>{met ? '✓' : '○'}</span>
      <span className={met ? 'text-green-600' : 'text-red-500'}>{label}</span>
    </div>
  );
}
