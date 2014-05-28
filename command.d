/**
	Command history.

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

module command;

import state;
import subwindow;
import tmc;

interface Command
{
	SubWindow execute(TmcFile tmc);
	SubWindow undo(TmcFile tmc);
}

class CommandHistory
{
	this(State s)
	{
		_state = s;
	}

	void execute(Command c)
	{
		_commands = _commands[0 .. _currentPosition];
		_commands ~= c;
		++_currentPosition;
		_state.modified = this.modified;
		c.execute(_state.tmc);
	}

	@property bool canUndo() const pure nothrow
	{
		return _currentPosition > 0;
	}

	SubWindow undo()
	{
		assert(canUndo);
		--_currentPosition;
		_state.modified = this.modified;
		return _commands[_currentPosition].undo(_state.tmc);
	}

	@property bool canRedo() const pure nothrow
	{
		return _currentPosition < _commands.length;
	}

	SubWindow redo()
	{
		assert(canRedo);
		scope(exit)
		{
			++_currentPosition;
			_state.modified = this.modified;
		}
		return _commands[_currentPosition].execute(_state.tmc);
	}

	@property bool modified() const pure nothrow
	{
		return _currentPosition != _savedPosition;
	}

	void setSavePoint()
	{
		_savedPosition = _currentPosition;
		_state.modified = this.modified;
	}

private:
	State _state;
	Command[] _commands;
	size_t _savedPosition = 0;
	size_t _currentPosition = 0;
}
