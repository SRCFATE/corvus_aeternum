{{flutter_js}}
{{flutter_build_config}}

// Esta URL nueva saca a quienes todavía conserven el paquete inmutable de la
// versión anterior. A partir de aquí `main.dart.js` se revalida con el origen,
// por lo que los siguientes despliegues ya no dependen de cambiar esta clave.
const corvusBuildVersion = '20260907-atelier-v4';
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
