# ZLIB
ZLIB_VERSION := 1.2.8
ZLIB_URL := http://zlib.net/fossils/zlib-$(ZLIB_VERSION).tar.gz


ifeq ($(shell uname),Darwin) # zlib tries to use libtool on Darwin
ifdef HAVE_CROSS_COMPILE
ZLIB_CONFIG_VARS=CHOST=$(HOST)
endif
endif

ifdef HAVE_TIZEN
EX_ECFLAGS = -fPIC
endif

ifdef HAVE_LINUX
EX_ECFLAGS = -fPIC
endif

ifdef HAVE_WIN32
extra_makefile=-fwin32/Makefile.gcc
endif

$(TARBALLS)/zlib-$(ZLIB_VERSION).tar.gz:
	$(call download,$(ZLIB_URL))

.sum-zlib: zlib-$(ZLIB_VERSION).tar.gz

zlib: zlib-$(ZLIB_VERSION).tar.gz .sum-zlib
	$(UNPACK)
	$(MOVE)

.zlib: zlib
ifndef HAVE_WIN32
	cd $< && $(HOSTVARS) $(ZLIB_CONFIG_VARS) CFLAGS="$(CFLAGS) $(EX_ECFLAGS)" ./configure --prefix=$(PREFIX) --static
	cd $< && $(MAKE) install
endif
ifdef HAVE_WIN64
	cd $< && make -fwin32/Makefile.gcc PREFIX=x86_64-w64-mingw32- BINARY_PATH=$(PREFIX)/bin INCLUDE_PATH=$(PREFIX)/include LIBRARY_PATH=$(PREFIX)/lib install
else ifdef HAVE_WIN32
	cd $< && make -fwin32/Makefile.gcc PREFIX=i686-w64-mingw32- BINARY_PATH=$(PREFIX)/bin INCLUDE_PATH=$(PREFIX)/include LIBRARY_PATH=$(PREFIX)/lib install
endif
	touch $@
