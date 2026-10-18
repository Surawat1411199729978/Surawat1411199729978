// Network-first for the app shell so updates show up right away; falls back to cache when offline.
// Firestore traffic goes to other origins and is not touched here (Firestore keeps its own offline cache).
const CACHE = 'team-tasks-v1'
const SHELL = ['./', 'index.html', 'main.js', 'styles.css', 'manifest.webmanifest', 'icon-192.png', 'apple-touch-icon.png']

self.addEventListener('install', (event) => {
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(SHELL)))
  self.skipWaiting()
})

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) => Promise.all(keys.filter((k) => k !== CACHE).map((k) => caches.delete(k))))
  )
  self.clients.claim()
})

self.addEventListener('fetch', (event) => {
  const url = new URL(event.request.url)
  if (event.request.method !== 'GET' || url.origin !== self.location.origin) return
  event.respondWith(
    fetch(event.request)
      .then((response) => {
        const copy = response.clone()
        caches.open(CACHE).then((cache) => cache.put(event.request, copy))
        return response
      })
      .catch(() => caches.match(event.request, { ignoreSearch: true }).then((r) => r || caches.match('index.html')))
  )
})
