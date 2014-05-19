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

import command;
import tmc;

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

	uint octave;
	bool followSong;
	Playing playing = Playing.nothing;

private:
	TmcFile _tmc;
	CommandHistory _history;
}
