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

// TODO: asap.Generate is called from a different thread, there should
// be some synchronization.
class Player
{
	this()
	{
		_asap = new ASAPTmc;
		_asap.FrameCallback = &this.frameCallback;
		_audio = new Audio(44100, SDL_AudioFormat.AUDIO_S16LSB, 2, 576, &this.generate);
		_playing = false;
		_sema = new Semaphore;
	}

	void start()
	{	
		_audio.play();
	}

	void close()
	{
		_audio.close();
	}

	void playSong(uint songLine)
	{
		stop();
		_asap.load(0x2800, _tmc.save(0x2800, false));
		_asap.MusicAddr = 0x2800;
		_asap.Fastplay = 312 / _tmc.fastplay;
		atomicStore(_playing, true);
		_asap.Play(songLine);
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

private:
	void generate(ubyte[] buf)
	{
		import std.stdio;
		if (atomicLoad(_playing))
		{
			_silence = false;
			atomicStore(_silence, false);
			_asap.Generate(buf, cast(int) buf.length, ASAPSampleFormat.S16LE);
		}
		else
		{
			if (!_silence)
			{
				_silence = true;
				_sema.notify();
			}
			buf[] = 0;
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
	shared bool _playing;
	shared bool _silence;
	Semaphore _sema;
}
