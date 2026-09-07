{{flutter_js}}
{{flutter_build_config}}

// La versión viaja en la URL de `main.dart.js`, de modo que un despliegue
// nuevo estrena dirección y el navegador no puede servir el anterior desde la
// caché. Al revés: mientras la versión no cambie, sí puede servirlo, que es
// justo lo que se busca.
const corvusBuildVersion = '20260907-experiencia';
for (const build of _flutter.buildConfig.builds) {
  if (build.mainJsPath) {
    build.mainJsPath = `${build.mainJsPath}?v=${corvusBuildVersion}`;
  }
}

// La pantalla de arranque se retira cuando hay algo real detrás, no antes.
// `runApp()` resuelve una vez montado el árbol de la aplicación; esperar a ese
// momento evita el parpadeo de negro entre que desaparece la marca y aparece
// la primera pantalla.
function retirarPantallaDeArranque() {
  const boot = document.getElementById('corvus-boot');
  if (!boot) return;

  boot.classList.add('corvus-boot-done');
  // Se quita del árbol al terminar el fundido: dejarla puesta con opacidad
  // cero mantendría una capa a pantalla completa por encima de todo.
  boot.addEventListener('transitionend', () => boot.remove(), { once: true });
  // Y una red de seguridad, por si el navegador no emite `transitionend`
  // (ocurre con animaciones reducidas, donde no hay transición que terminar).
  setTimeout(() => boot.remove(), 900);
}

_flutter.loader.load({
  onEntrypointLoaded: async (engineInitializer) => {
    const appRunner = await engineInitializer.initializeEngine();
    await appRunner.runApp();
    retirarPantallaDeArranque();
  },
});
