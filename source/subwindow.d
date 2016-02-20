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

class TextScreen
{
	this(uint width, uint height)
	{
		_width = width;
		_height = height;
		_chars = new char[width * height];
	}

	void opIndexAssign(char c, uint x, uint y)
	{
		_chars[y * width + x] = c;
	}

	char opIndex(uint x, uint y) const
	{
		return _chars[y * width + x];
	}

	@property uint width() const pure nothrow { return _width; }
	@property uint height() const pure nothrow { return _height; }

private:
	uint _width;
	uint _height;
	char[] _chars;
}

class SubWindow
{
	this(TextScreen ts, uint x, uint y, uint width, uint height)
	{
		_textScreen = ts;
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

	bool key(SDLKey key, SDLMod mod, wchar unicode) { return false; }

	@property uint width() const pure nothrow { return _width; }
	@property uint height() const pure nothrow { return _height; }

protected:
	abstract void draw();

	void text(uint fg, uint bg, uint x, uint y, in char[] t)
	{
//		_surface.lock();
//		scope(exit) _surface.unlock();
		foreach (char c; t)
		{
/*			uint addr = c * 8;
			foreach (l; 0 .. 8)
			{
				ubyte d = _font[addr + l];
				foreach (p; 0 .. 8)
				{
					_surface.putPixel(sx + p, sy + l, (d & 0x80) ? fg : bg);
					d <<= 1;
				}
			}*/
			_textScreen[_xo + x, _yo + y] = c;
			++x;
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
/*		_surface.fillRect(
			SDL_Rect(
				cast(ushort) ((_xo + x) * 8), cast(ushort) ((_yo + y) * 8),
				cast(ushort) (w * 8), cast(ushort) (h * 8)), col);*/
	}

	static uint rgbAverage(uint col1, uint col2)
	{
		return (((col1 ^ col2) & 0xfffefefe) >>> 1) + (col1 & col2);
	}

	void bar(uint x, uint y, uint vol, uint colbar, uint colbak, uint hshift = 0)
	{
/*		enum step = 2;
		auto leftX = cast(ushort) ((_xo + x) * 8 + hshift);
		auto topY = cast(ushort) ((_yo + y) * 8 - 15 * step);
		auto botY = cast(ushort) (topY + 16 * step);
		auto barHeight = cast(ushort) (vol * step);
		auto remHeight = cast(ushort) ((15 - vol) * step);
		uint avgCol = rgbAverage(colbak, colbar);
		_surface.fillRect(SDL_Rect(leftX, topY, 8, remHeight), colbak);
		for (uint yy = topY + remHeight; yy < botY; yy += 2)
		{
			_surface.fillRect(SDL_Rect(leftX, cast(ushort) yy, 7, 1), colbar);
			_surface.fillRect(SDL_Rect(leftX, cast(ushort) (yy + 1), 7, 1), avgCol);
		}*/
	}

	void frame(int x, int y, int w, int h, uint col)
	{
/*		_surface.lock();
		scope(exit) _surface.unlock();
		int leftX = (_xo + x) * 8 - 2;
		int rightX = (_xo + x + w) * 8 + 1;
		if (y >= _topLimit && y < _bottomLimit)
		{
			foreach (xx; leftX .. rightX)
				_surface.putPixel(xx, (_yo + y) * 8 - 2, col);
		}
		if (y + h >= _topLimit && y + h < _bottomLimit)
		{
			foreach (xx; leftX .. rightX + 1)
				_surface.putPixel(xx, (_yo + y + h) * 8 + 1, col);
		}
		foreach (yy;
			(_yo + (y >= _topLimit ? y : _topLimit)) * 8 - 2 ..
			(_yo + (y + h >= _bottomLimit ? _bottomLimit : y + h)) * 8 + 1)
		{
			_surface.putPixel(leftX, yy, col);
			_surface.putPixel(rightX, yy, col);
		}*/
	}

	uint fgcolor;
	uint bgcolor;

protected:
	TextScreen _textScreen;
	uint _xo;
	uint _yo;

	int _topLimit;
	int _bottomLimit;

private:
	bool _active;
	SubWindow _next;
	uint _width;
	uint _height;
	static ubyte[1024] _font; // = cast(immutable(ubyte)[]) import("default.fnt");
}
