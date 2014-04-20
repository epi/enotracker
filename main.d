import std.file;
import std.stdio;

import sdl;
import tmc;
import textrender;
import pattern;
import song;
import subwindow;

enum ScreenSize
{
	width = 1024,
	height = 768,
}

void main(string[] args)
{
	version(unittest)
	{
		writeln("test ok");
		return;
	}

	auto tmc = new TmcFile;
	auto content = cast(immutable(ubyte)[]) std.file.read(args[1]);
	tmc.load(content);

	auto screen = new Screen(ScreenSize.width, ScreenSize.height, 32);
	scope (exit) screen.free();

	screen.fillRect(SDL_Rect(0, 0, ScreenSize.width, ScreenSize.height), 0x101010);
	
	auto tr = new TextRenderer(screen);

	tr.fgcolor = 0xFFFFFF;
	tr.bgcolor = 0x000000;

	tr.text(0, 0, "Theta Music Composer 1X11");

	SubWindow[] windows;

	auto se = new SongEditor(tr, 48, 2, 20);
	se.tmc = tmc;
	se.draw();
	windows ~= se;

	auto pe = new PatternEditor(tr, 1, 23, 48);
	pe.tmc = tmc;
	windows ~= pe;

	se.addObserver(&pe.changeSongLine);

	foreach (w; windows)
		w.deactivate();
	
	uint activeWindow = 0;
	windows[activeWindow].activate();

	screen.flip();

	SDL_EnableKeyRepeat(500, 30);
	for (;;)
	{
		SDL_Event event;
		while (SDL_WaitEvent(&event))
		{
			switch (event.type)
			{
			case SDL_EventType.SDL_QUIT:
				return;
			case SDL_EventType.SDL_KEYDOWN:
				if (event.key.keysym.sym == SDLKey.SDLK_TAB)
				{
					windows[activeWindow].deactivate();
					activeWindow = (activeWindow + 1) % windows.length;
					windows[activeWindow].activate();
					screen.flip();
				}
				else if (windows[activeWindow].key(event.key.keysym.sym, event.key.keysym.mod))
					screen.flip();
				break;
			default:
				break;
			}
		}
	}
}

