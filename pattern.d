/**
	Pattern editor.

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

module pattern;

import std.algorithm;
import std.conv;

import player;
import subwindow;
import textrender;
import tmc;

class PatternEditor : SubWindow
{
	this(TextRenderer tr, uint x, uint y, uint h)
	{
		_tw = TextWindow(tr, x, y);
		_h = h;
		_centerLine = (_h - 3) / 2;
		_songLine = 0;
		_maxLines = _h - 2;
	}

	void draw()
	{
		enum width = 4 + 12 * 8 - 1;
		_tw.box(0, 0, width, _h, _active ? Color.ActiveBg : Color.InactiveBg);
		_tw.box(0, 1 + _centerLine, width, 1, _active ? Color.ActiveHighlightBg : Color.InactiveHighlightBg);
		foreach (i; 0 .. _maxLines)
		{
			drawLine(i, i + _pattLine - _centerLine);
		}
		if (_active)
			drawCursor();
	}

	void drawLine(uint i, int line)
	{
		uint sl = _songLine;
		if (line < 0)
		{
			if (sl == 0)
				return;
			--sl;
			line = line & 0x3f;
			_tw.fgcolor = _active ? Color.ActiveOuterFg : Color.InactiveOuterFg;
			_tw.bgcolor = _active ? Color.ActiveBg : Color.InactiveBg;
		}
		else if (line > 0x3f)
		{
			++sl;
			if (sl >= _tmc.song.length)
				return;
			line = line & 0x3f;
			_tw.fgcolor = _active ? Color.ActiveOuterFg : Color.InactiveOuterFg;
			_tw.bgcolor = _active ? Color.ActiveBg : Color.InactiveBg;
		}
		else if (line == _pattLine)
		{
			_tw.fgcolor = _active ? Color.ActiveHighlightFg : Color.InactiveFg;
			_tw.bgcolor = _active ? Color.ActiveHighlightBg : Color.InactiveHighlightBg;
		}
		else
		{
			_tw.fgcolor = _active ? Color.ActiveFg : Color.InactiveFg;
			_tw.bgcolor = _active ? Color.ActiveBg : Color.InactiveBg;
		}
		_tw.textf(1, 1 + i, "%02X", line);
		foreach (chn; 0 .. 8)
		{
			uint pattn = _tmc.song[sl][chn].pattn;
			if (pattn > 0x7f)
				continue;
			_tw.textf(4 + chn * 12, 1 + i, "%s", _tmc.patterns[pattn][line]);
		}
	}

	void drawCursor()
	{
		static struct Range { uint start; uint end; }
		Range r;
		uint chn = _cursorX / 4;
		final switch (_cursorX % 4)
		{
			case 0:
				r = Range(0, 6); break;
			case 1:
				r = Range(8, 9); break;
			case 2:
				r = Range(9, 10); break;
			case 3:
				r = Range(10, 11); break;
		}
		uint pattn = _tmc.song[_songLine][chn].pattn;
		_tw.textf(
			_active ? Color.ActiveHighlightBg : Color.InactiveHighlightBg,
			_active ? Color.ActiveHighlightFg : Color.InactiveFg,
			4 + chn * 12 + r.start, 1 + _centerLine,
			to!string(_tmc.patterns[pattn][_pattLine])[r.start .. r.end]);
	}

	void activate()
	{
		_active = true;
		draw();
	}

	void deactivate()
	{
		_active = false;
		draw();
	}

	bool key(SDLKey key, SDLMod mod)
	{
		if (key == SDLKey.SDLK_LEFT)
		{
			if (mod & (SDLMod.KMOD_RCTRL | SDLMod.KMOD_LCTRL))
				_cursorX = (_cursorX - 1) & 0x1c;
			else
				_cursorX = (_cursorX - 1) & 0x1f;
			draw();
			return true;
		}
		else if (key == SDLKey.SDLK_RIGHT)
		{
			if (mod & (SDLMod.KMOD_RCTRL | SDLMod.KMOD_LCTRL))
				_cursorX = (_cursorX + 4) & 0x1c;
			else
				_cursorX = (_cursorX + 1) & 0x1f;
			draw();
			return true;
		}
		else if (key == SDLKey.SDLK_UP)
		{
			_pattLine = (_pattLine - 1) & 0x3f;
			draw();
			return true;
		}
		else if (key == SDLKey.SDLK_DOWN)
		{
			_pattLine = (_pattLine + 1) & 0x3f;
			draw();
			return true;
		}
		return false;
	}

	void changeSongLine(uint currentSongLine)
	{
		_songLine = currentSongLine;
		draw();
	}

	void update(uint sl, uint pl)
	{
		if (sl != _songLine || pl != _pattLine)
		{
			_songLine = sl;
			_pattLine = pl;
			draw();
		}
	}

	void drawBars(T)(in T[] chnvol)
	{
		foreach (i, vol; chnvol)
		{
			_tw.bar(cast(uint) i * 12 + 10, _centerLine + 1, vol, Color.Bar,
				_active ? Color.ActiveBg : Color.InactiveBg);
		}
	}

	@property void tmc(TmcFile t) { _tmc = t; }
	@property void player(Player p) { _player = p; }

private:
	enum Color
	{
		ActiveBg = 0x282840,
		ActiveFg = 0xd0d0e0,
		ActiveHighlightFg = 0xffffff,
		ActiveHighlightBg = 0x303048,
		InactiveBg = 0x202028,
		InactiveFg = 0x808080,
		InactiveHighlightBg = 0x282830,
		ActiveOuterFg = 0xa0a0b0,
		InactiveOuterFg = 0x606060,
		Bar = 0xe0c040,
	}

	TextWindow _tw;
	uint _h;
	uint _songLine;
	uint _pattLine;
	uint _maxLines;
	uint _centerLine;
	TmcFile _tmc;
	Player _player;
	uint _cursorX;
	bool _active;
}
