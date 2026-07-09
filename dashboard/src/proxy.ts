import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

const locales = ['ar', 'en'];
const defaultLocale = 'ar';
const API_URL = process.env.NEXT_PUBLIC_API_URL || 'http://localhost:8000';

function getLocale(request: NextRequest): string {
  const cookie = request.cookies.get('NEXT_LOCALE')?.value;
  if (cookie && locales.includes(cookie)) return cookie;

  const acceptLang = request.headers.get('accept-language') || '';
  for (const part of acceptLang.split(',')) {
    const lang = part.trim().split(';')[0].split('-')[0];
    if (locales.includes(lang)) return lang;
  }

  return defaultLocale;
}

export async function proxy(request: NextRequest) {
  const { pathname } = request.nextUrl;

  // Proxy /storage/* by fetching the file from Laravel and passing it through
  if (pathname.startsWith('/storage/')) {
    const url = new URL('/api' + pathname, API_URL);
    const upstream = await fetch(url.toString());
    const headers = new Headers();
    const passHeaders = ['content-type', 'content-length', 'cache-control', 'etag', 'last-modified'];
    for (const key of passHeaders) {
      const value = upstream.headers.get(key);
      if (value) headers.set(key, value);
    }
    return new NextResponse(upstream.body, {
      status: upstream.status,
      statusText: upstream.statusText,
      headers,
    });
  }

  const locale = getLocale(request);

  const requestHeaders = new Headers(request.headers);
  requestHeaders.set('X-NEXT-INTL-LOCALE', locale);

  const response = NextResponse.next({
    request: { headers: requestHeaders },
  });

  response.cookies.set('NEXT_LOCALE', locale, {
    sameSite: 'lax',
    maxAge: 60 * 60 * 24 * 365,
  });

  return response;
}

export const config = {
  matcher: ['/((?!api|_next|_vercel).*)'],
};
