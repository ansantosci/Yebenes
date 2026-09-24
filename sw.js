const APP_VERSION = '16';
const CACHE_PREFIX = 'yebenes-runtime-v';
const CACHE = `${CACHE_PREFIX}${APP_VERSION}`;
const LEGACY_CACHE_PREFIX = 'yebenes-v';
const PRECACHE = [
  './',
  './index.html',
  `./styles.css?v=${APP_VERSION}`,
  `./app.js?v=${APP_VERSION}`,
  './manifest.webmanifest'
];

async function putFresh(cache, url) {
  const response = await fetch(url, { cache: 'reload' });
  if (response && response.ok) await cache.put(url, response.clone());
}

self.addEventListener('install', event => {
  event.waitUntil((async () => {
    const cache = await caches.open(CACHE);
    await Promise.all(PRECACHE.map(url => putFresh(cache, url).catch(() => null)));
    // Activate immediately. The client decides whether to reload now or later.
    await self.skipWaiting();
  })());
});

self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    const hadLegacyCache = keys.some(key => key.startsWith(LEGACY_CACHE_PREFIX) && !key.startsWith(CACHE_PREFIX));

    await Promise.all(
      keys
        .filter(key => key !== CACHE && (key.startsWith(CACHE_PREFIX) || key.startsWith(LEGACY_CACHE_PREFIX)))
        .map(key => caches.delete(key))
    );

    await self.clients.claim();
    const clients = await self.clients.matchAll({ type: 'window', includeUncontrolled: true });

    // One-time bridge from the old cache strategy (v14 and earlier): force a clean reload
    // because those clients did not know how to react to an update message.
    if (hadLegacyCache) {
      await Promise.all(clients.map(client => client.navigate(client.url).catch(() => null)));
      return;
    }

    // From v15 onward the app can offer an explicit "Actualizar ahora" action.
    clients.forEach(client => client.postMessage({ type: 'APP_UPDATE_READY', version: APP_VERSION }));
  })());
});

self.addEventListener('message', event => {
  if (event.data?.type === 'SKIP_WAITING') self.skipWaiting();
});

self.addEventListener('fetch', event => {
  if (event.request.method !== 'GET') return;

  const requestUrl = new URL(event.request.url);
  if (requestUrl.origin !== self.location.origin) return;

  event.respondWith((async () => {
    const cache = await caches.open(CACHE);
    try {
      // Development/update strategy: network first and bypass the HTTP cache.
      const response = await fetch(event.request, { cache: 'no-store' });
      if (response && response.ok) await cache.put(event.request, response.clone());
      return response;
    } catch (error) {
      const cached = await cache.match(event.request, { ignoreSearch: false });
      if (cached) return cached;

      if (event.request.mode === 'navigate') {
        return (await cache.match('./index.html')) || (await cache.match('./'));
      }
      throw error;
    }
  })());
});
