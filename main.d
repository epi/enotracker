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

import std.path : baseName;
import std.string : toStringz, fromStringz;

import asap;
import info;
import instrument;
import keys;
import oscilloscope;
import pattern;
import player;
import sdl;
import song;
import state;
import subwindow;
import tmc;

extern(C) {

enum nfdresult_t {
    NFD_ERROR,       /* <<programmatic error */
    NFD_OKAY,        /* <<user pressed okay, or successful return */
    NFD_CANCEL       /* <<user pressed cancel */
}

nfdresult_t NFD_SaveDialog(const(char)* filterList, char* defaultPath, char** outPath);
nfdresult_t NFD_OpenDialog(const(char)* filterList, char* defaultPath, char** outPath);
}

class Enotracker
{
	private enum ScreenSize
	{
		width = 816,
		height = 616,
	}

	void initState()
	{
		_state = new State;
		_songEditor.state = _state;
		_patternEditor.state = _state;
		_instrumentEditor.state = _state;
		_infoEditor.state = _state;
		_player.state = _state;
		_state.addObserver("main", ()
			{
				if (_state.fileName != _state.oldFileName
				 || _state.modified != _state.oldModified)
				{
					auto title = (_state.fileName.baseName()
						~ (_state.modified ? " *" : "")
						~ " - enotracker").toStringz();
					SDL_WM_SetCaption(title, title);
				}
			});
		_state.fileName = "";
	}

	this()
	{
		_screen = new Screen(ScreenSize.width, ScreenSize.height, 32);
		scope(failure) _screen.destroy();

		// create and connect windows
		_songEditor = new SongEditor(_screen, 1, 3, 20);
		_patternEditor = new PatternEditor(_screen, 1, 24, 48);
		_instrumentEditor = new InstrumentEditor(_screen, 54, 8);
		_oscilloscope = new Oscilloscope(_screen, 84, 8, 15, 6);
		_infoEditor = new InfoEditor(_screen, 54, 3);

		_songEditor.next = _patternEditor;
		_patternEditor.next = _instrumentEditor;
		_instrumentEditor.next = _songEditor;
		_activeWindow = _songEditor;

		// create and attach player
		_player = new Player;
		scope(failure) _player.destroy();

		_songEditor.player = _player;
		_patternEditor.player = _player;
		_instrumentEditor.player = _player;

		// create and attach editor state
		initState();

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
		_screen.destroy();
		_player.destroy();
	}

	void loadFile(string filename)
	{
		import std.file : read;
		auto content = cast(immutable(ubyte)[]) read(filename);
		_state.tmc.load(content);
		_songEditor.active = true;
		_patternEditor.active = false;
		_instrumentEditor.active = false;
		_infoEditor.active = false;
		_oscilloscope.active = false;
		_screen.flip();
		_state.fileName = filename;
		_state.history.setSavePoint();
	}

