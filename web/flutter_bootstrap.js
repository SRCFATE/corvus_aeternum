{{flutter_js}}
{{flutter_build_config}}

const corvusBuildVersion = '20260822-private-author-forums';
for (const build of _flutter.buildConfig.builds) {
  if (build.mainJsPath) {
    build.mainJsPath = `${build.mainJsPath}?v=${corvusBuildVersion}`;
  }
}

_flutter.loader.load();
