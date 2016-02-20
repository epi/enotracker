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

import command;
import keys;
import player;
import state;
import subwindow;
import tmc;

class InstrumentEditor : SubWindow
{
	this(TextScreen s, uint x, uint y)
	{
		enum w = 21 + 1 + 2 + 1 + 2 + 2;
		enum h = 4 * 2 + 1 + 4 + 2;
		super(s, x, y, w, h);
	}

	override void draw()
	{
		fgcolor = active ? Color.ActiveFg : Color.InactiveFg;
		bgcolor = active ? Color.ActiveBg : Color.InactiveBg;
		box(0, 0, width, height, bgcolor);
		text(23, 1, "Ins");
		textf(23, 2, "-%02X", _state.instrument);

		foreach (i; 0 .. 21)
		{
			InstrumentTick tick = _state.tmc.instruments[_state.instrument].ticks[i];
			bar(1 + i, 5, tick.lvolume, Color.Bar,
				active ? Color.ActiveHighlightBg : Color.InactiveHighlightBg);
			bar(1 + i, 9, tick.rvolume, Color.Bar,
				active ? Color.ActiveHighlightBg : Color.InactiveHighlightBg);
			textf(1 + i, 10, "%1X", tick.distortion);
			textf(1 + i, 11, "%1X", tick.effect);
			textf(1 + i, 12, "%1X", tick.parameter >> 4);
			textf(1 + i, 13, "%1X", tick.parameter & 0xf);
		}

		foreach (i; 0 .. 9)
			textf(26, 5 + i, "%02X", _state.tmc.instruments[_state.instrument].params[i]);

		foreach (i; 0 .. 8)
			textf(23, 6 + i, "%02x", _state.tmc.instruments[_state.instrument].arp[i]);
		if (active)
			drawCursor();
	}

	override bool key(SDLKey key, SDLMod m, wchar unicode)
	{
		auto mod = m.packModifiers();
		auto km = KeyMod(key, mod);
		if (mod == Modifiers.shift)
		{
			uint note = noteKeys.get(key, 0);
			if (note)
			{
				note += 12 * _state.octave;
				if (note > 63)
					note = 63;
				_player.playNote(note, _state.instrument, _state.track, _changed);
				_changed = false;
				return false;
			}
		}
		if (km == KeyMod(SDLKey.SDLK_PAGEUP, Modifiers.none))
		{
			_state.instrument = (_state.instrument - 1) & 0x3f;
			draw();
			return true;
		}
		else if (km == KeyMod(SDLKey.SDLK_PAGEDOWN, Modifiers.none))
		{
			_state.instrument = (_state.instrument + 1) & 0x3f;
			draw();
			return true;
		}
		else if (key == SDLKey.SDLK_LEFT) // deliberately ignore modifiers for easier navigation
		{
			if (_cursorX > 0)
			{
				--_cursorX;
				draw();
				return true;
			}
		}
		else if (key == SDLKey.SDLK_RIGHT) // deliberately ignore modifiers for easier navigation
		{
			if (_cursorX < 24)
			{
				++_cursorX;
				draw();
				return true;
			}
		}
		else if (km == KeyMod(SDLKey.SDLK_UP, Modifiers.none))
		{
			if (_cursorY > 0)
			{
				--_cursorY;
				draw();
				return true;
			}
		}
		else if (km == KeyMod(SDLKey.SDLK_DOWN, Modifiers.none))
		{
			if (_cursorY < 8)
			{
				++_cursorY;
				if (_cursorX < 21 && _cursorY < 6)
					_cursorY = 6;
				draw();
				return true;
			}
		}
		else if (km == KeyMod(SDLKey.SDLK_HOME, Modifiers.none))
		{
			_cursorX = 0;
			draw();
			return true;
		}
		else if (km == KeyMod(SDLKey.SDLK_END, Modifiers.none))
		{
			_cursorX = 20;
			draw();
			return true;
		}
		else if (km == KeyMod(SDLKey.SDLK_c, Modifiers.ctrl))
		{
			_clipboard = _state.tmc.instruments[_state.instrument];
			return false;
		}
		else if (_state.editing)
		{
			if (km == KeyMod(SDLKey.SDLK_UP, Modifiers.ctrl))
			{
				return changeVolume(Envelope.primary, 1);
			}
			else if (km == KeyMod(SDLKey.SDLK_DOWN, Modifiers.ctrl))
			{
				return changeVolume(Envelope.primary, -1);
			}
			else if (km == KeyMod(SDLKey.SDLK_UP, Modifiers.shift))
			{
				return changeVolume(Envelope.secondary, 1);
			}
			else if (km == KeyMod(SDLKey.SDLK_DOWN, Modifiers.shift))
			{
				return changeVolume(Envelope.secondary, -1);
			}
			else if (km == KeyMod(SDLKey.SDLK_PAGEUP, Modifiers.ctrl))
			{
				return liftEnvelope(Envelope.primary, 1);
			}
			else if (km == KeyMod(SDLKey.SDLK_PAGEDOWN, Modifiers.ctrl))
			{
				return liftEnvelope(Envelope.primary, -1);
			}
			else if (km == KeyMod(SDLKey.SDLK_PAGEUP, Modifiers.shift))
			{
				return liftEnvelope(Envelope.secondary, 1);
			}
			else if (km == KeyMod(SDLKey.SDLK_PAGEDOWN, Modifiers.shift))
			{
				return liftEnvelope(Envelope.secondary, -1);
			}
			else if (km == KeyMod(SDLKey.SDLK_v, Modifiers.ctrl))
			{
				_state.history.execute(this.new SwapEverythingCommand(
					_state.instrument, _clipboard));
				draw();
				return true;
			}
			else if (mod == Modifiers.none)
			{
				int d = getHexDigit(key);
				if (0 <= d && d <= 15)
				{
					_state.history.execute(this.new SetDigitCommand(
						_state.instrument, _cursorX, _cursorY, d));
					draw();
					return true;
				}
			}
		}
		return false;
	}

