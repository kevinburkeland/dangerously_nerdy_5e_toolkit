const BUILD_VERSION = 'BUILD_TIMESTAMP_PLACEHOLDER';
const CACHE_NAME = '5e-toolkit-' + BUILD_VERSION;
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

// Install Event - Pre-cache essential static shell assets & activate immediately
self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then((cache) => {
      return cache.addAll(RESOURCES_TO_CACHE);
    })
  );
});

// Activate Event - Purge all stale cache versions & claim all open clients immediately
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cache) => {
          if (cache !== CACHE_NAME) {
            console.log('[ServiceWorker] Purging stale cache:', cache);
            return caches.delete(cache);
          }
        })
      );
    }).then(() => self.clients.claim())
  );
});

// Message listener to trigger immediate skip waiting on demand
self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});

// Fetch Strategy:
// 1. Navigation & App Logic (HTML, JS, manifest) -> Network-First (always fresh, cache fallback when offline)
// 2. Static Assets (Images, Icons, Fonts) -> Stale-While-Revalidate
self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;

  const url = new URL(event.request.url);
  const isNavigation = event.request.mode === 'navigate';
  const isCodeAsset = url.pathname.endsWith('.js') || 
                      url.pathname.endsWith('.html') || 
                      url.pathname.endsWith('manifest.json') ||
                      url.pathname.endsWith('.wasm');

  if (isNavigation || isCodeAsset) {
    // Network-First strategy
    event.respondWith(
      fetch(event.request)
        .then((networkResponse) => {
          if (networkResponse && networkResponse.status === 200) {
            const responseClone = networkResponse.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(event.request, responseClone));
          }
          return networkResponse;
        })
        .catch(() => {
          // Offline fallback
          return caches.match(event.request).then((cachedResponse) => {
            if (cachedResponse) return cachedResponse;
            if (isNavigation) {
              return caches.match('index.html');
            }
          });
        })
    );
    return;
  }

  // Stale-While-Revalidate strategy for static media assets
  event.respondWith(
    caches.match(event.request).then((cachedResponse) => {
      const fetchPromise = fetch(event.request).then((networkResponse) => {
        if (networkResponse && networkResponse.status === 200) {
          const responseClone = networkResponse.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, responseClone));
        }
        return networkResponse;
      }).catch(() => {});

      return cachedResponse || fetchPromise;
    })
  );
});
