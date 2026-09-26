# Matrix Lock

Draws the [Matrix Rain](https://github.com/nzkritik/omarchy-matrix-rain) effect
on the [Omarchy](https://omarchy.org/) lock screen, and tells you when an
Omarchy update has left it out of date.

It follows your desktop: rain while the rain is your selected background, the
stock blurred still for any other wallpaper. Preview it without locking yourself
out with `omarchy-shell lock preview`.

## Install

```bash
omarchy-matrix-lock install
omarchy restart shell
```

```bash
omarchy-matrix-lock status      # what is installed, and what the lock will show
omarchy-matrix-lock sync        # after an Omarchy update, or after updating this plugin
omarchy-matrix-lock uninstall   # put the stock lock screen back
omarchy-matrix-lock check       # quiet; exit 0 current, 3 stale, 1 not installed
```

The rain is drawn by one GPU fragment shader, about 2% of a CPU core at
1920x1080 against roughly 25% for the text-item version before it. Without a
GPU scene graph, or if the shader cannot load, it falls back to that text-item
renderer on its own. `rain.frag.qsb` is `rain.frag` compiled for Qt 6, and
`tools/build-shaders.sh` rebuilds it byte for byte.

**Upgrading from 1.0:** run `omarchy-matrix-lock sync` (the plugin will remind
you), because the clone needs the new renderer files copied in.

The rain itself is self-contained — the `MatrixRain*.qml` files and the shader ship here
and are copied into the clone — so this works with or without the desktop wallpaper plugin
installed, and removing that plugin can never break your lock screen.

## What it does to your system

Omarchy's lock screen is a `WlSessionLock` surface, and a session lock covers
every layer-shell surface on the output — so a wallpaper overlay cannot show
through it, and the rain has to be drawn inside the lock screen's own QML. The
supported way to change a built-in plugin is `omarchy plugin clone`, so
`install` clones `omarchy.lock` to `<user>.lock` and patches the clone.

`LockView.qml` is regenerated from the lock screen **you have installed** each
time you run `install` or `sync`, rather than shipping a frozen copy, and every
patch anchor must match exactly once or the edit is refused rather than
half-applied. `Service.qml` — the whole password and fingerprint PAM flow — is
left exactly as cloned.

Two things to know before you install it:

- **The clone stops tracking upstream.** Your lock screen will not pick up fixes
  to `omarchy.lock`, security ones included, until you run `sync`. This is why
  the plugin ships a service at all: it records which stock `LockView.qml` the
  clone was generated from, and notifies you on the next shell start after that
  file changes. That is the notification you get after `omarchy update`.
- `uninstall` removes the clone outright only when nothing of yours would go
  with it — otherwise it restores `LockView.qml` and leaves your clone in place.

## Handling untrusted paths

The output of this script becomes a lock screen, so the paths it touches get
more care than a wallpaper would need.

- The stock `LockView.qml` is resolved from a fixed `/usr/share/omarchy`, never
  from `$OMARCHY_PATH` — the environment must not be able to redirect the file
  whose contents become your lock screen.
- The clone id comes from `id -un`, not `$USER`, and is validated as a single
  safe path component before it is used as a directory name.
- Every read of a user-writable path goes through one bounded, no-follow,
  non-blocking helper, so a symlink is refused, a planted FIFO returns instead
  of wedging the process, and a swollen file cannot be pulled in whole.
- Every write is staged in the destination directory, `fsync`ed, and committed
  with an atomic rename, after refusing any destination that is a symlink or
  not a regular file.

## Uninstall

```bash
omarchy-matrix-lock uninstall
omarchy plugin remove nzkritik.matrix-lock --yes
rm -rf ~/.local/state/omarchy-matrix-lock
```

Take the lock screen off *first*, while this plugin is still around to do it.
Removing the plugin without that leaves the clone behind with its own copy of
`MatrixRain.qml` — that still works, but `omarchy plugin remove <user>.lock` is
then the way to undo it.

## Licence

MIT
