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
import std.math;

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
		enum w = 4 + 12 * 8;
		super(s, x, y, w, h);
		_centerLine = (h - 3) / 2;
		_maxLines = h - 2;
		_topLimit = 1;
		_bottomLimit = h - 1;
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

	override bool key(SDLKey key, SDLMod m, wchar unicode)
	{
		auto mod = m.packModifiers();
		auto km = KeyMod(key, mod);
		// bool selectionEmpty = _selection == Selection.init;

		if (km == KeyMod(SDLKey.SDLK_LEFT, Modifiers.none))
		{
			_selection = Selection.init;
			_cursorX = (_cursorX - 1) & 0x1f;
			_state.track = _cursorX / 4;
			goto redrawLine;
		}
		else if (km == KeyMod(SDLKey.SDLK_LEFT, Modifiers.ctrl))
		{
			_selection = Selection.init;
			_cursorX = (_cursorX - 1) & 0x1c;
			_state.track = _cursorX / 4;
			goto redrawLine;
		}
		else if (km == KeyMod(SDLKey.SDLK_RIGHT, Modifiers.none))
		{
			_selection = Selection.init;
			_cursorX = (_cursorX + 1) & 0x1f;
			_state.track = _cursorX / 4;
			goto redrawLine;
		}
		else if (km == KeyMod(SDLKey.SDLK_RIGHT, Modifiers.ctrl))
		{
			_selection = Selection.init;
			_cursorX = (_cursorX + 4) & 0x1c;
			_state.track = _cursorX / 4;
			goto redrawLine;
		}
		else if (!_state.followSong
		      || _state.playing == State.Playing.nothing
		      || _state.playing == State.Playing.note)
		{
			auto pos = _state.patternPosition;
			if (km == KeyMod(SDLKey.SDLK_UP, Modifiers.none) && pos > 0)
			{
				_selection = Selection.init;
				_state.patternPosition = pos - 1;
				return true;
			}
			if (km == KeyMod(SDLKey.SDLK_UP, Modifiers.shift) && pos > 0)
			{
				select(pos, pos > 0 ? pos - 1 : pos);
				return true;
			}
			else if (km == KeyMod(SDLKey.SDLK_DOWN, Modifiers.none) && pos < 0x3f)
			{
				_selection = Selection.init;
				_state.patternPosition = pos + 1;
				return true;
			}
			else if (km == KeyMod(SDLKey.SDLK_DOWN, Modifiers.shift) && pos <= 0x3f)
			{
				select(pos, pos < 0x3f ? pos + 1 : pos);
				return true;
			}
			else if (km == KeyMod(SDLKey.SDLK_PAGEUP, Modifiers.none) && pos > 0)
			{
				_selection = Selection.init;
				_state.patternPosition = pos > 8 ? pos - 8 : 0;
				return true;
			}
			else if (km == KeyMod(SDLKey.SDLK_PAGEUP, Modifiers.shift) && pos > 0)
			{
				select(pos, pos > 8 ? pos - 8 : 0);
				return true;
			}
			else if (km == KeyMod(SDLKey.SDLK_PAGEDOWN, Modifiers.none) && pos < 0x3f)
			{
				_selection = Selection.init;
				_state.patternPosition = pos > 0x37 ? 0x3f : pos + 8;
				return true;
			}
			else if (km == KeyMod(SDLKey.SDLK_PAGEDOWN, Modifiers.shift) && pos < 0x3f)
			{
				select(pos, pos > 0x37 ? 0x3f : pos + 8);
				return true;
			}
			else if (km == KeyMod(SDLKey.SDLK_HOME, Modifiers.none))
			{
				_selection = Selection.init;
				_state.patternPosition = 0;
				return true;
			}
			else if (km == KeyMod(SDLKey.SDLK_HOME, Modifiers.shift))
			{
				select(pos, 0);
				return true;
			}
			else if (km == KeyMod(SDLKey.SDLK_END, Modifiers.none))
			{
				_selection = Selection.init;
				_state.patternPosition = 0x3f;
				return true;
			}
			else if (km == KeyMod(SDLKey.SDLK_END, Modifiers.shift))
			{
				select(pos, 0x3f);
				return true;
			}
			else if (km == KeyMod(SDLKey.SDLK_a, Modifiers.ctrl))
			{
				Selection s = { track : _cursorX / 4, startPosition : 0, endPosition : 0x3f};
				_selection = s;
				goto redrawWindow;
			}
			else if (km == KeyMod(SDLKey.SDLK_c, Modifiers.ctrl))
			{
				auto pattern = _state.tmc.getPatternBySongPositionAndTrack(_state.songPosition, _cursorX / 4);
				_clipboard = pattern[][_selection.begin .. _selection.end].dup;
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

		if (mod == Modifiers.none)
		{
			uint col = _cursorX % 4;
			uint track = _cursorX / 4;
			if (col == 0)
			{
				uint note = noteKeys.get(key, 0);
				if (note >= 1)
				{
					note += _state.octave * 12;
					if (note <= 0x3f)
					{
						_player.playNote(note, _state.instrument, track);
						if (_state.editing)
						{
							_state.history.execute(this.new SetNoteCommand(
								_state.songPosition, _state.patternPosition, track, note, _state.instrument));
							return true;
						}
					}
					return false;
				}
			}
			else if (_state.editing)
			{
				int d = getHexDigit(key);
				if (0 <= d && d <= 15)
				{
					if (col == 3)
					{
						_state.history.execute(this.new SetCommandCommand(
							_state.songPosition, _state.patternPosition, track, d));
					}
					else
					{
						_state.history.execute(this.new SetVolumeCommand(
							_state.songPosition, _state.patternPosition, track,
								col == 1 ? Envelope.primary : Envelope.secondary, d));
					}
					goto redrawWindow;
				}
			}
		}

		if (_state.editing)
		{
			if (km == KeyMod(SDLKey.SDLK_v, Modifiers.ctrl))
			{
				_state.history.execute(this.new SwapLinesCommand(
					_state.songPosition, _state.patternPosition, _cursorX / 4, _clipboard.dup, true));
				return true;
			}
			else if (km == KeyMod(SDLKey.SDLK_BACKSPACE, Modifiers.none))
			{
				if (_selection == Selection.init)
				{
					_state.history.execute(this.new EraseNoteCommand(
						_state.songPosition, _state.patternPosition, _cursorX / 4, _cursorX % 4 == 3));
					goto redrawWindow;
				}
				else
				{
					auto cmd = this.new SwapLinesCommand(
						_state.songPosition, _selection.begin, _cursorX / 4,
						new Pattern.Line[_selection.end - _selection.begin], false);
					_selection = Selection.init;
					_state.history.execute(cmd);
					goto redrawWindow;
				}
			}
			else if (km == KeyMod(SDLKey.SDLK_DELETE, Modifiers.none))
			{
				auto patt = _state.tmc.getPatternBySongPositionAndTrack(_state.songPosition, _cursorX / 4);
				if (_selection == Selection.init)
				{
					_state.history.execute(this.new SwapLinesCommand(
						_state.songPosition, _state.patternPosition, _cursorX / 4,
						patt[][_state.patternPosition + 1 .. $] ~ Pattern.Line(), false));
					goto redrawWindow;
				}
				else
				{
					auto cmd = this.new SwapLinesCommand(
						_state.songPosition, _selection.begin, _cursorX / 4,
						patt[][_selection.end .. $] ~ new Pattern.Line[_selection.length], false);
					_selection = Selection.init;
					_state.history.execute(cmd);
					goto redrawWindow;
				}
			}
			else if (km == KeyMod(SDLKey.SDLK_INSERT, Modifiers.none))
			{
				auto patt = _state.tmc.getPatternBySongPositionAndTrack(_state.songPosition, _cursorX / 4);
				auto cmd = this.new SwapLinesCommand(
					_state.songPosition, _state.patternPosition, _cursorX / 4,
					Pattern.Line() ~ patt[][_state.patternPosition .. $ - 1], false);
				_selection = Selection.init;
				_state.history.execute(cmd);
				goto redrawWindow;
			}
		}

		return false;
redrawLine:
		// if (!selectionEmpty && _selection == Selection.init) goto redrawWindow;
redrawWindow:
		draw();
		return true;

disableEditing:
		_selection = Selection.init;
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
	abstract class PatternCommand : Command
	{
		this(uint songPosition, uint patternPosition, uint track)
		{
			_songPosition = songPosition;
			_patternPosition = patternPosition;
			_track = track;
		}

	protected:
		uint _songPosition;
		uint _patternPosition;
		uint _track;
	}

	class SwapLinesCommand : PatternCommand
	{
		this(uint songPosition, uint patternPosition, uint track, Pattern.Line[] lines, bool cursorPastSwappedLines)
		{
			super(songPosition, patternPosition, track);
			_lines = lines.dup;
			_cursorPastSwappedLines = cursorPastSwappedLines;
		}

		SubWindow execute(TmcFile tmc)
		{
			doIt(tmc, false);
			return this.outer;
		}

		SubWindow undo(TmcFile tmc)
		{
			doIt(tmc, true);
			return this.outer;
		}

	protected:
		void doIt(TmcFile tmc, bool back)
		{
			with (this.outer)
			{
				auto sp = _songPosition;
				auto pos = _patternPosition;
				auto patt = tmc.getPatternBySongPositionAndTrack(sp, _track);
				uint endpos = min(pos + _lines.length, 0x40);
				foreach (p; pos .. endpos)
					swap(_lines[p - pos], patt[p]);
				_state.setSongAndPatternPosition(sp,
					back || !_cursorPastSwappedLines ? pos : (endpos < 0x3f ? endpos : 0x3f));
			}
		}

		Pattern.Line[] _lines;
		bool _cursorPastSwappedLines;
	}

	class SetNoteCommand : SwapLinesCommand
	{
		this(uint songPosition, uint patternPosition, uint track, uint note, uint instrument)
		{
			auto patt = this.outer._state.tmc.getPatternBySongPositionAndTrack(songPosition, track);
			auto line = patt[patternPosition];
			line.note = cast(ubyte) note;
			line.instr = cast(ubyte) instrument;
			line.vol = 0x00;
			line.setVol = true;
			super(songPosition, patternPosition, track, [ line ], true);
		}
	}

	class EraseNoteCommand : SwapLinesCommand
	{
		this(uint songPosition, uint patternPosition, uint track, bool eraseCommand)
		{
			auto patt = this.outer._state.tmc.getPatternBySongPositionAndTrack(songPosition, track);
			auto line = patt[patternPosition];
			if (eraseCommand)
			{
				line.setCmd = false;
			}
			else
			{
				line.note = 0;
				line.instr = 0;
				line.setVol = false;
			}
			super(songPosition, patternPosition, track, [ line ], true);
		}
	}

	class SetCommandCommand : SwapLinesCommand
	{
		this(uint songPosition, uint patternPosition, uint track, uint cmd)
		{
			auto patt = this.outer._state.tmc.getPatternBySongPositionAndTrack(songPosition, track);
			auto line = patt[patternPosition];
			line.setCmd = true;
			line.cmd = cmd & 0xf;
			super(songPosition, patternPosition, track, [ line ], false);
		}
	}

	class SetVolumeCommand : SwapLinesCommand
	{
		this(uint songPosition, uint patternPosition, uint track, Envelope which, uint vol)
		{
			auto patt = this.outer._state.tmc.getPatternBySongPositionAndTrack(songPosition, track);
			auto line = patt[patternPosition];
			line.setVol = true;
			if (which == Envelope.primary)
				line.vol = (line.vol & 0xf) | ((~vol & 0xf) << 4);
			else if (which == Envelope.secondary)
				line.vol = (line.vol & 0xf0) | (~vol & 0xf);
			super(songPosition, patternPosition, track, [ line ], false);
		}
	}

	static struct Selection
	{
		uint track = uint.max;
		uint startPosition = uint.max;
		uint endPosition = uint.max;
		@property uint begin() const pure nothrow
		{
			return min(startPosition, endPosition);
		}
		@property uint end() const pure nothrow
		{
			return max(startPosition, endPosition) + 1;
		}
		@property uint length() const pure nothrow
		{
			return end - begin;
		}
	}

	void drawSelection()
	{
		if (_selection == Selection.init)
			return;
		uint top = min(_selection.startPosition, _selection.endPosition);
		uint height = abs(cast(int) (_selection.endPosition - _selection.startPosition)) + 1;
		frame(4 + _selection.track * 12, _centerLine - (_state.patternPosition - top) + 1,
			11, height, Color.ActiveFg);
	}

	void select(uint pos, uint newpos)
	{
		if (_selection == Selection.init)
		{
			_selection.track = _cursorX / 4;
			_selection.startPosition = pos;
		}
		_selection.endPosition = newpos;
		_state.patternPosition = newpos;
	}

	void drawCursor()
	{
		drawSelection();
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
		Selection = 0xd0ffe0,
	}

	uint _maxLines;
	uint _centerLine;
	uint _cursorX;
	State _state;
	Selection _selection;
	Player _player;
	Pattern.Line[] _clipboard;
}
