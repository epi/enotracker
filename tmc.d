/**
	Load and save TMC music data.

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

module tmc;

import std.algorithm;
import std.bitmanip;
import std.format;
import std.range;
import std.string;
import std.system;

class Pattern
{
	static struct Line
	{
		mixin(bitfields!(
			ubyte, "note",     6,
			ubyte, "_pad1",    2,
			ubyte, "instr",    6,
			ubyte, "_pad2",    2,
			ubyte, "vol",      8,
			ubyte, "cmd",      4,
			bool,  "setVol",   1,
			bool,  "setCmd",   1,
			ubyte, "_pad3",    2));

		@property bool empty() const pure nothrow
		{
			return note == 0 && instr == 0 && !setVol && !setCmd;
		}

		void toString(scope void delegate(const(char)[]) sink) const
		{
			static string[] noteNames = [
				"C-", "C#", "D-", "D#", "E-", "F-",
				"F#", "G-", "G#", "A-", "A#", "H-" ];

			if (note == 0)
				sink("---");
			else
			{
				sink(noteNames[(note - 1) % 12]);
				formattedWrite(sink, "%d", (note - 1) / 12 + 1);
			}
			if (note > 0)
				formattedWrite(sink, " %02X", instr);
			else
				sink(" --");
			if (setVol)
				formattedWrite(sink, "  %02X", vol ^ 0xff);
			else
				sink("  --");
			if (setCmd)
				formattedWrite(sink, "%X", cmd);
			else
				sink(" ");
		}
	}

	@property inout(Line[0x40]) lines() inout { return _lines; }

	ref inout(Line) opIndex(size_t i) inout { return _lines[i]; }

private:
	ubyte[] pack() // const pure nothrow
	{
		ubyte[] result;
		ubyte emptyLines = 0;
		ubyte lastInstr = 0xff;
		foreach (const ref line; _lines)
		{
			if (line.empty)
			{
				++emptyLines;
				continue;
			}
			if (emptyLines)
			{
				result ~= 0xc0 | cast(ubyte) (emptyLines - 1);
				emptyLines = 0;
			}
			if (line.note > 0 && line.instr != lastInstr)
			{
				lastInstr = line.instr;
				result ~= 0x80 | lastInstr;
			}
			if (line.setCmd)
			{
				result ~= 0x40 | line.note;
				if (line.setVol)
				{
					result ~= 0x80 | line.cmd;
					result ~= line.vol;
				}
				else
					result ~= line.cmd;
			}
			else
			{
				result ~= line.note;
				result ~= line.vol;
			}
		}
		result ~= 0xff;
		return result;
	}

	Line[0x40] _lines;
}

class TmcException : Exception
{
	this(string a) { super("TMC Error: " ~ a); }
}

class TmcLoadException : TmcException
{
	this(string a) { super("Not a valid TMC file: " ~ a); }
}

align(1) struct SongEntry
{ 
	ubyte transp;
	ubyte pattn;

	@property bool empty() const pure nothrow
	{
		return transp == 0xff && pattn == 0xff;
	}
	
	@property string toString() const
	{
		return format("%02X-%02X", pattn, transp);
	}
}

struct SongLine
{
	SongEntry[8] chan;

	ref inout(SongEntry) opIndex(uint c) inout { return chan[7 - c]; }

	@property bool empty() const pure nothrow
	{
		return all!"a.empty"(chan[]);
	}

	@property bool last() const pure nothrow
	{
		return chan[7].pattn >= 0x80;
	}

	@property string toString() const
	{
		return chan[].retro().map!(x => x.toString())().join(" ");
	}
}

static assert(SongLine.sizeof == 16);

align(1) struct InstrumentTick
{
	ubyte[3] data;
	@property bool empty() const pure nothrow
	{
		return all!"a == 0"(data[]);
	}

	@property ubyte lvolume() const pure nothrow { return data[0] & 0xf; }
	@property ubyte rvolume() const pure nothrow { return data[1] & 0xf; }
	@property ubyte distortion() const pure nothrow { return data[0] >> 4; }
	@property ubyte effect() const pure nothrow { return data[1] >> 4; }
	@property ubyte parameter() const pure nothrow { return data[2]; }
}

align(1) struct Instrument
{
	InstrumentTick[21] ticks;
	align(1) ubyte[8] arp;
	align(1) ubyte[9] params;

	@property bool empty() const pure nothrow
	{
		return all!"a == 0"(params[]) && all!"a == 0"(arp[]) && all!"a.empty"(ticks[]);
	}
}

static assert(Instrument.sizeof == 80);

class TmcFile
{
	this()
	{
	}

	void load(const(ubyte)[] data)
	{
		if (data.length < 6)
			throw new TmcLoadException("File too short");
		if (data.peek!(ushort, Endian.littleEndian)() != 0xffff)
			throw new TmcLoadException("Missing DOS header");
		ushort start = data[2 .. 4].peek!(ushort, Endian.littleEndian)();
		ushort end = data[4 .. 6].peek!(ushort, Endian.littleEndian)();
		if (end < start)
			throw new TmcLoadException("Invalid load address range");
		if (end - start + 7 != data.length)
			throw new TmcLoadException("File length does not match header");
		data = data[6 .. $];
		if (data.length < TmcData.sizeof)
			throw new TmcLoadException("Data too short");
		auto main = cast(const(TmcData)*) data.ptr;
		_title[] = main.title;
		_speed = main.speed;
		_fastplay = main.fastplay;

		// read song data
		auto songData = cast(const(SongLine)[]) data[TmcData.sizeof .. $ & ~15];
		auto songLength = songData.countUntil!(line => line.last)();
		if (songLength < 0)
			throw new TmcLoadException("Invalid song data");
		_song = songData[0 .. songLength + 1].dup;

		// read instrument data
		foreach (ins; 0 .. 0x40)
		{
			size_t addr = (main.instrh[ins] << 8) | main.instrl[ins];
			if (addr != 0)
			{
				addr -= start;
				if (addr > data.length
				 || addr + Instrument.sizeof > data.length)
					throw new TmcLoadException(
						format("Instrument %02X address out of range", ins));
				_instruments[ins] =
					* cast(const(Instrument)*) data[addr .. $];
			}
		}

		// read pattern data
		foreach (pat; 0 .. 0x80)
		{
			size_t addr = (main.patth[pat] << 8) | main.pattl[pat];
			if (addr != 0)
			{
				addr -= start;
				if (addr > data.length)
					throw new TmcLoadException(
						format("Pattern %02X address out of range", pat));
				_patterns[pat] = parsePattern(data[addr .. $]);
			}
		}
	}

	Pattern parsePattern(const(ubyte)[] data)
	{
		size_t line = 0;
		size_t i;
		ubyte instr;
		auto pat = new Pattern;
		bool x = false;
		while (i < data.length && line < 0x40)
		{
			ubyte c = data[i];
			ubyte t = c & 0xc0;
			ubyte p = c & 0x3f;
			final switch (t)
			{
			case 0x00:
				pat[line].note = p;
				pat[line].instr = instr;
				++i;
				if (i >= data.length)
					throw new TmcLoadException(
						format("Pattern %02X has incomplete data", pat));
				pat[line].setVol = true;
				pat[line].vol = data[i];
				++line;
				break;
			case 0x40:
				pat[line].note = p;
				pat[line].instr = instr;
				++i;
				if (i >= data.length)
					throw new TmcLoadException(
						format("Pattern %02X has incomplete data", pat));
				pat[line].setCmd = true;
				pat[line].cmd = data[i] & 0xf;
				if (data[i] & 0x80)
				{
					++i;
					if (i >= data.length)
						throw new TmcLoadException(
							format("Pattern %02X has incomplete data", pat));
					pat[line].setVol = true;
					pat[line].vol = data[i];
				}
				++line;
				break;
			case 0x80:
				instr = p;
				break;
			case 0xc0:
				line += p + 1;
				break;
			}
			++i;
		}
		return pat;
	}

	ubyte[] save(ushort addr, bool addHeader)
	{
		auto result = new ubyte[](TmcData.sizeof);

		TmcData main;
		main.title[] = _title[];
		main.speed = _speed;
		main.fastplay = _fastplay;

		result ~= cast(const(ubyte)[]) _song[];

		foreach (i, const ref instr; _instruments)
		{
			if (!instr.empty)
			{
				auto ia = addr + result.length;
				main.instrl[i] = (ia) & 0xff;
				main.instrh[i] = (ia >> 8) & 0xff;
				result ~= cast(const(ubyte)[]) (&instr)[0 .. 1];
			}
		}

		foreach (i, patt; _patterns)
		{
			auto pa = addr + result.length;
			main.pattl[i] = pa & 0xff;
			main.patth[i] = (pa >> 8) & 0xff;
			result ~= patt.pack();
		}

		*(cast(TmcData*) result.ptr) = main;

		if (!addHeader)
			return result;
		auto endaddr = addr + result.length - 1;
		ubyte[6] header = [ 0xff, 0xff, addr & 0xff, (addr >> 8) & 0xff,
			endaddr & 0xff, (endaddr >> 8) & 0xff ];
			return header[] ~ result;
	}

	@property inout(Instrument)[] instruments() inout { return _instruments; }
	@property inout(Pattern)[] patterns() inout { return _patterns; }
	@property inout(SongLine)[] song() inout { return _song; }

	@property ubyte speed() const { return _speed; }
	@property ubyte fastplay() const { return _fastplay; }

private:
	static struct TmcData
	{
		char[0x1e] title;
		ubyte speed;
		ubyte fastplay;
		ubyte[0x40] instrl;
		ubyte[0x40] instrh;
		ubyte[0x80] pattl;
		ubyte[0x80] patth;
	}
	static assert(TmcData.sizeof == 0x1a0);

	char[0x1e] _title;
	ubyte _speed;
	ubyte _fastplay;
	
	SongLine[] _song;
	Instrument[0x40] _instruments;
	Pattern[0x80] _patterns;
}

unittest
{
	auto fdata = cast(immutable(ubyte)[]) import("pongbl.tmc");
	auto tmc = new TmcFile;
	tmc.load(fdata);
	auto saved = tmc.save(0x2800, true);
	assert (fdata[] == saved[]);
}
