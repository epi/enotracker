/**
	Entry point for enotracker.

	Copyright:
	This file is part of enotracker $(LINK https://github.com/epi/enotracker)
	Copyright (C) 2014 Adrian Matoga

	enotracker is free software: you can redistribute it and/or modify
	it under the terms of the GNU General Public License as published by
	the Free Software Foundation, either version 3 of the License, or
	(at your option) any later version.

	enotracker is distributed in the hope that it will be useful,
	but WITHOUT ANY WARRANTY; without even the implied warranty of
	MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
	GNU General Public License for more details.

	You should have received a copy of the GNU General Public License
	along with enotracker.  If not, see $(LINK http://www.gnu.org/licenses/).
*/

import std.file;

import asap;
import instrument;
import pattern;
import player;
import sdl;
import song;
import subwindow;
import textrender;
import tmc;

enum ScreenSize
{
	width = 808,
	height = 600,
}

void main(string[] args)
{
	version(unittest)
	{
		import std.stdio;
		writeln("test ok");
		return;
	}

	auto tmc = new TmcFile;
	auto content = cast(immutable(ubyte)[]) std.file.read(args[1]);
	tmc.load(content);

	auto screen = new Screen(ScreenSize.width, ScreenSize.height, 32);
	scope (exit) screen.free();

	screen.fillRect(SDL_Rect(0, 0, ScreenSize.width, ScreenSize.height), 0x000000);
	
	auto tr = new TextRenderer(screen);

	tr.fgcolor = 0xFFFFFF;
	tr.bgcolor = 0x000000;

	tr.text(2, 1, args[1]);

	SubWindow[] windows;

	auto se = new SongEditor(tr, 1, 3, 19);
	se.tmc = tmc;
	windows ~= se;

	auto pe = new PatternEditor(tr, 1, 23, 48);
	pe.tmc = tmc;
	windows ~= pe;

	auto ie = new InstrumentEditor(tr, 54, 7);
	ie.tmc = tmc;
	windows ~= ie;

	se.addObserver(&pe.changeSongLine);

	foreach (w; windows)
		w.deactivate();
	
	uint activeWindow = 0;
	windows[activeWindow].activate();

	screen.flip();

	auto player = new Player;
	scope(exit) player.close();
	player.start();
	player.tmc = tmc;

	se.player = player;
	pe.player = player;
	ie.player = player;

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
				else if (event.key.keysym.sym == SDLKey.SDLK_ESCAPE)
				{
					player.stop();
					ubyte[8] zeroChnVol;
					pe.drawBars(zeroChnVol[]);
					screen.flip();
				}
				else if (windows[activeWindow].key(event.key.keysym.sym, event.key.keysym.mod))
					screen.flip();
				break;
			case SDL_EventType.SDL_USEREVENT:
			{
				auto fevent = cast(const(ASAPFrameEvent)*) &event;
				se.update(fevent.songPosition);
				pe.update(fevent.songPosition, fevent.patternPosition);
				pe.drawBars(fevent.channelVolumes);
				screen.flip();
				break;
			}
			default:
				break;
			}
		}
	}
}
