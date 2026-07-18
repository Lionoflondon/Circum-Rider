{{flutter_js}}
{{flutter_build_config}}

window.CIRCUM_RIDER_BUILD = 'rider-web-cache-v2';

function showRiderBootstrapError() {
  const loading = document.getElementById('startup-loading');
  const error = document.getElementById('startup-error');
  if (loading) loading.style.display = 'none';
  if (error) error.style.display = 'block';
}

_flutter.loader.load({
    serviceWorkerSettings: null,
    onEntrypointLoaded: async (engineInitializer) => {
      try {
        const appRunner = await engineInitializer.initializeEngine();
        await appRunner.runApp();
      } catch (error) {
        console.error('Rider startup failed.', error);
        showRiderBootstrapError();
      }
    },
  });
