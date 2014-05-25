/**
	Manage current editor state.

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

module state;

import std.array : replace;
import std.ascii : toUpper;

import command;
import tmc;

private string generateObservableProperty(string type, string name)
{
	return
		q{
			public @property $type$ $name$() const pure nothrow { return _$name$; }
			public @property $type$ old$uname$() const pure nothrow { return _old$uname$; }
			public @property void $name$($type$ v)
			{
				if (_old$uname$ != v)
				{
					_$name$ = v;
					notify();
					_old$uname$ = v;
				}
			}
			private $type$ _$name$;
			private $type$ _old$uname$;
		}
		.replace("$type$", type)
		.replace("$name$", name)
		.replace("$uname$", name[0].toUpper ~ name[1 .. $]);
}

class State
{
	enum Playing
	{
		nothing,
		note,
		pattern,
		song
	}

	this()
	{
		_tmc = new TmcFile;
		_history = new CommandHistory;
		_history.tmc = tmc;
	}

	@property TmcFile tmc() { return _tmc; }
	@property CommandHistory history() { return _history; }

	uint instrument;
	Playing playing = Playing.nothing;

	mixin(generateObservableProperty("uint", "octave"));
	mixin(generateObservableProperty("bool", "editing"));
	mixin(generateObservableProperty("bool", "followSong"));
	mixin(generateObservableProperty("uint", "songPosition"));
	mixin(generateObservableProperty("uint", "patternPosition"));

	void setSongAndPatternPosition(uint sp, uint pp)
	{
		if (sp != _oldSongPosition || pp != _oldPatternPosition)
		{
			_songPosition = sp;
			_patternPosition = pp;
			notify();
			_oldSongPosition = sp;
			_oldPatternPosition = pp;
		}
	}

	void addObserver(string name, void delegate() obs)
	{
		_observers[name] = obs;
	}

private:
	void notify()
	{
		foreach (n, d; _observers)
			d();
	}

	void delegate()[string] _observers;
	TmcFile _tmc;
	CommandHistory _history;
}