	@property void player(Player p) { _player = p; }
	@property void state(State s) { _state = s; }

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

	class ChangeVolumeCommand : Command
	{
		this(uint instrument, Envelope envelope, uint index, uint volume)
		{
			_instrument = instrument;
			_envelope = envelope;
			_index = index;
			_volume = volume;
		}

		SubWindow execute(TmcFile tmc)
		{
			Instrument *instr = &tmc.instruments[_instrument];
			uint temp = instr.ticks[_index].getVolume(_envelope);
			swap(temp, _volume);
			instr.ticks[_index].setVolume(_envelope, temp);
			this.outer._cursorX = _index;
			this.outer._changed = true;
			return this.outer;
		}

		SubWindow undo(TmcFile tmc)
		{
			return execute(tmc);
		}

	private:
		uint _instrument;
		Envelope _envelope;
		uint _index;
		uint _volume;
	}

	class SetDigitCommand : Command
	{
		this(uint instrument, uint x, uint y, uint digit)
		{
			_instrument = instrument;
			_x = x;
			_y = y;
			_digit = digit;
		}

		SubWindow execute(TmcFile tmc)
		{
			doIt(tmc);
			if (_x <= 19 || _x == 21 || _x == 23)
			{
				this.outer._cursorX = _x + 1;
				this.outer._cursorY = _y;
			}
			else if (_x == 22 || _x == 24)
			{
				this.outer._cursorX = _x - 1;
				this.outer._cursorY = _y < 8 ? _y + 1 : _y;
			}
			else
			{
				this.outer._cursorX = _x;
				this.outer._cursorY = _y;
			}
			return this.outer;
		}

		SubWindow undo(TmcFile tmc)
		{
			doIt(tmc);
			this.outer._cursorX = _x;
			this.outer._cursorY = _y;
			return this.outer;
		}

	private:
		void doIt(TmcFile tmc)
		{
			Instrument *instr = &tmc.instruments[_instrument];
			uint temp = getDigitUnderCursor(tmc, _instrument, _x, _y);
			swap(temp, _digit);
			setDigitUnderCursor(tmc, _instrument, _x, _y, temp);
			this.outer._state.instrument = _instrument;
			this.outer._changed = true;
		}

		uint _instrument;
		uint _x;
		uint _y;
		uint _digit;
	}

	class SwapEnvelopeCommand : Command
	{
		this(uint instrument, Envelope envelope, ubyte[21] volumes)
		{
			_instrument = instrument;
			_envelope = envelope;
			_volumes = volumes;
		}

		SubWindow execute(TmcFile tmc)
		{
			return doIt(tmc);
		}

		SubWindow undo(TmcFile tmc)
		{
			return doIt(tmc);
		}

	private:
		SubWindow doIt(TmcFile tmc)
		{
			Instrument *instr = &tmc.instruments[_instrument];
			ubyte[21] temp;
			instr.getEnvelope(_envelope, temp);
			swap(temp, _volumes);
			instr.setEnvelope(_envelope, temp);
			this.outer._state.instrument = _instrument;
			this.outer._changed = true;
			return this.outer;
		}

		uint _instrument;
		Envelope _envelope;
		ubyte[21] _volumes;
	}

