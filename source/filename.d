/**
	General song info editor.

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

module filename;

import keys;
import subwindow;

class FileNameEditor : SubWindow
{
	this(TextScreen s, uint x, uint y, string currentName, void delegate(string, bool) closeHandler)
	{
		enum w = 100;
		enum h = 3;
		super(s, x, y, w, h);
		_name = currentName.dup;
		_closeHandler = closeHandler;
	}

	override void draw()
	{
		if (!active)
		{
			box(0, 0, width, height, 0);
			return;
		}
		fgcolor = Color.ActiveFg;
		bgcolor = Color.ActiveBg;
		box(0, 0, width, height, bgcolor);
		text(1, 1, "Save as:");
		text(Color.ActiveHighlightFg, 10, 1, _name);
		text(bgcolor, fgcolor, cast(uint) (10 + _name.length), 1, " ");
	}

	override bool key(SDLKey key, SDLMod mod, wchar unicode)
	{
		if (unicode >= 0x20 && unicode < 0x80)
		{
			_name ~= cast(char) unicode;
			draw();
			return true;
		}
		auto km = KeyMod(key, mod.packModifiers());
		if (km == KeyMod(SDLKey.SDLK_BACKSPACE, Modifiers.none))
		{
			if (_name.length > 0)
				_name = _name[0 .. $ - 1];
			draw();
			return true;
		}
		else if (km == KeyMod(SDLKey.SDLK_ESCAPE, Modifiers.none))
		{
			_closeHandler(_name.idup, false);
			return false;
		}
		else if (km == KeyMod(SDLKey.SDLK_RETURN, Modifiers.none))
		{
			_closeHandler(_name.idup, true);
			return false;
		}
		return false;
	}

private:
	enum Color
	{
		ActiveBg = 0x283840,
		ActiveFg = 0xd0d8e0,
		ActiveHighlightFg = 0xf0f0f0,
	}

	char[] _name;
	void delegate(string, bool) _closeHandler;
}
