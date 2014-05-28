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

import command;
import keys;
import player;
import state;
import subwindow;
import tmc;

class PatternEditor : SubWindow
{
	this(Surface s, uint x, uint y, uint h)
	{
		enum w = 4 + 12 * 8 - 1;
		super(s, x, y, w, h);
		_centerLine = (h - 3) / 2;
		_maxLines = h - 2;
	}

	override void draw()
	{
		box(0, 0, width, height, active ? Color.ActiveBg : Color.InactiveBg);
		box(0, 1 + _centerLine, width, 1, active ? Color.ActiveHighlightBg : Color.InactiveHighlightBg);
		auto pos = _state.patternPosition;
		if (_state.playing == State.Playing.song || _state.playing == State.Playing.pattern)
		{
			foreach (chn; 0 .. 8)
			{
				uint pattn = _state.tmc.song[_state.songPosition][chn].pattn;
				if (pattn > 0x7f)
					continue;
				if (pos >= _state.tmc.patterns[pattn].actualLength)
					pos = _state.tmc.patterns[pattn].actualLength - 1;
			}
		}
		foreach (i; 0 .. _maxLines)
			drawLine(i, i + pos - _centerLine);
		if (active)
			drawCursor();
	}

	void drawLine(uint i, int drawPos)
	{
		uint sp = _state.songPosition;
		uint pos = _state.patternPosition;
		if (drawPos < 0)
		{
			if (sp == 0)
				return;
			--sp;
			drawPos = drawPos & 0x3f;
			fgcolor = active ? Color.ActiveOuterFg : Color.InactiveOuterFg;
			bgcolor = active ? Color.ActiveBg : Color.InactiveBg;
		}
		else if (drawPos > 0x3f)
		{
			++sp;
			if (sp >= _state.tmc.song.length)
				return;
			drawPos = drawPos & 0x3f;
			fgcolor = active ? Color.ActiveOuterFg : Color.InactiveOuterFg;
			bgcolor = active ? Color.ActiveBg : Color.InactiveBg;
		}
		else if (drawPos == pos)
		{
			fgcolor = active ? Color.ActiveHighlightFg : Color.InactiveFg;
			bgcolor = active ? Color.ActiveHighlightBg : Color.InactiveHighlightBg;
		}
		else
		{
			fgcolor = active ? Color.ActiveFg : Color.InactiveFg;
			bgcolor = active ? Color.ActiveBg : Color.InactiveBg;
		}
		textf(1, 1 + i, "%02X", drawPos);
		foreach (chn; 0 .. 8)
		{
			uint pattn = _state.tmc.song[sp][chn].pattn;
			if (pattn > 0x7f)
				continue;
			textf(4 + chn * 12, 1 + i, "%s", _state.tmc.patterns[pattn][drawPos]);
		}
	}

