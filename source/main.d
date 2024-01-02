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

import std.file : read, write;
import std.path : baseName;
import std.string : toStringz;

import asap;
import filename;
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

private import gtk.Main;
private import gtk.MainWindow;
private import gtk.MessageDialog;
private import gtk.Version;

import gtk.MenuBar;
import gtk.AccelGroup;
import gtk.Menu;
import gtk.MenuItem;
import gtk.VBox;
import gtk.Widget;
import gtk.Statusbar;
import core.memory;

import std.stdio;
import std.math;
import std.datetime;

import glib.Timeout;

import cairo.Context;
import cairo.Surface;

import gtk.Widget;
import gtk.DrawingArea;

class Enotracker
{
	private enum ScreenSize
	{
		width = 816,
		height = 616,
	}

	this()
	{
		//_screen = new Screen(ScreenSize.width, ScreenSize.height, 32);
		//scope(failure) clear(_screen);

		_screen = new TextScreen(ScreenSize.width / 8, ScreenSize.height / 8);

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
		scope(failure) destroy(_player);

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

		// draw UI
		//_screen.fillRect(SDL_Rect(0, 0, ScreenSize.width, ScreenSize.height), 0x000000);
		_songEditor.active = true;
		_patternEditor.active = false;
		_instrumentEditor.active = false;
		_infoEditor.active = false;
		_oscilloscope.active = false;
		//_screen.flip();

		_state.fileName = "";
	}

	~this()
	{
		//clear(_screen);
		destroy(_player);
	}

	void loadFile(string filename)
	{
		auto content = cast(immutable(ubyte)[]) imported!`std.file`.read(filename);
		_state.tmc.load(content);
		_songEditor.active = true;
		_patternEditor.active = false;
		_instrumentEditor.active = false;
		_infoEditor.active = false;
		_oscilloscope.active = false;
		//_screen.flip();
		_state.fileName = filename;
		_state.history.setSavePoint();
	}

	void processEvents()
	{
/*		SDL_EnableKeyRepeat(500, 30);
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
		}*/
	}

private:
	bool handleKeyDown(SDLKey key, SDLMod mod, wchar unicode)
	{
/*		if (key == SDLKey.SDLK_F7)
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
		else if (key == SDLKey.SDLK_s && mod.packModifiers() == Modifiers.ctrl)
		{
			SubWindow previousWindow = _activeWindow;
			auto fne = new FileNameEditor(_screen, 1, 73, _state.fileName,
				(string newName, bool accepted)
				{
					try
					{
						if (accepted)
						{
							std.file.write(newName, _state.tmc.save(0x2800, true));
							_state.fileName = newName;
							_state.history.setSavePoint();
						}
					}
					finally
					{
						_activeWindow.active = false;
						_activeWindow = _activeWindow.next;
						_activeWindow.active = true;
						_screen.flip();
					}
				});
			fne.next = previousWindow;
			_activeWindow = fne;
			previousWindow.active = false;
			_activeWindow.active = true;
			return true;
		}
		return _activeWindow.key(key, mod, unicode);*/
		return false;
	}

	TextScreen _screen;
	//Screen _screen;
	SongEditor _songEditor;
	PatternEditor _patternEditor;
	InstrumentEditor _instrumentEditor;
	InfoEditor _infoEditor;
	Oscilloscope _oscilloscope;
	SubWindow _activeWindow;
	Player _player;
	State _state;
}

class FooWidget : DrawingArea
{
public:
	this(TextScreen ts)
	{
		_textScreen = ts;
		//Attach our expose callback, which will draw the window.
		addOnDraw(&drawCallback);
	}

protected:
	char[] line;

	//Override default signal handler:
	bool drawCallback(scope Context cr, Widget widget)
	{
		GtkAllocation size;

		getAllocation(size);
		cr.scale(size.width / 800.0, size.height / 600.0);
//		cr.save();
			cr.setSourceRgba(0.0, 0.0, 0.0, 1.0);
			cr.paint();
			string _fontFamily = "DejaVu Sans Mono";
			cr.selectFontFace(_fontFamily, cairo_font_slant_t.NORMAL, cairo_font_weight_t.BOLD);

			cr.setSourceRgba(0.0, 1.0, 0.0, 1.0);
			if (line.length < _textScreen.width)
				line.length = _textScreen.width;
			foreach (y; 0 .. _textScreen.height)
			{
				foreach (x; 0 .. _textScreen.width)
				{
					auto c = _textScreen[x, y];
					line[x] = (c >= 0x20 && c <= 0x7e) ? c : ' ';
				}
				cr.moveTo(0, y * 10);
				cr.showText(line.idup);
			}
//		cr.restore();


		return true;
	}

