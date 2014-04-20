module pattern;

import std.conv;

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
				r = Range(7, 8); break;
			case 2:
				r = Range(8, 9); break;
			case 3:
				r = Range(9, 10); break;
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

	@property void tmc(TmcFile t) { _tmc = t; }

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
	}

	TextWindow _tw;
	uint _h;
	uint _songLine;
	uint _pattLine;
	uint _maxLines;
	uint _centerLine;
	TmcFile _tmc;
	uint _cursorX;
	bool _active;
}
