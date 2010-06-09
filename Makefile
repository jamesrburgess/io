SYS ?= $(shell uname -s)


ifeq ($(SYS),Linux)
INSTALL_PREFIX ?= /usr
else
INSTALL_PREFIX ?= /usr/local
endif

NEEDS_DL := Darwin Linux SunOS syllable
ifneq (,$(findstring $(SYS),$(NEEDS_DL)))
LFLAGS +=-ldl
endif

NEEDS_M := FreeBSD Linux NetBSD DragonFly
ifneq (,$(findstring $(SYS),$(NEEDS_M)))
LFLAGS +=-lm
endif

#NEEDS_PTHREAD := FreeBSD Linux NetBSD
#ifneq (,$(findstring $(SYS),$(NEEDS_PTHREAD)))
#LFLAGS +=-lpthread
#endif

DLL_SUFFIX := so
DLL_COMMAND := -shared -Wl,-soname="libiovmall.so"
#DLL_COMMAND := -shared -Wl,-soname=${INSTALL_PREFIX}"/lib/libiovmall.so"
FLAT_NAMESPACE :=

LINKDLL := $(CC)
LINKDLLOUTFLAG := -o 
LINKDIRFLAG := -L
LINKLIBFLAG := -l
DLL_LIB_SUFFIX := 
DLL_LIB_PREFIX := lib
CCOUTFLAG := -o 
AROUTFLAG := 
RANLIB ?= ranlib
AR     ?= ar
ARFLAGS := rcu 

ifeq ($(SYS),Darwin)
DLL_SUFFIX := dylib
DLL_COMMAND := -dynamiclib
FLAT_NAMESPACE := -flat_namespace
endif

ifneq (,$(findstring CYGW,$(SYS)))
DLL_SUFFIX := dll
BINARY_SUFFIX := .exe
endif

ifneq (,$(findstring MINGW,$(SYS)))
DLL_SUFFIX := dll
BINARY_SUFFIX := .exe
endif

ifneq (,$(findstring Windows,$(SYS)))
CC := cl -nologo
DLL_LIB_PREFIX := lib
LINKDLL := link
LINKDLLOUTFLAG :=-out:
LINKLIBFLAG := lib
DLL_SUFFIX := dll
DLL_COMMAND := -dll -manifest -debug /INCREMENTAL:NO -subsystem:CONSOLE 
DLL_EXTRA_LIBS := ws2_32.lib shell32.lib
FLAT_NAMESPACE :=
AR := link -lib
ARFLAGS :=
AROUTFLAG := -out:
VMALL := vmall_
BINARY_SUFFIX := .exe
RANLIB := echo no ranlib
endif

###########################

date := $(shell date +'%Y-%m-%d')

#libs := $(shell ls libs)
libs := basekit coroutine garbagecollector iovm

all: addons

testaddon:
	./_build/binaries/io_static$(BINARY_SUFFIX) addons/$(addon)/tests/correctness/run.io

vm:
	$(MAKE) -C libs/basekit
	$(MAKE) -C libs/coroutine
	$(MAKE) -C libs/garbagecollector
	$(MAKE) -C libs/iovm
	$(MAKE) vmlib
	cd tools; $(MAKE)
ifneq (,$(findstring Windows,$(SYS)))
	mt.exe -manifest tools/_build/binaries/io.exe.manifest -outputresource:tools/_build/binaries/io.exe
	rm tools/_build/binaries/io.exe.manifest
	mt.exe -manifest tools/_build/binaries/io_static.exe.manifest -outputresource:tools/_build/binaries/io_static.exe
	rm tools/_build/binaries/io_static.exe.manifest
