module song;

import std.conv;

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
		_topLine = 0;
		_songLine = 0;
	}

	void draw()
	{
		_tw.fgcolor = _active ? Color.ActiveFg : Color.InactiveFg;
		_tw.bgcolor = _active ? Color.ActiveBg : Color.InactiveBg;
		uint hcolor = _active ? Color.ActiveHighlight : Color.InactiveFg;
		_tw.box(0, 0, 52, _h, _tw.bgcolor);
		foreach (chn; 0 .. 8)
			_tw.textf(hcolor, 4 + chn * 6, 1, "Trac%s", chn + 1);
		foreach (i; 0 .. _h - 4)
		{
			if (_topLine + i > _tmc.song.length)
				break;
			drawLine(_topLine + i);
		}
		if (_active)
			drawCursor();
	}

	void drawLine(uint line)
	{
		if (line < _topLine || line >= _topLine + _h - 4 || line > _tmc.song.length)
			return;
		_tw.bgcolor = _active ? Color.ActiveBg : Color.InactiveBg;
		uint i = line - _topLine;
		if (line == _songLine)
			_tw.fgcolor = _active ? Color.ActiveHighlight : Color.InactiveFg;
		else
			_tw.fgcolor = _active ? Color.ActiveFg : Color.InactiveFg;
		_tw.textf(1, 3 + i, "%02X", line);
		foreach (chn; 0 .. 8)
		{
			_tw.textf(4 + chn * 6, 3 + i, "%02X-%02X",
				_tmc.song[line][chn].pattn,
				_tmc.song[line][chn].transp);					
		}
	}

	ubyte getDigitUnderCursor()
	{
		uint chn = _cursorX / 4;
		final switch (_cursorX % 4)
		{
		case 0:
			return _tmc.song[_songLine][chn].pattn >> 4;
		case 1:
			return _tmc.song[_songLine][chn].pattn & 0xf;
		case 2:
			return _tmc.song[_songLine][chn].transp >> 4;
		case 3:
			return _tmc.song[_songLine][chn].transp & 0xf;
		}
	}

	void drawCursor()
	{
		uint scrx = (_cursorX / 2) * 3 + _cursorX % 2;
		ubyte v = getDigitUnderCursor();
		_tw.textf(0x305030, 0xffffff, 4 + scrx, 3 + _songLine - _topLine, "%1X", v);
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
			drawLine(_songLine);
			drawCursor();
			return true;
		}
		else if (key == SDLKey.SDLK_RIGHT)
		{
			if (mod & (SDLMod.KMOD_RCTRL | SDLMod.KMOD_LCTRL))
				_cursorX = (_cursorX + 4) & 0x1c;
			else
				_cursorX = (_cursorX + 1) & 0x1f;
			drawLine(_songLine);
			drawCursor();
			return true;
		}
		else if (key == SDLKey.SDLK_UP)
		{
			if (_songLine > 0)
			{
				--_songLine;
				if (_songLine >= _topLine)
				{
					drawLine(_songLine + 1);
					drawLine(_songLine);
				}
				else
				{
					--_topLine;
					draw();
				}
				drawCursor();
				notify();
				return true;
			}
		}
		else if (key == SDLKey.SDLK_DOWN)
		{
			if (_songLine < _tmc.song.length - 1)
			{
				++_songLine;
				if (_songLine - _topLine < _maxLines)
				{
					drawLine(_songLine - 1);
					drawLine(_songLine);
				}
				else
				{
					++_topLine;
					draw();
				}
				drawCursor();
				notify();
				return true;
			}
		}
		return false;
	}

	@property void tmc(TmcFile t) { _tmc = t; }

	alias Observer = void delegate(uint currentSongLine);

	void addObserver(Observer obs)
	{
		_observers ~= obs;
	}

private:
	void notify()
	{
		foreach (obs; _observers)
			obs(_songLine);
	}

	enum Color
	{
		ActiveBg = 0x284028,
		ActiveFg = 0xd0e0d0,
		ActiveHighlight = 0xffffff,
		InactiveBg = 0x202820,
		InactiveFg = 0x808080,
	}

	Observer[] _observers;
	TextWindow _tw;
	uint _cursorX;
	uint _h;
	uint _maxLines;
	uint _topLine;
	uint _songLine;
	bool _active = false;
	TmcFile _tmc;
	
}

