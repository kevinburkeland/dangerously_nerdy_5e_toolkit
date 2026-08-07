const CACHE_NAME = '5e-toolkit-v1';
const RESOURCES_TO_CACHE = [
  './',
  'index.html',
  'manifest.json',
  'favicon.png',
  'assets/images/logo.png',
  'pwa_icons/Icon-192.png',
  'pwa_icons/Icon-512.png',
  'pwa_icons/Icon-maskable-192.png',
  'pwa_icons/Icon-maskable-512.png',
  'pwa_icons/desktop_screenshot.png',
  'pwa_icons/mobile_screenshot.png'
];

// Install Event - Pre-cache essential static shell assets
self.addEventListener('install', (event) => {
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(RESOURCES_TO_CACHE);
    }).then(() => self.skipWaiting())
  );
});

// Activate Event - Clean up stale cache versions
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cache) => {
          if (cache !== CACHE_NAME) {
            return caches.delete(cache);
          }
        })
      );
    }).then(() => self.clients.claim())
  );
});

// Fetch Event - Stale-while-revalidate / Offline fallback for Chrome PWA compliance
self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;

  event.respondWith(
    caches.match(event.request).then((cachedResponse) => {
      if (cachedResponse) {
        fetch(event.request).then((networkResponse) => {
          if (networkResponse && networkResponse.status === 200) {
            caches.open(CACHE_NAME).then((cache) => cache.put(event.request, networkResponse));
          }
        }).catch(() => {});
        return cachedResponse;
      }
      return fetch(event.request);
    })
  );
});
