# install-nixos

[NixOS](https://nixos.org) is not very fun to install - you have to run [a lot of commands](https://nixos.org/nixos/manual/index.html#sec-installation-partitioning), which take time to type, and is prone to typos or accidentally skipping some commands. But more importantly, it's not friendly to NixOS noobs!

The goal of this script is to make installing NixOS easier, quicker, and less error-prone. It does *not* accomodate all use-cases, but I will happily accept pull requests to accomodate other use-cases.

## Features

- Let's you choose which device to install to and [swap size](https://web.mit.edu/rhel-doc/5/RHEL-5-manual/Deployment_Guide-en-US/ch-swapspace.html) easily
- Runs all the steps the NixOS manual asks you to run to install NixOS
- Allows you to choose how much [swap space](https://web.mit.edu/rhel-doc/5/RHEL-5-manual/Deployment_Guide-en-US/ch-swapspace.html) you want
- Type a git URL and clone it to `/etc/nixos` - this is useful if you already have a NixOS configuration, like [mine](https://github.com/jamescostian/.config)
  - If the repo contains a `setup.sh` or `setup` file, you can optionally run it just before rebooting. An environment variable (`RUNNING_FROM_NIXOS_INSTALLER`) will be set while your setup script is run, and at the time it's run, it will be in `/mnt/etc/nixos` - any path you'd normally use will be prepended by `/mnt`, e.g. instead of using `/home/james` you should use `/mnt/home/james` when this script gets run.
- Small, per-machine niceties:
  - Moves `useDHCP` stuff from the generated `configuration.nix` to `hardware-configuration.nix` so `configuration.nix` can be checked into version control more easily; solves [this issue](https://github.com/NixOS/nixpkgs/issues/73595)
  - Pick a hostname that gets added to `hardware-configuration.nix` - this feature is optional.

The following are **NOT SUPPORTED** - you can send me a pull request if you'd like support for them:

- Legacy BIOS (almost all computers these days support a newer bios)
- Dual-boot, or even just allow existing data partitions to be untouched by the installer
- Full-disk encryption (see #1)

## Install

1. [Download the graphical NixOS installer](https://nixos.org/nixos/download.html)
2. [Copy it to a USB](https://nixos.org/nixos/download.html) - if that sounds hard, try using [etcher](https://www.balena.io/etcher/)
3. Boot from that USB and wait for it to show you the GUI
4. Connect to the internet
5. Open Konsole (the program)
6. Type `sudo sh -c <(curl -sSLf https://jami.am/nix)`
7. Press the ENTER key and follow the instructions!

The URL will redirect to [the installer script](install-nixos.sh) - you can type in the full URL if you don't trust me, or break it into a few more steps - `curl`, then `cat -e` to inspect the script, and finally execute it if you deem it safe.
