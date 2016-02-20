src := main.d tmc.d info.d filename.d song.d pattern.d instrument.d oscilloscope.d subwindow.d sdl.d command.d player.d state.d keys.d asap.d

xtmc: $(src)
	dmd $(src) -g -J. -of$@ -L-lgtkd-2 -L-ldl

unittest: $(src) default.fnt
	dmd $(src) -g -debug -unittest -J. -of$@ && ./$@

clean:
	rm -f xtmc unittest xtmc.o unittest.o
.PHONY: clean

.DELETE_ON_ERROR:
