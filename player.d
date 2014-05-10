/**
	Play TMC music.

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

module player;

import std.algorithm;
import std.range;

import core.atomic;
import core.sync.semaphore;

import asap;
import sdl;
import tmc;

struct ASAPFrameEvent
{
	ubyte type = SDL_EventType.SDL_USEREVENT;
	ubyte songPosition;
	ubyte patternPosition;
	ubyte[8] channelVolumes;
}

enum BufferLength = 576;

struct ASAPBufferEvent
{
	ubyte type = SDL_EventType.SDL_USEREVENT + 1;
	shared(short)[] data;
	@property auto left() inout nothrow { return cast(inout(short)[]) data[0 .. $ / 2]; }
	@property auto right() inout nothrow { return cast(inout(short)[]) data[$ / 2 .. $]; }
}

class Player
{
	this()
	{
		_playing = false;
		_silence = true;
		_asap = new ASAPTmc;
		_asap.FrameCallback = &this.frameCallback;
		_audio = new Audio(44100, SDL_AudioFormat.AUDIO_S16LSB, 2, BufferLength, &this.generate);
		_sema = new Semaphore;
		_bufferEvent.data.length = BufferLength / short.sizeof;
		_audio.play();
	}

	~this()
	{
		_audio.close();
	}

	void playSong(uint songLine)
	{
		stop();
		_asap.load(0x2800, _tmc.save(0x2800, false));
		_asap.MusicAddr = 0x2800;
		_asap.Fastplay = 312 / _tmc.fastplay;
		_asap.Play(songLine);
		if (cas(&_playing, false, true))
			_sema.wait();
	}

	void playPattern(uint songLine, uint pattLine)
	{
		throw new Exception("not implemented");
	}

	void playLine(uint songLine, uint pattLine)
	{
		throw new Exception("not implemented");
	}

	void stop()
	{
		if (cas(&_playing, true, false))
			_sema.wait();
	}

	@property void tmc(TmcFile t) { _tmc = t; }

	@property bool playing() const nothrow { return atomicLoad(_playing); }

private:
	void generate(ubyte[] buf)
	{
		if (atomicLoad(_playing))
		{
			mute(false);
			_asap.Generate(buf, cast(int) buf.length, ASAPSampleFormat.S16LE);
			postBufferEvent(buf[]);
		}
		else
		{
			mute(true);
			buf[] = 0;
		}
	}

	ASAPBufferEvent _bufferEvent;

	void postBufferEvent(in ubyte[] buf)
	{
		if (buf.length >= BufferLength)
		{
			auto shbuf = cast(const(short[])) buf[0 .. BufferLength];
			shbuf[0 .. $].stride(2).copy(_bufferEvent.left);
			shbuf[1 .. $].stride(2).copy(_bufferEvent.right);
			SDL_PushEvent(cast(SDL_Event*) &_bufferEvent);
		}
	}

	void mute(bool m)
	{
		if (_silence != m)
		{
			_silence = m;
			_sema.notify();
		}
	}

	void frameCallback()
	{
		ASAPFrameEvent event;
		event.songPosition = cast(ubyte) _asap.GetSongPosition();
		event.patternPosition = cast(ubyte) _asap.GetPatternPosition();
		foreach (chn; 0 .. 8)
			event.channelVolumes[chn] = cast(ubyte) _asap.GetPokeyChannelVolume(chn);
		SDL_PushEvent(cast(SDL_Event*) &event);
	}

	ASAPTmc _asap;
	TmcFile _tmc;
	Audio _audio;
	Semaphore _sema;
	shared bool _playing;
	bool _silence;
}
