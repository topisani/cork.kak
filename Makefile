install:
	install -d ~/.local/bin
	install -m 0755 cork.sh ~/.local/bin/cork

uninstall:
	rm -Rf ~/.local/bin/cork

