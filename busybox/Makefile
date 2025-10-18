# Variabili
BUSYBOX_VERSION := 1.36.1
BUILD_DIR := $(PWD)/build/busybox-musl
SRC_DIR := $(BUILD_DIR)/busybox-$(BUSYBOX_VERSION)
INSTALL_DIR := $(BUILD_DIR)/install
ARCHIVE := busybox-$(BUSYBOX_VERSION).tar.bz2
URL := https://busybox.net/downloads/$(ARCHIVE)

# Imposta musl-gcc come compilatore
CC := gcc

.PHONY: all clean distclean download extract configure build install help

all: help

help:
	@echo "Target disponibili:"
	@echo "  make download   - Scarica i sorgenti di BusyBox"
	@echo "  make extract    - Estrai l'archivio"
	@echo "  make configure  - Configura la build statica con musl"
	@echo "  make build      - Compila BusyBox con musl-gcc"
	@echo "  make install    - Installa in $(INSTALL_DIR)"
	@echo "  make clean      - Rimuove tutto"

download:
	mkdir -p $(BUILD_DIR)
	cd $(BUILD_DIR) && wget -nc $(URL)

extract: $(BUILD_DIR)/$(ARCHIVE)
	cd $(BUILD_DIR) && tar -xf $(ARCHIVE)

$(SRC_DIR)/.config configure: $(SRC_DIR)
	cd $(SRC_DIR) && make defconfig
	sed -i 's/^# CONFIG_STATIC is not set/CONFIG_STATIC=y/' $(SRC_DIR)/.config
	
$(SRC_DIR)/busybox build: $(SRC_DIR)/.config
	$(MAKE) -C $(SRC_DIR) CC=$(CC) -j$$(nproc)

install: $(SRC_DIR)/busybox
	$(MAKE) -C $(SRC_DIR) CONFIG_PREFIX=$(INSTALL_DIR) install
	@echo "[+] Installazione completata in $(INSTALL_DIR)"
	@$(INSTALL_DIR)/bin/busybox --help

distclean:
	rm -rf $(BUILD_DIR)

	

$(BUILD_DIR)/$(ARCHIVE): download
