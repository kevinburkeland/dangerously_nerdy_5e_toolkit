// DangerouslyNerdy 5e Toolkit - PWA Service Worker Cache Shield
// Enforces an immutable cache-first strategy for app shell assets
// while strictly excluding API and websocket streams to preserve IndexedDB authority.

const BUILD_VERSION = 'BUILD_TIMESTAMP_PLACEHOLDER';
const CACHE_NAME = '5e-toolkit-shield-' + BUILD_VERSION;

const APP_SHELL_ASSETS = [
  './',
  'index.html',
  'flutter.js',
  'main.dart.js',
  'manifest.json',
  'favicon.png',
  'assets/FontManifest.json',
  'assets/AssetManifest.bin.json',
  'assets/fonts/MaterialIcons-Regular.otf',
  'pwa_icons/Icon-192.png',
  'pwa_icons/Icon-512.png',
  'pwa_icons/Icon-maskable-192.png',
  'pwa_icons/Icon-maskable-512.png',
];

// Install Event: Pre-cache essential app shell assets and activate immediately
self.addEventListener('install', (event) => {
  self.skipWaiting();
  event.waitUntil(
    caches.open(CACHE_NAME).then(async (cache) => {
      await Promise.allSettled(
        APP_SHELL_ASSETS.map(async (url) => {
          try {
            const response = await fetch(url);
            if (response && response.ok) {
              await cache.put(url, response);
            }
          } catch (err) {
            console.warn('[ServiceWorker Shield] Pre-cache bypass:', url, err);
          }
        })
      );
    })
  );
});

// Activate Event: Purge stale caches and claim clients immediately
self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((cacheNames) => {
      return Promise.all(
        cacheNames.map((cache) => {
          if (cache !== CACHE_NAME) {
            console.log('[ServiceWorker Shield] Evicting legacy cache:', cache);
            return caches.delete(cache);
          }
        })
      );
    }).then(() => self.clients.claim())
  );
});

self.addEventListener('message', (event) => {
  if (event.data && event.data.type === 'SKIP_WAITING') {
    self.skipWaiting();
  }
});

self.addEventListener('fetch', (event) => {
  if (event.request.method !== 'GET') return;

  const url = new URL(event.request.url);

  // 1. Explicitly exclude external domains, APIs, and dynamic socket endpoints
  // Preserves IndexedDB as the singular offline authority
  if (url.origin !== self.location.origin) return;
  if (url.pathname.startsWith('/api/') ||
      url.pathname.includes('/ws') ||
      url.pathname.includes('/socket') ||
      url.protocol === 'ws:' ||
      url.protocol === 'wss:') {
    return;
  }

  // 2. Identify App Shell assets (index.html, flutter.js, main.dart.js, canvaskit/*, wasm binaries)
  const isAppShell = url.pathname.endsWith('index.html') ||
                     url.pathname === '/' ||
                     url.pathname.endsWith('flutter.js') ||
                     url.pathname.endsWith('main.dart.js') ||
                     url.pathname.includes('canvaskit') ||
                     url.pathname.endsWith('.wasm');

  if (isAppShell) {
    // Immutable Cache-First Strategy for app shell
    event.respondWith(
      caches.match(event.request).then((cachedResponse) => {
        if (cachedResponse) {
          return cachedResponse;
        }
        return fetch(event.request).then((networkResponse) => {
          if (networkResponse && networkResponse.status === 200) {
            const responseClone = networkResponse.clone();
            caches.open(CACHE_NAME).then((cache) => cache.put(event.request, responseClone));
          }
          return networkResponse;
        }).catch(async () => {
          if (event.request.mode === 'navigate') {
            const fallback = await caches.match('index.html');
            if (fallback) return fallback;
          }
          return new Response('App shell offline unavailable', {
            status: 503,
            statusText: 'Service Unavailable',
          });
        });
      })
    );
    return;
  }

  // 3. Stale-While-Revalidate for other static assets (fonts, icons, media)
  event.respondWith(
    caches.match(event.request).then((cachedResponse) => {
      const fetchPromise = fetch(event.request).then((networkResponse) => {
        if (networkResponse && networkResponse.status === 200) {
          const responseClone = networkResponse.clone();
          caches.open(CACHE_NAME).then((cache) => cache.put(event.request, responseClone));
        }
        return networkResponse;
      }).catch(() => cachedResponse || new Response('', { status: 404, statusText: 'Not Found' }));

      return cachedResponse || fetchPromise;
    })
  );
});
