# VaultBoard 🔒

**An offline-first, local-only Kanban board for the desktop.**

VaultBoard is a modern task board inspired by Trello, built with one rule: your
tasks never leave your machine. No account, no cloud, no network access —
everything is stored locally and persists across restarts.

Built with Flutter (Material 3, dark theme) for **Linux** and **Windows**.

## Features

- **Multiple boards** with a collapsible sidebar — create, switch, rename,
  delete, each with its own accent color.
- **Unlimited lists per board** — rename, delete, clear completed cards, and
  reorder by dragging the list header or via the *Move left / Move right* menu.
- **Rich cards** — title, description, creation date, color-coded priority
  (High / Medium / Low) and a completion toggle.
- **Full drag-and-drop** — move cards between lists or reorder within a list,
  with live insertion indicators.
- **Instant local search** — filter cards across the whole board as you type;
  non-matching cards dim so drag-and-drop keeps working mid-search.
- **Live stats** — a completion meter in the board header shows done/total and
  percentage at a glance.

## Install

Prebuilt packages are attached to every [GitHub release](../../releases).

### Debian / Ubuntu / Mint

```bash
sudo apt install ./vaultboard_<version>_amd64.deb
```

### Fedora / RHEL / openSUSE

```bash
sudo dnf install ./vaultboard-<version>-1.x86_64.rpm
```

### Arch / Manjaro / EndeavourOS

```bash
sudo pacman -U ./vaultboard-<version>-1-x86_64.pkg.tar.zst
```

Or build from source with the provided PKGBUILD:

```bash
cd packaging/arch
makepkg -si
```

### Portable Linux (any distro)

```bash
tar -xzf vaultboard-<version>-linux-x86_64.tar.gz -C ~/apps/vaultboard
~/apps/vaultboard/vaultboard
```

All Linux packages install the app to `/usr/lib/vaultboard`, a `vaultboard`
launcher in `/usr/bin`, and desktop integration (`.desktop` entry, icon and
AppStream metadata) so VaultBoard shows up in your application menu.

### Windows

Download `vaultboard-<version>-windows-x64.zip` from the releases page,
extract it anywhere and run `vaultboard.exe`.

## Where is my data?

Everything lives in a single local Hive database:

- **Linux:** `~/Documents/VaultBoard/`
- **Windows:** `%USERPROFILE%\Documents\VaultBoard\`

Back up that folder and you have backed up all your boards.

## Development

Requires the [Flutter SDK](https://docs.flutter.dev/get-started/install)
(stable channel) with desktop support enabled.

```bash
flutter pub get
flutter run -d linux      # or -d windows
flutter analyze
flutter test
```

### Building distro packages locally

The packaging script produces `.deb`, `.rpm`, pacman `.pkg.tar.zst` and a
portable tarball in `dist/`:

```bash
# one-time: gem install fpm   (plus `rpm` for the .rpm target)
bash packaging/linux/build_packages.sh
```

### Project layout

```
lib/
├── main.dart              # Entry point, Hive init, app shell
├── theme.dart             # Dark "vault" theme + desktop scroll behavior
├── models/models.dart     # Board / KanbanList / KanbanCard (+ JSON)
├── data/storage.dart      # Hive persistence layer
├── providers/providers.dart  # Riverpod state (boards, selection, search, stats)
├── screens/home_screen.dart  # Sidebar + canvas layout
└── widgets/               # Sidebar, board canvas, columns, cards, dialogs
packaging/
├── linux/                 # .desktop, icon, metainfo, build_packages.sh
└── arch/PKGBUILD          # Source build for Arch Linux
.github/workflows/
├── ci.yml                 # Dev branches & PRs: analyze, test, build artifacts
└── release.yml            # main: build all packages, publish GitHub release
```

## CI / CD

- **`CI`** runs on every push to any branch except `main` (and on PRs to
  `main`): analyze + tests, then uploads Linux and Windows dev bundles as
  workflow artifacts.
- **`Release`** runs on every push to `main`: builds the `.deb`, `.rpm`,
  pacman package, portable tarball and Windows zip, then publishes a GitHub
  release tagged `v<version>` from `pubspec.yaml`. Bump `version:` in
  `pubspec.yaml` before merging to main for a clean tag; pushing `main` again
  without a bump releases under `v<version>-build.<run>` so every push still
  gets its own release.

## License

[MIT](LICENSE)
