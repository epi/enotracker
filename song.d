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

import command;
import keys;
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

	static ubyte getDigitUnderCursor(TmcFile tmc, uint position, uint cursorX)
	{
		uint chn = cursorX / 4;
		final switch (cursorX % 4)
		{
		case 0:
			return tmc.song[position][chn].pattn >> 4;
		case 1:
			return tmc.song[position][chn].pattn & 0xf;
		case 2:
			return tmc.song[position][chn].transp >> 4;
		case 3:
			return tmc.song[position][chn].transp & 0xf;
		}
	}

	static void setDigitUnderCursor(TmcFile tmc, uint position, uint cursorX, uint digit)
	{
		uint chn = cursorX / 4;
		final switch (cursorX % 4)
		{
		case 0:
			tmc.song[position][chn].pattn = cast(ubyte) ((tmc.song[position][chn].pattn & 0xf) | (digit << 4));
			break;
		case 1:
			tmc.song[position][chn].pattn = cast(ubyte) ((tmc.song[position][chn].pattn & 0xf0) | digit);
			break;
		case 2:
			tmc.song[position][chn].transp = cast(ubyte) ((tmc.song[position][chn].transp & 0xf) | (digit << 4));
			break;
		case 3:
			tmc.song[position][chn].transp = cast(ubyte) ((tmc.song[position][chn].transp & 0xf0) | digit);
		}
	}

	ubyte getDigitUnderCursor()
	{
		return getDigitUnderCursor(_state.tmc, _position, _cursorX);
	}

	void drawCursor()
	{
		uint scrx = (_cursorX / 2) * 3 + _cursorX % 2;
		ubyte v = getDigitUnderCursor();
		textf(Color.ActiveHighlightBg, Color.ActiveHighlightFg,
			4 + scrx, 3 + _centerLine, "%1X", v);
	}

	override bool key(SDLKey key, SDLMod m)
	{
		auto mod = m.packModifiers();
		auto km = KeyMod(key, mod);

		if (km == KeyMod(SDLKey.SDLK_LEFT, Modifiers.none))
		{
			_cursorX = (_cursorX - 1) & 0x1f;
			goto redrawLine;
		}
		else if (km == KeyMod(SDLKey.SDLK_LEFT, Modifiers.ctrl))
		{
			_cursorX = (_cursorX - 1) & 0x1c;
			goto redrawLine;
		}
		else if (km == KeyMod(SDLKey.SDLK_RIGHT, Modifiers.none))
		{
			_cursorX = (_cursorX + 1) & 0x1f;
			goto redrawLine;
		}
		else if (km == KeyMod(SDLKey.SDLK_RIGHT, Modifiers.ctrl))
		{
			_cursorX = (_cursorX + 4) & 0x1c;
			goto redrawLine;
		}
		else if (km == KeyMod(SDLKey.SDLK_UP, Modifiers.none)
		      && _position > 0
		      && !(_state.playing != State.Playing.nothing && _state.followSong))
		{
			--_position;
			goto redrawWindow;
		}
		else if (km == KeyMod(SDLKey.SDLK_DOWN, Modifiers.none)
		      && _position < _state.tmc.song.length - 1
		      && !(_state.playing != State.Playing.nothing && _state.followSong))
		{
			++_position;
			goto redrawWindow;
		}
		else if (km == KeyMod(SDLKey.SDLK_PAGEUP, Modifiers.none)
		      && _position > 0
		      && !(_state.playing != State.Playing.nothing && _state.followSong))
		{
			if (_position > _centerLine)
				_position -= _centerLine;
			else
				_position = 0;
			goto redrawWindow;
		}
		else if (km == KeyMod(SDLKey.SDLK_PAGEDOWN, Modifiers.none)
		      && _position < _state.tmc.song.length - 1
		      && !(_state.playing != State.Playing.nothing && _state.followSong))
		{
			_position += _centerLine;
			if (_position >= _state.tmc.song.length)
				_position = cast(uint) (_state.tmc.song.length - 1);
			goto redrawWindow;
		}
		else if (key == SDLKey.SDLK_RETURN || key == SDLKey.SDLK_KP_ENTER || key == SDLKey.SDLK_F11)
		{
			switch (mod)
			{
			case Modifiers.none:
				_player.playSong(_position);
				goto disableEditing;
			case Modifiers.shift:
				_player.playSong(0);
				goto disableEditing;
			default:
				break;
			}
		}
		else if (km == KeyMod(SDLKey.SDLK_F10, Modifiers.none)
		      && _state.playing == State.Playing.song)
		{
			_player.playSong(_position == 0 ? 0 : _position - 1);
			return false;
		}
		else if (km == KeyMod(SDLKey.SDLK_F11, Modifiers.none)
		      && _state.playing == State.Playing.song)
		{
			_player.playSong(_position);
			return false;
		}
		else if (km == KeyMod(SDLKey.SDLK_F12, Modifiers.none)
		      && _state.playing == State.Playing.song)
		{
			_player.playSong(_position >= _state.tmc.song.length - 1 ? _position : _position + 1);
			return false;
		}
		else if (_state.editing)
		{
			if (km == KeyMod(SDLKey.SDLK_INSERT, Modifiers.none) && _state.tmc.song.length < Song.maxLength)
			{
				_state.history.execute(new class(this, _position) Command
					{
						this(SongEditor se, uint songPosition)
						{
							_se = se;
							_songPosition = songPosition;
						}

						SubWindow execute(TmcFile tmc)
						{
							tmc.song.insert(_songPosition);
							_se._position = _songPosition;
							return _se;
						}

						SubWindow undo(TmcFile tmc)
						{
							tmc.song.erase(_songPosition);
							_se._position = _songPosition;
							return _se;
						}

					private:
						SongEditor _se;
						uint _songPosition;
					});
				goto redrawWindow;
			}
			else if (km == KeyMod(SDLKey.SDLK_DELETE, Modifiers.none) && _position < _state.tmc.song.length - 1)
			{
				_state.history.execute(new class(this, _position) Command
					{
						this(SongEditor se, uint songPosition)
						{
							_se = se;
							_songPosition = songPosition;
						}

						SubWindow execute(TmcFile tmc)
						{
							_deletedLine = tmc.song[_songPosition];
							tmc.song.erase(_songPosition);
							_se._position = _songPosition;
							return _se;
						}

						SubWindow undo(TmcFile tmc)
						{
							tmc.song.insert(_songPosition, _deletedLine);
							_se._position = _songPosition;
							return _se;
						}

					private:
						SongEditor _se;
						SongLine _deletedLine;
						uint _songPosition;
					});
				goto redrawWindow;
			}
			else
			{
				int digit = getHexDigit(key);
				if (digit >= 0
				 && (_cursorX == 0 || (_cursorX & 3) != 0 || digit < 8)
				 && (_position < _state.tmc.song.length - 1 || _cursorX == 2 || _cursorX == 3))
				{
					_state.history.execute(new class(this, _position, _cursorX, digit) Command
						{
							this(SongEditor se, uint songPosition, uint cursorPosition, uint digit)
							{
								_se = se;
								_songPosition = songPosition;
								_cursorPosition = cursorPosition;
								_digit = digit;
							}

							SubWindow execute(TmcFile tmc)
							{
								doExecute(tmc);
								_se._cursorX = (_se._cursorX + 1) % 32;
								_se.notify();
								return _se;
							}

							SubWindow undo(TmcFile tmc)
							{
								doExecute(tmc);
								_se.notify();
								return _se;
							}

						private:
							void doExecute(TmcFile tmc)
							{
								uint oldDigit = getDigitUnderCursor(tmc, _songPosition, _cursorPosition);
								setDigitUnderCursor(tmc, _songPosition, _cursorPosition, _digit);
								_digit = oldDigit;
								_se._position = _songPosition;
								_se._cursorX = _cursorPosition;
							}

							SongEditor _se;
							uint _songPosition;
							uint _cursorPosition;
							uint _digit;
						});
					goto redrawLine;
				}
			}
		}
		return false;

redrawLine:
		drawLine(_centerLine, _position);
		drawCursor();
		return true;

redrawWindow:
		notify();
		draw();
		drawCursor();
		return true;

disableEditing:
		_state.editing = false;
		return true;
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