	void processEvents()
	{
		SDL_EnableKeyRepeat(500, 30);
		for (;;)
		{
			SDL_Event event;
			while (SDL_WaitEvent(&event))
			{
				try
				{
					switch (event.type)
					{
					case SDL_EventType.SDL_QUIT:
						if (!_state.modified)
							return;
						break;
					case SDL_EventType.SDL_KEYDOWN:
						if (handleKeyDown(event.key.keysym.sym, event.key.keysym.mod, event.key.keysym.unicode))
							_screen.flip();
						break;
					case SDL_EventType.SDL_USEREVENT:
					{
						auto fevent = cast(const(ASAPFrameEvent)*) &event;
						if (_state.followSong
						 && (_state.playing == State.Playing.pattern || _state.playing == State.Playing.song))
						{
							_state.setSongAndPatternPosition(fevent.songPosition, fevent.patternPosition);
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
				catch (Throwable t)
				{
					import std.stdio;
					stderr.writeln(t.msg);
				}
			}
		}
	}

private:
	bool handleKeyDown(SDLKey key, SDLMod mod, wchar unicode)
	{
		if (key == SDLKey.SDLK_F7)
		{
			_state.followSong = !_state.followSong;
			return true;
		}
		else if (key == SDLKey.SDLK_F8)
		{
			if (_state.octave > 0)
			{
				_state.octave = _state.octave - 1;
				return true;
			}
		}
		else if (key == SDLKey.SDLK_F9)
		{
			if (_state.octave < 4)
			{
				_state.octave = _state.octave + 1;
				return true;
			}
		}
		else if (key == SDLKey.SDLK_TAB)
		{
			_activeWindow.active = false;
			_activeWindow = _activeWindow.next;
			_activeWindow.active = true;
			return true;
		}
		else if (key == SDLKey.SDLK_ESCAPE)
		{
			_player.stop();
			_patternEditor.draw();
			_oscilloscope.update();
			return true;
		}
		else if (key == SDLKey.SDLK_z && mod.packModifiers() == Modifiers.ctrl)
		{
			if (_state.history.canUndo)
			{
				SubWindow previousWindow = _activeWindow;
				_activeWindow = _state.history.undo();
				if (_activeWindow !is previousWindow)
					previousWindow.active = false;
				_activeWindow.active = true;
				return true;
			}
		}
		else if (key == SDLKey.SDLK_z && mod.packModifiers() == (Modifiers.ctrl | Modifiers.shift))
		{
			if (_state.history.canRedo)
			{
				SubWindow previousWindow = _activeWindow;
				_activeWindow = _state.history.redo();
				if (_activeWindow !is previousWindow)
					previousWindow.active = false;
				_activeWindow.active = true;
				return true;
			}
		}
		else if (key == SDLKey.SDLK_SPACE)
		{
			_state.editing = !_state.editing;
			if (_state.editing)
			{
				if (_state.playing != State.Playing.nothing)
					_player.stop();
			}
			_patternEditor.draw();
			return true;
		}
		else if (key == SDLKey.SDLK_s &&
			(mod.packModifiers() == Modifiers.ctrl && _state.fileName.length))
		{
			import std.file: write;
			try
			{
				write(_state.fileName, _state.tmc.save(0x2800, true));
				_state.history.setSavePoint();
			}
			finally
			{
				_screen.flip();
			}
		}
		else if (key == SDLKey.SDLK_s &&
			((mod.packModifiers() == (Modifiers.ctrl | Modifiers.shift))
			 || (mod.packModifiers() == Modifiers.ctrl && _state.fileName == "")))
		{
			import core.stdc.stdlib, std.file: write;
			if (_state.playing != State.Playing.nothing)
				_player.stop();
			char* outPath;
			nfdresult_t r = NFD_SaveDialog("tmc".toStringz, null, &outPath);
			scope(exit) free(outPath);
			if (r == nfdresult_t.NFD_OKAY) {
				try
				{
					string newName = fromStringz(outPath).idup;
					write(newName, _state.tmc.save(0x2800, true));
					_state.fileName = newName;
					_state.history.setSavePoint();
				}
				finally
				{
					_screen.flip();
				}
			}
			return true;
		}
		else if (key == SDLKey.SDLK_l && mod.packModifiers() == Modifiers.ctrl && !_state.modified)
		{
			import core.stdc.stdlib, std.file: write;
			if (_state.playing != State.Playing.nothing)
				_player.stop();
			char* outPath;
			nfdresult_t r = NFD_OpenDialog("tmc".toStringz, null, &outPath);
			scope(exit) free(outPath);
			if (r == nfdresult_t.NFD_OKAY) {
				string newName = fromStringz(outPath).idup;
				initState();
				loadFile(newName);
			}
			return true;
		}
		return _activeWindow.key(key, mod, unicode);
	}

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

void theMain(string[] args)
{
	version(unittest)
	{
		import std.stdio;
		writeln("test ok");
		return;
	}

	auto eno = new Enotracker;
	scope(exit) eno.destroy();
	if (args.length > 1)
		eno.loadFile(args[1]);
	eno.processEvents();
}

version(Windows)
{
	extern (Windows) int WinMain(void* hInstance, void* hPrevInstance, void* lpCmdLine, int nCmdShow)
	{
		try
		{
			theMain([]);
		}
		catch (Throwable t)
		{
			return 1;
		}
		return 0;
	}
}
else
{
	void main(string[] args)
	{
		theMain(args);
	}
}
