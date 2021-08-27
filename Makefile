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
	@echo "Run \"make install\" to install fm.awk."

dependencies:
	@echo "Checking optional dependencies..."
ifndef CHAFA
	@echo "chafa is missing! Install it to preview images."
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
	@install fm.awk $(DESTDIR)$(PREFIX)/bin
	@ln -sf fm.awk $(DESTDIR)$(PREFIX)/bin/fmawk
ifeq ($(UEBERZUG_SUPPORT), YES)
	@install fmawk-ueberzug $(DESTDIR)$(PREFIX)/bin
endif

uninstall:
	@rm -rf $(DESTDIR)$(PREFIX)/bin/fm.awk
	@rm -rf $(DESTDIR)$(PREFIX)/bin/fmawk
ifeq ($(UEBERZUG_SUPPORT), YES)
	@rm -rf $(DESTDIR)$(PREFIX)/bin/fmawk-ueberzug
endif
