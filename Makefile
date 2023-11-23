DC := ldc2
CC := clang

CFLAGS = -O2 -Wall -Wextra -fno-exceptions -DNDEBUG
CXXFLAGS = -O2 -Wall -Wextra -fno-exceptions
DFLAGS = -J. -O -release
LDFLAGS = -L-lSDL

NFD = nativefiledialog/src

ifeq ($(OS),Windows_NT)
EXEEXT = .exe
cobjs += nfd_win.obj nfd_common.obj
LDFLAGS += -L/SUBSYSTEM:WINDOWS
else
cobjs += nfd_gtk.o nfd_common.o
CFLAGS += $(shell pkg-config --cflags gtk+-3.0)
LDFLAGS += $(addprefix -L,$(shell pkg-config --libs gtk+-3.0))
endif

src := main.d tmc.d sdl.d pattern.d song.d instrument.d oscilloscope.d subwindow.d asap.d player.d keys.d info.d state.d command.d

xtmc$(EXEEXT): $(src) $(cobjs) default.fnt
	$(DC) $(DFLAGS) $(src) $(cobjs) -of$@ $(LDFLAGS)

nfd_common.obj: $(NFD)/nfd_common.c $(NFD)/include/nfd.h
	$(CC) -c -I$(NFD)/include $(CFLAGS) $< -o $@

nfd_win.obj: $(NFD)/nfd_win.cpp $(NFD)/include/nfd.h
	$(CC) -c -I$(NFD)/include $(CFLAGS) $< -o $@

%.o: $(NFD)/%.c $(NFD)/include/nfd.h
	$(CC) -c -I$(NFD)/include $(CFLAGS) $< -o $@

unittest: $(src) default.fnt
	$(DC) $(src) -g -debug -unittest -J. -of$@ && ./$@

clean:
	rm -f xtmc$(EXEEXT) unittest *.obj *.o
.PHONY: clean

.DELETE_ON_ERROR:
