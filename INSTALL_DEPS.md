# Installing Build Dependencies

## For WSL/Ubuntu/Debian

The build requires `pkg-config` and OpenSSL development libraries:

```bash
sudo apt-get update
sudo apt-get install -y pkg-config libssl-dev cmake build-essential
```

## For Other Systems

### Fedora/RHEL/CentOS
```bash
sudo dnf install pkgconfig openssl-devel cmake gcc
```

### Arch Linux
```bash
sudo pacman -S pkg-config openssl cmake base-devel
```

### macOS
```bash
brew install pkg-config openssl cmake
```

## Verify Installation

After installing, verify the tools are available:

```bash
pkg-config --version
cmake --version
openssl version
```

## Build

Once dependencies are installed, you can build:

```bash
cargo build
# or
cargo run -p slipstream-server -- --help
```