	class SwapEverythingCommand : Command
	{
		this(uint instrument, Instrument swapped)
		{
			_instrument = instrument;
			_swapped = swapped;
		}

		SubWindow execute(TmcFile tmc)
		{
			swap(_swapped, tmc.instruments[_instrument]);
			this.outer._state.instrument = _instrument;
			this.outer._changed = true;
			return this.outer;
		}

		SubWindow undo(TmcFile tmc)
		{
			return execute(tmc);
		}

	private:
		uint _instrument;
		Instrument _swapped;
	}

	bool liftEnvelope(Envelope e, int diff)
	{
		auto i = _state.instrument;
		Instrument *instr = &_state.tmc.instruments[i];
		ubyte[21] volumes;
		instr.getEnvelope(e, volumes);
		bool change = false;
		foreach (ref v; volumes)
		{
			int vol = v + diff;
			if (0 <= vol && vol <= 15)
			{
				v = cast(ubyte) vol;
				change = true;
			}
		}
		if (change)
		{
			_state.history.execute(this.new SwapEnvelopeCommand(
				_state.instrument, e, volumes));
			draw();
			return true;
		}
		return false;
	}

	bool changeVolume(Envelope e, int diff)
	{
		auto i = _state.instrument;
		Instrument *instr = &_state.tmc.instruments[i];
		int vol = instr.ticks[_cursorX].getVolume(e) + diff;
		if (!(0 <= vol && vol <= 15))
			return false;
		_state.history.execute(this.new ChangeVolumeCommand(
			_state.instrument, e, _cursorX, vol));
		draw();
		return true;
	}

	static uint getDigitUnderCursor(TmcFile tmc, uint instrument, uint x, uint y)
	{
		Instrument* instr = &tmc.instruments[instrument];
		if (x < 21)
		{
			switch (y)
			{
			case 8:
				return instr.ticks[x].parameter & 0xf;
			case 7:
				return instr.ticks[x].parameter >> 4;
			case 6:
				return instr.ticks[x].effect;
			default:
				return instr.ticks[x].distortion;
			}
		}
		else if (x == 21)
			return instr.arp[y > 0 ? y - 1 : 0] >> 4;
		else if (x == 22)
			return instr.arp[y > 0 ? y - 1 : 0] & 0xf;
		else if (x == 23)
			return instr.params[y] >> 4;
		else if (x == 24)
			return instr.params[y] & 0xf;
		assert(0);
	}

	static void setDigitUnderCursor(TmcFile tmc, uint instrument, uint x, uint y, uint digit)
	{
		Instrument* instr = &tmc.instruments[instrument];
		if (x < 21)
		{
			switch (y)
			{
			case 8:
				instr.ticks[x].parameter = (instr.ticks[x].parameter & 0xf0) | (digit & 0xf);
				break;
			case 7:
				instr.ticks[x].parameter = (instr.ticks[x].parameter & 0x0f) | ((digit & 0xf) << 4);
				break;
			case 6:
				instr.ticks[x].effect = digit;
				break;
			default:
				instr.ticks[x].distortion = digit;
				break;
			}
		}
		else if (x == 21)
		{
			if (y > 0)
				--y;
			instr.arp[y] = (instr.arp[y] & 0x0f) | ((digit & 0xf) << 4);
		}
		else if (x == 22)
		{
			if (y > 0)
				--y;
			instr.arp[y] = (instr.arp[y] & 0xf0) | (digit & 0xf);
		}
		else if (x == 23)
			instr.params[y] = (instr.params[y] & 0x0f) | ((digit & 0xf) << 4);
		else if (x == 24)
			instr.params[y] = (instr.params[y] & 0xf0) | (digit & 0xf);
	}

	@property uint screenX() pure nothrow const
	{
		if (_cursorX < 21)
			return _cursorX + 1;
		if (_cursorX < 23)
			return _cursorX + 2;
		return _cursorX + 3;
	}

	@property uint screenY() pure nothrow const
	{
		if (_cursorX < 21)
			return _cursorY >= 5 ? _cursorY + 5 : 10;
		if (_cursorX < 23)
			return _cursorY >= 1 ? _cursorY + 5 : 6;
		return _cursorY + 5;
	}

	void drawCursor()
	{
		uint d = getDigitUnderCursor(_state.tmc, _state.instrument, _cursorX, _cursorY);
		uint sx = screenX;
		uint sy = screenY;
		textf(bgcolor, fgcolor, sx, sy, "%X", d);
	}

	Player _player;
	State _state;
	uint _cursorX;
	uint _cursorY = 5;
	bool _changed;
	Instrument _clipboard;
}
