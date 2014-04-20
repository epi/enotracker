module textrender;

import std.string;

import sdl;

class TextRenderer
{
	uint fgcolor;
	uint bgcolor;

	this(Surface s)
	{
		_surface = s;
		_font = _defaultFont;
	}

	void setFont(in ubyte[] a, bool atascii = false)
	{
		assert(a.length == 0x400);
		if (atascii)
			_font = a.idup;
		else
			_font = (a[0x200 .. 0x300] ~ a[0x000 .. 0x200] ~ a[0x300 .. 0x400]).idup;
	}

	void text(uint fg, uint bg, uint x, uint y, in char[] t)
	{
		_surface.lock();
		scope(exit) _surface.unlock();
		uint sx = x * 8;
		uint sy = y * 8;
		foreach (char c; t)
		{
			uint addr = c * 8;
			foreach (l; 0 .. 8)
			{
				ubyte d = _font[addr + l];
				foreach (p; 0 .. 8)
				{
					_surface.putPixel(sx + p, sy + l, (d & 0x80) ? fg : bg);
					d <<= 1;
				}
			}
			sx += 8;
		}
	}
	
	void text(uint fg, uint x, uint y, in char[] t)
	{
		text(fg, bgcolor, x, y, t);
	}

	void text(uint x, uint y, in char[] t)
	{
		text(fgcolor, bgcolor, x, y, t);
	}

	void textf(A...)(uint fg, uint bg, uint x, uint y, in char[] fmt, A args)
	{
		text(fg, bg, x, y, format(fmt, args));
	}

	void textf(A...)(uint fg, uint x, uint y, in char[] fmt, A args)
	{
		text(fg, bgcolor, x, y, format(fmt, args));
	}

	void textf(A...)(uint x, uint y, in char[] fmt, A args)
	{
		text(fgcolor, bgcolor, x, y, format(fmt, args));
	}

	void box(uint x, uint y, uint w, uint h, uint col)
	{
		_surface.fillRect(
			SDL_Rect(
				cast(ushort) (x * 8), cast(ushort) (y * 8),
				cast(ushort) (w * 8), cast(ushort) (h * 8)), col);
	}

private:
	immutable(ubyte)[] _font;
	Surface _surface;

	uint _cursorX;
	uint _cursorY;
	uint _cursorW;

	static _defaultFont = cast(immutable(ubyte)[]) import("default.fnt");
}

struct TextWindow
{
	this(TextRenderer tr, uint xoffset, uint yoffset)
	{
		_tr = tr;
		_xo = xoffset;
		_yo = yoffset;
	}

	void text(uint fg, uint bg, uint x, uint y, in char[] t)
	{
		_tr.text(fg, bg, _xo + x, _yo + y, t);
	}

	void text(uint fg, uint x, uint y, in char[] t)
	{
		_tr.text(fg, _xo + x, _yo + y, t);
	}

	void text(uint x, uint y, in char[] t)
	{
		_tr.text(_xo + x, _yo + y, t);
	}

	void textf(A...)(uint fg, uint bg, uint x, uint y, in char[] fmt, A args)
	{
		_tr.textf(fg, bg, _xo + x, _yo + y, fmt, args);
	}

	void textf(A...)(uint fg, uint x, uint y, in char[] fmt, A args)
	{
		_tr.textf(fg, _xo + x, _yo + y, fmt, args);
	}

	void textf(A...)(uint x, uint y, in char[] fmt, A args)
	{
		_tr.textf(_xo + x, _yo + y, fmt, args);
	}

	void box(uint x, uint y, uint w, uint h, uint col)
	{
		_tr.box(_xo + x, _yo + y, w, h, col);
	}

	@property void fgcolor(uint fg) { _tr.fgcolor = fg; }
	@property uint fgcolor() const { return _tr.fgcolor; }
	@property void bgcolor(uint bg) { _tr.bgcolor = bg; }
	@property uint bgcolor() const { return _tr.bgcolor; }

private:
	TextRenderer _tr;
	uint _xo;
	uint _yo;
}

