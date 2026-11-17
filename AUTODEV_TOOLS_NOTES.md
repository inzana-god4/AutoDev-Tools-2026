# AutoDev Tools 2015 reconstruction notes

Static inspection only. The original executable was not run.

## Source artifact

- Main executable: `C:\Program Files (x86)\RBF Studio Inc\AutoDev Tools 2015\AutoDevTools2015.exe`
- Product: AutoDev Tools 2015
- File/Product version: 8.0.3.2
- Description: A complete tool for Android modification and management.
- SHA256: `D3CB2DE0BFFF6D56F48A302E9AB1288422050DDE3D18C95CC3614A2A1DD9E487`
- Digital signature: not signed
- Command-line helper: `adt2.exe`
- `adt2.exe` version: 2.0.1.3
- `adt2.exe` description: Commandline for AutoDev Tools 2015

## Bundled toolchain

The installed folder includes a small Android modding/kitchen toolchain:

- `adb.exe`
- `fastboot.exe`
- `apktool.jar`
- `aapt.exe`
- `signapk.jar`
- `zipalign.exe`
- `abe.jar`
- `screenshot.jar`
- `7z.exe`
- `make_ext4fs.exe`
- `sdat2img.exe`
- `rimg2sdat.exe`
- `Imgextractor.exe`
- `dos2unix.exe`
- `md5.exe`
- `AdbFileExplorer.exe`
- `MotorolaBootLogoMaker.exe`
- Java 8 installers
- Java Cryptography Extension files
- bundled helper APKs: DroidCam, FolderMount, Framaroot, KingRoot, OI File Manager, Sixaxis Compatibility Checker

## Original command sections

The helper executable contains an embedded batch-like command router:

```text
adt2.exe [section] [command] [parameters]
```

Sections:

- `apk`
- `device`
- `files`
- `rom`
- `functions`
- `apps`
- `RBF_DEBUG`

## APK features

Original commands:

- `apk framework`
- `apk decompile`
- `apk recompile`
- `apk sign`
- `apk install`
- `apk uninstall`
- `apk unpack`
- `apk repack`
- `apk zipalign`

Modern equivalent:

- Import APK/AAB/APKS.
- Show manifest, app label, package id, min/target SDK, permissions, activities, services, receivers, providers.
- Decode resources through current `apktool`.
- Optional Java/Kotlin view through `jadx`.
- Edit common resources: `strings.xml`, app name, colors, drawables, icons, assets.
- Rebuild through `apktool`.
- Align with current `zipalign`.
- Sign with current `apksigner`.
- Install with modern platform-tools.

## Device features

Original commands:

- `device check`
- `device list`
- `device reboot`
- `device recovery`
- `device bootloader`
- `device terminal`
- `device filemanager`
- `device screenshot`
- `device connect`
- `device disconnect`
- `device bootloader_code`
- `device bootloader_unlock`
- `device bootloader_lock`
- `device flash`
- `device erase`
- `device reboot_bootloader`
- `device bypass_lockscreen`

Modern equivalent:

- ADB device list with state, model, Android version, SDK, ABI, battery.
- Reboot controls: system, recovery, bootloader.
- ADB shell terminal.
- Logcat viewer with filters.
- Screenshot and screen recording.
- Wireless ADB pairing/connect/disconnect.
- Fastboot commands behind explicit confirmations.

Avoid reviving:

- `bypass_lockscreen`: this removes lockscreen database files on rooted devices. It should not be included.
- One-click bootloader unlock/lock by arbitrary code unless clearly scoped to official documented flows and strong warnings.
- Fastboot erase/flash should require high-friction confirmations.

## File features

Original commands:

- `files md5`
- `files backup`
- `files restore`
- `files backup_extract`
- `files backup_repack`
- `files backup_repack_kk`
- `files sync_documents`
- `files sync_movies`
- `files sync_musics`
- `files sync_pictures`

Modern equivalent:

- Hash panel: MD5/SHA1/SHA256.
- Pull/push common folders.
- File browser for `/sdcard`.
- Backup/restore should be updated carefully because `adb backup` is deprecated and limited on modern Android.
- App data backup should prefer run-as/debuggable app workflows or documented device-owner/developer workflows.

## ROM features

Original commands:

- `rom add_apk`
- `rom remove_apk`
- `rom list`
- `rom chframework`
- `rom chbootanimation`
- `rom buildprop`
- `rom updaterscript`
- `rom makezip`
- `rom unpack_lollipop`
- `rom repack_lollipop`

Modern equivalent:

- ROM workspace import.
- List system/product/vendor apps.
- Add/remove APKs from a ROM workspace.
- Edit `build.prop` and updater scripts with validation.
- Change bootanimation.
- Build flashable ZIP.
- Unpack/repack sparse images and `system.new.dat.br` style payloads.
- Add support for modern payload formats where feasible.

## Extra bundled apps/functions

Original commands opened installers or installed helper APKs:

- ADB installer
- Metapad
- Moto Boot Logo Maker
- DroidCam
- Sixaxis Pair Tool
- Java installer
- JCE installer
- OI File Manager
- KingRoot
- Framaroot
- FolderMount

Modern approach:

- Do not bundle root exploit APKs such as KingRoot/Framaroot.
- Do not bundle old Java installers.
- Use current Android platform-tools.
- Detect missing dependencies and offer official download links or embedded open-source binaries where license permits.
- Keep third-party app installation out of the core product unless it is explicitly user-provided.

## Suggested product shape

Name ideas:

- AutoDev Tools 2026
- AutoDev Tools NG
- AutoDev 2026
- ReAutoDev

Recommended architecture:

- Desktop app: Tauri + React + TypeScript, or .NET 8 + Avalonia.
- Tool runner service: strict command wrappers with typed parameters.
- Workspace model: one project folder per APK/ROM.
- Task log: every command captured with stdout/stderr and generated outputs.
- Dependency manager: detect/install/update platform-tools, apktool, jadx, bundletool, apksigner.

## MVP roadmap

Phase 1:

- Project shell with dashboard.
- Dependency detection.
- APK import.
- Manifest/info viewer.
- APK decompile/rebuild/sign/zipalign/install.
- ADB device list and install/reboot/shell/logcat.

Phase 2:

- Resource editor for labels, strings, colors, icons.
- Global search in decoded APK.
- `jadx` source viewer.
- Diff view between original and modified project.
- Build history and rollback.

Phase 3:

- ROM workspace.
- Bootanimation editor.
- `build.prop` editor.
- Flashable ZIP builder.
- Sparse image / dat unpack-repack workflows.

Phase 4:

- Plugin system for custom actions.
- Themes including a 2015 nostalgia skin.
- Portable mode.
- Project templates.

