/**
	Scope window.

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

module oscilloscope;

import std.algorithm;
import std.conv;

import player;
import subwindow;
import tmc;

class Oscilloscope : SubWindow
{
	this(TextScreen s, uint x, uint y, uint w, uint h)
	{
		super(s, x, y, w + 2, h * 2 + 3);
		bgcolor = Color.box;
		fgcolor = Color.signal; 
	}

	override void draw()
	{
		box(0, 0, width, height, Color.bg);
		update();
	}

	void update(in short[] left = null, in short[] right = null)
	{
		plot(1, 1, left);
		plot(1, (height - 3) / 2 + 2, right);
	}

	@property void tmc(TmcFile t) { _tmc = t; }
	@property void player(Player p) { _player = p; }

private:
	enum Color
	{
		bg = 0x280404,
		box = 0x400000,
		signal = 0xff0000,
	}

	void plot(uint x, uint y, in short[] samples)
	{
/*		int w = width - 2;
		int h = (height - 3) / 2;
		
		uint sampleToHpos(int sample)
		{
			return (_yo + y) * 8 + (h * 4) - sample * h * 4 / 32768; 
		}

		box(x, y, w, h, bgcolor);
		auto f = fgcolor;
		if (samples.length)
		{
			uint prev = sampleToHpos(samples[0]);
			foreach (i, s; samples)
			{
				uint cur = sampleToHpos(s);
				int step = cur > prev ? 1 : -1;
				for (;;)
				{
					_surface.putPixel(
						cast(uint) ((_xo + x) * 8 + i * w * 8 / samples.length), prev, f);
					if (prev == cur)
						break;
					prev += step;
				}
			}
		}
		else
		{
			uint cur = sampleToHpos(0);
			foreach (i; 0 .. w * 8)
				_surface.putPixel((_xo + x) * 8 + i, cur, f);
		} */
	}

	uint _currentInstr;
	TmcFile _tmc;
	Player _player;
}
