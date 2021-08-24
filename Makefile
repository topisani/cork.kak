install:
	install -d ~/.local/bin
	install cork.sh ~/.local/bin/cork
	chmod +x ~/.local/bin/cork
	
uninstall:
	rm -Rf ~/.local/bin/cork

