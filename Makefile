src := main.d tmc.d sdl.d pattern.d song.d instrument.d oscilloscope.d subwindow.d asap.d player.d keys.d

xtmc: $(src) default.fnt
	dmd $(src) -g -J. -of$@

unittest: $(src) default.fnt
	dmd $(src) -g -debug -unittest -J. -of$@ && ./$@

clean:
	rm -f xtmc unittest xtmc.o unittest.o
.PHONY: clean

.DELETE_ON_ERROR:
