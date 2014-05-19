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

import subwindow;
import tmc;

interface Command
{
	SubWindow execute(TmcFile tmc);
	SubWindow undo(TmcFile tmc);
}

class CommandHistory
{
	void execute(Command c)
	{
		_commands = _commands[0 .. _currentPosition];
		_commands ~= c;
		++_currentPosition;
		c.execute(tmc);
	}

	@property bool canUndo() const pure nothrow
	{
		return _currentPosition > 0;
	}

	SubWindow undo()
	{
		assert(canUndo);
		--_currentPosition;
		return _commands[_currentPosition].undo(tmc);
	}

	@property bool canRedo() const pure nothrow
	{
		return _currentPosition < _commands.length;
	}

	SubWindow redo()
	{
		assert(canRedo);
		scope(exit) ++_currentPosition;
		return _commands[_currentPosition].execute(tmc);
	}

	@property bool fileChanged() const pure nothrow
	{
		return _currentPosition == _savedPosition;
	}

	void save()
	{
		_savedPosition = _currentPosition;
	}

	TmcFile tmc;

private:
	Command[] _commands;
	size_t _savedPosition = 0;
	size_t _currentPosition = 0;
}
