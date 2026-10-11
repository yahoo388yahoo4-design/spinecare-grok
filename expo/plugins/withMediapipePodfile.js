const { withPodfile } = require('@expo/config-plugins');

module.exports = function withMediapipePodfile(config) {
  return withPodfile(config, (mod) => {
    const marker = 'prepare_react_native_project!';
    const frameworkLine = 'use_frameworks! :linkage => :static';
    if (!mod.modResults.contents.includes(frameworkLine)) {
      if (mod.modResults.contents.includes(marker)) {
        mod.modResults.contents = mod.modResults.contents.replace(
          marker,
          marker + '\n\n' + frameworkLine
        );
      } else {
        throw new Error('Could not configure static frameworks for MediaPipe. Review the generated iOS Podfile.');
      }
    }
    return mod;
  });
};
