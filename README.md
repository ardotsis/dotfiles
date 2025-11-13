# ar.sis's dotfiles

> [!WARNING]
> This project is still work in progress. So please do not expect to work. Thank you 🩷

_simple / minimal / suckless / secure / free / reproducible / efficient / unique / kawaii / menhera_

## Install

### `ardotsis@vultr`

```sh
curl -fsSL "dotfiles.menhera.art" | bash -s -- -h vultr
```

### `ardotsis@arch`

```sh
curl -fsSL "dotfiles.menhera.art" | bash -s -- -h arch
```

### `ardotsis@windows`

```batch
(Placeholder)
```

> [!NOTE]
> Original URL: ```https://raw.githubusercontent.com/ardotsis/dotfiles/refs/heads/main/install.sh```

## Shortcut Keys

### System

#### Windows

- (Placeholder)

#### Arch Linux

- (Placeholder)

### Applications

#### VSCode

- Toggle Github Copilot completions: `F1`

#### Neovim

- (Placeholder)

## ToDo

- [ ] Use a tools made by Rust.
  - zsh

- [ ] Backup dotfiles repository on another Git provider.
  - GitLab
  - Codeberg
  - Gitea

- [ ] Debian
  - Preseed

- [ ] dotfiles for Windows.
  - unattend.xml
    - <https://schneegans.de/windows/unattend-generator/>
  - winutil
  - Custom settings
  - Install Apps
  - komorebi
  - WindowsTerminal

- [ ] See this.
  - <https://github.com/ardotsis/dotfiles-old>

## Memo

### About VSCode

- Do not use VSCode with Japanese IME. Some keybindings may not work. (e.g., Focus on Terminal)
- VSCode settings might conflict between _User_ and _Workstation_. Backup and reset the _User_ configuration files.
  - `"C:\Users\<USER>\AppData\Roaming\Code\User\settings.json"`
  - `"C:\Users\<USER>\AppData\Roaming\Code\User\keybindings.json"`
