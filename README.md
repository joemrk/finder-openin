# Finder Open In

A macOS app that adds "Open in <IDE>" items to the Finder context menu. Each
item is a command from a JSON config that receives the path of the selected
item or of the current folder.

<img width="321" height="562" alt="image" src="https://github.com/user-attachments/assets/f3b98923-0eda-46cd-a299-6c3a5d4fe83a" />


## Features

- **Finder menu** for a selected file or folder and for the folder background.
  One selected item → its path; several or none → the window's current folder,
  one launch.
- **JSON command config**, picked up without rebuilding or restarting.
- **Command launch** through `/bin/zsh -lc 'exec "$@"'`: the path is passed as a
  separate argument, so spaces, quotes, `$` and non-ASCII characters work
  without escaping.
- **Failure window** (centered, OK button) when the command is not found, exits
  with an error, the path is gone or the config is broken.
- **Menu-bar icon**: config status, Open Config, Extension Settings…, Quit.
- **Logging** through `os.Logger`.
- **49 unit tests** (`make test`), including real `zsh` launches.

## How it works

```
Finder ──right-click──▶ FinderExtension (sandboxed)
                          │  reads commands.json from the App Group container
                          │  click → opens finderopenin://run?id=…&path=…
                          ▼
                       FinderOpenIn.app (not sandboxed, menu-bar agent)
                          │  looks the command up by id in the config, substitutes {path}
                          ▼
                       /bin/zsh -lc 'exec "$@"' zsh <argv…>
```

The sandboxed extension cannot spawn processes, so it only passes the command
id and the path. The app accepts nothing but the id - the command template
always comes from the config. The app starts by itself on the first menu click
(through the URL scheme).

| Folder             | Contents                                                                                                                  |
| ------------------ | ------------------------------------------------------------------------------------------------------------------------- |
| `Shared/`          | Config model and loading, `{path}` substitution, URL request, loggers. Compiled into the app, the extension and the tests |
| `FinderExtension/` | `FinderSync.swift` - the menu and sending the URL                                                                         |
| `App/`             | `AppDelegate` (URL handler), `CommandRunner` (launch and error texts), `FailureAlert`, `StatusMenu`, `DefaultConfig`      |
| `Tests/`           | Unit tests for `Shared/` and `CommandRunner`                                                                              |
| `project.yml`      | XcodeGen project description; `.xcodeproj`, `Info.plist` and `.entitlements` are generated from it                        |

## Config

`~/Library/Group Containers/<TeamID>.io.github.joemrk.FinderOpenIn/commands.json`
(or menu bar → Open Config):

```json
[
  { "title": "Antigravity", "cmd": ["antigravity-ide", "{path}"] },
  { "title": "VS Code", "cmd": ["code", "{path}"] },
  { "title": "Zed", "cmd": ["zed", "{path}"] }
]
```

- `title` — the name in the menu ("Open in <title>") and also the command id;
  must be unique.
- `cmd` - argv. `{path}` is replaced with the path inside any token
  (`"--dir={path}"` works too). The command is looked up in the `PATH` of a zsh
  login shell (`.zshenv`, `.zprofile`; `.zshrc` is not read).

## Build and install

Requires macOS 15+, Xcode and XcodeGen (`brew install xcodegen`).

| Command        | Action                                                       |
| -------------- | ------------------------------------------------------------ |
| `make build`   | Generate the project and build                               |
| `make test`    | Run the tests                                                |
| `make install` | Build, copy to `/Applications`, enable the extension, launch |
| `make log`     | Stream the logs of the app and the extension                 |

Logs directly:

```
log stream --level debug --predicate 'subsystem == "io.github.joemrk.FinderOpenIn"'
```

### Signing with your own team

The project is signed manually with an "Apple Development" certificate and no
provisioning profile; a free Personal Team is enough. The Team ID
`78K254QW6P` is hard-coded, so replace it with your own in:

- `project.yml` - `DEVELOPMENT_TEAM` and both `application-groups` entries;
- `Shared/ConfigLocation.swift` - `appGroupID`.

## Development notes

- **`make install` kills the extension processes at the end.** Every
  registration or enable through `pluginkit` adds one more extension instance
  to Finder while the old ones stay, so menu items get duplicated. Do not
  remove this step.
- **The App Group is prefixed with the Team ID** (`<TeamID>.…`), not `group.` —
  this way it works without a provisioning profile. Changing the Team ID also
  changes the config path.
- **Finder does not pass `NSMenuItem.representedObject`** - the command is
  identified by `tag` (the index in the config snapshot taken when the menu was
  built).
- **A trailing comma in the JSON array is not an error** - `JSONDecoder`
  accepts it.

## Known limitations

- In iCloud Drive and other File Provider storage folders Finder does not show
  Finder Sync extension items.
- The menu-bar icon appears only after the app has started (the first click in
  the Finder menu or a manual launch).
- The first command run in `~/Desktop`, `~/Documents` or `~/Downloads` triggers
  the system folder-access prompt.

## TODO

- [ ] Launch at login
