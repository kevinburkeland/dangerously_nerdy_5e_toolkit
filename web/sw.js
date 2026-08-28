const BUILD_VERSION = 'BUILD_TIMESTAMP_PLACEHOLDER';
const CACHE_NAME = '5e-toolkit-' + BUILD_VERSION;
const RESOURCES_TO_CACHE = [
  './',
  'index.html',
  'manifest.json',
  'favicon.png',
  'assets/FontManifest.json',
  'assets/AssetManifest.bin.json',
  'assets/fonts/MaterialIcons-Regular.otf',
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
    caches.open(CACHE_NAME).then(async (cache) => {
      await Promise.allSettled(
        RESOURCES_TO_CACHE.map(async (url) => {
          try {
            const response = await fetch(url);
            if (response && response.ok) {
              await cache.put(url, response);
            }
          } catch (err) {
            console.warn('[ServiceWorker] Pre-cache skip for:', url, err);
          }
        })
      );
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
// 1. Navigation, App Logic, Fonts & Manifests (HTML, JS, WASM, JSON, BIN, OTF, TTF, WOFF) -> Network-First (always fresh, cache fallback when offline)
// 2. Static Media (Images, Favicons) -> Stale-While-Revalidate
self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;

  const url = new URL(event.request.url);

  // Strictly only intercept same-origin requests to never interfere with Firebase, Google APIs, Firestore, or external CDNs
  if (url.origin !== self.location.origin) return;

  const isNavigation = event.request.mode === 'navigate';
  const isCodeOrFontAsset = url.pathname.endsWith('.js') || 
                            url.pathname.endsWith('.mjs') ||
                            url.pathname.endsWith('.html') || 
                            url.pathname.endsWith('.wasm') ||
                            url.pathname.endsWith('.json') ||
                            url.pathname.endsWith('.bin') ||
                            url.pathname.endsWith('.otf') ||
                            url.pathname.endsWith('.ttf') ||
                            url.pathname.endsWith('.woff') ||
                            url.pathname.endsWith('.woff2');

  if (isNavigation || isCodeOrFontAsset) {
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
        .catch(async () => {
          // Offline fallback
          const cachedResponse = await caches.match(event.request);
          if (cachedResponse) return cachedResponse;
          if (isNavigation) {
            const indexResponse = await caches.match('index.html');
            if (indexResponse) return indexResponse;
          }
          return new Response('Network error occurred', { status: 503, statusText: 'Service Unavailable' });
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
      }).catch((err) => {
        console.warn('[ServiceWorker] Fetch failed for:', event.request.url, err);
        return cachedResponse || new Response('', { status: 404, statusText: 'Not Found' });
      });

      return cachedResponse || fetchPromise;
    })
  );
});
