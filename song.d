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
import state;
import subwindow;
import tmc;

class SongEditor : SubWindow
{
	this(Surface s, uint x, uint y, uint h)
	{
		super(s, x, y, 52, h);
		_maxLines = h - 4;
		_centerLine = (h - 4) / 2;
		_position = 0;
	}

	override void draw()
	{
		fgcolor = active ? Color.ActiveFg : Color.InactiveFg;
		bgcolor = active ? Color.ActiveBg : Color.InactiveBg;
		box(0, 0, width, height, bgcolor);
		box(0, 3 + _centerLine, width, 1,
			active ? Color.ActiveHighlightBg : Color.InactiveHighlightBg);
		uint hcolor = active ? Color.ActiveHighlightFg : Color.InactiveFg;
		foreach (chn; 0 .. 8)
			textf(hcolor, 4 + chn * 6, 1, "Trac%s", chn + 1);
		foreach (i; 0 .. height - 4)
			drawLine(i, _position - _centerLine + i);
		if (active)
			drawCursor();
	}

	void drawLine(uint i, int pos)
	{
		if (pos < 0 || pos >= _state.tmc.song.length)
			return;
		bgcolor = active ? Color.ActiveBg : Color.InactiveBg;
		if (i == _centerLine)
		{
			fgcolor = active ? Color.ActiveHighlightFg : Color.InactiveFg;
			bgcolor = active ? Color.ActiveHighlightBg : Color.InactiveHighlightBg;
		}
		else
		{
			fgcolor = active ? Color.ActiveFg : Color.InactiveFg;
			bgcolor = active ? Color.ActiveBg : Color.InactiveBg;
		}
		textf(1, 3 + i, "%02X", pos);
		foreach (chn; 0 .. 8)
		{
			textf(4 + chn * 6, 3 + i, "%02X-%02X",
				_state.tmc.song[pos][chn].pattn,
				_state.tmc.song[pos][chn].transp);
		}
	}

	ubyte getDigitUnderCursor()
	{
		uint chn = _cursorX / 4;
		final switch (_cursorX % 4)
		{
		case 0:
			return _state.tmc.song[_position][chn].pattn >> 4;
		case 1:
			return _state.tmc.song[_position][chn].pattn & 0xf;
		case 2:
			return _state.tmc.song[_position][chn].transp >> 4;
		case 3:
			return _state.tmc.song[_position][chn].transp & 0xf;
		}
	}

	void drawCursor()
	{
		uint scrx = (_cursorX / 2) * 3 + _cursorX % 2;
		ubyte v = getDigitUnderCursor();
		textf(Color.ActiveHighlightBg, Color.ActiveHighlightFg,
			4 + scrx, 3 + _centerLine, "%1X", v);
	}

	override bool key(SDLKey key, SDLMod mod)
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
			if (_position < _state.tmc.song.length - 1)
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
			_player.playSong(_position == 0 ? 0 : _position - 1);
		}
		else if (key == SDLKey.SDLK_F12)
		{
			_player.playSong(_position + 1);
		}
		return false;
	}

	@property void state(State s) { _state = s; }
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
	uint _cursorX;
	uint _maxLines;
	uint _centerLine;
	uint _position;
	State _state;
	Player _player;
}
