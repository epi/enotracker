/**
	Interface for subwindows in main enotracker window.

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

import std.string;

import sdl;
public import sdl: Surface, SDLKey, SDLMod;

class SubWindow
{
	this(Surface s, uint x, uint y, uint width, uint height)
	{
		_surface = s;
		_xo = x;
		_yo = y;
		_width = width;
		_height = height;
	}

	@property bool active() const pure nothrow { return _active; }

	@property void active(bool a)
	{
		_active = a;
		draw();
	}

	@property SubWindow next()
	{
		if (!_next)
			throw new Exception("Next SubWindow not assigned");
		return _next;
	}

	@property void next(SubWindow sw) { _next = sw; }

	abstract bool key(SDLKey key, SDLMod mod);

	@property uint width() const pure nothrow { return _width; }
	@property uint height() const pure nothrow { return _height; }

protected:
	abstract void draw();

	void text(uint fg, uint bg, uint x, uint y, in char[] t)
	{
		_surface.lock();
		scope(exit) _surface.unlock();
		uint sx = (_xo + x) * 8;
		uint sy = (_yo + y) * 8;
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
				cast(ushort) ((_xo + x) * 8), cast(ushort) ((_yo + y) * 8),
				cast(ushort) (w * 8), cast(ushort) (h * 8)), col);
	}

	void bar(uint x, uint y, uint vol, uint colbar, uint colbak, uint hshift = 0, uint step = 2)
	{
		_surface.fillRect(SDL_Rect(
			cast(ushort) ((_xo + x) * 8 + hshift), cast(ushort) ((_yo + y) * 8 - 15 * step),
			8, cast(ushort) ((15 - vol) * step)), colbak);
		_surface.fillRect(SDL_Rect(
			cast(ushort) ((_xo + x) * 8 + hshift), cast(ushort) ((_yo + y) * 8 - vol * step),
			8, cast(ushort) (vol * step)), colbar);
	}

	uint fgcolor;
	uint bgcolor;

protected:
	Surface _surface;
	uint _xo;
	uint _yo;

private:
	bool _active;
	SubWindow _next;
	uint _width;
	uint _height;
	static _font = cast(immutable(ubyte)[]) import("default.fnt");
}
