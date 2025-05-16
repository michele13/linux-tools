# QEMU Build Instructions

## Dependencies

### Debian

    libpixman-1-dev libglib2.0-dev pkg-config mesa ninja-build sphinx sphinx-rtd-theme-common libgtk3.0-cil-dev

## Build Instructions

Configure the package

    ../qemu-9.2.3/configure --prefix=/opt/qemu-9.2.3/ \
      --target-list=arm-softmmu,aarch64-softmmu,x86_64-softmmu,riscv64-softmmu \
      --enable-slirp

Build and install

    make && make install
