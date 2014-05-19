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
import info;
import instrument;
import oscilloscope;
import pattern;
import player;
import sdl;
import song;
import state;
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
		_songEditor = new SongEditor(_screen, 1, 3, 20);
		_patternEditor = new PatternEditor(_screen, 1, 24, 48);
		_instrumentEditor = new InstrumentEditor(_screen, 54, 8);
		_oscilloscope = new Oscilloscope(_screen, 84, 8, 14, 6);
		_infoEditor = new InfoEditor(_screen, 54, 3);

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

		// create and attach editor state
		_state = new State;
		_songEditor.state = _state;
		_patternEditor.state = _state;
		_instrumentEditor.state = _state;
		_infoEditor.state = _state;
		_player.state = _state;

		// draw UI
		_screen.fillRect(SDL_Rect(0, 0, ScreenSize.width, ScreenSize.height), 0x000000);
		_songEditor.active = true;
		_patternEditor.active = false;
		_instrumentEditor.active = false;
		_infoEditor.active = false;
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
		_state.tmc.load(content);
		_songEditor.active = true;
		_patternEditor.active = false;
		_instrumentEditor.active = false;
		_infoEditor.active = false;
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
					if (event.key.keysym.sym == SDLKey.SDLK_F7)
					{
						_state.followSong = !_state.followSong;
						_infoEditor.draw();
						_screen.flip();
					}
					if (event.key.keysym.sym == SDLKey.SDLK_F8)
					{
						if (_state.octave > 0)
						{
							--_state.octave;
							_infoEditor.draw();
							_screen.flip();
						}
					}
					else if (event.key.keysym.sym == SDLKey.SDLK_F9)
					{
						if (_state.octave < 4)
						{
							++_state.octave;
							_infoEditor.draw();
							_screen.flip();
						}
					}
					else if (event.key.keysym.sym == SDLKey.SDLK_TAB)
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
					if (_state.followSong
					 && (_state.playing == State.Playing.pattern || _state.playing == State.Playing.song))
					{
						_songEditor.update(fevent.songPosition);
						_patternEditor.update(fevent.songPosition, fevent.patternPosition);
					}
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
	SongEditor _songEditor;
	PatternEditor _patternEditor;
	InstrumentEditor _instrumentEditor;
	InfoEditor _infoEditor;
	Oscilloscope _oscilloscope;
	SubWindow _activeWindow;
	Player _player;
	State _state;
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
