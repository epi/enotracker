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
import oscilloscope;
import pattern;
import player;
import sdl;
import song;
import subwindow;
import tmc;

class Enotracker
{
	private enum ScreenSize
	{
		width = 808,
		height = 600,
	}

	this()
	{
		_screen = new Screen(ScreenSize.width, ScreenSize.height, 32);
		scope(failure) clear(_screen);

		// create and connect windows
		_songEditor = new SongEditor(_screen, 1, 3, 19);
		_patternEditor = new PatternEditor(_screen, 1, 23, 48);
		_instrumentEditor = new InstrumentEditor(_screen, 54, 7);
		_oscilloscope = new Oscilloscope(_screen, 84, 7, 14, 6);
		// _nameEditor = new NameEditor(_screen, 54, 3);

		_songEditor.next = _patternEditor;
		_patternEditor.next = _instrumentEditor;
		_instrumentEditor.next = _songEditor;
		_songEditor.addObserver(&_patternEditor.changeSongLine);
		_activeWindow = _songEditor;

		// create and attach player
		_player = new Player;
		scope(failure) clear(_player);

		_songEditor.player = _player;
		_patternEditor.player = _player;
		_instrumentEditor.player = _player;

		// create and attach music data object
		_tmc = new TmcFile;
		_player.tmc = _tmc;
		_songEditor.tmc = _tmc;
		_patternEditor.tmc = _tmc;
		_instrumentEditor.tmc = _tmc;

		// draw UI
		_screen.fillRect(SDL_Rect(0, 0, ScreenSize.width, ScreenSize.height), 0x000000);
		_songEditor.active = true;
		_patternEditor.active = false;
		_instrumentEditor.active = false;
		// _nameEditor.active = false;
		// _speedEditor.active = false;
		_oscilloscope.active = false;
		_screen.flip();
	}

	~this()
	{
		clear(_screen);
		clear(_player);
	}

	void loadFile(string filename)
	{
		auto content = cast(immutable(ubyte)[]) std.file.read(filename);
		_tmc.load(content);
		_player.reload();
		_songEditor.active = true;
		_patternEditor.active = false;
		_instrumentEditor.active = false;
		// _nameEditor.active = false;
		// _speedEditor.active = false;
		_oscilloscope.active = false;
		_screen.flip();
	}

	void processEvents()
	{
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
						_activeWindow.active = false;
						_activeWindow = _activeWindow.next;
						_activeWindow.active = true;
						_screen.flip();
					}
					else if (event.key.keysym.sym == SDLKey.SDLK_ESCAPE)
					{
						_player.stop();
						ubyte[8] zeroChnVol;
						_patternEditor.drawBars(zeroChnVol[]);
						_oscilloscope.update();
						_screen.flip();
					}
					else if (_activeWindow.key(event.key.keysym.sym, event.key.keysym.mod))
						_screen.flip();
					break;
				case SDL_EventType.SDL_USEREVENT:
				{
					auto fevent = cast(const(ASAPFrameEvent)*) &event;
					_songEditor.update(fevent.songPosition);
					_patternEditor.update(fevent.songPosition, fevent.patternPosition);
					_patternEditor.drawBars(fevent.channelVolumes);
					_screen.flip();
					break;
				}
				case SDL_EventType.SDL_USEREVENT + 1:
				{
					auto bevent = cast(const(ASAPBufferEvent)*) &event;
					_oscilloscope.update(
						cast(const(short)[]) bevent.left,
						cast(const(short)[]) bevent.right);
					_screen.flip();
					break;
				}
				default:
					break;
				}
			}
		}
	}

private:
	Screen _screen;
	TmcFile _tmc;
	SongEditor _songEditor;
	PatternEditor _patternEditor;
	InstrumentEditor _instrumentEditor;
	Oscilloscope _oscilloscope;
	SubWindow _activeWindow;
	Player _player;
}

void main(string[] args)
{
	version(unittest)
	{
		import std.stdio;
		writeln("test ok");
		return;
	}

	auto eno = new Enotracker;
	scope(exit) clear(eno);
	if (args.length > 1)
		eno.loadFile(args[1]);
	eno.processEvents();
}
