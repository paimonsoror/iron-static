# export/

Nothing in this folder is committed except this file. Release signing material must never enter git
(`*.keystore` and `*.jks` are ignored; `export_presets.cfg` must hold no passwords).

## Debug builds

Debug APKs are signed with the Godot-generated debug keystore (`%APPDATA%\Godot\keystores\debug.keystore`,
alias `androiddebugkey`, password `android`), configured in the editor settings. Nothing to do.

## Creating a release keystore (before the first Play upload, M7)

1. Use JDK 17 `keytool`, store the result **outside the repo**, for example `C:\dev\secrets\ironstatic-release.keystore`:

   ```powershell
   & C:\dev\tools\jdk-17\bin\keytool.exe -genkeypair -v -keystore C:\dev\secrets\ironstatic-release.keystore `
     -alias ironstatic -keyalg RSA -keysize 2048 -validity 10000
   ```

2. Back it up in at least two places (password manager plus offline copy). Losing it means losing the ability to
   update the app unless Play App Signing is enrolled; with Play App Signing this is the upload key, which Google can reset.
3. Give Godot the keystore without writing it into `export_presets.cfg`: use the environment variables
   `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`, `GODOT_ANDROID_KEYSTORE_RELEASE_USER`,
   `GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD` when exporting a release build headlessly.
4. Never commit the keystore, its password, or an export preset that contains them.