	void drawCursor()
	{
		uint chn = _cursorX / 4;
		uint pattn = _state.tmc.song[_state.songPosition][chn].pattn;
		auto str = pattn > 0x7f
			? "            "
			: to!string(_state.tmc.patterns[pattn][_state.patternPosition]);

		static struct Range { uint start; uint end; }
		Range r;
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
		textf(
			active ? Color.ActiveHighlightBg : Color.InactiveHighlightBg,
			active ? Color.ActiveHighlightFg : Color.InactiveFg,
			4 + chn * 12 + r.start, 1 + _centerLine, str[r.start .. r.end]);
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
		else if (km == KeyMod(SDLKey.SDLK_HOME, Modifiers.none))
		{
			_cursorX = 0;
			goto redrawLine;
		}
		else if (km == KeyMod(SDLKey.SDLK_END, Modifiers.none))
		{
			_cursorX = 0x1c;
			goto redrawLine;
		}
		else if (!_state.followSong
		      || _state.playing == State.Playing.nothing
		      || _state.playing == State.Playing.note)
		{
			auto pos = _state.patternPosition;
			if (km == KeyMod(SDLKey.SDLK_UP, Modifiers.none) && pos > 0)
			{
				_state.patternPosition = pos - 1;
				return true;
			}
			else if (km == KeyMod(SDLKey.SDLK_DOWN, Modifiers.none) && pos < 0x3f)
			{
				_state.patternPosition = pos + 1;
				return true;
			}
			else if (km == KeyMod(SDLKey.SDLK_PAGEUP, Modifiers.none) && pos > 0)
			{
				_state.patternPosition = pos > 8 ? pos - 8 : 0;
				return true;
			}
			else if (km == KeyMod(SDLKey.SDLK_PAGEDOWN, Modifiers.none) && pos < 0x3f)
			{
				_state.patternPosition = pos > 0x37 ? 0x3f : pos + 8;
				return true;
			}
			else if (km == KeyMod(SDLKey.SDLK_HOME, Modifiers.ctrl))
			{
				_cursorX = 0;
				_state.patternPosition = 0;
				goto redrawLine;
			}
			else if (km == KeyMod(SDLKey.SDLK_END, Modifiers.ctrl))
			{
				_cursorX = 0;
				_state.patternPosition = 0x3f;
				goto redrawLine;
			}
		}

		if (key == SDLKey.SDLK_RETURN)
		{
			switch (mod)
			{
			case Modifiers.none:
				_player.playPattern(_state.songPosition, _state.patternPosition);
				goto disableEditing;
			case Modifiers.shift:
				_player.playPattern(_state.songPosition, 0);
				goto disableEditing;
			default:
				return false;
			}
		}

		if (mod == Modifiers.none && _cursorX % 4 == 0)
		{
			uint note = noteKeys.get(key, 0);
			if (note >= 1)
			{
				note += _state.octave * 12;
				if (note <= 0x3f)
				{
					_player.playNote(note, _state.instrument, _cursorX / 4);
					if (_state.editing)
					{
						_state.history.execute(this.new SetNoteCommand(
							_state.songPosition, _state.patternPosition, _cursorX / 4, note, _state.instrument));
						goto redrawWindow;
					}
				}
				return false;
			}
		}
		return false;
redrawLine:
redrawWindow:
		draw();
		return true;

disableEditing:
		_state.editing = false;
		return true;
	}

	void drawBars(T)(in T[] chnvol)
	{
		foreach (i, vol; chnvol)
		{
			bar(cast(uint) i * 12 + 10, _centerLine + 1, vol, Color.Bar,
				active ? Color.ActiveBg : Color.InactiveBg, 4);
		}
	}

	@property void state(State s)
	{
		_state = s;
		s.addObserver("pattern", ()
			{
				if (_state.patternPosition != _state.oldPatternPosition
				 || _state.songPosition != _state.oldSongPosition)
					draw();
			});
	}

	@property void player(Player p) { _player = p; }

private:
	class SetNoteCommand : Command
	{
		this(uint songPosition, uint patternPosition, uint track, uint note, uint instrument)
		{
			_songPosition = songPosition;
			_patternPosition = patternPosition;
			_track = track;
			auto patt = this.outer._state.tmc.getPatternBySongPositionAndTrack(_songPosition, _track);
			_line = patt[patternPosition];
			_line.note = cast(ubyte) note;
			_line.instr = cast(ubyte) instrument;
			_line.vol = 0x00;
			_line.setVol = true;
		}

		SubWindow execute(TmcFile tmc)
		{
			doIt(tmc, 1);
			return this.outer;
		}

		SubWindow undo(TmcFile tmc)
		{
			doIt(tmc, 0);
			return this.outer;
		}

	private:
		void doIt(TmcFile tmc, uint incrementPatternPosition)
		{
			with (this.outer)
			{
				auto sp = _songPosition;
				auto pos = _patternPosition;
				auto patt = tmc.getPatternBySongPositionAndTrack(sp, _track);
				swap(patt[pos], _line);
				_state.setSongAndPatternPosition(sp, pos < 0x3f ? pos + incrementPatternPosition : pos);
			}
		}

		Pattern.Line _line;
		uint _songPosition;
		uint _patternPosition;
		uint _track;
	}

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

	uint _maxLines;
	uint _centerLine;
	Player _player;
	State _state;
	uint _cursorX;
}
