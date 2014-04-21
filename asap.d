/**
	Emulate POKEY and 6502 to generate waveforms for TMC music.

	Copyright:
	Generated from asap.ci, part of ASAP $(LINK http://asap.sf.net/).
	Copyright (C) 2010-2013  Piotr Fusik
	Modified by Adrian Matoga (C) 2014.
	This file is part of enotracker $(LINK https://github.com/epi/enotracker)

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

import std.utf;
import std.algorithm;

/// Atari 8-bit chip music emulator.
///
/// This class performs no I/O operations - all music data must be passed in byte arrays.
class ASAPTmc
{
	private int BlocksPlayed;

	private void Call6502(int addr)
	{
		this.Memory[53760] = 32;
		this.Memory[53761] = cast(ubyte) addr;
		this.Memory[53762] = cast(ubyte) (addr >> 8);
		this.Memory[53763] = 210;
		this.Cpu.Pc = 53760;
	}

	private void Call6502Player()
	{
		if (--this.TmcPerFrameCounter <= 0) {
			this.TmcPerFrameCounter = this.Memory[this.MusicAddr + 31];
			this.Call6502(this.PlayerAddr + 3);
		}
		else
			this.Call6502(this.PlayerAddr + 6);
	}

	private Cpu6502 Cpu;
	int PlayerAddr;
	int MusicAddr;
	int Fastplay;
	int Cycle;

	private int Do6502Frame()
	{
		this.NextEventCycle = 0;
		this.NextScanlineCycle = 0;
		this.Nmist = this.Nmist == NmiStatus.Reset ? NmiStatus.OnVBlank : NmiStatus.WasVBlank;
		int cycles = 35568;
		this.Cpu.DoFrame(this, cycles);
		this.Cycle -= cycles;
		if (this.NextPlayerCycle != 8388608)
			this.NextPlayerCycle -= cycles;
		if (this.Pokeys.Timer1Cycle != 8388608)
			this.Pokeys.Timer1Cycle -= cycles;
		if (this.Pokeys.Timer2Cycle != 8388608)
			this.Pokeys.Timer2Cycle -= cycles;
		if (this.Pokeys.Timer4Cycle != 8388608)
			this.Pokeys.Timer4Cycle -= cycles;
		return cycles;
	}

	private void Do6502Init(int pc, int a, int x, int y)
	{
		this.Cpu.Pc = pc;
		this.Cpu.A = a & 255;
		this.Cpu.X = x & 255;
		this.Cpu.Y = y & 255;
		this.Memory[53760] = 210;
		this.Memory[510] = 255;
		this.Memory[511] = 209;
		this.Cpu.S = 253;
		for (int frame = 0; frame < 50; frame++) {
			this.Do6502Frame();
			if (this.Cpu.Pc == 53760)
				return;
		}
		throw new Exception("INIT routine didn't return");
	}

	private int DoFrame()
	{
		this.Pokeys.StartFrame();
		int cycles = this.Do6502Frame();
		this.Pokeys.EndFrame(cycles);
		return cycles;
	}

	/// Fills the specified buffer with generated samples.
	/// Params:
	/// buffer = The destination buffer.
	/// bufferLen = Number of bytes to fill.
	/// format = Format of samples.
	final int Generate(ubyte[] buffer, int bufferLen, ASAPSampleFormat format)
	{
		return this.GenerateAt(buffer, 0, bufferLen, format);
	}

	private int GenerateAt(ubyte[] buffer, int bufferOffset, int bufferLen, ASAPSampleFormat format)
	{
		int blockShift = 1 + (format != ASAPSampleFormat.U8 ? 1 : 0);
		int bufferBlocks = bufferLen >> blockShift;
		int block = 0;
		for (;;) {
			int blocks = this.Pokeys.Generate(buffer, bufferOffset + (block << blockShift), bufferBlocks - block, format);
			this.BlocksPlayed += blocks;
			block += blocks;
			if (block >= bufferBlocks)
				break;
			int cycles = this.DoFrame();
			if (FrameCallback !is null)
				FrameCallback();
		}
		return block << blockShift;
	}

	/// Returns current playback position in blocks.
	///
	/// A block is one sample or a pair of samples for stereo.
	final int GetBlocksPlayed()
	{
		return this.BlocksPlayed;
	}

	/// Returns POKEY channel volume - an integer between 0 and 15.
	/// Params:
	/// channel = POKEY channel number (from 0 to 7).
	final int GetPokeyChannelVolume(int channel)
	{
		switch (channel) {
		case 0:
			return this.Pokeys.BasePokey.Audc1 & 15;
		case 1:
			return this.Pokeys.BasePokey.Audc2 & 15;
		case 2:
			return this.Pokeys.BasePokey.Audc3 & 15;
		case 3:
			return this.Pokeys.BasePokey.Audc4 & 15;
		case 4:
			return this.Pokeys.ExtraPokey.Audc1 & 15;
		case 5:
			return this.Pokeys.ExtraPokey.Audc2 & 15;
		case 6:
			return this.Pokeys.ExtraPokey.Audc3 & 15;
		case 7:
			return this.Pokeys.ExtraPokey.Audc4 & 15;
		default:
			return 0;
		}
	}

	/// Returns current playback position in milliseconds.
	final int GetPosition()
	{
		return this.BlocksPlayed * 10 / 441;
	}

	/// Fills leading bytes of the specified buffer with WAV file header.
	///
	/// Returns the number of changed bytes.
	/// Params:
	/// buffer = The destination buffer.
	/// format = Format of samples.
	/// metadata = Include metadata (title, author, date).
	final int GetWavHeader(ubyte[] buffer, ASAPSampleFormat format, bool metadata)
	{
		int use16bit = format != ASAPSampleFormat.U8 ? 1 : 0;
		int blockSize = 2 << use16bit;
		int bytesPerSecond = 44100 * blockSize;
		int totalBlocks = ASAPTmc.MillisecondsToBlocks(-1);
		int nBytes = (totalBlocks - this.BlocksPlayed) * blockSize;
		ASAPTmc.PutLittleEndian(buffer, 8, 1163280727);
		ASAPTmc.PutLittleEndians(buffer, 12, 544501094, 16);
		buffer[20] = 1;
		buffer[21] = 0;
		buffer[22] = 2;
		buffer[23] = 0;
		ASAPTmc.PutLittleEndians(buffer, 24, 44100, bytesPerSecond);
		buffer[32] = cast(ubyte) blockSize;
		buffer[33] = 0;
		buffer[34] = cast(ubyte) (8 << use16bit);
		buffer[35] = 0;
		int i = 36;
		if (metadata) {
			throw new Exception("Metadata not supported");
		}
		ASAPTmc.PutLittleEndians(buffer, 0, 1179011410, i + nBytes);
		ASAPTmc.PutLittleEndians(buffer, i, 1635017060, nBytes);
		return i + 8;
	}

	final void HandleEvent()
	{
		int cycle = this.Cycle;
		if (cycle >= this.NextScanlineCycle) {
			if (cycle - this.NextScanlineCycle < 50)
				this.Cycle = cycle += 9;
			this.NextScanlineCycle += 114;
			if (cycle >= this.NextPlayerCycle) {
				this.Call6502Player();
				this.NextPlayerCycle += 114 * this.Fastplay;
			}
		}
		int nextEventCycle = this.NextScanlineCycle;
		if (cycle >= this.Pokeys.Timer1Cycle) {
			this.Pokeys.Irqst &= ~1;
			this.Pokeys.Timer1Cycle = 8388608;
		}
		else if (nextEventCycle > this.Pokeys.Timer1Cycle)
			nextEventCycle = this.Pokeys.Timer1Cycle;
		if (cycle >= this.Pokeys.Timer2Cycle) {
			this.Pokeys.Irqst &= ~2;
			this.Pokeys.Timer2Cycle = 8388608;
		}
		else if (nextEventCycle > this.Pokeys.Timer2Cycle)
			nextEventCycle = this.Pokeys.Timer2Cycle;
		if (cycle >= this.Pokeys.Timer4Cycle) {
			this.Pokeys.Irqst &= ~4;
			this.Pokeys.Timer4Cycle = 8388608;
		}
		else if (nextEventCycle > this.Pokeys.Timer4Cycle)
			nextEventCycle = this.Pokeys.Timer4Cycle;
		this.NextEventCycle = nextEventCycle;
	}

	ubyte[] Memory;

	private static int MillisecondsToBlocks(int milliseconds)
	{
		return milliseconds * 441 / 10;
	}

	/// Mutes the selected POKEY channels.
	/// Params:
	/// mask = An 8-bit mask which selects POKEY channels to be muted.
	final void MutePokeyChannels(int mask)
	{
		this.Pokeys.BasePokey.Mute(mask);
		this.Pokeys.ExtraPokey.Mute(mask >> 4);
	}
	int NextEventCycle;
	private int NextPlayerCycle;
	private int NextScanlineCycle;
	private NmiStatus Nmist;

	final int PeekHardware(int addr)
	{
		switch (addr & 65311) {
		case 53268:
			return 1;
		case 53770:
		case 53786:
			return this.Pokeys.GetRandom(addr, this.Cycle);
		case 53774:
			return this.Pokeys.Irqst;
		case 53790:
			if (this.Pokeys.ExtraPokeyMask != 0) {
				return 255;
			}
			return this.Pokeys.Irqst;
		case 53772:
		case 53788:
		case 53775:
		case 53791:
			return 255;
		case 54283:
		case 54299:
			if (this.Cycle > 35568)
				return 0;
			return this.Cycle / 228;
		case 54287:
		case 54303:
			switch (this.Nmist) {
			case NmiStatus.Reset:
				return 31;
			case NmiStatus.WasVBlank:
				return 95;
			case NmiStatus.OnVBlank:
			default:
				return this.Cycle < 28291 ? 31 : 95;
			}
		default:
			return this.Memory[addr];
		}
	}

	/// Prepares playback of the specified song of the loaded module.
	/// Params:
	/// song = Zero-based song index.
	/// duration = Playback time in milliseconds, -1 means infinity.
	final void Play(int position)
	{
		this.NextPlayerCycle = 8388608;
		this.BlocksPlayed = 0;
		this.Cycle = 0;
		this.Cpu.Nz = 0;
		this.Cpu.C = 0;
		this.Cpu.Vdi = 0;
		this.Nmist = NmiStatus.OnVBlank;
		this.Pokeys.Initialize(false, true);
		this.MutePokeyChannels(255);

		this.Do6502Init(this.PlayerAddr, 112, this.MusicAddr >> 8, this.MusicAddr);
		this.Do6502Init(this.PlayerAddr, 16, position, 0);
		this.TmcPerFrameCounter = 1;

		this.MutePokeyChannels(0);
		this.NextPlayerCycle = 0;
	}

	final void PokeHardware(int addr, int data)
	{
		if (addr >> 8 == 210) {
			if ((addr & this.Pokeys.ExtraPokeyMask + 15) == 14) {
				this.Pokeys.Irqst |= data ^ 255;
				if ((data & this.Pokeys.Irqst & 1) != 0) {
					if (this.Pokeys.Timer1Cycle == 8388608) {
						int t = this.Pokeys.BasePokey.TickCycle1;
						while (t < this.Cycle)
							t += this.Pokeys.BasePokey.PeriodCycles1;
						this.Pokeys.Timer1Cycle = t;
						if (this.NextEventCycle > t)
							this.NextEventCycle = t;
					}
				}
				else
					this.Pokeys.Timer1Cycle = 8388608;
				if ((data & this.Pokeys.Irqst & 2) != 0) {
					if (this.Pokeys.Timer2Cycle == 8388608) {
						int t = this.Pokeys.BasePokey.TickCycle2;
						while (t < this.Cycle)
							t += this.Pokeys.BasePokey.PeriodCycles2;
						this.Pokeys.Timer2Cycle = t;
						if (this.NextEventCycle > t)
							this.NextEventCycle = t;
					}
				}
				else
					this.Pokeys.Timer2Cycle = 8388608;
				if ((data & this.Pokeys.Irqst & 4) != 0) {
					if (this.Pokeys.Timer4Cycle == 8388608) {
						int t = this.Pokeys.BasePokey.TickCycle4;
						while (t < this.Cycle)
							t += this.Pokeys.BasePokey.PeriodCycles4;
						this.Pokeys.Timer4Cycle = t;
						if (this.NextEventCycle > t)
							this.NextEventCycle = t;
					}
				}
				else
					this.Pokeys.Timer4Cycle = 8388608;
			}
			else
				this.Pokeys.Poke(addr, data, this.Cycle);
		}
		else if ((addr & 65295) == 54282) {
			int x = this.Cycle % 114;
			this.Cycle += (x <= 106 ? 106 : 220) - x;
		}
		else if ((addr & 65295) == 54287) {
			this.Nmist = this.Cycle < 28292 ? NmiStatus.OnVBlank : NmiStatus.Reset;
		}
		else
			this.Memory[addr] = cast(ubyte) data;
	}
	PokeyPair Pokeys;

	private static void PutLittleEndian(ubyte[] buffer, int offset, int value)
	{
		buffer[offset] = cast(ubyte) value;
		buffer[offset + 1] = cast(ubyte) (value >> 8);
		buffer[offset + 2] = cast(ubyte) (value >> 16);
		buffer[offset + 3] = cast(ubyte) (value >> 24);
	}

	private static void PutLittleEndians(ubyte[] buffer, int offset, int value1, int value2)
	{
		ASAPTmc.PutLittleEndian(buffer, offset, value1);
		ASAPTmc.PutLittleEndian(buffer, offset + 4, value2);
	}

	private static int PutWavMetadata(ubyte[] buffer, int offset, int fourCC, string value)
	{
		int len = cast(int) value.length;
		if (len > 0) {
			ASAPTmc.PutLittleEndians(buffer, offset, fourCC, (len | 1) + 1);
			offset += 8;
			for (int i = 0; i < len; i++)
				buffer[offset++] = cast(ubyte) value[i];
			buffer[offset++] = 0;
			if ((len & 1) == 0)
				buffer[offset++] = 0;
		}
		return offset;
	}
	/// Output sample rate.
	public static immutable(int) SampleRate = 44100;

	/// Changes the playback position.
	/// Params:
	/// position = The requested absolute position in milliseconds.
	final void Seek(int position)
	{
		this.SeekSample(ASAPTmc.MillisecondsToBlocks(position));
	}

	/// Changes the playback position.
	/// Params:
	/// block = The requested absolute position in samples (always 44100 per second, even in stereo).
	final void SeekSample(int block)
	{
		while (this.BlocksPlayed + this.Pokeys.ReadySamplesEnd < block) {
			this.BlocksPlayed += this.Pokeys.ReadySamplesEnd;
			this.DoFrame();
		}
		this.Pokeys.ReadySamplesStart = block - this.BlocksPlayed;
		this.BlocksPlayed = block;
	}
	private int TmcPerFrameCounter;
	private int PozptrAddr;

	void delegate() FrameCallback;

	this()
	{
		Cpu = new Cpu6502;
		Memory = new ubyte[65536];
		Pokeys = new PokeyPair;
		PlayerAddr = 0x500;
		FrameCallback = null;
		load(PlayerAddr, tmcPlayer);
		PozptrAddr = cast(int) (PlayerAddr + tmcPlayer.countUntil([ 0, 0, 4, 5, 6, 7, 0, 1, 2, 3 ]));
	}

	int GetPatternPosition()
	{
		int pos = Memory[PozptrAddr];
		if (pos == 0)
			return 0;
		return pos - 1;
	}

	int GetSongPosition()
	{
		int addr = Memory[0xfe] | (Memory[0xff] << 8);
		int pos = (addr - MusicAddr - 0x1a0) / 16;
		if (pos == 0)
			return 0;
		return pos - 1;
	}

	void load(int addr, in ubyte[] data)
	{
		Memory[addr .. addr + data.length] = data[];
	}

	private static immutable(ubyte[]) tmcPlayer = [ 76, 206, 13, 76, 208, 8, 76, 239, 9, 15,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1,
		1, 1, 0, 0, 0, 0, 1, 1, 1, 1, 1, 1, 1, 1, 2, 2,
		2, 2, 0, 0, 0, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 3,
		3, 3, 0, 0, 1, 1, 1, 1, 2, 2, 2, 2, 3, 3, 3, 3,
		4, 4, 0, 0, 1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4,
		5, 5, 0, 0, 1, 1, 2, 2, 2, 3, 3, 4, 4, 4, 5, 5,
		6, 6, 0, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6,
		7, 7, 0, 1, 1, 2, 2, 3, 3, 4, 4, 5, 5, 6, 6, 7,
		7, 8, 0, 1, 1, 2, 2, 3, 4, 4, 5, 5, 6, 7, 7, 8,
		8, 9, 0, 1, 1, 2, 3, 3, 4, 5, 5, 6, 7, 7, 8, 9,
		9, 10, 0, 1, 1, 2, 3, 4, 4, 5, 6, 7, 7, 8, 9, 10,
		10, 11, 0, 1, 2, 2, 3, 4, 5, 6, 6, 7, 8, 9, 10, 10,
		11, 12, 0, 1, 2, 3, 3, 4, 5, 6, 7, 8, 9, 10, 10, 11,
		12, 13, 0, 1, 2, 3, 4, 5, 6, 7, 7, 8, 9, 10, 11, 12,
		13, 14, 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13,
		14, 15, 0, 241, 228, 215, 203, 192, 181, 170, 161, 152, 143, 135, 127, 120,
		114, 107, 101, 95, 90, 85, 80, 75, 71, 67, 63, 60, 56, 53, 50, 47,
		44, 42, 39, 37, 35, 33, 31, 29, 28, 26, 24, 23, 22, 20, 19, 18,
		17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2,
		1, 0, 0, 242, 230, 218, 206, 191, 182, 170, 161, 152, 143, 137, 128, 122,
		113, 107, 101, 95, 92, 86, 80, 77, 71, 68, 62, 60, 56, 53, 50, 47,
		45, 42, 40, 37, 35, 33, 31, 29, 28, 26, 24, 23, 22, 20, 19, 18,
		17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2,
		1, 0, 0, 255, 241, 228, 216, 202, 192, 181, 171, 162, 153, 142, 135, 127,
		121, 115, 112, 102, 97, 90, 85, 82, 75, 72, 67, 63, 60, 57, 55, 51,
		48, 45, 42, 40, 37, 36, 33, 31, 30, 28, 27, 25, 23, 22, 21, 19,
		18, 17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3,
		2, 1, 0, 243, 230, 217, 204, 193, 181, 173, 162, 153, 144, 136, 128, 121,
		114, 108, 102, 96, 91, 85, 81, 76, 72, 68, 64, 60, 57, 53, 50, 47,
		45, 42, 40, 37, 35, 33, 31, 29, 28, 26, 24, 23, 22, 20, 19, 18,
		17, 16, 15, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2,
		1, 0, 0, 242, 51, 150, 226, 56, 140, 0, 106, 232, 106, 239, 128, 8,
		174, 70, 230, 149, 65, 246, 176, 110, 48, 246, 187, 132, 82, 34, 244, 200,
		160, 122, 85, 52, 20, 245, 216, 189, 164, 141, 119, 96, 78, 56, 39, 21,
		6, 247, 232, 219, 207, 195, 184, 172, 162, 154, 144, 136, 127, 120, 112, 106,
		100, 94, 0, 13, 13, 12, 11, 11, 10, 10, 9, 8, 8, 7, 7, 7,
		6, 6, 5, 5, 5, 4, 4, 4, 4, 3, 3, 3, 3, 3, 2, 2,
		2, 2, 2, 2, 2, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1, 1,
		1, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
		0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 4, 5,
		6, 7, 0, 1, 2, 3, 4, 2, 0, 0, 4, 2, 0, 0, 0, 16,
		0, 8, 0, 16, 0, 8, 173, 183, 8, 240, 94, 173, 182, 8, 201, 64,
		144, 90, 206, 181, 8, 240, 3, 76, 239, 9, 162, 7, 169, 0, 157, 196,
		7, 157, 204, 7, 202, 16, 247, 141, 182, 8, 170, 160, 15, 177, 254, 16,
		32, 136, 177, 254, 16, 3, 76, 95, 14, 134, 252, 10, 10, 38, 252, 10,
		38, 252, 10, 38, 252, 105, 0, 133, 254, 165, 252, 105, 0, 133, 255, 144,
		218, 157, 212, 7, 136, 177, 254, 157, 220, 7, 232, 136, 16, 207, 24, 165,
		254, 105, 16, 133, 254, 144, 2, 230, 255, 76, 239, 9, 206, 181, 8, 16,
		248, 238, 182, 8, 173, 180, 8, 141, 181, 8, 162, 7, 222, 204, 7, 48,
		3, 76, 233, 9, 188, 212, 7, 185, 255, 255, 133, 252, 185, 255, 255, 133,
		253, 188, 196, 7, 177, 252, 208, 6, 32, 109, 13, 76, 230, 9, 201, 64,
		176, 18, 125, 220, 7, 157, 228, 7, 32, 109, 13, 188, 42, 5, 32, 188,
		14, 76, 230, 9, 208, 34, 200, 254, 196, 7, 177, 252, 16, 7, 133, 251,
		32, 109, 13, 165, 251, 41, 127, 208, 7, 169, 64, 141, 182, 8, 208, 76,
		141, 180, 8, 141, 181, 8, 208, 68, 201, 128, 176, 43, 41, 63, 125, 220,
		7, 157, 228, 7, 200, 254, 196, 7, 177, 252, 41, 127, 208, 7, 169, 64,
		141, 182, 8, 208, 6, 141, 180, 8, 141, 181, 8, 32, 109, 13, 188, 42,
		5, 32, 188, 14, 76, 230, 9, 201, 192, 176, 12, 41, 63, 157, 42, 5,
		200, 254, 196, 7, 76, 94, 9, 41, 63, 157, 204, 7, 254, 196, 7, 202,
		48, 3, 76, 70, 9, 162, 7, 189, 188, 7, 240, 33, 32, 46, 11, 189,
		50, 5, 61, 192, 8, 240, 22, 160, 71, 177, 252, 24, 125, 34, 5, 157,
		36, 5, 168, 185, 60, 6, 56, 125, 100, 8, 157, 246, 7, 202, 16, 215,
		14, 9, 5, 14, 9, 5, 14, 9, 5, 14, 9, 5, 232, 134, 252, 134,
		253, 162, 7, 138, 168, 185, 252, 7, 208, 12, 188, 184, 8, 185, 4, 8,
		208, 4, 138, 168, 169, 0, 133, 250, 152, 157, 26, 5, 185, 244, 7, 157,
		18, 5, 185, 50, 5, 133, 251, 5, 253, 133, 253, 165, 251, 61, 192, 8,
		240, 6, 185, 246, 7, 157, 20, 5, 165, 251, 61, 200, 8, 240, 18, 185,
		34, 5, 41, 63, 168, 200, 132, 252, 185, 123, 7, 157, 18, 5, 76, 137,
		10, 164, 252, 240, 10, 185, 59, 7, 157, 18, 5, 169, 0, 133, 252, 165,
		250, 13, 9, 5, 168, 185, 60, 5, 188, 26, 5, 25, 236, 7, 157, 10,
		5, 224, 4, 208, 9, 165, 253, 141, 59, 5, 169, 0, 133, 253, 202, 16,
		130, 78, 9, 5, 78, 9, 5, 78, 9, 5, 78, 9, 5, 165, 253, 162,
		3, 142, 31, 210, 142, 15, 210, 174, 22, 5, 172, 18, 5, 142, 16, 210,
		140, 0, 210, 174, 14, 5, 172, 10, 5, 142, 17, 210, 140, 1, 210, 174,
		23, 5, 172, 19, 5, 142, 18, 210, 140, 2, 210, 174, 15, 5, 172, 11,
		5, 142, 19, 210, 140, 3, 210, 174, 24, 5, 172, 20, 5, 142, 20, 210,
		140, 4, 210, 174, 16, 5, 172, 12, 5, 142, 21, 210, 140, 5, 210, 174,
		25, 5, 172, 21, 5, 142, 22, 210, 140, 6, 210, 174, 17, 5, 172, 13,
		5, 142, 23, 210, 140, 7, 210, 141, 58, 5, 174, 59, 5, 142, 24, 210,
		141, 8, 210, 96, 189, 28, 8, 133, 252, 189, 36, 8, 133, 253, 188, 44,
		8, 192, 63, 240, 123, 254, 44, 8, 254, 44, 8, 254, 44, 8, 177, 252,
		41, 240, 157, 236, 7, 177, 252, 41, 15, 56, 253, 12, 8, 16, 2, 169,
		0, 157, 252, 7, 200, 177, 252, 41, 15, 56, 253, 20, 8, 16, 2, 169,
		0, 157, 4, 8, 177, 252, 41, 240, 240, 116, 16, 11, 160, 73, 177, 252,
		188, 44, 8, 136, 136, 16, 2, 169, 0, 157, 50, 5, 177, 252, 41, 112,
		240, 99, 74, 74, 141, 154, 11, 169, 0, 157, 100, 8, 200, 177, 252, 144,
		254, 234, 234, 234, 234, 76, 56, 13, 234, 76, 53, 13, 234, 76, 60, 13,
		234, 76, 74, 13, 234, 76, 84, 13, 234, 76, 95, 13, 234, 76, 81, 13,
		189, 52, 8, 240, 18, 222, 68, 8, 208, 13, 157, 68, 8, 189, 252, 7,
		41, 15, 240, 3, 222, 252, 7, 189, 60, 8, 240, 18, 222, 76, 8, 208,
		13, 157, 76, 8, 189, 4, 8, 41, 15, 240, 3, 222, 4, 8, 160, 72,
		177, 252, 157, 50, 5, 189, 148, 8, 24, 105, 63, 168, 177, 252, 125, 228,
		7, 157, 34, 5, 168, 185, 60, 6, 157, 244, 7, 222, 164, 8, 16, 51,
		189, 156, 8, 157, 164, 8, 189, 172, 8, 240, 24, 24, 125, 148, 8, 157,
		148, 8, 240, 7, 221, 140, 8, 208, 26, 169, 254, 24, 105, 1, 157, 172,
		8, 208, 16, 254, 148, 8, 189, 140, 8, 221, 148, 8, 176, 5, 169, 0,
		157, 148, 8, 189, 116, 8, 240, 4, 222, 116, 8, 96, 189, 108, 8, 133,
		250, 189, 92, 8, 133, 251, 32, 105, 12, 222, 132, 8, 16, 16, 165, 250,
		157, 108, 8, 165, 251, 157, 92, 8, 189, 124, 8, 157, 132, 8, 96, 189,
		84, 8, 141, 112, 12, 16, 254, 76, 167, 12, 234, 76, 144, 12, 234, 76,
		174, 12, 234, 76, 180, 12, 234, 76, 190, 12, 234, 76, 210, 12, 234, 76,
		226, 12, 234, 76, 244, 12, 165, 250, 230, 250, 41, 3, 74, 144, 15, 208,
		71, 165, 251, 157, 100, 8, 24, 125, 244, 7, 157, 244, 7, 96, 169, 0,
		157, 100, 8, 96, 32, 29, 13, 76, 157, 12, 32, 29, 13, 24, 125, 34,
		5, 76, 84, 13, 165, 250, 157, 100, 8, 24, 125, 244, 7, 157, 244, 7,
		165, 250, 24, 101, 251, 133, 250, 96, 189, 34, 5, 56, 229, 250, 157, 34,
		5, 168, 185, 60, 6, 76, 199, 12, 189, 244, 7, 56, 229, 251, 157, 244,
		7, 56, 169, 0, 229, 251, 157, 100, 8, 96, 189, 132, 8, 208, 174, 165,
		251, 16, 16, 189, 4, 8, 240, 165, 189, 252, 7, 201, 15, 240, 158, 254,
		252, 7, 96, 189, 252, 7, 240, 149, 189, 4, 8, 201, 15, 240, 142, 254,
		4, 8, 96, 164, 250, 165, 251, 48, 2, 200, 200, 136, 152, 133, 250, 197,
		251, 208, 6, 165, 251, 73, 255, 133, 251, 152, 96, 125, 244, 7, 157, 244,
		7, 96, 188, 228, 7, 121, 60, 6, 157, 244, 7, 152, 157, 34, 5, 96,
		45, 10, 210, 157, 244, 7, 96, 125, 228, 7, 157, 34, 5, 168, 185, 60,
		6, 157, 244, 7, 96, 157, 34, 5, 168, 189, 244, 7, 121, 60, 6, 157,
		244, 7, 96, 200, 254, 196, 7, 177, 252, 74, 74, 74, 74, 157, 12, 8,
		177, 252, 41, 15, 157, 20, 8, 96, 32, 95, 14, 160, 15, 169, 0, 133,
		254, 169, 0, 133, 255, 138, 240, 46, 177, 254, 16, 1, 202, 24, 165, 254,
		105, 16, 133, 254, 144, 239, 230, 255, 176, 235, 32, 95, 14, 169, 0, 133,
		252, 138, 10, 10, 38, 252, 10, 38, 252, 10, 38, 252, 105, 0, 133, 254,
		165, 252, 105, 0, 133, 255, 169, 64, 141, 182, 8, 169, 1, 141, 181, 8,
		141, 183, 8, 96, 201, 16, 144, 176, 201, 32, 144, 206, 201, 48, 176, 3,
		76, 174, 14, 201, 64, 176, 9, 138, 41, 15, 240, 3, 141, 180, 8, 96,
		201, 80, 144, 113, 201, 96, 176, 6, 169, 0, 141, 183, 8, 96, 201, 112,
		144, 248, 169, 1, 141, 181, 8, 169, 64, 141, 182, 8, 132, 252, 134, 253,
		160, 30, 177, 252, 141, 180, 8, 165, 252, 24, 105, 32, 141, 194, 14, 144,
		1, 232, 142, 195, 14, 24, 105, 64, 141, 202, 14, 144, 1, 232, 142, 203,
		14, 24, 105, 64, 141, 82, 9, 144, 1, 232, 142, 83, 9, 24, 105, 128,
		141, 87, 9, 144, 1, 232, 142, 88, 9, 24, 105, 128, 133, 254, 141, 16,
		9, 141, 136, 13, 141, 183, 13, 144, 1, 232, 134, 255, 142, 22, 9, 142,
		140, 13, 142, 189, 13, 160, 7, 169, 0, 141, 183, 8, 153, 0, 210, 153,
		16, 210, 153, 10, 5, 153, 252, 7, 153, 4, 8, 153, 50, 5, 153, 188,
		7, 136, 16, 232, 141, 8, 210, 141, 24, 210, 141, 58, 5, 141, 59, 5,
		96, 157, 252, 7, 157, 4, 8, 157, 50, 5, 189, 228, 7, 157, 34, 5,
		96, 152, 73, 240, 74, 74, 74, 74, 157, 12, 8, 152, 41, 15, 73, 15,
		157, 20, 8, 96, 41, 7, 133, 252, 138, 166, 252, 41, 63, 240, 226, 157,
		228, 7, 169, 0, 157, 188, 7, 185, 255, 255, 157, 28, 8, 133, 252, 185,
		255, 255, 157, 36, 8, 133, 253, 5, 252, 240, 182, 160, 74, 177, 252, 157,
		52, 8, 157, 68, 8, 200, 177, 252, 157, 60, 8, 157, 76, 8, 200, 177,
		252, 41, 112, 74, 74, 157, 84, 8, 177, 252, 41, 15, 157, 92, 8, 177,
		252, 16, 11, 189, 92, 8, 73, 255, 24, 105, 1, 157, 92, 8, 200, 177,
		252, 157, 116, 8, 200, 177, 252, 41, 63, 157, 124, 8, 157, 132, 8, 200,
		177, 252, 41, 128, 240, 2, 169, 1, 157, 172, 8, 177, 252, 41, 112, 74,
		74, 74, 74, 157, 140, 8, 208, 3, 157, 172, 8, 177, 252, 41, 15, 157,
		156, 8, 157, 164, 8, 136, 177, 252, 41, 192, 24, 125, 228, 7, 157, 228,
		7, 157, 34, 5, 168, 185, 60, 6, 157, 244, 7, 169, 0, 157, 44, 8,
		157, 100, 8, 157, 108, 8, 157, 148, 8, 169, 1, 157, 188, 7, 96 ];
}

/// Format of output samples.
enum ASAPSampleFormat
{
	/// Unsigned 8-bit.
	U8,
	/// Signed 16-bit little-endian.
	S16LE,
	/// Signed 16-bit big-endian.
	S16BE
}

class Cpu6502
{
	int A;
	int C;

	/// Runs 6502 emulation for the specified number of Atari scanlines.
	///
	/// Each scanline is 114 cycles of which 9 is taken by ANTIC for memory refresh.
	final void DoFrame(ASAPTmc asap, int cycleLimit)
	{
		int pc = this.Pc;
		int nz = this.Nz;
		int a = this.A;
		int x = this.X;
		int y = this.Y;
		int c = this.C;
		int s = this.S;
		int vdi = this.Vdi;
		while (asap.Cycle < cycleLimit) {
			if (asap.Cycle >= asap.NextEventCycle) {
				this.Pc = pc;
				this.S = s;
				asap.HandleEvent();
				pc = this.Pc;
				s = this.S;
				if ((vdi & 4) == 0 && asap.Pokeys.Irqst != 255) {
					asap.Memory[256 + s] = cast(ubyte) (pc >> 8);
					s = s - 1 & 255;
					asap.Memory[256 + s] = cast(ubyte) pc;
					s = s - 1 & 255;
					asap.Memory[256 + s] = cast(ubyte) (((nz | nz >> 1) & 128) + vdi + ((nz & 255) == 0 ? 2 : 0) + c + 32);
					s = s - 1 & 255;
					vdi |= 4;
					pc = asap.Memory[65534] + (asap.Memory[65535] << 8);
					asap.Cycle += 7;
				}
			}
			int data = asap.Memory[pc++];
			asap.Cycle += CiConstArray_1[data];
			int addr;
			switch (data) {
			case 0:
				pc++;
				asap.Memory[256 + s] = cast(ubyte) (pc >> 8);
				s = s - 1 & 255;
				asap.Memory[256 + s] = cast(ubyte) pc;
				s = s - 1 & 255;
				asap.Memory[256 + s] = cast(ubyte) (((nz | nz >> 1) & 128) + vdi + ((nz & 255) == 0 ? 2 : 0) + c + 48);
				s = s - 1 & 255;
				vdi |= 4;
				pc = asap.Memory[65534] + (asap.Memory[65535] << 8);
				break;
			case 1:
				addr = asap.Memory[pc++] + x & 255;
				addr = asap.Memory[addr] + (asap.Memory[addr + 1 & 255] << 8);
				nz = a |= (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				break;
			case 2:
			case 18:
			case 34:
			case 50:
			case 66:
			case 82:
			case 98:
			case 114:
			case 146:
			case 178:
			case 210:
			case 242:
				pc--;
				asap.Cycle = asap.NextEventCycle;
				break;
			case 5:
				addr = asap.Memory[pc++];
				nz = a |= asap.Memory[addr];
				break;
			case 6:
				addr = asap.Memory[pc++];
				nz = asap.Memory[addr];
				c = nz >> 7;
				nz = nz << 1 & 255;
				asap.Memory[addr] = cast(ubyte) nz;
				break;
			case 8:
				asap.Memory[256 + s] = cast(ubyte) (((nz | nz >> 1) & 128) + vdi + ((nz & 255) == 0 ? 2 : 0) + c + 48);
				s = s - 1 & 255;
				break;
			case 9:
				nz = a |= asap.Memory[pc++];
				break;
			case 10:
				c = a >> 7;
				nz = a = a << 1 & 255;
				break;
			case 13:
				addr = asap.Memory[pc++];
				addr += asap.Memory[pc++] << 8;
				nz = a |= (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				break;
			case 14:
				addr = asap.Memory[pc++];
				addr += asap.Memory[pc++] << 8;
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				c = nz >> 7;
				nz = nz << 1 & 255;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				break;
			case 16:
				if (nz < 128) {
					addr = cast(byte) asap.Memory[pc];
					pc++;
					addr += pc;
					if ((addr ^ pc) >> 8 != 0)
						asap.Cycle++;
					asap.Cycle++;
					pc = addr;
					break;
				}
				pc++;
				break;
			case 17:
				addr = asap.Memory[pc++];
				addr = asap.Memory[addr] + (asap.Memory[addr + 1 & 255] << 8) + y & 65535;
				if ((addr & 255) < y)
					asap.Cycle++;
				nz = a |= (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				break;
			case 21:
				addr = asap.Memory[pc++] + x & 255;
				nz = a |= asap.Memory[addr];
				break;
			case 22:
				addr = asap.Memory[pc++] + x & 255;
				nz = asap.Memory[addr];
				c = nz >> 7;
				nz = nz << 1 & 255;
				asap.Memory[addr] = cast(ubyte) nz;
				break;
			case 24:
				c = 0;
				break;
			case 25:
				addr = asap.Memory[pc++];
				addr = addr + (asap.Memory[pc++] << 8) + y & 65535;
				if ((addr & 255) < y)
					asap.Cycle++;
				nz = a |= (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				break;
			case 29:
				addr = asap.Memory[pc++];
				addr = addr + (asap.Memory[pc++] << 8) + x & 65535;
				if ((addr & 255) < x)
					asap.Cycle++;
				nz = a |= (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				break;
			case 30:
				addr = asap.Memory[pc++];
				addr = addr + (asap.Memory[pc++] << 8) + x & 65535;
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				c = nz >> 7;
				nz = nz << 1 & 255;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				break;
			case 32:
				addr = asap.Memory[pc++];
				asap.Memory[256 + s] = cast(ubyte) (pc >> 8);
				s = s - 1 & 255;
				asap.Memory[256 + s] = cast(ubyte) pc;
				s = s - 1 & 255;
				pc = addr + (asap.Memory[pc] << 8);
				break;
			case 33:
				addr = asap.Memory[pc++] + x & 255;
				addr = asap.Memory[addr] + (asap.Memory[addr + 1 & 255] << 8);
				nz = a &= (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				break;
			case 36:
				addr = asap.Memory[pc++];
				nz = asap.Memory[addr];
				vdi = (vdi & 12) + (nz & 64);
				nz = ((nz & 128) << 1) + (nz & a);
				break;
			case 37:
				addr = asap.Memory[pc++];
				nz = a &= asap.Memory[addr];
				break;
			case 38:
				addr = asap.Memory[pc++];
				nz = asap.Memory[addr];
				nz = (nz << 1) + c;
				c = nz >> 8;
				nz &= 255;
				asap.Memory[addr] = cast(ubyte) nz;
				break;
			case 40:
				s = s + 1 & 255;
				vdi = asap.Memory[256 + s];
				nz = ((vdi & 128) << 1) + (~vdi & 2);
				c = vdi & 1;
				vdi &= 76;
				if ((vdi & 4) == 0 && asap.Pokeys.Irqst != 255) {
					asap.Memory[256 + s] = cast(ubyte) (pc >> 8);
					s = s - 1 & 255;
					asap.Memory[256 + s] = cast(ubyte) pc;
					s = s - 1 & 255;
					asap.Memory[256 + s] = cast(ubyte) (((nz | nz >> 1) & 128) + vdi + ((nz & 255) == 0 ? 2 : 0) + c + 32);
					s = s - 1 & 255;
					vdi |= 4;
					pc = asap.Memory[65534] + (asap.Memory[65535] << 8);
					asap.Cycle += 7;
				}
				break;
			case 41:
				nz = a &= asap.Memory[pc++];
				break;
			case 42:
				a = (a << 1) + c;
				c = a >> 8;
				nz = a &= 255;
				break;
			case 44:
				addr = asap.Memory[pc++];
				addr += asap.Memory[pc++] << 8;
				nz = (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				vdi = (vdi & 12) + (nz & 64);
				nz = ((nz & 128) << 1) + (nz & a);
				break;
			case 45:
				addr = asap.Memory[pc++];
				addr += asap.Memory[pc++] << 8;
				nz = a &= (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				break;
			case 46:
				addr = asap.Memory[pc++];
				addr += asap.Memory[pc++] << 8;
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				nz = (nz << 1) + c;
				c = nz >> 8;
				nz &= 255;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				break;
			case 48:
				if (nz >= 128) {
					addr = cast(byte) asap.Memory[pc];
					pc++;
					addr += pc;
					if ((addr ^ pc) >> 8 != 0)
						asap.Cycle++;
					asap.Cycle++;
					pc = addr;
					break;
				}
				pc++;
				break;
			case 49:
				addr = asap.Memory[pc++];
				addr = asap.Memory[addr] + (asap.Memory[addr + 1 & 255] << 8) + y & 65535;
				if ((addr & 255) < y)
					asap.Cycle++;
				nz = a &= (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				break;
			case 53:
				addr = asap.Memory[pc++] + x & 255;
				nz = a &= asap.Memory[addr];
				break;
			case 54:
				addr = asap.Memory[pc++] + x & 255;
				nz = asap.Memory[addr];
				nz = (nz << 1) + c;
				c = nz >> 8;
				nz &= 255;
				asap.Memory[addr] = cast(ubyte) nz;
				break;
			case 56:
				c = 1;
				break;
			case 57:
				addr = asap.Memory[pc++];
				addr = addr + (asap.Memory[pc++] << 8) + y & 65535;
				if ((addr & 255) < y)
					asap.Cycle++;
				nz = a &= (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				break;
			case 61:
				addr = asap.Memory[pc++];
				addr = addr + (asap.Memory[pc++] << 8) + x & 65535;
				if ((addr & 255) < x)
					asap.Cycle++;
				nz = a &= (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				break;
			case 62:
				addr = asap.Memory[pc++];
				addr = addr + (asap.Memory[pc++] << 8) + x & 65535;
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				nz = (nz << 1) + c;
				c = nz >> 8;
				nz &= 255;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				break;
			case 64:
				s = s + 1 & 255;
				vdi = asap.Memory[256 + s];
				nz = ((vdi & 128) << 1) + (~vdi & 2);
				c = vdi & 1;
				vdi &= 76;
				s = s + 1 & 255;
				pc = asap.Memory[256 + s];
				s = s + 1 & 255;
				addr = asap.Memory[256 + s];
				pc += addr << 8;
				if ((vdi & 4) == 0 && asap.Pokeys.Irqst != 255) {
					asap.Memory[256 + s] = cast(ubyte) (pc >> 8);
					s = s - 1 & 255;
					asap.Memory[256 + s] = cast(ubyte) pc;
					s = s - 1 & 255;
					asap.Memory[256 + s] = cast(ubyte) (((nz | nz >> 1) & 128) + vdi + ((nz & 255) == 0 ? 2 : 0) + c + 32);
					s = s - 1 & 255;
					vdi |= 4;
					pc = asap.Memory[65534] + (asap.Memory[65535] << 8);
					asap.Cycle += 7;
				}
				break;
			case 65:
				addr = asap.Memory[pc++] + x & 255;
				addr = asap.Memory[addr] + (asap.Memory[addr + 1 & 255] << 8);
				nz = a ^= (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				break;
			case 69:
				addr = asap.Memory[pc++];
				nz = a ^= asap.Memory[addr];
				break;
			case 70:
				addr = asap.Memory[pc++];
				nz = asap.Memory[addr];
				c = nz & 1;
				nz >>= 1;
				asap.Memory[addr] = cast(ubyte) nz;
				break;
			case 72:
				asap.Memory[256 + s] = cast(ubyte) a;
				s = s - 1 & 255;
				break;
			case 73:
				nz = a ^= asap.Memory[pc++];
				break;
			case 74:
				c = a & 1;
				nz = a >>= 1;
				break;
			case 76:
				addr = asap.Memory[pc++];
				pc = addr + (asap.Memory[pc] << 8);
				break;
			case 77:
				addr = asap.Memory[pc++];
				addr += asap.Memory[pc++] << 8;
				nz = a ^= (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				break;
			case 78:
				addr = asap.Memory[pc++];
				addr += asap.Memory[pc++] << 8;
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				c = nz & 1;
				nz >>= 1;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				break;
			case 80:
				if ((vdi & 64) == 0) {
					addr = cast(byte) asap.Memory[pc];
					pc++;
					addr += pc;
					if ((addr ^ pc) >> 8 != 0)
						asap.Cycle++;
					asap.Cycle++;
					pc = addr;
					break;
				}
				pc++;
				break;
			case 81:
				addr = asap.Memory[pc++];
				addr = asap.Memory[addr] + (asap.Memory[addr + 1 & 255] << 8) + y & 65535;
				if ((addr & 255) < y)
					asap.Cycle++;
				nz = a ^= (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				break;
			case 85:
				addr = asap.Memory[pc++] + x & 255;
				nz = a ^= asap.Memory[addr];
				break;
			case 86:
				addr = asap.Memory[pc++] + x & 255;
				nz = asap.Memory[addr];
				c = nz & 1;
				nz >>= 1;
				asap.Memory[addr] = cast(ubyte) nz;
				break;
			case 88:
				vdi &= 72;
				if ((vdi & 4) == 0 && asap.Pokeys.Irqst != 255) {
					asap.Memory[256 + s] = cast(ubyte) (pc >> 8);
					s = s - 1 & 255;
					asap.Memory[256 + s] = cast(ubyte) pc;
					s = s - 1 & 255;
					asap.Memory[256 + s] = cast(ubyte) (((nz | nz >> 1) & 128) + vdi + ((nz & 255) == 0 ? 2 : 0) + c + 32);
					s = s - 1 & 255;
					vdi |= 4;
					pc = asap.Memory[65534] + (asap.Memory[65535] << 8);
					asap.Cycle += 7;
				}
				break;
			case 89:
				addr = asap.Memory[pc++];
				addr = addr + (asap.Memory[pc++] << 8) + y & 65535;
				if ((addr & 255) < y)
					asap.Cycle++;
				nz = a ^= (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				break;
			case 93:
				addr = asap.Memory[pc++];
				addr = addr + (asap.Memory[pc++] << 8) + x & 65535;
				if ((addr & 255) < x)
					asap.Cycle++;
				nz = a ^= (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				break;
			case 94:
				addr = asap.Memory[pc++];
				addr = addr + (asap.Memory[pc++] << 8) + x & 65535;
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				c = nz & 1;
				nz >>= 1;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				break;
			case 96:
				s = s + 1 & 255;
				pc = asap.Memory[256 + s];
				s = s + 1 & 255;
				addr = asap.Memory[256 + s];
				pc += (addr << 8) + 1;
				break;
			case 97:
				addr = asap.Memory[pc++] + x & 255;
				addr = asap.Memory[addr] + (asap.Memory[addr + 1 & 255] << 8);
				data = (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				{
					int tmp = a + data + c;
					nz = tmp & 255;
					if ((vdi & 8) == 0) {
						vdi = (vdi & 12) + ((~(data ^ a) & (a ^ tmp)) >> 1 & 64);
						c = tmp >> 8;
						a = nz;
					}
					else {
						int al = (a & 15) + (data & 15) + c;
						if (al >= 10) {
							tmp += al < 26 ? 6 : -10;
							if (nz != 0)
								nz = (tmp & 128) + 1;
						}
						vdi = (vdi & 12) + ((~(data ^ a) & (a ^ tmp)) >> 1 & 64);
						if (tmp >= 160) {
							c = 1;
							a = tmp + 96 & 255;
						}
						else {
							c = 0;
							a = tmp;
						}
					}
				}
				break;
			case 101:
				addr = asap.Memory[pc++];
				data = asap.Memory[addr];
				{
					int tmp = a + data + c;
					nz = tmp & 255;
					if ((vdi & 8) == 0) {
						vdi = (vdi & 12) + ((~(data ^ a) & (a ^ tmp)) >> 1 & 64);
						c = tmp >> 8;
						a = nz;
					}
					else {
						int al = (a & 15) + (data & 15) + c;
						if (al >= 10) {
							tmp += al < 26 ? 6 : -10;
							if (nz != 0)
								nz = (tmp & 128) + 1;
						}
						vdi = (vdi & 12) + ((~(data ^ a) & (a ^ tmp)) >> 1 & 64);
						if (tmp >= 160) {
							c = 1;
							a = tmp + 96 & 255;
						}
						else {
							c = 0;
							a = tmp;
						}
					}
				}
				break;
			case 102:
				addr = asap.Memory[pc++];
				nz = asap.Memory[addr] + (c << 8);
				c = nz & 1;
				nz >>= 1;
				asap.Memory[addr] = cast(ubyte) nz;
				break;
			case 104:
				s = s + 1 & 255;
				a = asap.Memory[256 + s];
				nz = a;
				break;
			case 105:
				data = asap.Memory[pc++];
				{
					int tmp = a + data + c;
					nz = tmp & 255;
					if ((vdi & 8) == 0) {
						vdi = (vdi & 12) + ((~(data ^ a) & (a ^ tmp)) >> 1 & 64);
						c = tmp >> 8;
						a = nz;
					}
					else {
						int al = (a & 15) + (data & 15) + c;
						if (al >= 10) {
							tmp += al < 26 ? 6 : -10;
							if (nz != 0)
								nz = (tmp & 128) + 1;
						}
						vdi = (vdi & 12) + ((~(data ^ a) & (a ^ tmp)) >> 1 & 64);
						if (tmp >= 160) {
							c = 1;
							a = tmp + 96 & 255;
						}
						else {
							c = 0;
							a = tmp;
						}
					}
				}
				break;
			case 106:
				nz = (c << 7) + (a >> 1);
				c = a & 1;
				a = nz;
				break;
			case 108:
				addr = asap.Memory[pc++];
				addr += asap.Memory[pc++] << 8;
				if ((addr & 255) == 255)
					pc = asap.Memory[addr] + (asap.Memory[addr - 255] << 8);
				else
					pc = asap.Memory[addr] + (asap.Memory[addr + 1] << 8);
				break;
			case 109:
				addr = asap.Memory[pc++];
				addr += asap.Memory[pc++] << 8;
				data = (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				{
					int tmp = a + data + c;
					nz = tmp & 255;
					if ((vdi & 8) == 0) {
						vdi = (vdi & 12) + ((~(data ^ a) & (a ^ tmp)) >> 1 & 64);
						c = tmp >> 8;
						a = nz;
					}
					else {
						int al = (a & 15) + (data & 15) + c;
						if (al >= 10) {
							tmp += al < 26 ? 6 : -10;
							if (nz != 0)
								nz = (tmp & 128) + 1;
						}
						vdi = (vdi & 12) + ((~(data ^ a) & (a ^ tmp)) >> 1 & 64);
						if (tmp >= 160) {
							c = 1;
							a = tmp + 96 & 255;
						}
						else {
							c = 0;
							a = tmp;
						}
					}
				}
				break;
			case 110:
				addr = asap.Memory[pc++];
				addr += asap.Memory[pc++] << 8;
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				nz += c << 8;
				c = nz & 1;
				nz >>= 1;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				break;
			case 112:
				if ((vdi & 64) != 0) {
					addr = cast(byte) asap.Memory[pc];
					pc++;
					addr += pc;
					if ((addr ^ pc) >> 8 != 0)
						asap.Cycle++;
					asap.Cycle++;
					pc = addr;
					break;
				}
				pc++;
				break;
			case 113:
				addr = asap.Memory[pc++];
				addr = asap.Memory[addr] + (asap.Memory[addr + 1 & 255] << 8) + y & 65535;
				if ((addr & 255) < y)
					asap.Cycle++;
				data = (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				{
					int tmp = a + data + c;
					nz = tmp & 255;
					if ((vdi & 8) == 0) {
						vdi = (vdi & 12) + ((~(data ^ a) & (a ^ tmp)) >> 1 & 64);
						c = tmp >> 8;
						a = nz;
					}
					else {
						int al = (a & 15) + (data & 15) + c;
						if (al >= 10) {
							tmp += al < 26 ? 6 : -10;
							if (nz != 0)
								nz = (tmp & 128) + 1;
						}
						vdi = (vdi & 12) + ((~(data ^ a) & (a ^ tmp)) >> 1 & 64);
						if (tmp >= 160) {
							c = 1;
							a = tmp + 96 & 255;
						}
						else {
							c = 0;
							a = tmp;
						}
					}
				}
				break;
			case 117:
				addr = asap.Memory[pc++] + x & 255;
				data = asap.Memory[addr];
				{
					int tmp = a + data + c;
					nz = tmp & 255;
					if ((vdi & 8) == 0) {
						vdi = (vdi & 12) + ((~(data ^ a) & (a ^ tmp)) >> 1 & 64);
						c = tmp >> 8;
						a = nz;
					}
					else {
						int al = (a & 15) + (data & 15) + c;
						if (al >= 10) {
							tmp += al < 26 ? 6 : -10;
							if (nz != 0)
								nz = (tmp & 128) + 1;
						}
						vdi = (vdi & 12) + ((~(data ^ a) & (a ^ tmp)) >> 1 & 64);
						if (tmp >= 160) {
							c = 1;
							a = tmp + 96 & 255;
						}
						else {
							c = 0;
							a = tmp;
						}
					}
				}
				break;
			case 118:
				addr = asap.Memory[pc++] + x & 255;
				nz = asap.Memory[addr] + (c << 8);
				c = nz & 1;
				nz >>= 1;
				asap.Memory[addr] = cast(ubyte) nz;
				break;
			case 120:
				vdi |= 4;
				break;
			case 121:
				addr = asap.Memory[pc++];
				addr = addr + (asap.Memory[pc++] << 8) + y & 65535;
				if ((addr & 255) < y)
					asap.Cycle++;
				data = (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				{
					int tmp = a + data + c;
					nz = tmp & 255;
					if ((vdi & 8) == 0) {
						vdi = (vdi & 12) + ((~(data ^ a) & (a ^ tmp)) >> 1 & 64);
						c = tmp >> 8;
						a = nz;
					}
					else {
						int al = (a & 15) + (data & 15) + c;
						if (al >= 10) {
							tmp += al < 26 ? 6 : -10;
							if (nz != 0)
								nz = (tmp & 128) + 1;
						}
						vdi = (vdi & 12) + ((~(data ^ a) & (a ^ tmp)) >> 1 & 64);
						if (tmp >= 160) {
							c = 1;
							a = tmp + 96 & 255;
						}
						else {
							c = 0;
							a = tmp;
						}
					}
				}
				break;
			case 125:
				addr = asap.Memory[pc++];
				addr = addr + (asap.Memory[pc++] << 8) + x & 65535;
				if ((addr & 255) < x)
					asap.Cycle++;
				data = (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				{
					int tmp = a + data + c;
					nz = tmp & 255;
					if ((vdi & 8) == 0) {
						vdi = (vdi & 12) + ((~(data ^ a) & (a ^ tmp)) >> 1 & 64);
						c = tmp >> 8;
						a = nz;
					}
					else {
						int al = (a & 15) + (data & 15) + c;
						if (al >= 10) {
							tmp += al < 26 ? 6 : -10;
							if (nz != 0)
								nz = (tmp & 128) + 1;
						}
						vdi = (vdi & 12) + ((~(data ^ a) & (a ^ tmp)) >> 1 & 64);
						if (tmp >= 160) {
							c = 1;
							a = tmp + 96 & 255;
						}
						else {
							c = 0;
							a = tmp;
						}
					}
				}
				break;
			case 126:
				addr = asap.Memory[pc++];
				addr = addr + (asap.Memory[pc++] << 8) + x & 65535;
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				nz += c << 8;
				c = nz & 1;
				nz >>= 1;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				break;
			case 129:
				addr = asap.Memory[pc++] + x & 255;
				addr = asap.Memory[addr] + (asap.Memory[addr + 1 & 255] << 8);
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, a);
				else
					asap.Memory[addr] = cast(ubyte) a;
				break;
			case 132:
				addr = asap.Memory[pc++];
				asap.Memory[addr] = cast(ubyte) y;
				break;
			case 133:
				addr = asap.Memory[pc++];
				asap.Memory[addr] = cast(ubyte) a;
				break;
			case 134:
				addr = asap.Memory[pc++];
				asap.Memory[addr] = cast(ubyte) x;
				break;
			case 136:
				nz = y = y - 1 & 255;
				break;
			case 138:
				nz = a = x;
				break;
			case 140:
				addr = asap.Memory[pc++];
				addr += asap.Memory[pc++] << 8;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, y);
				else
					asap.Memory[addr] = cast(ubyte) y;
				break;
			case 141:
				addr = asap.Memory[pc++];
				addr += asap.Memory[pc++] << 8;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, a);
				else
					asap.Memory[addr] = cast(ubyte) a;
				break;
			case 142:
				addr = asap.Memory[pc++];
				addr += asap.Memory[pc++] << 8;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, x);
				else
					asap.Memory[addr] = cast(ubyte) x;
				break;
			case 144:
				if (c == 0) {
					addr = cast(byte) asap.Memory[pc];
					pc++;
					addr += pc;
					if ((addr ^ pc) >> 8 != 0)
						asap.Cycle++;
					asap.Cycle++;
					pc = addr;
					break;
				}
				pc++;
				break;
			case 145:
				addr = asap.Memory[pc++];
				addr = asap.Memory[addr] + (asap.Memory[addr + 1 & 255] << 8) + y & 65535;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, a);
				else
					asap.Memory[addr] = cast(ubyte) a;
				break;
			case 148:
				addr = asap.Memory[pc++] + x & 255;
				asap.Memory[addr] = cast(ubyte) y;
				break;
			case 149:
				addr = asap.Memory[pc++] + x & 255;
				asap.Memory[addr] = cast(ubyte) a;
				break;
			case 150:
				addr = asap.Memory[pc++] + y & 255;
				asap.Memory[addr] = cast(ubyte) x;
				break;
			case 152:
				nz = a = y;
				break;
			case 153:
				addr = asap.Memory[pc++];
				addr = addr + (asap.Memory[pc++] << 8) + y & 65535;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, a);
				else
					asap.Memory[addr] = cast(ubyte) a;
				break;
			case 154:
				s = x;
				break;
			case 157:
				addr = asap.Memory[pc++];
				addr = addr + (asap.Memory[pc++] << 8) + x & 65535;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, a);
				else
					asap.Memory[addr] = cast(ubyte) a;
				break;
			case 160:
				nz = y = asap.Memory[pc++];
				break;
			case 161:
				addr = asap.Memory[pc++] + x & 255;
				addr = asap.Memory[addr] + (asap.Memory[addr + 1 & 255] << 8);
				nz = a = (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				break;
			case 162:
				nz = x = asap.Memory[pc++];
				break;
			case 164:
				addr = asap.Memory[pc++];
				nz = y = asap.Memory[addr];
				break;
			case 165:
				addr = asap.Memory[pc++];
				nz = a = asap.Memory[addr];
				break;
			case 166:
				addr = asap.Memory[pc++];
				nz = x = asap.Memory[addr];
				break;
			case 168:
				nz = y = a;
				break;
			case 169:
				nz = a = asap.Memory[pc++];
				break;
			case 170:
				nz = x = a;
				break;
			case 172:
				addr = asap.Memory[pc++];
				addr += asap.Memory[pc++] << 8;
				nz = y = (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				break;
			case 173:
				addr = asap.Memory[pc++];
				addr += asap.Memory[pc++] << 8;
				nz = a = (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				break;
			case 174:
				addr = asap.Memory[pc++];
				addr += asap.Memory[pc++] << 8;
				nz = x = (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				break;
			case 176:
				if (c != 0) {
					addr = cast(byte) asap.Memory[pc];
					pc++;
					addr += pc;
					if ((addr ^ pc) >> 8 != 0)
						asap.Cycle++;
					asap.Cycle++;
					pc = addr;
					break;
				}
				pc++;
				break;
			case 177:
				addr = asap.Memory[pc++];
				addr = asap.Memory[addr] + (asap.Memory[addr + 1 & 255] << 8) + y & 65535;
				if ((addr & 255) < y)
					asap.Cycle++;
				nz = a = (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				break;
			case 180:
				addr = asap.Memory[pc++] + x & 255;
				nz = y = asap.Memory[addr];
				break;
			case 181:
				addr = asap.Memory[pc++] + x & 255;
				nz = a = asap.Memory[addr];
				break;
			case 182:
				addr = asap.Memory[pc++] + y & 255;
				nz = x = asap.Memory[addr];
				break;
			case 184:
				vdi &= 12;
				break;
			case 185:
				addr = asap.Memory[pc++];
				addr = addr + (asap.Memory[pc++] << 8) + y & 65535;
				if ((addr & 255) < y)
					asap.Cycle++;
				nz = a = (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				break;
			case 186:
				nz = x = s;
				break;
			case 188:
				addr = asap.Memory[pc++];
				addr = addr + (asap.Memory[pc++] << 8) + x & 65535;
				if ((addr & 255) < x)
					asap.Cycle++;
				nz = y = (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				break;
			case 189:
				addr = asap.Memory[pc++];
				addr = addr + (asap.Memory[pc++] << 8) + x & 65535;
				if ((addr & 255) < x)
					asap.Cycle++;
				nz = a = (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				break;
			case 190:
				addr = asap.Memory[pc++];
				addr = addr + (asap.Memory[pc++] << 8) + y & 65535;
				if ((addr & 255) < y)
					asap.Cycle++;
				nz = x = (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				break;
			case 192:
				nz = asap.Memory[pc++];
				c = y >= nz ? 1 : 0;
				nz = y - nz & 255;
				break;
			case 193:
				addr = asap.Memory[pc++] + x & 255;
				addr = asap.Memory[addr] + (asap.Memory[addr + 1 & 255] << 8);
				nz = (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				c = a >= nz ? 1 : 0;
				nz = a - nz & 255;
				break;
			case 196:
				addr = asap.Memory[pc++];
				nz = asap.Memory[addr];
				c = y >= nz ? 1 : 0;
				nz = y - nz & 255;
				break;
			case 197:
				addr = asap.Memory[pc++];
				nz = asap.Memory[addr];
				c = a >= nz ? 1 : 0;
				nz = a - nz & 255;
				break;
			case 198:
				addr = asap.Memory[pc++];
				nz = asap.Memory[addr];
				nz = nz - 1 & 255;
				asap.Memory[addr] = cast(ubyte) nz;
				break;
			case 200:
				nz = y = y + 1 & 255;
				break;
			case 201:
				nz = asap.Memory[pc++];
				c = a >= nz ? 1 : 0;
				nz = a - nz & 255;
				break;
			case 202:
				nz = x = x - 1 & 255;
				break;
			case 204:
				addr = asap.Memory[pc++];
				addr += asap.Memory[pc++] << 8;
				nz = (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				c = y >= nz ? 1 : 0;
				nz = y - nz & 255;
				break;
			case 205:
				addr = asap.Memory[pc++];
				addr += asap.Memory[pc++] << 8;
				nz = (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				c = a >= nz ? 1 : 0;
				nz = a - nz & 255;
				break;
			case 206:
				addr = asap.Memory[pc++];
				addr += asap.Memory[pc++] << 8;
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				nz = nz - 1 & 255;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				break;
			case 208:
				if ((nz & 255) != 0) {
					addr = cast(byte) asap.Memory[pc];
					pc++;
					addr += pc;
					if ((addr ^ pc) >> 8 != 0)
						asap.Cycle++;
					asap.Cycle++;
					pc = addr;
					break;
				}
				pc++;
				break;
			case 209:
				addr = asap.Memory[pc++];
				addr = asap.Memory[addr] + (asap.Memory[addr + 1 & 255] << 8) + y & 65535;
				if ((addr & 255) < y)
					asap.Cycle++;
				nz = (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				c = a >= nz ? 1 : 0;
				nz = a - nz & 255;
				break;
			case 213:
				addr = asap.Memory[pc++] + x & 255;
				nz = asap.Memory[addr];
				c = a >= nz ? 1 : 0;
				nz = a - nz & 255;
				break;
			case 214:
				addr = asap.Memory[pc++] + x & 255;
				nz = asap.Memory[addr];
				nz = nz - 1 & 255;
				asap.Memory[addr] = cast(ubyte) nz;
				break;
			case 216:
				vdi &= 68;
				break;
			case 217:
				addr = asap.Memory[pc++];
				addr = addr + (asap.Memory[pc++] << 8) + y & 65535;
				if ((addr & 255) < y)
					asap.Cycle++;
				nz = (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				c = a >= nz ? 1 : 0;
				nz = a - nz & 255;
				break;
			case 221:
				addr = asap.Memory[pc++];
				addr = addr + (asap.Memory[pc++] << 8) + x & 65535;
				if ((addr & 255) < x)
					asap.Cycle++;
				nz = (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				c = a >= nz ? 1 : 0;
				nz = a - nz & 255;
				break;
			case 222:
				addr = asap.Memory[pc++];
				addr = addr + (asap.Memory[pc++] << 8) + x & 65535;
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				nz = nz - 1 & 255;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				break;
			case 224:
				nz = asap.Memory[pc++];
				c = x >= nz ? 1 : 0;
				nz = x - nz & 255;
				break;
			case 225:
				addr = asap.Memory[pc++] + x & 255;
				addr = asap.Memory[addr] + (asap.Memory[addr + 1 & 255] << 8);
				data = (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				{
					int tmp = a - data - 1 + c;
					int al = (a & 15) - (data & 15) - 1 + c;
					vdi = (vdi & 12) + (((data ^ a) & (a ^ tmp)) >> 1 & 64);
					c = tmp >= 0 ? 1 : 0;
					nz = a = tmp & 255;
					if ((vdi & 8) != 0) {
						if (al < 0)
							a += al < -10 ? 10 : -6;
						if (c == 0)
							a = a - 96 & 255;
					}
				}
				break;
			case 228:
				addr = asap.Memory[pc++];
				nz = asap.Memory[addr];
				c = x >= nz ? 1 : 0;
				nz = x - nz & 255;
				break;
			case 229:
				addr = asap.Memory[pc++];
				data = asap.Memory[addr];
				{
					int tmp = a - data - 1 + c;
					int al = (a & 15) - (data & 15) - 1 + c;
					vdi = (vdi & 12) + (((data ^ a) & (a ^ tmp)) >> 1 & 64);
					c = tmp >= 0 ? 1 : 0;
					nz = a = tmp & 255;
					if ((vdi & 8) != 0) {
						if (al < 0)
							a += al < -10 ? 10 : -6;
						if (c == 0)
							a = a - 96 & 255;
					}
				}
				break;
			case 230:
				addr = asap.Memory[pc++];
				nz = asap.Memory[addr];
				nz = nz + 1 & 255;
				asap.Memory[addr] = cast(ubyte) nz;
				break;
			case 232:
				nz = x = x + 1 & 255;
				break;
			case 233:
			case 235:
				data = asap.Memory[pc++];
				{
					int tmp = a - data - 1 + c;
					int al = (a & 15) - (data & 15) - 1 + c;
					vdi = (vdi & 12) + (((data ^ a) & (a ^ tmp)) >> 1 & 64);
					c = tmp >= 0 ? 1 : 0;
					nz = a = tmp & 255;
					if ((vdi & 8) != 0) {
						if (al < 0)
							a += al < -10 ? 10 : -6;
						if (c == 0)
							a = a - 96 & 255;
					}
				}
				break;
			case 234:
			case 26:
			case 58:
			case 90:
			case 122:
			case 218:
			case 250:
				break;
			case 236:
				addr = asap.Memory[pc++];
				addr += asap.Memory[pc++] << 8;
				nz = (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				c = x >= nz ? 1 : 0;
				nz = x - nz & 255;
				break;
			case 237:
				addr = asap.Memory[pc++];
				addr += asap.Memory[pc++] << 8;
				data = (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				{
					int tmp = a - data - 1 + c;
					int al = (a & 15) - (data & 15) - 1 + c;
					vdi = (vdi & 12) + (((data ^ a) & (a ^ tmp)) >> 1 & 64);
					c = tmp >= 0 ? 1 : 0;
					nz = a = tmp & 255;
					if ((vdi & 8) != 0) {
						if (al < 0)
							a += al < -10 ? 10 : -6;
						if (c == 0)
							a = a - 96 & 255;
					}
				}
				break;
			case 238:
				addr = asap.Memory[pc++];
				addr += asap.Memory[pc++] << 8;
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				nz = nz + 1 & 255;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				break;
			case 240:
				if ((nz & 255) == 0) {
					addr = cast(byte) asap.Memory[pc];
					pc++;
					addr += pc;
					if ((addr ^ pc) >> 8 != 0)
						asap.Cycle++;
					asap.Cycle++;
					pc = addr;
					break;
				}
				pc++;
				break;
			case 241:
				addr = asap.Memory[pc++];
				addr = asap.Memory[addr] + (asap.Memory[addr + 1 & 255] << 8) + y & 65535;
				if ((addr & 255) < y)
					asap.Cycle++;
				data = (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				{
					int tmp = a - data - 1 + c;
					int al = (a & 15) - (data & 15) - 1 + c;
					vdi = (vdi & 12) + (((data ^ a) & (a ^ tmp)) >> 1 & 64);
					c = tmp >= 0 ? 1 : 0;
					nz = a = tmp & 255;
					if ((vdi & 8) != 0) {
						if (al < 0)
							a += al < -10 ? 10 : -6;
						if (c == 0)
							a = a - 96 & 255;
					}
				}
				break;
			case 245:
				addr = asap.Memory[pc++] + x & 255;
				data = asap.Memory[addr];
				{
					int tmp = a - data - 1 + c;
					int al = (a & 15) - (data & 15) - 1 + c;
					vdi = (vdi & 12) + (((data ^ a) & (a ^ tmp)) >> 1 & 64);
					c = tmp >= 0 ? 1 : 0;
					nz = a = tmp & 255;
					if ((vdi & 8) != 0) {
						if (al < 0)
							a += al < -10 ? 10 : -6;
						if (c == 0)
							a = a - 96 & 255;
					}
				}
				break;
			case 246:
				addr = asap.Memory[pc++] + x & 255;
				nz = asap.Memory[addr];
				nz = nz + 1 & 255;
				asap.Memory[addr] = cast(ubyte) nz;
				break;
			case 248:
				vdi |= 8;
				break;
			case 249:
				addr = asap.Memory[pc++];
				addr = addr + (asap.Memory[pc++] << 8) + y & 65535;
				if ((addr & 255) < y)
					asap.Cycle++;
				data = (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				{
					int tmp = a - data - 1 + c;
					int al = (a & 15) - (data & 15) - 1 + c;
					vdi = (vdi & 12) + (((data ^ a) & (a ^ tmp)) >> 1 & 64);
					c = tmp >= 0 ? 1 : 0;
					nz = a = tmp & 255;
					if ((vdi & 8) != 0) {
						if (al < 0)
							a += al < -10 ? 10 : -6;
						if (c == 0)
							a = a - 96 & 255;
					}
				}
				break;
			case 253:
				addr = asap.Memory[pc++];
				addr = addr + (asap.Memory[pc++] << 8) + x & 65535;
				if ((addr & 255) < x)
					asap.Cycle++;
				data = (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				{
					int tmp = a - data - 1 + c;
					int al = (a & 15) - (data & 15) - 1 + c;
					vdi = (vdi & 12) + (((data ^ a) & (a ^ tmp)) >> 1 & 64);
					c = tmp >= 0 ? 1 : 0;
					nz = a = tmp & 255;
					if ((vdi & 8) != 0) {
						if (al < 0)
							a += al < -10 ? 10 : -6;
						if (c == 0)
							a = a - 96 & 255;
					}
				}
				break;
			case 254:
				addr = asap.Memory[pc++];
				addr = addr + (asap.Memory[pc++] << 8) + x & 65535;
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				nz = nz + 1 & 255;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				break;
			case 3:
				addr = asap.Memory[pc++] + x & 255;
				addr = asap.Memory[addr] + (asap.Memory[addr + 1 & 255] << 8);
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				c = nz >> 7;
				nz = nz << 1 & 255;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				nz = a |= nz;
				break;
			case 4:
			case 68:
			case 100:
			case 20:
			case 52:
			case 84:
			case 116:
			case 212:
			case 244:
			case 128:
			case 130:
			case 137:
			case 194:
			case 226:
				pc++;
				break;
			case 7:
				addr = asap.Memory[pc++];
				nz = asap.Memory[addr];
				c = nz >> 7;
				nz = nz << 1 & 255;
				asap.Memory[addr] = cast(ubyte) nz;
				nz = a |= nz;
				break;
			case 11:
			case 43:
				nz = a &= asap.Memory[pc++];
				c = nz >> 7;
				break;
			case 12:
				pc += 2;
				break;
			case 15:
				addr = asap.Memory[pc++];
				addr += asap.Memory[pc++] << 8;
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				c = nz >> 7;
				nz = nz << 1 & 255;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				nz = a |= nz;
				break;
			case 19:
				addr = asap.Memory[pc++];
				addr = asap.Memory[addr] + (asap.Memory[addr + 1 & 255] << 8) + y & 65535;
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				c = nz >> 7;
				nz = nz << 1 & 255;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				nz = a |= nz;
				break;
			case 23:
				addr = asap.Memory[pc++] + x & 255;
				nz = asap.Memory[addr];
				c = nz >> 7;
				nz = nz << 1 & 255;
				asap.Memory[addr] = cast(ubyte) nz;
				nz = a |= nz;
				break;
			case 27:
				addr = asap.Memory[pc++];
				addr = addr + (asap.Memory[pc++] << 8) + y & 65535;
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				c = nz >> 7;
				nz = nz << 1 & 255;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				nz = a |= nz;
				break;
			case 28:
			case 60:
			case 92:
			case 124:
			case 220:
			case 252:
				if (asap.Memory[pc++] + x >= 256)
					asap.Cycle++;
				pc++;
				break;
			case 31:
				addr = asap.Memory[pc++];
				addr = addr + (asap.Memory[pc++] << 8) + x & 65535;
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				c = nz >> 7;
				nz = nz << 1 & 255;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				nz = a |= nz;
				break;
			case 35:
				addr = asap.Memory[pc++] + x & 255;
				addr = asap.Memory[addr] + (asap.Memory[addr + 1 & 255] << 8);
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				nz = (nz << 1) + c;
				c = nz >> 8;
				nz &= 255;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				nz = a &= nz;
				break;
			case 39:
				addr = asap.Memory[pc++];
				nz = asap.Memory[addr];
				nz = (nz << 1) + c;
				c = nz >> 8;
				nz &= 255;
				asap.Memory[addr] = cast(ubyte) nz;
				nz = a &= nz;
				break;
			case 47:
				addr = asap.Memory[pc++];
				addr += asap.Memory[pc++] << 8;
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				nz = (nz << 1) + c;
				c = nz >> 8;
				nz &= 255;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				nz = a &= nz;
				break;
			case 51:
				addr = asap.Memory[pc++];
				addr = asap.Memory[addr] + (asap.Memory[addr + 1 & 255] << 8) + y & 65535;
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				nz = (nz << 1) + c;
				c = nz >> 8;
				nz &= 255;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				nz = a &= nz;
				break;
			case 55:
				addr = asap.Memory[pc++] + x & 255;
				nz = asap.Memory[addr];
				nz = (nz << 1) + c;
				c = nz >> 8;
				nz &= 255;
				asap.Memory[addr] = cast(ubyte) nz;
				nz = a &= nz;
				break;
			case 59:
				addr = asap.Memory[pc++];
				addr = addr + (asap.Memory[pc++] << 8) + y & 65535;
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				nz = (nz << 1) + c;
				c = nz >> 8;
				nz &= 255;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				nz = a &= nz;
				break;
			case 63:
				addr = asap.Memory[pc++];
				addr = addr + (asap.Memory[pc++] << 8) + x & 65535;
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				nz = (nz << 1) + c;
				c = nz >> 8;
				nz &= 255;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				nz = a &= nz;
				break;
			case 67:
				addr = asap.Memory[pc++] + x & 255;
				addr = asap.Memory[addr] + (asap.Memory[addr + 1 & 255] << 8);
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				c = nz & 1;
				nz >>= 1;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				nz = a ^= nz;
				break;
			case 71:
				addr = asap.Memory[pc++];
				nz = asap.Memory[addr];
				c = nz & 1;
				nz >>= 1;
				asap.Memory[addr] = cast(ubyte) nz;
				nz = a ^= nz;
				break;
			case 75:
				a &= asap.Memory[pc++];
				c = a & 1;
				nz = a >>= 1;
				break;
			case 79:
				addr = asap.Memory[pc++];
				addr += asap.Memory[pc++] << 8;
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				c = nz & 1;
				nz >>= 1;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				nz = a ^= nz;
				break;
			case 83:
				addr = asap.Memory[pc++];
				addr = asap.Memory[addr] + (asap.Memory[addr + 1 & 255] << 8) + y & 65535;
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				c = nz & 1;
				nz >>= 1;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				nz = a ^= nz;
				break;
			case 87:
				addr = asap.Memory[pc++] + x & 255;
				nz = asap.Memory[addr];
				c = nz & 1;
				nz >>= 1;
				asap.Memory[addr] = cast(ubyte) nz;
				nz = a ^= nz;
				break;
			case 91:
				addr = asap.Memory[pc++];
				addr = addr + (asap.Memory[pc++] << 8) + y & 65535;
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				c = nz & 1;
				nz >>= 1;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				nz = a ^= nz;
				break;
			case 95:
				addr = asap.Memory[pc++];
				addr = addr + (asap.Memory[pc++] << 8) + x & 65535;
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				c = nz & 1;
				nz >>= 1;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				nz = a ^= nz;
				break;
			case 99:
				addr = asap.Memory[pc++] + x & 255;
				addr = asap.Memory[addr] + (asap.Memory[addr + 1 & 255] << 8);
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				nz += c << 8;
				c = nz & 1;
				nz >>= 1;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				data = nz;
				{
					int tmp = a + data + c;
					nz = tmp & 255;
					if ((vdi & 8) == 0) {
						vdi = (vdi & 12) + ((~(data ^ a) & (a ^ tmp)) >> 1 & 64);
						c = tmp >> 8;
						a = nz;
					}
					else {
						int al = (a & 15) + (data & 15) + c;
						if (al >= 10) {
							tmp += al < 26 ? 6 : -10;
							if (nz != 0)
								nz = (tmp & 128) + 1;
						}
						vdi = (vdi & 12) + ((~(data ^ a) & (a ^ tmp)) >> 1 & 64);
						if (tmp >= 160) {
							c = 1;
							a = tmp + 96 & 255;
						}
						else {
							c = 0;
							a = tmp;
						}
					}
				}
				break;
			case 103:
				addr = asap.Memory[pc++];
				nz = asap.Memory[addr] + (c << 8);
				c = nz & 1;
				nz >>= 1;
				asap.Memory[addr] = cast(ubyte) nz;
				data = nz;
				{
					int tmp = a + data + c;
					nz = tmp & 255;
					if ((vdi & 8) == 0) {
						vdi = (vdi & 12) + ((~(data ^ a) & (a ^ tmp)) >> 1 & 64);
						c = tmp >> 8;
						a = nz;
					}
					else {
						int al = (a & 15) + (data & 15) + c;
						if (al >= 10) {
							tmp += al < 26 ? 6 : -10;
							if (nz != 0)
								nz = (tmp & 128) + 1;
						}
						vdi = (vdi & 12) + ((~(data ^ a) & (a ^ tmp)) >> 1 & 64);
						if (tmp >= 160) {
							c = 1;
							a = tmp + 96 & 255;
						}
						else {
							c = 0;
							a = tmp;
						}
					}
				}
				break;
			case 107:
				data = a & asap.Memory[pc++];
				nz = a = (data >> 1) + (c << 7);
				vdi = (vdi & 12) + ((a ^ data) & 64);
				if ((vdi & 8) == 0)
					c = data >> 7;
				else {
					if ((data & 15) >= 5)
						a = (a & 240) + (a + 6 & 15);
					if (data >= 80) {
						a = a + 96 & 255;
						c = 1;
					}
					else
						c = 0;
				}
				break;
			case 111:
				addr = asap.Memory[pc++];
				addr += asap.Memory[pc++] << 8;
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				nz += c << 8;
				c = nz & 1;
				nz >>= 1;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				data = nz;
				{
					int tmp = a + data + c;
					nz = tmp & 255;
					if ((vdi & 8) == 0) {
						vdi = (vdi & 12) + ((~(data ^ a) & (a ^ tmp)) >> 1 & 64);
						c = tmp >> 8;
						a = nz;
					}
					else {
						int al = (a & 15) + (data & 15) + c;
						if (al >= 10) {
							tmp += al < 26 ? 6 : -10;
							if (nz != 0)
								nz = (tmp & 128) + 1;
						}
						vdi = (vdi & 12) + ((~(data ^ a) & (a ^ tmp)) >> 1 & 64);
						if (tmp >= 160) {
							c = 1;
							a = tmp + 96 & 255;
						}
						else {
							c = 0;
							a = tmp;
						}
					}
				}
				break;
			case 115:
				addr = asap.Memory[pc++];
				addr = asap.Memory[addr] + (asap.Memory[addr + 1 & 255] << 8) + y & 65535;
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				nz += c << 8;
				c = nz & 1;
				nz >>= 1;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				data = nz;
				{
					int tmp = a + data + c;
					nz = tmp & 255;
					if ((vdi & 8) == 0) {
						vdi = (vdi & 12) + ((~(data ^ a) & (a ^ tmp)) >> 1 & 64);
						c = tmp >> 8;
						a = nz;
					}
					else {
						int al = (a & 15) + (data & 15) + c;
						if (al >= 10) {
							tmp += al < 26 ? 6 : -10;
							if (nz != 0)
								nz = (tmp & 128) + 1;
						}
						vdi = (vdi & 12) + ((~(data ^ a) & (a ^ tmp)) >> 1 & 64);
						if (tmp >= 160) {
							c = 1;
							a = tmp + 96 & 255;
						}
						else {
							c = 0;
							a = tmp;
						}
					}
				}
				break;
			case 119:
				addr = asap.Memory[pc++] + x & 255;
				nz = asap.Memory[addr] + (c << 8);
				c = nz & 1;
				nz >>= 1;
				asap.Memory[addr] = cast(ubyte) nz;
				data = nz;
				{
					int tmp = a + data + c;
					nz = tmp & 255;
					if ((vdi & 8) == 0) {
						vdi = (vdi & 12) + ((~(data ^ a) & (a ^ tmp)) >> 1 & 64);
						c = tmp >> 8;
						a = nz;
					}
					else {
						int al = (a & 15) + (data & 15) + c;
						if (al >= 10) {
							tmp += al < 26 ? 6 : -10;
							if (nz != 0)
								nz = (tmp & 128) + 1;
						}
						vdi = (vdi & 12) + ((~(data ^ a) & (a ^ tmp)) >> 1 & 64);
						if (tmp >= 160) {
							c = 1;
							a = tmp + 96 & 255;
						}
						else {
							c = 0;
							a = tmp;
						}
					}
				}
				break;
			case 123:
				addr = asap.Memory[pc++];
				addr = addr + (asap.Memory[pc++] << 8) + y & 65535;
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				nz += c << 8;
				c = nz & 1;
				nz >>= 1;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				data = nz;
				{
					int tmp = a + data + c;
					nz = tmp & 255;
					if ((vdi & 8) == 0) {
						vdi = (vdi & 12) + ((~(data ^ a) & (a ^ tmp)) >> 1 & 64);
						c = tmp >> 8;
						a = nz;
					}
					else {
						int al = (a & 15) + (data & 15) + c;
						if (al >= 10) {
							tmp += al < 26 ? 6 : -10;
							if (nz != 0)
								nz = (tmp & 128) + 1;
						}
						vdi = (vdi & 12) + ((~(data ^ a) & (a ^ tmp)) >> 1 & 64);
						if (tmp >= 160) {
							c = 1;
							a = tmp + 96 & 255;
						}
						else {
							c = 0;
							a = tmp;
						}
					}
				}
				break;
			case 127:
				addr = asap.Memory[pc++];
				addr = addr + (asap.Memory[pc++] << 8) + x & 65535;
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				nz += c << 8;
				c = nz & 1;
				nz >>= 1;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				data = nz;
				{
					int tmp = a + data + c;
					nz = tmp & 255;
					if ((vdi & 8) == 0) {
						vdi = (vdi & 12) + ((~(data ^ a) & (a ^ tmp)) >> 1 & 64);
						c = tmp >> 8;
						a = nz;
					}
					else {
						int al = (a & 15) + (data & 15) + c;
						if (al >= 10) {
							tmp += al < 26 ? 6 : -10;
							if (nz != 0)
								nz = (tmp & 128) + 1;
						}
						vdi = (vdi & 12) + ((~(data ^ a) & (a ^ tmp)) >> 1 & 64);
						if (tmp >= 160) {
							c = 1;
							a = tmp + 96 & 255;
						}
						else {
							c = 0;
							a = tmp;
						}
					}
				}
				break;
			case 131:
				addr = asap.Memory[pc++] + x & 255;
				addr = asap.Memory[addr] + (asap.Memory[addr + 1 & 255] << 8);
				data = a & x;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, data);
				else
					asap.Memory[addr] = cast(ubyte) data;
				break;
			case 135:
				addr = asap.Memory[pc++];
				data = a & x;
				asap.Memory[addr] = cast(ubyte) data;
				break;
			case 139:
				data = asap.Memory[pc++];
				a &= (data | 239) & x;
				nz = a & data;
				break;
			case 143:
				addr = asap.Memory[pc++];
				addr += asap.Memory[pc++] << 8;
				data = a & x;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, data);
				else
					asap.Memory[addr] = cast(ubyte) data;
				break;
			case 147:
				{
					addr = asap.Memory[pc++];
					int hi = asap.Memory[addr + 1 & 255];
					addr = asap.Memory[addr];
					data = hi + 1 & a & x;
					addr += y;
					if (addr >= 256)
						hi = data - 1;
					addr += hi << 8;
					if ((addr & 63744) == 53248)
						asap.PokeHardware(addr, data);
					else
						asap.Memory[addr] = cast(ubyte) data;
				}
				break;
			case 151:
				addr = asap.Memory[pc++] + y & 255;
				data = a & x;
				asap.Memory[addr] = cast(ubyte) data;
				break;
			case 155:
				s = a & x;
				{
					addr = asap.Memory[pc++];
					int hi = asap.Memory[pc++];
					data = hi + 1 & s;
					addr += y;
					if (addr >= 256)
						hi = data - 1;
					addr += hi << 8;
					if ((addr & 63744) == 53248)
						asap.PokeHardware(addr, data);
					else
						asap.Memory[addr] = cast(ubyte) data;
				}
				break;
			case 156:
				{
					addr = asap.Memory[pc++];
					int hi = asap.Memory[pc++];
					data = hi + 1 & y;
					addr += x;
					if (addr >= 256)
						hi = data - 1;
					addr += hi << 8;
					if ((addr & 63744) == 53248)
						asap.PokeHardware(addr, data);
					else
						asap.Memory[addr] = cast(ubyte) data;
				}
				break;
			case 158:
				{
					addr = asap.Memory[pc++];
					int hi = asap.Memory[pc++];
					data = hi + 1 & x;
					addr += y;
					if (addr >= 256)
						hi = data - 1;
					addr += hi << 8;
					if ((addr & 63744) == 53248)
						asap.PokeHardware(addr, data);
					else
						asap.Memory[addr] = cast(ubyte) data;
				}
				break;
			case 159:
				{
					addr = asap.Memory[pc++];
					int hi = asap.Memory[pc++];
					data = hi + 1 & a & x;
					addr += y;
					if (addr >= 256)
						hi = data - 1;
					addr += hi << 8;
					if ((addr & 63744) == 53248)
						asap.PokeHardware(addr, data);
					else
						asap.Memory[addr] = cast(ubyte) data;
				}
				break;
			case 163:
				addr = asap.Memory[pc++] + x & 255;
				addr = asap.Memory[addr] + (asap.Memory[addr + 1 & 255] << 8);
				nz = x = a = (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				break;
			case 167:
				addr = asap.Memory[pc++];
				nz = x = a = asap.Memory[addr];
				break;
			case 171:
				nz = x = a &= asap.Memory[pc++];
				break;
			case 175:
				addr = asap.Memory[pc++];
				addr += asap.Memory[pc++] << 8;
				nz = x = a = (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				break;
			case 179:
				addr = asap.Memory[pc++];
				addr = asap.Memory[addr] + (asap.Memory[addr + 1 & 255] << 8) + y & 65535;
				if ((addr & 255) < y)
					asap.Cycle++;
				nz = x = a = (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				break;
			case 183:
				addr = asap.Memory[pc++] + y & 255;
				nz = x = a = asap.Memory[addr];
				break;
			case 187:
				addr = asap.Memory[pc++];
				addr = addr + (asap.Memory[pc++] << 8) + y & 65535;
				if ((addr & 255) < y)
					asap.Cycle++;
				nz = x = a = s &= (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				break;
			case 191:
				addr = asap.Memory[pc++];
				addr = addr + (asap.Memory[pc++] << 8) + y & 65535;
				if ((addr & 255) < y)
					asap.Cycle++;
				nz = x = a = (addr & 63744) == 53248 ? asap.PeekHardware(addr) : asap.Memory[addr];
				break;
			case 195:
				addr = asap.Memory[pc++] + x & 255;
				addr = asap.Memory[addr] + (asap.Memory[addr + 1 & 255] << 8);
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				nz = nz - 1 & 255;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				c = a >= nz ? 1 : 0;
				nz = a - nz & 255;
				break;
			case 199:
				addr = asap.Memory[pc++];
				nz = asap.Memory[addr];
				nz = nz - 1 & 255;
				asap.Memory[addr] = cast(ubyte) nz;
				c = a >= nz ? 1 : 0;
				nz = a - nz & 255;
				break;
			case 203:
				nz = asap.Memory[pc++];
				x &= a;
				c = x >= nz ? 1 : 0;
				nz = x = x - nz & 255;
				break;
			case 207:
				addr = asap.Memory[pc++];
				addr += asap.Memory[pc++] << 8;
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				nz = nz - 1 & 255;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				c = a >= nz ? 1 : 0;
				nz = a - nz & 255;
				break;
			case 211:
				addr = asap.Memory[pc++];
				addr = asap.Memory[addr] + (asap.Memory[addr + 1 & 255] << 8) + y & 65535;
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				nz = nz - 1 & 255;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				c = a >= nz ? 1 : 0;
				nz = a - nz & 255;
				break;
			case 215:
				addr = asap.Memory[pc++] + x & 255;
				nz = asap.Memory[addr];
				nz = nz - 1 & 255;
				asap.Memory[addr] = cast(ubyte) nz;
				c = a >= nz ? 1 : 0;
				nz = a - nz & 255;
				break;
			case 219:
				addr = asap.Memory[pc++];
				addr = addr + (asap.Memory[pc++] << 8) + y & 65535;
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				nz = nz - 1 & 255;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				c = a >= nz ? 1 : 0;
				nz = a - nz & 255;
				break;
			case 223:
				addr = asap.Memory[pc++];
				addr = addr + (asap.Memory[pc++] << 8) + x & 65535;
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				nz = nz - 1 & 255;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				c = a >= nz ? 1 : 0;
				nz = a - nz & 255;
				break;
			case 227:
				addr = asap.Memory[pc++] + x & 255;
				addr = asap.Memory[addr] + (asap.Memory[addr + 1 & 255] << 8);
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				nz = nz + 1 & 255;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				data = nz;
				{
					int tmp = a - data - 1 + c;
					int al = (a & 15) - (data & 15) - 1 + c;
					vdi = (vdi & 12) + (((data ^ a) & (a ^ tmp)) >> 1 & 64);
					c = tmp >= 0 ? 1 : 0;
					nz = a = tmp & 255;
					if ((vdi & 8) != 0) {
						if (al < 0)
							a += al < -10 ? 10 : -6;
						if (c == 0)
							a = a - 96 & 255;
					}
				}
				break;
			case 231:
				addr = asap.Memory[pc++];
				nz = asap.Memory[addr];
				nz = nz + 1 & 255;
				asap.Memory[addr] = cast(ubyte) nz;
				data = nz;
				{
					int tmp = a - data - 1 + c;
					int al = (a & 15) - (data & 15) - 1 + c;
					vdi = (vdi & 12) + (((data ^ a) & (a ^ tmp)) >> 1 & 64);
					c = tmp >= 0 ? 1 : 0;
					nz = a = tmp & 255;
					if ((vdi & 8) != 0) {
						if (al < 0)
							a += al < -10 ? 10 : -6;
						if (c == 0)
							a = a - 96 & 255;
					}
				}
				break;
			case 239:
				addr = asap.Memory[pc++];
				addr += asap.Memory[pc++] << 8;
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				nz = nz + 1 & 255;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				data = nz;
				{
					int tmp = a - data - 1 + c;
					int al = (a & 15) - (data & 15) - 1 + c;
					vdi = (vdi & 12) + (((data ^ a) & (a ^ tmp)) >> 1 & 64);
					c = tmp >= 0 ? 1 : 0;
					nz = a = tmp & 255;
					if ((vdi & 8) != 0) {
						if (al < 0)
							a += al < -10 ? 10 : -6;
						if (c == 0)
							a = a - 96 & 255;
					}
				}
				break;
			case 243:
				addr = asap.Memory[pc++];
				addr = asap.Memory[addr] + (asap.Memory[addr + 1 & 255] << 8) + y & 65535;
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				nz = nz + 1 & 255;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				data = nz;
				{
					int tmp = a - data - 1 + c;
					int al = (a & 15) - (data & 15) - 1 + c;
					vdi = (vdi & 12) + (((data ^ a) & (a ^ tmp)) >> 1 & 64);
					c = tmp >= 0 ? 1 : 0;
					nz = a = tmp & 255;
					if ((vdi & 8) != 0) {
						if (al < 0)
							a += al < -10 ? 10 : -6;
						if (c == 0)
							a = a - 96 & 255;
					}
				}
				break;
			case 247:
				addr = asap.Memory[pc++] + x & 255;
				nz = asap.Memory[addr];
				nz = nz + 1 & 255;
				asap.Memory[addr] = cast(ubyte) nz;
				data = nz;
				{
					int tmp = a - data - 1 + c;
					int al = (a & 15) - (data & 15) - 1 + c;
					vdi = (vdi & 12) + (((data ^ a) & (a ^ tmp)) >> 1 & 64);
					c = tmp >= 0 ? 1 : 0;
					nz = a = tmp & 255;
					if ((vdi & 8) != 0) {
						if (al < 0)
							a += al < -10 ? 10 : -6;
						if (c == 0)
							a = a - 96 & 255;
					}
				}
				break;
			case 251:
				addr = asap.Memory[pc++];
				addr = addr + (asap.Memory[pc++] << 8) + y & 65535;
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				nz = nz + 1 & 255;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				data = nz;
				{
					int tmp = a - data - 1 + c;
					int al = (a & 15) - (data & 15) - 1 + c;
					vdi = (vdi & 12) + (((data ^ a) & (a ^ tmp)) >> 1 & 64);
					c = tmp >= 0 ? 1 : 0;
					nz = a = tmp & 255;
					if ((vdi & 8) != 0) {
						if (al < 0)
							a += al < -10 ? 10 : -6;
						if (c == 0)
							a = a - 96 & 255;
					}
				}
				break;
			case 255:
				addr = asap.Memory[pc++];
				addr = addr + (asap.Memory[pc++] << 8) + x & 65535;
				if (addr >> 8 == 210) {
					asap.Cycle--;
					nz = asap.PeekHardware(addr);
					asap.PokeHardware(addr, nz);
					asap.Cycle++;
				}
				else
					nz = asap.Memory[addr];
				nz = nz + 1 & 255;
				if ((addr & 63744) == 53248)
					asap.PokeHardware(addr, nz);
				else
					asap.Memory[addr] = cast(ubyte) nz;
				data = nz;
				{
					int tmp = a - data - 1 + c;
					int al = (a & 15) - (data & 15) - 1 + c;
					vdi = (vdi & 12) + (((data ^ a) & (a ^ tmp)) >> 1 & 64);
					c = tmp >= 0 ? 1 : 0;
					nz = a = tmp & 255;
					if ((vdi & 8) != 0) {
						if (al < 0)
							a += al < -10 ? 10 : -6;
						if (c == 0)
							a = a - 96 & 255;
					}
				}
				break;
			default:
				break;
			}
		}
		this.Pc = pc;
		this.Nz = nz;
		this.A = a;
		this.X = x;
		this.Y = y;
		this.C = c;
		this.S = s;
		this.Vdi = vdi;
	}
	int Nz;
	int Pc;
	int S;
	int Vdi;
	int X;
	int Y;
	static immutable(int[]) CiConstArray_1 = [ 7, 6, 2, 8, 3, 3, 5, 5, 3, 2, 2, 2, 4, 4, 6, 6,
		2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7,
		6, 6, 2, 8, 3, 3, 5, 5, 4, 2, 2, 2, 4, 4, 6, 6,
		2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7,
		6, 6, 2, 8, 3, 3, 5, 5, 3, 2, 2, 2, 3, 4, 6, 6,
		2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7,
		6, 6, 2, 8, 3, 3, 5, 5, 4, 2, 2, 2, 5, 4, 6, 6,
		2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7,
		2, 6, 2, 6, 3, 3, 3, 3, 2, 2, 2, 2, 4, 4, 4, 4,
		2, 6, 2, 6, 4, 4, 4, 4, 2, 5, 2, 5, 5, 5, 5, 5,
		2, 6, 2, 6, 3, 3, 3, 3, 2, 2, 2, 2, 4, 4, 4, 4,
		2, 5, 2, 5, 4, 4, 4, 4, 2, 4, 2, 4, 4, 4, 4, 4,
		2, 6, 2, 8, 3, 3, 5, 5, 2, 2, 2, 2, 4, 4, 6, 6,
		2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7,
		2, 6, 2, 8, 3, 3, 5, 5, 2, 2, 2, 2, 4, 4, 6, 6,
		2, 5, 2, 8, 4, 4, 6, 6, 2, 4, 2, 7, 4, 4, 7, 7 ];
}

enum NmiStatus
{
	Reset,
	OnVBlank,
	WasVBlank
}

class Pokey
{

	final void AddDelta(PokeyPair pokeys, int cycle, int delta)
	{
		int i = cycle * pokeys.SampleFactor + pokeys.SampleOffset;
		int delta2 = (delta >> 16) * (i >> 4 & 65535);
		i >>= 20;
		this.DeltaBuffer[i] += delta - delta2;
		this.DeltaBuffer[i + 1] += delta2;
	}
	int Audc1;
	int Audc2;
	int Audc3;
	int Audc4;
	int Audctl;
	int Audf1;
	int Audf2;
	int Audf3;
	int Audf4;
	int Delta1;
	int Delta2;
	int Delta3;
	int Delta4;
	int[] DeltaBuffer;
	int DivCycles;

	final void EndFrame(PokeyPair pokeys, int cycle)
	{
		this.GenerateUntilCycle(pokeys, cycle);
		this.PolyIndex += cycle;
		int m = (this.Audctl & 128) != 0 ? 237615 : 60948015;
		if (this.PolyIndex >= 2 * m)
			this.PolyIndex -= m;
		if (this.TickCycle1 != 8388608)
			this.TickCycle1 -= cycle;
		if (this.TickCycle2 != 8388608)
			this.TickCycle2 -= cycle;
		if (this.TickCycle3 != 8388608)
			this.TickCycle3 -= cycle;
		if (this.TickCycle4 != 8388608)
			this.TickCycle4 -= cycle;
	}

	/// Fills DeltaBuffer up to cycleLimit basing on current Audf/Audc/AudcTL values.
	final void GenerateUntilCycle(PokeyPair pokeys, int cycleLimit)
	{
		for (;;) {
			int cycle = cycleLimit;
			if (cycle > this.TickCycle1)
				cycle = this.TickCycle1;
			if (cycle > this.TickCycle2)
				cycle = this.TickCycle2;
			if (cycle > this.TickCycle3)
				cycle = this.TickCycle3;
			if (cycle > this.TickCycle4)
				cycle = this.TickCycle4;
			if (cycle == cycleLimit)
				break;
			if (cycle == this.TickCycle3) {
				this.TickCycle3 += this.PeriodCycles3;
				if ((this.Audctl & 4) != 0 && this.Delta1 > 0 && this.Mute1 == 0) {
					this.Delta1 = -this.Delta1;
					this.AddDelta(pokeys, cycle, this.Delta1);
				}
				if (this.Init) {
					switch (this.Audc3 >> 4) {
					case 10:
					case 14:
						this.Out3 ^= 1;
						this.Delta3 = -this.Delta3;
						this.AddDelta(pokeys, cycle, this.Delta3);
						break;
					default:
						break;
					}
				}
				else {
					int poly = cycle + this.PolyIndex - 2;
					int newOut = this.Out3;
					switch (this.Audc3 >> 4) {
					case 0:
						if (CiConstArray_2[poly % 31] != 0) {
							if ((this.Audctl & 128) != 0)
								newOut = pokeys.Poly9Lookup[poly % 511] & 1;
							else {
								poly %= 131071;
								newOut = pokeys.Poly17Lookup[poly >> 3] >> (poly & 7) & 1;
							}
						}
						break;
					case 2:
					case 6:
						newOut ^= CiConstArray_2[poly % 31];
						break;
					case 4:
						if (CiConstArray_2[poly % 31] != 0)
							newOut = CiConstArray_1[poly % 15];
						break;
					case 8:
						if ((this.Audctl & 128) != 0)
							newOut = pokeys.Poly9Lookup[poly % 511] & 1;
						else {
							poly %= 131071;
							newOut = pokeys.Poly17Lookup[poly >> 3] >> (poly & 7) & 1;
						}
						break;
					case 10:
					case 14:
						newOut ^= 1;
						break;
					case 12:
						newOut = CiConstArray_1[poly % 15];
						break;
					default:
						break;
					}
					if (newOut != this.Out3) {
						this.Out3 = newOut;
						this.Delta3 = -this.Delta3;
						this.AddDelta(pokeys, cycle, this.Delta3);
					}
				}
			}
			if (cycle == this.TickCycle4) {
				this.TickCycle4 += this.PeriodCycles4;
				if ((this.Audctl & 8) != 0)
					this.TickCycle3 = cycle + this.ReloadCycles3;
				if ((this.Audctl & 2) != 0 && this.Delta2 > 0 && this.Mute2 == 0) {
					this.Delta2 = -this.Delta2;
					this.AddDelta(pokeys, cycle, this.Delta2);
				}
				if (this.Init) {
					switch (this.Audc4 >> 4) {
					case 10:
					case 14:
						this.Out4 ^= 1;
						this.Delta4 = -this.Delta4;
						this.AddDelta(pokeys, cycle, this.Delta4);
						break;
					default:
						break;
					}
				}
				else {
					int poly = cycle + this.PolyIndex - 3;
					int newOut = this.Out4;
					switch (this.Audc4 >> 4) {
					case 0:
						if (CiConstArray_2[poly % 31] != 0) {
							if ((this.Audctl & 128) != 0)
								newOut = pokeys.Poly9Lookup[poly % 511] & 1;
							else {
								poly %= 131071;
								newOut = pokeys.Poly17Lookup[poly >> 3] >> (poly & 7) & 1;
							}
						}
						break;
					case 2:
					case 6:
						newOut ^= CiConstArray_2[poly % 31];
						break;
					case 4:
						if (CiConstArray_2[poly % 31] != 0)
							newOut = CiConstArray_1[poly % 15];
						break;
					case 8:
						if ((this.Audctl & 128) != 0)
							newOut = pokeys.Poly9Lookup[poly % 511] & 1;
						else {
							poly %= 131071;
							newOut = pokeys.Poly17Lookup[poly >> 3] >> (poly & 7) & 1;
						}
						break;
					case 10:
					case 14:
						newOut ^= 1;
						break;
					case 12:
						newOut = CiConstArray_1[poly % 15];
						break;
					default:
						break;
					}
					if (newOut != this.Out4) {
						this.Out4 = newOut;
						this.Delta4 = -this.Delta4;
						this.AddDelta(pokeys, cycle, this.Delta4);
					}
				}
			}
			if (cycle == this.TickCycle1) {
				this.TickCycle1 += this.PeriodCycles1;
				if ((this.Skctl & 136) == 8)
					this.TickCycle2 = cycle + this.PeriodCycles2;
				if (this.Init) {
					switch (this.Audc1 >> 4) {
					case 10:
					case 14:
						this.Out1 ^= 1;
						this.Delta1 = -this.Delta1;
						this.AddDelta(pokeys, cycle, this.Delta1);
						break;
					default:
						break;
					}
				}
				else {
					int poly = cycle + this.PolyIndex - 0;
					int newOut = this.Out1;
					switch (this.Audc1 >> 4) {
					case 0:
						if (CiConstArray_2[poly % 31] != 0) {
							if ((this.Audctl & 128) != 0)
								newOut = pokeys.Poly9Lookup[poly % 511] & 1;
							else {
								poly %= 131071;
								newOut = pokeys.Poly17Lookup[poly >> 3] >> (poly & 7) & 1;
							}
						}
						break;
					case 2:
					case 6:
						newOut ^= CiConstArray_2[poly % 31];
						break;
					case 4:
						if (CiConstArray_2[poly % 31] != 0)
							newOut = CiConstArray_1[poly % 15];
						break;
					case 8:
						if ((this.Audctl & 128) != 0)
							newOut = pokeys.Poly9Lookup[poly % 511] & 1;
						else {
							poly %= 131071;
							newOut = pokeys.Poly17Lookup[poly >> 3] >> (poly & 7) & 1;
						}
						break;
					case 10:
					case 14:
						newOut ^= 1;
						break;
					case 12:
						newOut = CiConstArray_1[poly % 15];
						break;
					default:
						break;
					}
					if (newOut != this.Out1) {
						this.Out1 = newOut;
						this.Delta1 = -this.Delta1;
						this.AddDelta(pokeys, cycle, this.Delta1);
					}
				}
			}
			if (cycle == this.TickCycle2) {
				this.TickCycle2 += this.PeriodCycles2;
				if ((this.Audctl & 16) != 0)
					this.TickCycle1 = cycle + this.ReloadCycles1;
				else if ((this.Skctl & 8) != 0)
					this.TickCycle1 = cycle + this.PeriodCycles1;
				if (this.Init) {
					switch (this.Audc2 >> 4) {
					case 10:
					case 14:
						this.Out2 ^= 1;
						this.Delta2 = -this.Delta2;
						this.AddDelta(pokeys, cycle, this.Delta2);
						break;
					default:
						break;
					}
				}
				else {
					int poly = cycle + this.PolyIndex - 1;
					int newOut = this.Out2;
					switch (this.Audc2 >> 4) {
					case 0:
						if (CiConstArray_2[poly % 31] != 0) {
							if ((this.Audctl & 128) != 0)
								newOut = pokeys.Poly9Lookup[poly % 511] & 1;
							else {
								poly %= 131071;
								newOut = pokeys.Poly17Lookup[poly >> 3] >> (poly & 7) & 1;
							}
						}
						break;
					case 2:
					case 6:
						newOut ^= CiConstArray_2[poly % 31];
						break;
					case 4:
						if (CiConstArray_2[poly % 31] != 0)
							newOut = CiConstArray_1[poly % 15];
						break;
					case 8:
						if ((this.Audctl & 128) != 0)
							newOut = pokeys.Poly9Lookup[poly % 511] & 1;
						else {
							poly %= 131071;
							newOut = pokeys.Poly17Lookup[poly >> 3] >> (poly & 7) & 1;
						}
						break;
					case 10:
					case 14:
						newOut ^= 1;
						break;
					case 12:
						newOut = CiConstArray_1[poly % 15];
						break;
					default:
						break;
					}
					if (newOut != this.Out2) {
						this.Out2 = newOut;
						this.Delta2 = -this.Delta2;
						this.AddDelta(pokeys, cycle, this.Delta2);
					}
				}
			}
		}
	}
	bool Init;

	final void Initialize()
	{
		this.Audf1 = 0;
		this.Audf2 = 0;
		this.Audf3 = 0;
		this.Audf4 = 0;
		this.Audc1 = 0;
		this.Audc2 = 0;
		this.Audc3 = 0;
		this.Audc4 = 0;
		this.Audctl = 0;
		this.Skctl = 3;
		this.Init = false;
		this.DivCycles = 28;
		this.PeriodCycles1 = 28;
		this.PeriodCycles2 = 28;
		this.PeriodCycles3 = 28;
		this.PeriodCycles4 = 28;
		this.ReloadCycles1 = 28;
		this.ReloadCycles3 = 28;
		this.PolyIndex = 60948015;
		this.TickCycle1 = 8388608;
		this.TickCycle2 = 8388608;
		this.TickCycle3 = 8388608;
		this.TickCycle4 = 8388608;
		this.Mute1 = 1;
		this.Mute2 = 1;
		this.Mute3 = 1;
		this.Mute4 = 1;
		this.Out1 = 0;
		this.Out2 = 0;
		this.Out3 = 0;
		this.Out4 = 0;
		this.Delta1 = 0;
		this.Delta2 = 0;
		this.Delta3 = 0;
		this.Delta4 = 0;
		this.DeltaBuffer[] = 0;
	}

	final bool IsSilent()
	{
		return ((this.Audc1 | this.Audc2 | this.Audc3 | this.Audc4) & 15) == 0;
	}

	final void Mute(int mask)
	{
		if ((mask & 1) != 0) {
			this.Mute1 |= 4;
			this.TickCycle1 = 8388608;
		}
		else {
			this.Mute1 &= ~4;
			if (this.TickCycle1 == 8388608 && this.Mute1 == 0)
				this.TickCycle1 = 0;
		}
		if ((mask & 2) != 0) {
			this.Mute2 |= 4;
			this.TickCycle2 = 8388608;
		}
		else {
			this.Mute2 &= ~4;
			if (this.TickCycle2 == 8388608 && this.Mute2 == 0)
				this.TickCycle2 = 0;
		}
		if ((mask & 4) != 0) {
			this.Mute3 |= 4;
			this.TickCycle3 = 8388608;
		}
		else {
			this.Mute3 &= ~4;
			if (this.TickCycle3 == 8388608 && this.Mute3 == 0)
				this.TickCycle3 = 0;
		}
		if ((mask & 8) != 0) {
			this.Mute4 |= 4;
			this.TickCycle4 = 8388608;
		}
		else {
			this.Mute4 &= ~4;
			if (this.TickCycle4 == 8388608 && this.Mute4 == 0)
				this.TickCycle4 = 0;
		}
	}
	int Mute1;
	int Mute2;
	int Mute3;
	int Mute4;
	private int Out1;
	private int Out2;
	private int Out3;
	private int Out4;
	int PeriodCycles1;
	int PeriodCycles2;
	int PeriodCycles3;
	int PeriodCycles4;
	int PolyIndex;
	int ReloadCycles1;
	int ReloadCycles3;
	int Skctl;
	int TickCycle1;
	int TickCycle2;
	int TickCycle3;
	int TickCycle4;
	static immutable(ubyte[]) CiConstArray_1 = [ 0, 0, 0, 0, 1, 1, 1, 0, 1, 1, 0, 0, 1, 0, 1 ];
	static immutable(ubyte[]) CiConstArray_2 = [ 0, 0, 0, 0, 0, 1, 1, 1, 0, 0, 1, 0, 0, 0, 1, 0,
		1, 0, 1, 1, 1, 1, 0, 1, 1, 0, 1, 0, 0, 1, 1 ];
	this()
	{
		DeltaBuffer = new int[888];
	}
}

class PokeyPair
{
	Pokey BasePokey;

	final int EndFrame(int cycle)
	{
		this.BasePokey.EndFrame(this, cycle);
		if (this.ExtraPokeyMask != 0)
			this.ExtraPokey.EndFrame(this, cycle);
		this.SampleOffset += cycle * this.SampleFactor;
		this.ReadySamplesStart = 0;
		this.ReadySamplesEnd = this.SampleOffset >> 20;
		this.SampleOffset &= 1048575;
		return this.ReadySamplesEnd;
	}
	Pokey ExtraPokey;
	int ExtraPokeyMask;

	/// Fills buffer with samples from DeltaBuffer.
	final int Generate(ubyte[] buffer, int bufferOffset, int blocks, ASAPSampleFormat format)
	{
		int i = this.ReadySamplesStart;
		int samplesEnd = this.ReadySamplesEnd;
		if (blocks < samplesEnd - i)
			samplesEnd = i + blocks;
		else
			blocks = samplesEnd - i;
		int accLeft = this.IirAccLeft;
		int accRight = this.IirAccRight;
		for (; i < samplesEnd; i++) {
			accLeft += this.BasePokey.DeltaBuffer[i] - (accLeft * 3 >> 10);
			int sample = accLeft >> 10;
			if (sample < -32767)
				sample = -32767;
			else if (sample > 32767)
				sample = 32767;
			switch (format) {
			case ASAPSampleFormat.U8:
				buffer[bufferOffset++] = cast(ubyte) ((sample >> 8) + 128);
				break;
			case ASAPSampleFormat.S16LE:
				buffer[bufferOffset++] = cast(ubyte) sample;
				buffer[bufferOffset++] = cast(ubyte) (sample >> 8);
				break;
			case ASAPSampleFormat.S16BE:
				buffer[bufferOffset++] = cast(ubyte) (sample >> 8);
				buffer[bufferOffset++] = cast(ubyte) sample;
				break;
			default:
				break;
			}
			if (this.ExtraPokeyMask != 0) {
				accRight += this.ExtraPokey.DeltaBuffer[i] - (accRight * 3 >> 10);
				sample = accRight >> 10;
				if (sample < -32767)
					sample = -32767;
				else if (sample > 32767)
					sample = 32767;
				switch (format) {
				case ASAPSampleFormat.U8:
					buffer[bufferOffset++] = cast(ubyte) ((sample >> 8) + 128);
					break;
				case ASAPSampleFormat.S16LE:
					buffer[bufferOffset++] = cast(ubyte) sample;
					buffer[bufferOffset++] = cast(ubyte) (sample >> 8);
					break;
				case ASAPSampleFormat.S16BE:
					buffer[bufferOffset++] = cast(ubyte) (sample >> 8);
					buffer[bufferOffset++] = cast(ubyte) sample;
					break;
				default:
					break;
				}
			}
		}
		if (i == this.ReadySamplesEnd) {
			accLeft += this.BasePokey.DeltaBuffer[i] + this.BasePokey.DeltaBuffer[i + 1];
			accRight += this.ExtraPokey.DeltaBuffer[i] + this.ExtraPokey.DeltaBuffer[i + 1];
		}
		this.ReadySamplesStart = i;
		this.IirAccLeft = accLeft;
		this.IirAccRight = accRight;
		return blocks;
	}

	final int GetRandom(int addr, int cycle)
	{
		Pokey pokey = (addr & this.ExtraPokeyMask) != 0 ? this.ExtraPokey : this.BasePokey;
		if (pokey.Init)
			return 255;
		int i = cycle + pokey.PolyIndex;
		if ((pokey.Audctl & 128) != 0)
			return this.Poly9Lookup[i % 511];
		i %= 131071;
		int j = i >> 3;
		i &= 7;
		return (this.Poly17Lookup[j] >> i) + (this.Poly17Lookup[j + 1] << 8 - i) & 255;
	}
	private int IirAccLeft;
	private int IirAccRight;

	final void Initialize(bool ntsc, bool stereo)
	{
		this.ExtraPokeyMask = stereo ? 16 : 0;
		this.Timer1Cycle = 8388608;
		this.Timer2Cycle = 8388608;
		this.Timer4Cycle = 8388608;
		this.Irqst = 255;
		this.BasePokey.Initialize();
		this.ExtraPokey.Initialize();
		this.SampleFactor = ntsc ? 25837 : 26075;
		this.SampleOffset = 0;
		this.ReadySamplesStart = 0;
		this.ReadySamplesEnd = 0;
		this.IirAccLeft = 0;
		this.IirAccRight = 0;
	}
	int Irqst;

	final bool IsSilent()
	{
		return this.BasePokey.IsSilent() && this.ExtraPokey.IsSilent();
	}

	final void Poke(int addr, int data, int cycle)
	{
		Pokey pokey = (addr & this.ExtraPokeyMask) != 0 ? this.ExtraPokey : this.BasePokey;
		switch (addr & 15) {
		case 0:
			if (data == pokey.Audf1)
				break;
			pokey.GenerateUntilCycle(this, cycle);
			pokey.Audf1 = data;
			switch (pokey.Audctl & 80) {
			case 0:
				pokey.PeriodCycles1 = pokey.DivCycles * (data + 1);
				break;
			case 16:
				pokey.PeriodCycles2 = pokey.DivCycles * (data + (pokey.Audf2 << 8) + 1);
				pokey.ReloadCycles1 = pokey.DivCycles * (data + 1);
				if (pokey.PeriodCycles2 <= 112 && (pokey.Audc2 >> 4 == 10 || pokey.Audc2 >> 4 == 14)) {
					pokey.Mute2 |= 1;
					pokey.TickCycle2 = 8388608;
				}
				else {
					pokey.Mute2 &= ~1;
					if (pokey.TickCycle2 == 8388608 && pokey.Mute2 == 0)
						pokey.TickCycle2 = cycle;
				}
				break;
			case 64:
				pokey.PeriodCycles1 = data + 4;
				break;
			case 80:
				pokey.PeriodCycles2 = data + (pokey.Audf2 << 8) + 7;
				pokey.ReloadCycles1 = data + 4;
				if (pokey.PeriodCycles2 <= 112 && (pokey.Audc2 >> 4 == 10 || pokey.Audc2 >> 4 == 14)) {
					pokey.Mute2 |= 1;
					pokey.TickCycle2 = 8388608;
				}
				else {
					pokey.Mute2 &= ~1;
					if (pokey.TickCycle2 == 8388608 && pokey.Mute2 == 0)
						pokey.TickCycle2 = cycle;
				}
				break;
			default:
				break;
			}
			if (pokey.PeriodCycles1 <= 112 && (pokey.Audc1 >> 4 == 10 || pokey.Audc1 >> 4 == 14)) {
				pokey.Mute1 |= 1;
				pokey.TickCycle1 = 8388608;
			}
			else {
				pokey.Mute1 &= ~1;
				if (pokey.TickCycle1 == 8388608 && pokey.Mute1 == 0)
					pokey.TickCycle1 = cycle;
			}
			break;
		case 1:
			if (data == pokey.Audc1)
				break;
			pokey.GenerateUntilCycle(this, cycle);
			pokey.Audc1 = data;
			if ((data & 16) != 0) {
				data = (data & 15) << 20;
				if ((pokey.Mute1 & 4) == 0)
					pokey.AddDelta(this, cycle, pokey.Delta1 > 0 ? data - pokey.Delta1 : data);
				pokey.Delta1 = data;
			}
			else {
				data = (data & 15) << 20;
				if (pokey.PeriodCycles1 <= 112 && (pokey.Audc1 >> 4 == 10 || pokey.Audc1 >> 4 == 14)) {
					pokey.Mute1 |= 1;
					pokey.TickCycle1 = 8388608;
				}
				else {
					pokey.Mute1 &= ~1;
					if (pokey.TickCycle1 == 8388608 && pokey.Mute1 == 0)
						pokey.TickCycle1 = cycle;
				}
				if (pokey.Delta1 > 0) {
					if ((pokey.Mute1 & 4) == 0)
						pokey.AddDelta(this, cycle, data - pokey.Delta1);
					pokey.Delta1 = data;
				}
				else
					pokey.Delta1 = -data;
			}
			break;
		case 2:
			if (data == pokey.Audf2)
				break;
			pokey.GenerateUntilCycle(this, cycle);
			pokey.Audf2 = data;
			switch (pokey.Audctl & 80) {
			case 0:
			case 64:
				pokey.PeriodCycles2 = pokey.DivCycles * (data + 1);
				break;
			case 16:
				pokey.PeriodCycles2 = pokey.DivCycles * (pokey.Audf1 + (data << 8) + 1);
				break;
			case 80:
				pokey.PeriodCycles2 = pokey.Audf1 + (data << 8) + 7;
				break;
			default:
				break;
			}
			if (pokey.PeriodCycles2 <= 112 && (pokey.Audc2 >> 4 == 10 || pokey.Audc2 >> 4 == 14)) {
				pokey.Mute2 |= 1;
				pokey.TickCycle2 = 8388608;
			}
			else {
				pokey.Mute2 &= ~1;
				if (pokey.TickCycle2 == 8388608 && pokey.Mute2 == 0)
					pokey.TickCycle2 = cycle;
			}
			break;
		case 3:
			if (data == pokey.Audc2)
				break;
			pokey.GenerateUntilCycle(this, cycle);
			pokey.Audc2 = data;
			if ((data & 16) != 0) {
				data = (data & 15) << 20;
				if ((pokey.Mute2 & 4) == 0)
					pokey.AddDelta(this, cycle, pokey.Delta2 > 0 ? data - pokey.Delta2 : data);
				pokey.Delta2 = data;
			}
			else {
				data = (data & 15) << 20;
				if (pokey.PeriodCycles2 <= 112 && (pokey.Audc2 >> 4 == 10 || pokey.Audc2 >> 4 == 14)) {
					pokey.Mute2 |= 1;
					pokey.TickCycle2 = 8388608;
				}
				else {
					pokey.Mute2 &= ~1;
					if (pokey.TickCycle2 == 8388608 && pokey.Mute2 == 0)
						pokey.TickCycle2 = cycle;
				}
				if (pokey.Delta2 > 0) {
					if ((pokey.Mute2 & 4) == 0)
						pokey.AddDelta(this, cycle, data - pokey.Delta2);
					pokey.Delta2 = data;
				}
				else
					pokey.Delta2 = -data;
			}
			break;
		case 4:
			if (data == pokey.Audf3)
				break;
			pokey.GenerateUntilCycle(this, cycle);
			pokey.Audf3 = data;
			switch (pokey.Audctl & 40) {
			case 0:
				pokey.PeriodCycles3 = pokey.DivCycles * (data + 1);
				break;
			case 8:
				pokey.PeriodCycles4 = pokey.DivCycles * (data + (pokey.Audf4 << 8) + 1);
				pokey.ReloadCycles3 = pokey.DivCycles * (data + 1);
				if (pokey.PeriodCycles4 <= 112 && (pokey.Audc4 >> 4 == 10 || pokey.Audc4 >> 4 == 14)) {
					pokey.Mute4 |= 1;
					pokey.TickCycle4 = 8388608;
				}
				else {
					pokey.Mute4 &= ~1;
					if (pokey.TickCycle4 == 8388608 && pokey.Mute4 == 0)
						pokey.TickCycle4 = cycle;
				}
				break;
			case 32:
				pokey.PeriodCycles3 = data + 4;
				break;
			case 40:
				pokey.PeriodCycles4 = data + (pokey.Audf4 << 8) + 7;
				pokey.ReloadCycles3 = data + 4;
				if (pokey.PeriodCycles4 <= 112 && (pokey.Audc4 >> 4 == 10 || pokey.Audc4 >> 4 == 14)) {
					pokey.Mute4 |= 1;
					pokey.TickCycle4 = 8388608;
				}
				else {
					pokey.Mute4 &= ~1;
					if (pokey.TickCycle4 == 8388608 && pokey.Mute4 == 0)
						pokey.TickCycle4 = cycle;
				}
				break;
			default:
				break;
			}
			if (pokey.PeriodCycles3 <= 112 && (pokey.Audc3 >> 4 == 10 || pokey.Audc3 >> 4 == 14)) {
				pokey.Mute3 |= 1;
				pokey.TickCycle3 = 8388608;
			}
			else {
				pokey.Mute3 &= ~1;
				if (pokey.TickCycle3 == 8388608 && pokey.Mute3 == 0)
					pokey.TickCycle3 = cycle;
			}
			break;
		case 5:
			if (data == pokey.Audc3)
				break;
			pokey.GenerateUntilCycle(this, cycle);
			pokey.Audc3 = data;
			if ((data & 16) != 0) {
				data = (data & 15) << 20;
				if ((pokey.Mute3 & 4) == 0)
					pokey.AddDelta(this, cycle, pokey.Delta3 > 0 ? data - pokey.Delta3 : data);
				pokey.Delta3 = data;
			}
			else {
				data = (data & 15) << 20;
				if (pokey.PeriodCycles3 <= 112 && (pokey.Audc3 >> 4 == 10 || pokey.Audc3 >> 4 == 14)) {
					pokey.Mute3 |= 1;
					pokey.TickCycle3 = 8388608;
				}
				else {
					pokey.Mute3 &= ~1;
					if (pokey.TickCycle3 == 8388608 && pokey.Mute3 == 0)
						pokey.TickCycle3 = cycle;
				}
				if (pokey.Delta3 > 0) {
					if ((pokey.Mute3 & 4) == 0)
						pokey.AddDelta(this, cycle, data - pokey.Delta3);
					pokey.Delta3 = data;
				}
				else
					pokey.Delta3 = -data;
			}
			break;
		case 6:
			if (data == pokey.Audf4)
				break;
			pokey.GenerateUntilCycle(this, cycle);
			pokey.Audf4 = data;
			switch (pokey.Audctl & 40) {
			case 0:
			case 32:
				pokey.PeriodCycles4 = pokey.DivCycles * (data + 1);
				break;
			case 8:
				pokey.PeriodCycles4 = pokey.DivCycles * (pokey.Audf3 + (data << 8) + 1);
				break;
			case 40:
				pokey.PeriodCycles4 = pokey.Audf3 + (data << 8) + 7;
				break;
			default:
				break;
			}
			if (pokey.PeriodCycles4 <= 112 && (pokey.Audc4 >> 4 == 10 || pokey.Audc4 >> 4 == 14)) {
				pokey.Mute4 |= 1;
				pokey.TickCycle4 = 8388608;
			}
			else {
				pokey.Mute4 &= ~1;
				if (pokey.TickCycle4 == 8388608 && pokey.Mute4 == 0)
					pokey.TickCycle4 = cycle;
			}
			break;
		case 7:
			if (data == pokey.Audc4)
				break;
			pokey.GenerateUntilCycle(this, cycle);
			pokey.Audc4 = data;
			if ((data & 16) != 0) {
				data = (data & 15) << 20;
				if ((pokey.Mute4 & 4) == 0)
					pokey.AddDelta(this, cycle, pokey.Delta4 > 0 ? data - pokey.Delta4 : data);
				pokey.Delta4 = data;
			}
			else {
				data = (data & 15) << 20;
				if (pokey.PeriodCycles4 <= 112 && (pokey.Audc4 >> 4 == 10 || pokey.Audc4 >> 4 == 14)) {
					pokey.Mute4 |= 1;
					pokey.TickCycle4 = 8388608;
				}
				else {
					pokey.Mute4 &= ~1;
					if (pokey.TickCycle4 == 8388608 && pokey.Mute4 == 0)
						pokey.TickCycle4 = cycle;
				}
				if (pokey.Delta4 > 0) {
					if ((pokey.Mute4 & 4) == 0)
						pokey.AddDelta(this, cycle, data - pokey.Delta4);
					pokey.Delta4 = data;
				}
				else
					pokey.Delta4 = -data;
			}
			break;
		case 8:
			if (data == pokey.Audctl)
				break;
			pokey.GenerateUntilCycle(this, cycle);
			pokey.Audctl = data;
			pokey.DivCycles = (data & 1) != 0 ? 114 : 28;
			switch (data & 80) {
			case 0:
				pokey.PeriodCycles1 = pokey.DivCycles * (pokey.Audf1 + 1);
				pokey.PeriodCycles2 = pokey.DivCycles * (pokey.Audf2 + 1);
				break;
			case 16:
				pokey.PeriodCycles1 = pokey.DivCycles << 8;
				pokey.PeriodCycles2 = pokey.DivCycles * (pokey.Audf1 + (pokey.Audf2 << 8) + 1);
				pokey.ReloadCycles1 = pokey.DivCycles * (pokey.Audf1 + 1);
				break;
			case 64:
				pokey.PeriodCycles1 = pokey.Audf1 + 4;
				pokey.PeriodCycles2 = pokey.DivCycles * (pokey.Audf2 + 1);
				break;
			case 80:
				pokey.PeriodCycles1 = 256;
				pokey.PeriodCycles2 = pokey.Audf1 + (pokey.Audf2 << 8) + 7;
				pokey.ReloadCycles1 = pokey.Audf1 + 4;
				break;
			default:
				break;
			}
			if (pokey.PeriodCycles1 <= 112 && (pokey.Audc1 >> 4 == 10 || pokey.Audc1 >> 4 == 14)) {
				pokey.Mute1 |= 1;
				pokey.TickCycle1 = 8388608;
			}
			else {
				pokey.Mute1 &= ~1;
				if (pokey.TickCycle1 == 8388608 && pokey.Mute1 == 0)
					pokey.TickCycle1 = cycle;
			}
			if (pokey.PeriodCycles2 <= 112 && (pokey.Audc2 >> 4 == 10 || pokey.Audc2 >> 4 == 14)) {
				pokey.Mute2 |= 1;
				pokey.TickCycle2 = 8388608;
			}
			else {
				pokey.Mute2 &= ~1;
				if (pokey.TickCycle2 == 8388608 && pokey.Mute2 == 0)
					pokey.TickCycle2 = cycle;
			}
			switch (data & 40) {
			case 0:
				pokey.PeriodCycles3 = pokey.DivCycles * (pokey.Audf3 + 1);
				pokey.PeriodCycles4 = pokey.DivCycles * (pokey.Audf4 + 1);
				break;
			case 8:
				pokey.PeriodCycles3 = pokey.DivCycles << 8;
				pokey.PeriodCycles4 = pokey.DivCycles * (pokey.Audf3 + (pokey.Audf4 << 8) + 1);
				pokey.ReloadCycles3 = pokey.DivCycles * (pokey.Audf3 + 1);
				break;
			case 32:
				pokey.PeriodCycles3 = pokey.Audf3 + 4;
				pokey.PeriodCycles4 = pokey.DivCycles * (pokey.Audf4 + 1);
				break;
			case 40:
				pokey.PeriodCycles3 = 256;
				pokey.PeriodCycles4 = pokey.Audf3 + (pokey.Audf4 << 8) + 7;
				pokey.ReloadCycles3 = pokey.Audf3 + 4;
				break;
			default:
				break;
			}
			if (pokey.PeriodCycles3 <= 112 && (pokey.Audc3 >> 4 == 10 || pokey.Audc3 >> 4 == 14)) {
				pokey.Mute3 |= 1;
				pokey.TickCycle3 = 8388608;
			}
			else {
				pokey.Mute3 &= ~1;
				if (pokey.TickCycle3 == 8388608 && pokey.Mute3 == 0)
					pokey.TickCycle3 = cycle;
			}
			if (pokey.PeriodCycles4 <= 112 && (pokey.Audc4 >> 4 == 10 || pokey.Audc4 >> 4 == 14)) {
				pokey.Mute4 |= 1;
				pokey.TickCycle4 = 8388608;
			}
			else {
				pokey.Mute4 &= ~1;
				if (pokey.TickCycle4 == 8388608 && pokey.Mute4 == 0)
					pokey.TickCycle4 = cycle;
			}
			if (pokey.Init && (data & 64) == 0) {
				pokey.Mute1 |= 2;
				pokey.TickCycle1 = 8388608;
			}
			else {
				pokey.Mute1 &= ~2;
				if (pokey.TickCycle1 == 8388608 && pokey.Mute1 == 0)
					pokey.TickCycle1 = cycle;
			}
			if (pokey.Init && (data & 80) != 80) {
				pokey.Mute2 |= 2;
				pokey.TickCycle2 = 8388608;
			}
			else {
				pokey.Mute2 &= ~2;
				if (pokey.TickCycle2 == 8388608 && pokey.Mute2 == 0)
					pokey.TickCycle2 = cycle;
			}
			if (pokey.Init && (data & 32) == 0) {
				pokey.Mute3 |= 2;
				pokey.TickCycle3 = 8388608;
			}
			else {
				pokey.Mute3 &= ~2;
				if (pokey.TickCycle3 == 8388608 && pokey.Mute3 == 0)
					pokey.TickCycle3 = cycle;
			}
			if (pokey.Init && (data & 40) != 40) {
				pokey.Mute4 |= 2;
				pokey.TickCycle4 = 8388608;
			}
			else {
				pokey.Mute4 &= ~2;
				if (pokey.TickCycle4 == 8388608 && pokey.Mute4 == 0)
					pokey.TickCycle4 = cycle;
			}
			break;
		case 9:
			if (pokey.TickCycle1 != 8388608)
				pokey.TickCycle1 = cycle + pokey.PeriodCycles1;
			if (pokey.TickCycle2 != 8388608)
				pokey.TickCycle2 = cycle + pokey.PeriodCycles2;
			if (pokey.TickCycle3 != 8388608)
				pokey.TickCycle3 = cycle + pokey.PeriodCycles3;
			if (pokey.TickCycle4 != 8388608)
				pokey.TickCycle4 = cycle + pokey.PeriodCycles4;
			break;
		case 15:
			if (data == pokey.Skctl)
				break;
			pokey.GenerateUntilCycle(this, cycle);
			pokey.Skctl = data;
			bool init = (data & 3) == 0;
			if (pokey.Init && !init)
				pokey.PolyIndex = ((pokey.Audctl & 128) != 0 ? 237614 : 60948014) - cycle;
			pokey.Init = init;
			if (pokey.Init && (pokey.Audctl & 64) == 0) {
				pokey.Mute1 |= 2;
				pokey.TickCycle1 = 8388608;
			}
			else {
				pokey.Mute1 &= ~2;
				if (pokey.TickCycle1 == 8388608 && pokey.Mute1 == 0)
					pokey.TickCycle1 = cycle;
			}
			if (pokey.Init && (pokey.Audctl & 80) != 80) {
				pokey.Mute2 |= 2;
				pokey.TickCycle2 = 8388608;
			}
			else {
				pokey.Mute2 &= ~2;
				if (pokey.TickCycle2 == 8388608 && pokey.Mute2 == 0)
					pokey.TickCycle2 = cycle;
			}
			if (pokey.Init && (pokey.Audctl & 32) == 0) {
				pokey.Mute3 |= 2;
				pokey.TickCycle3 = 8388608;
			}
			else {
				pokey.Mute3 &= ~2;
				if (pokey.TickCycle3 == 8388608 && pokey.Mute3 == 0)
					pokey.TickCycle3 = cycle;
			}
			if (pokey.Init && (pokey.Audctl & 40) != 40) {
				pokey.Mute4 |= 2;
				pokey.TickCycle4 = 8388608;
			}
			else {
				pokey.Mute4 &= ~2;
				if (pokey.TickCycle4 == 8388608 && pokey.Mute4 == 0)
					pokey.TickCycle4 = cycle;
			}
			if ((data & 16) != 0) {
				pokey.Mute3 |= 8;
				pokey.TickCycle3 = 8388608;
			}
			else {
				pokey.Mute3 &= ~8;
				if (pokey.TickCycle3 == 8388608 && pokey.Mute3 == 0)
					pokey.TickCycle3 = cycle;
			}
			if ((data & 16) != 0) {
				pokey.Mute4 |= 8;
				pokey.TickCycle4 = 8388608;
			}
			else {
				pokey.Mute4 &= ~8;
				if (pokey.TickCycle4 == 8388608 && pokey.Mute4 == 0)
					pokey.TickCycle4 = cycle;
			}
			break;
		default:
			break;
		}
	}
	ubyte[] Poly17Lookup;
	ubyte[] Poly9Lookup;
	int ReadySamplesEnd;
	int ReadySamplesStart;
	int SampleFactor;
	int SampleOffset;

	final void StartFrame()
	{
		this.BasePokey.DeltaBuffer[] = 0;
		if (this.ExtraPokeyMask != 0)
			this.ExtraPokey.DeltaBuffer[] = 0;
	}
	int Timer1Cycle;
	int Timer2Cycle;
	int Timer4Cycle;
	this()
	{
		BasePokey = new Pokey;
		ExtraPokey = new Pokey;
		Poly17Lookup = new ubyte[16385];
		Poly9Lookup = new ubyte[511];
		int reg = 511;
		for (int i = 0; i < 511; i++) {
			reg = (((reg >> 5 ^ reg) & 1) << 8) + (reg >> 1);
			this.Poly9Lookup[i] = cast(ubyte) reg;
		}
		reg = 131071;
		for (int i = 0; i < 16385; i++) {
			reg = (((reg >> 5 ^ reg) & 255) << 9) + (reg >> 8);
			this.Poly17Lookup[i] = cast(ubyte) (reg >> 1);
		}
	}
}
