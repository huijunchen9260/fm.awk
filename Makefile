PREFIX		?=	/usr

CHAFA				:=	$(shell command -v chafa 2>/dev/null)
FFMPEGTHUMBNAILER	:=	$(shell command -v ffmpegthumbnailer 2>/dev/null)
PDFTOPPM			:=	$(shell command -v pdftoppm 2>/dev/null)
UEBERZUG			:=	$(shell command -v ueberzug 2>/dev/null)

ifdef $(UEBERZUG)
UEBERZUG_SUPPORT	?=	YES
else
UEBERZUG_SUPPORT	?=	NO
endif


all:
	@echo Run \'make install\' to install fm.awk.

dependencies:
	@echo "Checking optional dependencies..."
ifndef CHAFA
	@echo "chafa is missing! Install it to use it's preview images."
endif
ifndef FFMPEGTHUMBNAILER
	@echo "ffmpegthumbnailer is missing! Install it to preview videos."
endif
ifndef PDFTOPPM
	@echo "pdftoppm is missing! Install it to preview PDFs!"
endif
ifndef UEBERZUG
	@echo "ueberzug is missing! Install it to preview images."
endif

install:	dependencies
	@mkdir -p $(DESTDIR)$(PREFIX)/bin
	@cp -p fm.awk $(DESTDIR)$(PREFIX)/bin/fm.awk
	@chmod 755 $(DESTDIR)$(PREFIX)/bin/fm.awk
	@ln -sf $(DESTDIR)$(PREFIX)/bin/fm.awk $(DESTDIR)$(PREFIX)/bin/fmawk
ifeq ($(UEBERZUG_SUPPORT), YES)
	@cp -p fmawk-ueberzug $(DESTDIR)$(PREFIX)/bin/fmawk-ueberzug
	@chmod 755 $(DESTDIR)$(PREFIX)/bin/fmawk-ueberzug
endif

uninstall:
	@rm -rf $(DESTDIR)$(PREFIX)/bin/fm.awk
	@rm -rf $(DESTDIR)$(PREFIX)/bin/fmawk
ifeq ($(UEBERZUG_SUPPORT), YES)
	@rm -rf $(DESTDIR)$(PREFIX)/bin/fmawk-ueberzug
endif
