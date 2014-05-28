/**
	General song info editor.

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

module info;

import state;
import subwindow;
import tmc;

class InfoEditor : SubWindow
{
	this(Surface s, uint x, uint y)
	{
		enum w = 47;
		enum h = 4;
		super(s, x, y, w, h);
	}

	override void draw()
	{
		fgcolor = active ? Color.ActiveFg : Color.InactiveFg;
		bgcolor = active ? Color.ActiveBg : Color.InactiveBg;
		box(0, 0, width, height, bgcolor);
		text(1, 1, "Title:");
		text(1, 2, "Speed:");
		text(11, 2, "x/Frame:");
		text(23, 2, "Octave:");
		if (_state.followSong)
			text(39, 1, "Follow");
		if (_state.editing)
			text(41, 2, "Edit");
		fgcolor = active ? Color.ActiveHighlightFg : Color.InactiveHighlightFg;
		text(8, 1, _state.tmc.title);
		textf(8, 2, "%d", _state.tmc.speed);
		textf(20, 2, "%d", _state.tmc.fastplay);
		textf(31, 2, "%d-%d", _state.octave + 1, _state.octave + 2);
		if (active)
			drawCursor();
	}

	void drawCursor()
	{
	}

	@property void state(State s)
	{
		_state = s;
		s.addObserver("info", ()
			{
				if (_state.editing != _state.oldEditing
				 || _state.followSong != _state.oldFollowSong
				 || _state.octave != _state.oldOctave)
					draw();
			});
	}

private:
	enum Color
	{
		ActiveBg = 0x283840,
		ActiveFg = 0xd0d8e0,
		ActiveHighlightFg = 0xf0f0f0,
		InactiveBg = 0x202428,
		InactiveFg = 0x808080,
		InactiveHighlightFg = 0xc0c0c0,
	}
	
	State _state;
}
