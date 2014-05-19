/**
	Musical key definitions.

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

module keys;

public import sdl : SDLKey, SDLMod;

uint[SDLKey] noteKeys;

int getHexDigit(SDLKey key, SDLMod mod)
{
	if (mod != 0)
		return -1;
	if (key >= SDLKey.SDLK_0 && key <= SDLKey.SDLK_9)
		return key - SDLKey.SDLK_0;
	if (key >= SDLKey.SDLK_a && key <= SDLKey.SDLK_f)
		return key - SDLKey.SDLK_a + 10;
	return -1;
}

enum Modifiers
{
	shift = 1,
	ctrl = 2,
	alt = 4,
	meta = 8,
}

uint packModifiers(SDLMod mod)
{
	uint result;
	if (mod & (SDLMod.KMOD_LSHIFT | SDLMod.KMOD_RSHIFT))
		result |= Modifiers.shift;
	if (mod & (SDLMod.KMOD_LCTRL | SDLMod.KMOD_RCTRL))
		result |= Modifiers.ctrl;
	if (mod & (SDLMod.KMOD_LALT | SDLMod.KMOD_RALT))
		result |= Modifiers.alt;
	if (mod & (SDLMod.KMOD_LMETA | SDLMod.KMOD_RMETA))
		result |= Modifiers.meta;
	return result;
}

static this()
{
	noteKeys = [
		SDLKey.SDLK_z : 1,
		SDLKey.SDLK_s : 2,
		SDLKey.SDLK_x : 3,
		SDLKey.SDLK_d : 4,
		SDLKey.SDLK_c : 5,
		SDLKey.SDLK_v : 6,
		SDLKey.SDLK_g : 7,
		SDLKey.SDLK_b : 8,
		SDLKey.SDLK_h : 9,
		SDLKey.SDLK_n : 10,
		SDLKey.SDLK_j : 11,
		SDLKey.SDLK_m : 12,
		SDLKey.SDLK_COMMA : 13,
		SDLKey.SDLK_l : 14,
		SDLKey.SDLK_PERIOD : 15,
		SDLKey.SDLK_SEMICOLON : 16,
		SDLKey.SDLK_SLASH : 17,

		SDLKey.SDLK_q : 13,
		SDLKey.SDLK_2 : 14,
		SDLKey.SDLK_w : 15,
		SDLKey.SDLK_3 : 16,
		SDLKey.SDLK_e : 17,
		SDLKey.SDLK_r : 18,
		SDLKey.SDLK_5 : 19,
		SDLKey.SDLK_t : 20,
		SDLKey.SDLK_6 : 21,
		SDLKey.SDLK_y : 22,
		SDLKey.SDLK_7 : 23,
		SDLKey.SDLK_u : 24,
		SDLKey.SDLK_i : 25,
		SDLKey.SDLK_9 : 26,
		SDLKey.SDLK_o : 27,
		SDLKey.SDLK_0 : 28,
		SDLKey.SDLK_p : 29,
	];
} 
