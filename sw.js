/* D2DW Service Worker — アプリシェルのオフラインキャッシュ
   バージョンを上げると古いキャッシュを破棄して更新します。 */
const CACHE = 'd2dw-v16';
const SHELL = [
  './', './index.html', './manifest.webmanifest',
  './assets/images/icon-192.png', './assets/images/icon-512.png', './assets/images/apple-touch-icon.png',
  'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.css',
  'https://cdnjs.cloudflare.com/ajax/libs/leaflet/1.9.4/leaflet.min.js',
  'https://cdn.jsdelivr.net/npm/@supabase/supabase-js/+esm'
];

self.addEventListener('install', e => {
  e.waitUntil((async () => {
    const c = await caches.open(CACHE);
    await Promise.allSettled(SHELL.map(u => c.add(u)));
    self.skipWaiting();
  })());
});

self.addEventListener('activate', e => {
  e.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter(k => k !== CACHE).map(k => caches.delete(k)));
    await self.clients.claim();
  })());
});

self.addEventListener('fetch', e => {
  const req = e.request;
  if (req.method !== 'GET') return;
  const url = new URL(req.url);

  // Supabase API / Auth / Realtime: 常にネットワーク（キャッシュしない）
  if (url.hostname.endsWith('supabase.co')) return;

  // 画面遷移: network-first（オンラインは最新、オフラインはキャッシュのシェル）
  if (req.mode === 'navigate') {
    e.respondWith((async () => {
      try { return await fetch(req); }
      catch (_) { return (await caches.match('./index.html')) || (await caches.match('./')) || Response.error(); }
    })());
    return;
  }

  // 地図タイル(OSM): cache-first（既に見たタイルはオフラインでも表示）
  if (url.hostname.endsWith('tile.openstreetmap.org')) {
    e.respondWith((async () => {
      const cached = await caches.match(req);
      if (cached) return cached;
      try { const net = await fetch(req); const c = await caches.open(CACHE); c.put(req, net.clone()); return net; }
      catch (_) { return cached || Response.error(); }
    })());
    return;
  }

  // それ以外(CDNライブラリ・アイコン等): cache-first → なければネットワーク
  e.respondWith((async () => {
    const cached = await caches.match(req);
    if (cached) return cached;
    try {
      const net = await fetch(req);
      if (net && net.ok) { const c = await caches.open(CACHE); c.put(req, net.clone()); }
      return net;
    } catch (_) { return cached || Response.error(); }
  })());
});
