# Building Mavis AAC

## MavisCorrector.plugin

The `MavisCorrector.plugin` is managed in a [separate repo](https://github.com/msolo/mavis-corrector/) as it has no shared dependencies with the rest of the application.

Normally this repo is checked out into `./mavis-corrector`.

The plugin must be compiled first:
```
(cd mavis-corrector && ./build-release.sh)
```

## Mavis AAC.app

Once the plugin is compiled and copied, the `build-release.sh` script is all that is needed.

```
./build-release.sh
```

This compiles a clean copy of the application and archives it as a DMG file, ready for distribution.

```
ls -lh Build/Products/Release/
```

# Signing and Notarizing

This process was not easy to uncover.

Each one of these had some valuable nuggets:
 * https://dev.to/kopiro/how-to-correctly-publish-your-mac-apps-outside-of-the-app-store-38a
 * https://haim.dev/posts/2020-08-08-python-macos-app/
 * https://hsanchezii.wordpress.com/2021/10/06/code-signing-python-py2app-applications/

 Ultimately, much of the difficulty came from what is apparently XCode corrupting the MavisCorrector.plugin, which made the XCode Archive workflow fail right off the bat.