	TextScreen _textScreen;
	double m_radius = 0.40;
	double m_lineWidth = 0.065;

	Timeout m_timeout;
}

class EnotrackerWindow : MainWindow
{
	this(Enotracker eno)
	{
		super("enotracker");
		_eno = eno;
		_eno._player.theActualFrameCallback = (ASAPFrameEvent fevent)
			{
				with(_eno)
				{
					if (_state.followSong
					 || (_state.playing == State.Playing.pattern || _state.playing == State.Playing.song))
					{
						_state.setSongAndPatternPosition(fevent.songPosition, fevent.patternPosition);
					}
				}
				this.queueDrawArea(0, 0, _eno._screen.width * 8, _eno._screen.height * 10);
			};
		setup();
		showAll();

		string versionCompare = Version.checkVersion(3, 0, 0);

		if (versionCompare.length > 0)
		{
			MessageDialog d = new MessageDialog(
				this,
				GtkDialogFlags.MODAL,
				MessageType.WARNING,
				ButtonsType.OK,
				"GtkD : Gtk+ version missmatch\n" ~ versionCompare ~
				"\nYou might run into problems!" ~
				"\n\nPress OK to continue");
			d.run();
			d.destroy();
		}
	}

	void onMenuActivate(MenuItem menuItem)
	{
		string action = menuItem.getActionName();
		switch( action )
		{
			case "help.about":
				_eno._player.playSong(0);
				break;
			default:
				MessageDialog d = new MessageDialog(
					this,
					GtkDialogFlags.MODAL,
					MessageType.INFO,
					ButtonsType.OK,
					"You pressed menu item "~action);
				d.run();
				d.destroy();
			break;
		}
	}

	MenuBar getMenuBar()
	{
		AccelGroup accelGroup = new AccelGroup();

		addAccelGroup(accelGroup);

		MenuBar menuBar = new MenuBar();

		Menu menu = menuBar.append("_File");

		MenuItem item = new MenuItem(&onMenuActivate, "_New","file.new", true, accelGroup, 'n');
//		item.addAccelerator("activate",accelGroup,'n',GdkModifierType.CONTROL_MASK,GtkAccelFlags.VISIBLE);

		menu.append(item);
		menu.append(new MenuItem(&onMenuActivate, "_Open","file.open", true, accelGroup, 'o'));
		menu.append(new MenuItem(&onMenuActivate, "_Close","file.close", true, accelGroup, 'c'));
		menu.append(new MenuItem(&onMenuActivate, "E_xit","file.exit", true, accelGroup, 'x'));

		menu = menuBar.append("_Edit");

		menu.append(new MenuItem(&onMenuActivate,"_Find","edit.find", true, accelGroup, 'f'));
		menu.append(new MenuItem(&onMenuActivate,"_Search","edit.search", true, accelGroup, 's'));

		menu = menuBar.append("_Help");
		menu.append(new MenuItem(&onMenuActivate,"_About","help.about", true, accelGroup, 'a',GdkModifierType.CONTROL_MASK|GdkModifierType.SHIFT_MASK));

		return menuBar;
	}

	void setup()
	{
		VBox mainBox = new VBox(false, 0);

		mainBox.packStart(getMenuBar(),false,false,0);
		mainBox.packStart(new FooWidget(_eno._screen),true,true,0);
		Statusbar statusbar = new Statusbar();
		auto i = statusbar.getContextId("dupa");
		statusbar.push(i, "Lorem ipsum dolor sit amet");

		mainBox.packStart(statusbar,false,true,0);
		add(mainBox);

		setDefaultSize(800, 600);
	}

	Enotracker _eno;
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
	scope(exit) destroy(eno);
	if (args.length > 1)
		eno.loadFile(args[1]);

	Main.initMultiThread([]);
	auto window = new EnotrackerWindow(eno);

	Main.run();
}
