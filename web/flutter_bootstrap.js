{{flutter_js}}
{{flutter_build_config}}

window.CIRCUM_RIDER_BUILD = 'rider-web-cache-v1';

async function clearLegacyRiderWebCaches() {
  if ('serviceWorker' in navigator) {
    const registrations = await navigator.serviceWorker.getRegistrations();
    await Promise.all(registrations.map((registration) => registration.unregister()));
  }

  if ('caches' in window) {
    const cacheNames = await caches.keys();
    await Promise.all(cacheNames.map((cacheName) => caches.delete(cacheName)));
  }
}

clearLegacyRiderWebCaches()
  .catch((error) => console.warn('Rider web cache cleanup failed.', error))
  .then(() => _flutter.loader.load({
    serviceWorkerSettings: null,
    onEntrypointLoaded: async (engineInitializer) => {
      const appRunner = await engineInitializer.initializeEngine();
      await appRunner.runApp();
      removeSplashFromWeb();
    },
  }));
