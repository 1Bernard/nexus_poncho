/**
 * Minimal Service Worker for Nexus Poncho
 * Used to satisfy PWA requirements and stop 404 errors in logs.
 */

const CACHE_NAME = 'nexus-v1';

self.addEventListener('install', (event) => {
  self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(clients.claim());
});

self.addEventListener('fetch', (event) => {
  // Pass-through
  event.respondWith(fetch(event.request));
});