endif
	mkdir -p _build/binaries || true
	cp tools/_build/binaries/* _build/binaries

addons: vm
	./_build/binaries/io_static$(BINARY_SUFFIX) build.io
	@if [ -f errors ]; then cat errors; echo; echo "Note: addons do not build when libs or headers are missing"; echo; rm errors; fi

vmlib:
	mkdir -p _build || true
	mkdir -p _build/dll || true
	$(LINKDLL) $(DLL_COMMAND) $(LINKDLLOUTFLAG)_build/dll/$(DLL_LIB_PREFIX)iovmall.$(DLL_SUFFIX) libs/*/_build/$(VMALL)objs/*.o $(LFLAGS) $(DLL_EXTRA_LIBS)
ifneq (,$(findstring Windows,$(SYS)))
	mt.exe -manifest _build/dll/$(DLL_LIB_PREFIX)iovmall.dll.manifest -outputresource:_build/dll/$(DLL_LIB_PREFIX)iovmall.dll
	rm _build/dll/$(DLL_LIB_PREFIX)iovmall.dll.manifest
endif
	mkdir -p _build/lib || true
	$(AR) $(ARFLAGS) $(AROUTFLAG)_build/lib/$(DLL_LIB_PREFIX)iovmall.a\
        libs/*/_build/$(VMALL)objs/*.o
	$(RANLIB) _build/lib/$(DLL_LIB_PREFIX)iovmall.a
	mkdir -p _build/headers || true
	cp libs/*/_build/headers/* _build/headers

# Unlink the io binary before copying so running Io processes will keep running
install:
	umask 022
	mkdir -p $(INSTALL_PREFIX)/bin || true
	mkdir -p $(INSTALL_PREFIX)/lib || true
	mkdir -p $(INSTALL_PREFIX)/include || true
	rm -f $(INSTALL_PREFIX)/bin/io$(BINARY_SUFFIX)
	cp _build/binaries/io$(BINARY_SUFFIX) $(INSTALL_PREFIX)/bin || true
	chmod ugo+rx $(INSTALL_PREFIX)/bin/io$(BINARY_SUFFIX)
	cp _build/binaries/io_static$(BINARY_SUFFIX) $(INSTALL_PREFIX)/bin || true
	chmod ugo+rx $(INSTALL_PREFIX)/bin/io_static$(BINARY_SUFFIX)  || true
	cp _build/dll/* $(INSTALL_PREFIX)/lib  || true
	cp _build/dll/* $(INSTALL_PREFIX)/bin  || true
	cp _build/lib/* $(INSTALL_PREFIX)/lib  || true
	rm -rf $(INSTALL_PREFIX)/lib/io || true
	mkdir -p $(INSTALL_PREFIX)/lib/io || true
	cp -fR addons $(INSTALL_PREFIX)/lib/io
	chmod -R ugo+rX $(INSTALL_PREFIX)/lib/io
	rm -rf $(INSTALL_PREFIX)/include/io || true
	mkdir -p $(INSTALL_PREFIX)/include/io || true
	cp -fR _build/headers/* $(INSTALL_PREFIX)/include/io

linkInstall:
	mkdir -p $(INSTALL_PREFIX)/bin || true
	mkdir -p $(INSTALL_PREFIX)/lib || true
	mkdir -p $(INSTALL_PREFIX)/include || true
	ln -sf `pwd`/_build/binaries/io$(BINARY_SUFFIX) $(INSTALL_PREFIX)/bin
	chmod ugo+rx $(INSTALL_PREFIX)/bin/io
	ln -sf `pwd`/_build/binaries/io_static$(BINARY_SUFFIX) $(INSTALL_PREFIX)/bin
	chmod ugo+rx $(INSTALL_PREFIX)/bin/io_static$(BINARY_SUFFIX)
	ln -sf `pwd`/_build/dll/* $(INSTALL_PREFIX)/lib
	ln -sf `pwd`/_build/dll/* $(INSTALL_PREFIX)/bin
	rm -rf $(INSTALL_PREFIX)/lib/io || true
	mkdir -p $(INSTALL_PREFIX)/lib/io || true
	ln -s `pwd`/addons $(INSTALL_PREFIX)/lib/io/addons
	chmod -R ugo+rX $(INSTALL_PREFIX)/lib/io
	rm -rf $(INSTALL_PREFIX)/include/io || true
	ln -sf `pwd`/_build/headers $(INSTALL_PREFIX)/include/io

uninstall:
	rm -rf $(INSTALL_PREFIX)/lib/io
	rm -rf $(INSTALL_PREFIX)/include/io
	rm -f $(INSTALL_PREFIX)/bin/io
	rm -f $(INSTALL_PREFIX)/bin/io_static$(BINARY_SUFFIX)
	rm -f $(INSTALL_PREFIX)/bin/$(DLL_LIB_PREFIX)iovmall.*
	rm -f $(INSTALL_PREFIX)/lib/$(DLL_LIB_PREFIX)iovmall.*

doc:
	./_build/binaries/io_static$(BINARY_SUFFIX) build.io docs

cleanDocs:
	./_build/binaries/io_static$(BINARY_SUFFIX) build.io cleanDocs

clean:
	for dir in $(libs); do \
		$(MAKE) -C libs/$$dir clean; \
	done

	( cd tools; $(MAKE) cleanDocs )
	./_build/binaries/io_static$(BINARY_SUFFIX) build.io clean || true
	-rm -f IoBindingsInit.*
	-rm -rf _build
	-rm -rf projects/osx/build
	-rm -rf projects/osxvm/build
	$(MAKE) -C tools clean

testvm:
	cd tools; make test

testaddons:
	_build/binaries/io_static$(BINARY_SUFFIX) build.io runUnitTests

test:
	$(MAKE) testvm
	$(MAKE) testaddons

dist:
	-rm -f Io-*.tar.gz
	echo "#ifndef IO_VERSION_STRING\n#define IO_VERSION_STRING \""$(shell date +'%Y%m%d')"\"\n#endif" > libs/iovm/source/IoVersion.h
	git add libs/iovm/source/IoVersion.h | true
	git commit -q --no-verify -m "setting version string for release" | true
	git archive --format=tar --prefix=Io-$(date)/ HEAD | gzip > Io-$(date).tar.gz
	ls -al Io-$(date).tar.gz

metrics:
	ls -1 libs/iovm/source/*.c | io -e 'File standardInput readLines map(asFile contents occurancesOfSeq(";")) sum .. " iovm"'
	ls -1 libs/basekit/source/*.c | io -e 'File standardInput readLines map(asFile contents occurancesOfSeq(";")) sum .. " basekit"'
	ls -1 libs/coroutine/source/*.c | io -e 'File standardInput readLines map(asFile contents occurancesOfSeq(";")) sum .. " libcoroutine"'
	ls -1 libs/*/source/*.c | io -e 'File standardInput readLines map(asFile contents occurancesOfSeq(";")) sum .. " total in core"'

aptget:
	_build/binaries/io$(BINARY_SUFFIX) build.io aptget

emerge:
	_build/binaries/io$(BINARY_SUFFIX) build.io emerge

port:
	_build/binaries/io$(BINARY_SUFFIX) build.io port

urpmi:
	_build/binaries/io$(BINARY_SUFFIX) build.io urpmi

.DEFAULT:
	./_build/binaries/io_static$(BINARY_SUFFIX) build.io -a $@

