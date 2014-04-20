public import sdl: SDLKey, SDLMod;

interface SubWindow
{
	void activate();
	void deactivate();
	bool key(SDLKey key, SDLMod mod);
}
