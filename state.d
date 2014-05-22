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

import std.ascii : toUpper;
import std.array : replace;

import command;
import tmc;

private string generateObservableProperty(string type, string name)
{
	return
		q{
			public @property $type$ $name$() const pure nothrow { return _$name$; }
			public @property void $name$($type$ v)
			{
				_$name$ = v;
				foreach (n, obs; _$name$Observers) obs(v);
			}
			public void add$uname$Observer(string name, void delegate($type$) obs)
			{
				_$name$Observers[name] = obs;
			}
			private $type$ _$name$;
			private void delegate($type$)[string] _$name$Observers;
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
	uint octave;
	bool followSong;
	Playing playing = Playing.nothing;

	mixin(generateObservableProperty("bool", "editing"));

private:
	TmcFile _tmc;
	CommandHistory _history;
}
