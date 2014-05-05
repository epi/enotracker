/**
	Song editor.

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

module song;

import std.conv;

import player;
import subwindow;
import textrender;
import tmc;

class SongEditor : SubWindow
{
	this(TextRenderer tr, uint x, uint y, uint h)
	{
		_tw = TextWindow(tr, x, y);
		_h = h;
		_maxLines = _h - 4;
		_centerLine = (_h - 4) / 2;
		_position = 0;
	}

	void draw()
	{
		enum width = 52;
		_tw.fgcolor = _active ? Color.ActiveFg : Color.InactiveFg;
		_tw.bgcolor = _active ? Color.ActiveBg : Color.InactiveBg;
		_tw.box(0, 0, width, _h, _tw.bgcolor);
		_tw.box(0, 3 + _centerLine, width, 1,
			_active ? Color.ActiveHighlightBg : Color.InactiveHighlightBg);
		uint hcolor = _active ? Color.ActiveHighlightFg : Color.InactiveFg;
		foreach (chn; 0 .. 8)
			_tw.textf(hcolor, 4 + chn * 6, 1, "Trac%s", chn + 1);
		foreach (i; 0 .. _h - 4)
			drawLine(i, _position - _centerLine + i);
		if (_active)
			drawCursor();
	}

	void drawLine(uint i, int pos)
	{
		if (pos < 0 || pos >= _tmc.song.length)
			return;
		_tw.bgcolor = _active ? Color.ActiveBg : Color.InactiveBg;
		if (i == _centerLine)
		{
			_tw.fgcolor = _active ? Color.ActiveHighlightFg : Color.InactiveFg;
			_tw.bgcolor = _active ? Color.ActiveHighlightBg : Color.InactiveHighlightBg;
		}
		else
		{
			_tw.fgcolor = _active ? Color.ActiveFg : Color.InactiveFg;
			_tw.bgcolor = _active ? Color.ActiveBg : Color.InactiveBg;
		}
		_tw.textf(1, 3 + i, "%02X", pos);
		foreach (chn; 0 .. 8)
		{
			_tw.textf(4 + chn * 6, 3 + i, "%02X-%02X",
				_tmc.song[pos][chn].pattn,
				_tmc.song[pos][chn].transp);
		}
	}

	ubyte getDigitUnderCursor()
	{
		uint chn = _cursorX / 4;
		final switch (_cursorX % 4)
		{
		case 0:
			return _tmc.song[_position][chn].pattn >> 4;
		case 1:
			return _tmc.song[_position][chn].pattn & 0xf;
		case 2:
			return _tmc.song[_position][chn].transp >> 4;
		case 3:
			return _tmc.song[_position][chn].transp & 0xf;
		}
	}

	void drawCursor()
	{
		uint scrx = (_cursorX / 2) * 3 + _cursorX % 2;
		ubyte v = getDigitUnderCursor();
		_tw.textf(Color.ActiveHighlightBg, Color.ActiveHighlightFg,
			4 + scrx, 3 + _centerLine, "%1X", v);
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
			drawLine(_centerLine, _position);
			drawCursor();
			return true;
		}
		else if (key == SDLKey.SDLK_RIGHT)
		{
			if (mod & (SDLMod.KMOD_RCTRL | SDLMod.KMOD_LCTRL))
				_cursorX = (_cursorX + 4) & 0x1c;
			else
				_cursorX = (_cursorX + 1) & 0x1f;
			drawLine(_centerLine, _position);
			drawCursor();
			return true;
		}
		else if (key == SDLKey.SDLK_UP)
		{
			if (_position > 0)
			{
				--_position;
				draw();
				drawCursor();
				notify();
				return true;
			}
		}
		else if (key == SDLKey.SDLK_DOWN)
		{
			if (_position < _tmc.song.length - 1)
			{
				++_position;
				draw();
				drawCursor();
				notify();
				return true;
			}
		}
		else if (key == SDLKey.SDLK_RETURN)
		{
			if (mod & (SDLMod.KMOD_RSHIFT | SDLMod.KMOD_LSHIFT))
				_player.playSong(0);
			else
				_player.playSong(_position);
		}
		else if (key == SDLKey.SDLK_F10)
		{
			if (_player.playing)
				_player.playSong(_position == 0 ? 0 : _position - 1);
		}
		else if (key == SDLKey.SDLK_F12)
		{
			if (_player.playing)
				_player.playSong(_position + 1);
		}
		return false;
	}

	@property void tmc(TmcFile t) { _tmc = t; }
	@property void player(Player p) { _player = p; }

	alias Observer = void delegate(uint currentSongLine);

	void addObserver(Observer obs)
	{
		_observers ~= obs;
	}

	void update(uint pos)
	{
		if (pos != _position)
		{
			_position = pos;
			draw();
		}
	}

private:
	void notify()
	{
		foreach (obs; _observers)
			obs(_position);
	}

	enum Color
	{
		ActiveBg = 0x284028,
		ActiveFg = 0xd0e0d0,
		ActiveHighlightFg = 0xffffff,
		ActiveHighlightBg = 0x304830,
		InactiveBg = 0x202820,
		InactiveFg = 0x808080,
		InactiveHighlightBg = 0x283028,
	}

	Observer[] _observers;
	TextWindow _tw;
	uint _cursorX;
	uint _h;
	uint _maxLines;
	uint _centerLine;
	uint _position;
	bool _active = false;
	TmcFile _tmc;
	Player _player;
}
