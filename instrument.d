/**
	Instrument editor.

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

module instrument;

import std.algorithm;
import std.conv;

import player;
import subwindow;
import tmc;

class InstrumentEditor : SubWindow
{
	this(Surface s, uint x, uint y)
	{
		enum w = 21 + 1 + 2 + 1 + 2 + 2;
		enum h = 4 * 2 + 1 + 4 + 2;
		super(s, x, y, w, h);
		_currentInstr = 0;
	}

	override void draw()
	{
		fgcolor = active ? Color.ActiveFg : Color.InactiveFg;
		bgcolor = active ? Color.ActiveBg : Color.InactiveBg;
		box(0, 0, width, height, bgcolor);
		text(23, 1, "Ins");
		textf(23, 2, "-%02X", _currentInstr);

		foreach (i; 0 .. 21)
		{
			InstrumentTick tick = _tmc.instruments[_currentInstr].ticks[i];
			bar(1 + i, 5, tick.lvolume, Color.Bar,
				active ? Color.ActiveHighlightBg : Color.InactiveHighlightBg, 0, 2);
			bar(1 + i, 9, tick.rvolume, Color.Bar,
				active ? Color.ActiveHighlightBg : Color.InactiveHighlightBg, 0, 2);
			textf(1 + i, 10, "%1X", tick.distortion);
			textf(1 + i, 11, "%1X", tick.effect);
			textf(1 + i, 12, "%1X", tick.parameter >> 4);
			textf(1 + i, 13, "%1X", tick.parameter & 0xf);
		}

		foreach (i; 0 .. 9)
			textf(26, 5 + i, "%02X", _tmc.instruments[_currentInstr].params[i]);

		foreach (i; 0 .. 8)
			textf(23, 6 + i, "%02x", _tmc.instruments[_currentInstr].arp[i]);
		if (active)
			drawCursor();
	}

	void drawCursor()
	{
	}

	override bool key(SDLKey key, SDLMod mod)
	{
		if (key == SDLKey.SDLK_PAGEUP)
		{
			_currentInstr = (_currentInstr - 1) & 0x3f;
			draw();
			return true;
		}
		else if (key == SDLKey.SDLK_PAGEDOWN)
		{
			_currentInstr = (_currentInstr + 1) & 0x3f;
			draw();
			return true;
		}
		return false;
	}

	void update(uint sl, uint pl)
	{
	}

	@property void tmc(TmcFile t) { _tmc = t; }
	@property void player(Player p) { _player = p; }

private:
	enum Color
	{
		ActiveBg = 0x382840,
		ActiveFg = 0xd8d0e0,
		ActiveHighlightFg = 0xffffff,
		ActiveHighlightBg = 0x403048,
		InactiveBg = 0x242028,
		InactiveFg = 0x808080,
		InactiveHighlightBg = 0x2c2830,
		ActiveOuterFg = 0xa8a0b0,
		InactiveOuterFg = 0x606060,
		Bar = 0xd0b030,
	}

	uint _currentInstr;
	TmcFile _tmc;
	Player _player;
}
