src := main.d tmc.d sdl.d textrender.d pattern.d song.d subwindow.d asap.d player.d instrument.d

xtmc: $(src) default.fnt
	dmd $(src) -g -J. -of$@

unittest: $(src) default.fnt
	dmd $(src) -g -debug -unittest -J. -of$@ && ./$@

clean:
	rm -f xtmc unittest xtmc.o unittest.o
.PHONY: clean

.DELETE_ON_ERROR:

