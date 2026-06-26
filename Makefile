# Two steps, on purpose:
#   make build     # builds the docker images — run as YOUR user (the one in the docker group)
#   make install   # symlinks `sandboxai` onto PATH — defaults to ~/.local/bin, so NO sudo needed
# System-wide instead:  sudo make install PREFIX=/usr/local
# Keep the clone in place: sandboxai resolves its own symlink to find base/ and proxy/.
PREFIX ?= $(HOME)/.local
BIN    := $(PREFIX)/bin/sandboxai

build:
	./setup.sh

install:
	@mkdir -p "$(PREFIX)/bin"
	ln -sf "$(CURDIR)/sandboxai" "$(BIN)"
	@echo "installed: $(BIN) -> $(CURDIR)/sandboxai"
	@command -v sandboxai >/dev/null 2>&1 || echo "warning: $(PREFIX)/bin is not on your PATH — add:  export PATH=\"$(PREFIX)/bin:\$$PATH\""
	@echo "if your shell still finds an old path, run 'hash -r' or open a new terminal"

uninstall:
	rm -f "$(BIN)"

.PHONY: build install uninstall
