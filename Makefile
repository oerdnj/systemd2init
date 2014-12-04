NAME = systemd2init
BINDIR = /usr/bin
DATADIR = /usr/share/$(NAME)

all:

install: all
	install -d $(DESTDIR)$(BINDIR) $(DESTDIR)$(DATADIR)
	sed 's/skeleton\./\/usr\/share\/systemd2init\/skeleton./' $(NAME).sh > $(DESTDIR)/$(BINDIR)/$(NAME)
	chmod +x $(DESTDIR)$(BINDIR)/$(NAME)
	install -t $(DESTDIR)$(DATADIR) skeleton.*
