// V17 development cleanup worker. The application no longer registers a Service Worker.
self.addEventListener('install', event => event.waitUntil(self.skipWaiting()));
self.addEventListener('activate', event => {
  event.waitUntil((async () => {
    const keys = await caches.keys();
    await Promise.all(keys.filter(k => k.startsWith('yebenes-')).map(k => caches.delete(k)));
    await self.registration.unregister();
  })());
});
