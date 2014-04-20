import std.stdio;
import std.string;
import std.typecons;

pragma (lib, "SDLmain");
pragma (lib, "SDL");
pragma (lib, "SDL_gfx");


private:

enum SDL_INIT_EVERYTHING = 0x0000FFFFU;

extern (C)
uint SDL_Init(uint flags);

extern (C)
void SDL_Quit();

enum SDL_SWSURFACE = 0x00000000;	/**< Surface is in system memory */
enum SDL_HWSURFACE = 0x00000001;	/**< Surface is in video memory */
enum SDL_ASYNCBLIT = 0x00000004;	/**< Use asynchronous blits if possible */


/** Available for SDL_SetVideoMode() */

enum SDL_ANYFORMAT = 0x10000000;	/**< Allow any video depth/pixel-format */
enum SDL_HWPALETTE = 0x20000000;	/**< Surface has exclusive palette */
enum SDL_DOUBLEBUF = 0x40000000;	/**< Set up double-buffered video mode */
enum SDL_FULLSCREEN = 0x80000000;	/**< Surface is a full screen display */
enum SDL_OPENGL = 0x00000002;      /**< Create an OpenGL rendering context */
enum SDL_OPENGLBLIT = 0x0000000A;	/**< Create an OpenGL rendering context and use it for blitting */
enum SDL_RESIZABLE = 0x00000010;	/**< This video mode may be resized */
enum SDL_NOFRAME = 0x00000020;	/**< No window caption or edge frame */

extern (C)
SDL_Surface* SDL_CreateRGBSurface(uint flags, int width, int height, int depth, uint Rmask, uint Gmask, uint Bmask, uint Amask);

extern (C)
SDL_Surface* SDL_SetVideoMode(int width, int height, int bpp, uint flags);

extern (C)
int filledTrigonRGBA(SDL_Surface* dst, short x1, short y1, short x2, short y2, short x3, short y3, ubyte r, ubyte g, ubyte b, ubyte a);

extern (C)
int trigonRGBA(SDL_Surface* dst, short x1, short y1, short x2, short y2, short x3, short y3, ubyte r, ubyte g, ubyte b, ubyte a);

extern (C)
int boxRGBA(SDL_Surface* dst, short x1, short y1, short x2, short y2, ubyte r, ubyte g, ubyte b, ubyte a);

extern (C)
int filledEllipseRGBA(SDL_Surface* dst, short x, short y, short xr, short yr, ubyte r, ubyte g, ubyte b, ubyte a);

extern (C)
int SDL_SoftStretch(SDL_Surface* src, const SDL_Rect* srcrect, SDL_Surface* dst, const SDL_Rect* dstrect);

extern (C)
int SDL_Flip(SDL_Surface* screen);

extern (C)
int SDL_LockSurface(SDL_Surface* surface);

extern (C)
int SDL_UnlockSurface(SDL_Surface* surface);

extern (C)
void SDL_FreeSurface(SDL_Surface* surface);

extern (C)
int SDL_FillRect(SDL_Surface* surface, SDL_Rect* dstrect, uint color);

// void* should be SDL_RWops* in the 2 funcs below
extern (C)
int SDL_SaveBMP_RW(SDL_Surface *surface, void *dst, int freedst);
extern (C)
void *SDL_RWFromFile(const char *file, const char *mode);

public:

struct SDL_Rect
{
	short x;
	short y;
	ushort w;
	ushort h;
}

struct SDL_Color
{
	ubyte r;
	ubyte g;
	ubyte b;
	ubyte unused;
}

alias SDL_Color SDL_Colour;

private:

struct SDL_Palette
{
	int ncolors;
	SDL_Color* colors;
}

struct SDL_PixelFormat
{
	SDL_Palette* palette;
	ubyte  BitsPerPixel;
	ubyte  BytesPerPixel;
	ubyte  Rloss;
	ubyte  Gloss;
	ubyte  Bloss;
	ubyte  Aloss;
	ubyte  Rshift;
	ubyte  Gshift;
	ubyte  Bshift;
	ubyte  Ashift;
	uint   Rmask;
	uint   Gmask;
	uint   Bmask;
	uint   Amask;

	/** RGB color key information */
	uint   colorkey;
	/** Alpha value information (per-surface alpha) */
	ubyte  alpha;
}

/** This structure should be treated as read-only, except for 'pixels',
 *  which, if not NULL, contains the raw pixel data for the surface.
 */
struct SDL_Surface
{
	uint flags;				/**< Read-only */
	SDL_PixelFormat* format;		/**< Read-only */
	int w, h;				/**< Read-only */
	ushort pitch;				/**< Read-only */
	void *pixels;				/**< Read-write */
	int offset;				/**< Private */

	/** Hardware-specific surface info */
	void *hwdata;
//	struct private_hwdata *hwdata;

	/** clipping information */
	SDL_Rect clip_rect;			/**< Read-only */
	uint   unused1;				/**< for binary compatibility */

	/** Allow recursive locks */
	uint   locked;				/**< Private */

	/** info for fast blit mapping to other surfaces */
	void *map;
//	struct SDL_BlitMap *map;		/**< Private */

	/** format version, bumped at every change to invalidate blit maps */
	uint format_version;		/**< Private */

	/** Reference count -- used when freeing surface */
	int refcount;				/**< Read-mostly */
}

public enum SDL_EventType
{
	SDL_NOEVENT = 0,			/**< Unused (do not remove) */
	SDL_ACTIVEEVENT,			/**< Application loses/gains visibility */
	SDL_KEYDOWN,			/**< Keys pressed */
	SDL_KEYUP,			/**< Keys released */
	SDL_MOUSEMOTION,			/**< Mouse moved */
	SDL_MOUSEBUTTONDOWN,		/**< Mouse button pressed */
	SDL_MOUSEBUTTONUP,		/**< Mouse button released */
	SDL_JOYAXISMOTION,		/**< Joystick axis motion */
	SDL_JOYBALLMOTION,		/**< Joystick trackball motion */
	SDL_JOYHATMOTION,		/**< Joystick hat position change */
	SDL_JOYBUTTONDOWN,		/**< Joystick button pressed */
	SDL_JOYBUTTONUP,			/**< Joystick button released */
	SDL_QUIT,			/**< User-requested quit */
	SDL_SYSWMEVENT,			/**< System specific event */
	SDL_EVENT_RESERVEDA,		/**< Reserved for future use.. */
	SDL_EVENT_RESERVEDB,		/**< Reserved for future use.. */
	SDL_VIDEORESIZE,			/**< User resized video mode */
	SDL_VIDEOEXPOSE,			/**< Screen needs to be redrawn */
	SDL_EVENT_RESERVED2,		/**< Reserved for future use.. */
	SDL_EVENT_RESERVED3,		/**< Reserved for future use.. */
	SDL_EVENT_RESERVED4,		/**< Reserved for future use.. */
	SDL_EVENT_RESERVED5,		/**< Reserved for future use.. */
	SDL_EVENT_RESERVED6,		/**< Reserved for future use.. */
	SDL_EVENT_RESERVED7,		/**< Reserved for future use.. */
	/** Events SDL_USEREVENT through SDL_MAXEVENTS-1 are for your use */
	SDL_USEREVENT = 24,
	/** This last event is only for bounding internal arrays
	*  It is the number of bits in the event mask datatype -- uint  
	*/
	SDL_NUMEVENTS = 32
}

public:

shared static this()
{
	if (SDL_Init(SDL_INIT_EVERYTHING) != 0)
		throw new SDLException("Failed to initialize SDL");
	else
		debug (SDL) writeln("SDL_Init OK");
}

shared static ~this()
{
	SDL_Quit();
	debug (SDL) writeln("SDL_Quit OK");
}

class SDLException : Exception
{
	this(string msg)
	{
		super(msg);
	}
}

class Surface
{
	void filledTrigonRGBA(int x1, int y1, int x2, int y2, int x3, int y3, ubyte r, ubyte g, ubyte b, ubyte a)
	{
		if (.filledTrigonRGBA(pSurf_,
			cast(short) x1, cast(short) y1,
			cast(short) x2, cast(short) y2,
			cast(short) x3, cast(short) y3,
			r, g, b, a) != 0)
			throw new SDLException("filledTrigonRGBA failed");
	}

	void trigonRGBA(int x1, int y1, int x2, int y2, int x3, int y3, ubyte r, ubyte g, ubyte b, ubyte a)
	{
		if (.trigonRGBA(pSurf_,
			cast(short) x1, cast(short) y1,
			cast(short) x2, cast(short) y2,
			cast(short) x3, cast(short) y3,
			r, g, b, a) != 0)
			throw new SDLException("trigonRGBA failed");
	}

	void filledEllipseRGBA(int x, int y, int xr, int yr, ubyte r, ubyte g, ubyte b, ubyte a)
	{
		if (.filledEllipseRGBA(pSurf_, 
			cast(short) x, cast(short) y,
			cast(short) xr, cast(short) yr,
			r, g, b, a) != 0)
			throw new SDLException("filledEllipseRGBA failed");
	}

	void boxRGBA(int x1, int y1, int x2, int y2, ubyte r, ubyte g, ubyte b, ubyte a)
	{
		if (.boxRGBA(pSurf_,
			cast(short) x1, cast(short) y1,
			cast(short) x2, cast(short) y2,
			r, g, b, a) != 0)
			throw new SDLException("boxRGBA failed");
	}

	void fillRect(SDL_Rect dstrect, uint color)
	{
		if (SDL_FillRect(pSurf_, &dstrect, color) != 0)
			throw new SDLException("SDL_FillRect failed");
	}

	uint getPixel(int x, int y)
	{
		if (x >= pSurf_.w || x < 0 || y >= pSurf_.h || y < 0)
			return 0;
		uint* pixels = cast(uint*)pSurf_.pixels;
		return pixels[(y * pSurf_.w) + x];
	}

	void putPixel(int x, int y, uint pixel)
	{
		if (x >= pSurf_.w || x < 0 || y >= pSurf_.h || y < 0)
			return;
		uint* pixels = cast(uint*)pSurf_.pixels;
		pixels[(y * pSurf_.w) + x] = pixel;
	}

	void lock()
	{
		if (SDL_LockSurface(pSurf_) != 0)
			throw new Exception("SDL_LockSurface failed");
	}

	void unlock()
	{
		if (SDL_UnlockSurface(pSurf_) != 0)
			throw new Exception("SDL_UnlockSurface failed");
	}

	void saveBMP(string filename)
	{
		if (SDL_SaveBMP_RW(pSurf_, SDL_RWFromFile(filename.toStringz(), "wb".toStringz()), 1) != 0)
			throw new Exception("SDL_SaveBMP failed");
	}

	void free()
	{
		SDL_FreeSurface(pSurf_);
	}

	~this()
	{
	}

private:
	this(SDL_Surface* pSurf)
	{
		pSurf_ = pSurf;
	}

	SDL_Surface *pSurf_;
}

class Screen : Surface
{
	this(int width, int height, int bpp, Flag!"DoubleBuffer" doubleBuffer = Flag!"DoubleBuffer".yes)
	{
		auto s = SDL_SetVideoMode(width, height, bpp, (doubleBuffer ? SDL_DOUBLEBUF : 0) | SDL_HWSURFACE);
		if (!s)
			throw new SDLException("Failed to set video mode");
		super(s);
	}
	
	void flip()
	{
		int result = SDL_Flip(pSurf_);
		if (result != 0)
			throw new SDLException("SDL_Flip failed");
	}
}

class RGBSurface : Surface
{
	this(int width, int height, int bpp)
	{
		auto pSurf = SDL_CreateRGBSurface(SDL_SWSURFACE, width, height, bpp, 0, 0, 0, 0);
		if (pSurf is null)
			throw new SDLException("Failed to create an RGB surface");
		super(pSurf);
	}
}

void softStretch(Surface src, SDL_Rect srcrect, Surface dest, SDL_Rect destrect)
{
	if (SDL_SoftStretch(src.pSurf_, &srcrect, dest.pSurf_, &destrect) != 0)
		throw new SDLException("SDL_SoftStretch failed");
}

extern (C)
void SDL_Delay(uint ms);

struct SDL_QuitEvent
{
	ubyte type;	/**< SDL_QUIT */
}

struct SDL_FakeEvent
{
	ubyte[256] unused;
}

enum SDLKey
{
        /** @name ASCII mapped keysyms
         *  The keyboard syms have been cleverly chosen to map to ASCII
         */
        /*@{*/
	SDLK_UNKNOWN		= 0,
	SDLK_FIRST		= 0,
	SDLK_BACKSPACE		= 8,
	SDLK_TAB		= 9,
	SDLK_CLEAR		= 12,
	SDLK_RETURN		= 13,
	SDLK_PAUSE		= 19,
	SDLK_ESCAPE		= 27,
	SDLK_SPACE		= 32,
	SDLK_EXCLAIM		= 33,
	SDLK_QUOTEDBL		= 34,
	SDLK_HASH		= 35,
	SDLK_DOLLAR		= 36,
	SDLK_AMPERSAND		= 38,
	SDLK_QUOTE		= 39,
	SDLK_LEFTPAREN		= 40,
	SDLK_RIGHTPAREN		= 41,
	SDLK_ASTERISK		= 42,
	SDLK_PLUS		= 43,
	SDLK_COMMA		= 44,
	SDLK_MINUS		= 45,
	SDLK_PERIOD		= 46,
	SDLK_SLASH		= 47,
	SDLK_0			= 48,
	SDLK_1			= 49,
	SDLK_2			= 50,
	SDLK_3			= 51,
	SDLK_4			= 52,
	SDLK_5			= 53,
	SDLK_6			= 54,
	SDLK_7			= 55,
	SDLK_8			= 56,
	SDLK_9			= 57,
	SDLK_COLON		= 58,
	SDLK_SEMICOLON		= 59,
	SDLK_LESS		= 60,
	SDLK_EQUALS		= 61,
	SDLK_GREATER		= 62,
	SDLK_QUESTION		= 63,
	SDLK_AT			= 64,
	/* 
	   Skip uppercase letters
	 */
	SDLK_LEFTBRACKET	= 91,
	SDLK_BACKSLASH		= 92,
	SDLK_RIGHTBRACKET	= 93,
	SDLK_CARET		= 94,
	SDLK_UNDERSCORE		= 95,
	SDLK_BACKQUOTE		= 96,
	SDLK_a			= 97,
	SDLK_b			= 98,
	SDLK_c			= 99,
	SDLK_d			= 100,
	SDLK_e			= 101,
	SDLK_f			= 102,
	SDLK_g			= 103,
	SDLK_h			= 104,
	SDLK_i			= 105,
	SDLK_j			= 106,
	SDLK_k			= 107,
	SDLK_l			= 108,
	SDLK_m			= 109,
	SDLK_n			= 110,
	SDLK_o			= 111,
	SDLK_p			= 112,
	SDLK_q			= 113,
	SDLK_r			= 114,
	SDLK_s			= 115,
	SDLK_t			= 116,
	SDLK_u			= 117,
	SDLK_v			= 118,
	SDLK_w			= 119,
	SDLK_x			= 120,
	SDLK_y			= 121,
	SDLK_z			= 122,
	SDLK_DELETE		= 127,
	/* End of ASCII mapped keysyms */
        /*@}*/

	/** @name International keyboard syms */
        /*@{*/
	SDLK_WORLD_0		= 160,		/* 0xA0 */
	SDLK_WORLD_1		= 161,
	SDLK_WORLD_2		= 162,
	SDLK_WORLD_3		= 163,
	SDLK_WORLD_4		= 164,
	SDLK_WORLD_5		= 165,
	SDLK_WORLD_6		= 166,
	SDLK_WORLD_7		= 167,
	SDLK_WORLD_8		= 168,
	SDLK_WORLD_9		= 169,
	SDLK_WORLD_10		= 170,
	SDLK_WORLD_11		= 171,
	SDLK_WORLD_12		= 172,
	SDLK_WORLD_13		= 173,
	SDLK_WORLD_14		= 174,
	SDLK_WORLD_15		= 175,
	SDLK_WORLD_16		= 176,
	SDLK_WORLD_17		= 177,
	SDLK_WORLD_18		= 178,
	SDLK_WORLD_19		= 179,
	SDLK_WORLD_20		= 180,
	SDLK_WORLD_21		= 181,
	SDLK_WORLD_22		= 182,
	SDLK_WORLD_23		= 183,
	SDLK_WORLD_24		= 184,
	SDLK_WORLD_25		= 185,
	SDLK_WORLD_26		= 186,
	SDLK_WORLD_27		= 187,
	SDLK_WORLD_28		= 188,
	SDLK_WORLD_29		= 189,
	SDLK_WORLD_30		= 190,
	SDLK_WORLD_31		= 191,
	SDLK_WORLD_32		= 192,
	SDLK_WORLD_33		= 193,
	SDLK_WORLD_34		= 194,
	SDLK_WORLD_35		= 195,
	SDLK_WORLD_36		= 196,
	SDLK_WORLD_37		= 197,
	SDLK_WORLD_38		= 198,
	SDLK_WORLD_39		= 199,
	SDLK_WORLD_40		= 200,
	SDLK_WORLD_41		= 201,
	SDLK_WORLD_42		= 202,
	SDLK_WORLD_43		= 203,
	SDLK_WORLD_44		= 204,
	SDLK_WORLD_45		= 205,
	SDLK_WORLD_46		= 206,
	SDLK_WORLD_47		= 207,
	SDLK_WORLD_48		= 208,
	SDLK_WORLD_49		= 209,
	SDLK_WORLD_50		= 210,
	SDLK_WORLD_51		= 211,
	SDLK_WORLD_52		= 212,
	SDLK_WORLD_53		= 213,
	SDLK_WORLD_54		= 214,
	SDLK_WORLD_55		= 215,
	SDLK_WORLD_56		= 216,
	SDLK_WORLD_57		= 217,
	SDLK_WORLD_58		= 218,
	SDLK_WORLD_59		= 219,
	SDLK_WORLD_60		= 220,
	SDLK_WORLD_61		= 221,
	SDLK_WORLD_62		= 222,
	SDLK_WORLD_63		= 223,
	SDLK_WORLD_64		= 224,
	SDLK_WORLD_65		= 225,
	SDLK_WORLD_66		= 226,
	SDLK_WORLD_67		= 227,
	SDLK_WORLD_68		= 228,
	SDLK_WORLD_69		= 229,
	SDLK_WORLD_70		= 230,
	SDLK_WORLD_71		= 231,
	SDLK_WORLD_72		= 232,
	SDLK_WORLD_73		= 233,
	SDLK_WORLD_74		= 234,
	SDLK_WORLD_75		= 235,
	SDLK_WORLD_76		= 236,
	SDLK_WORLD_77		= 237,
	SDLK_WORLD_78		= 238,
	SDLK_WORLD_79		= 239,
	SDLK_WORLD_80		= 240,
	SDLK_WORLD_81		= 241,
	SDLK_WORLD_82		= 242,
	SDLK_WORLD_83		= 243,
	SDLK_WORLD_84		= 244,
	SDLK_WORLD_85		= 245,
	SDLK_WORLD_86		= 246,
	SDLK_WORLD_87		= 247,
	SDLK_WORLD_88		= 248,
	SDLK_WORLD_89		= 249,
	SDLK_WORLD_90		= 250,
	SDLK_WORLD_91		= 251,
	SDLK_WORLD_92		= 252,
	SDLK_WORLD_93		= 253,
	SDLK_WORLD_94		= 254,
	SDLK_WORLD_95		= 255,		/* 0xFF */
        /*@}*/

	/** @name Numeric keypad */
        /*@{*/
	SDLK_KP0		= 256,
	SDLK_KP1		= 257,
	SDLK_KP2		= 258,
	SDLK_KP3		= 259,
	SDLK_KP4		= 260,
	SDLK_KP5		= 261,
	SDLK_KP6		= 262,
	SDLK_KP7		= 263,
	SDLK_KP8		= 264,
	SDLK_KP9		= 265,
	SDLK_KP_PERIOD		= 266,
	SDLK_KP_DIVIDE		= 267,
	SDLK_KP_MULTIPLY	= 268,
	SDLK_KP_MINUS		= 269,
	SDLK_KP_PLUS		= 270,
	SDLK_KP_ENTER		= 271,
	SDLK_KP_EQUALS		= 272,
        /*@}*/

	/** @name Arrows + Home/End pad */
        /*@{*/
	SDLK_UP			= 273,
	SDLK_DOWN		= 274,
	SDLK_RIGHT		= 275,
	SDLK_LEFT		= 276,
	SDLK_INSERT		= 277,
	SDLK_HOME		= 278,
	SDLK_END		= 279,
	SDLK_PAGEUP		= 280,
	SDLK_PAGEDOWN		= 281,
        /*@}*/

	/** @name Function keys */
        /*@{*/
	SDLK_F1			= 282,
	SDLK_F2			= 283,
	SDLK_F3			= 284,
	SDLK_F4			= 285,
	SDLK_F5			= 286,
	SDLK_F6			= 287,
	SDLK_F7			= 288,
	SDLK_F8			= 289,
	SDLK_F9			= 290,
	SDLK_F10		= 291,
	SDLK_F11		= 292,
	SDLK_F12		= 293,
	SDLK_F13		= 294,
	SDLK_F14		= 295,
	SDLK_F15		= 296,
        /*@}*/

	/** @name Key state modifier keys */
        /*@{*/
	SDLK_NUMLOCK		= 300,
	SDLK_CAPSLOCK		= 301,
	SDLK_SCROLLOCK		= 302,
	SDLK_RSHIFT		= 303,
	SDLK_LSHIFT		= 304,
	SDLK_RCTRL		= 305,
	SDLK_LCTRL		= 306,
	SDLK_RALT		= 307,
	SDLK_LALT		= 308,
	SDLK_RMETA		= 309,
	SDLK_LMETA		= 310,
	SDLK_LSUPER		= 311,		/**< Left "Windows" key */
	SDLK_RSUPER		= 312,		/**< Right "Windows" key */
	SDLK_MODE		= 313,		/**< "Alt Gr" key */
	SDLK_COMPOSE		= 314,		/**< Multi-key compose key */
        /*@}*/

	/** @name Miscellaneous function keys */
        /*@{*/
	SDLK_HELP		= 315,
	SDLK_PRINT		= 316,
	SDLK_SYSREQ		= 317,
	SDLK_BREAK		= 318,
	SDLK_MENU		= 319,
	SDLK_POWER		= 320,		/**< Power Macintosh power key */
	SDLK_EURO		= 321,		/**< Some european keyboards */
	SDLK_UNDO		= 322,		/**< Atari keyboard has Undo */
        /*@}*/

	/* Add any other keys here */

	SDLK_LAST
}

enum SDLMod
{
	KMOD_NONE  = 0x0000,
	KMOD_LSHIFT= 0x0001,
	KMOD_RSHIFT= 0x0002,
	KMOD_LCTRL = 0x0040,
	KMOD_RCTRL = 0x0080,
	KMOD_LALT  = 0x0100,
	KMOD_RALT  = 0x0200,
	KMOD_LMETA = 0x0400,
	KMOD_RMETA = 0x0800,
	KMOD_NUM   = 0x1000,
	KMOD_CAPS  = 0x2000,
	KMOD_MODE  = 0x4000,
	KMOD_RESERVED = 0x8000
}

struct SDL_keysym
{
	ubyte scancode;			/**< hardware specific scancode */
	SDLKey sym;			/**< SDL virtual keysym */
	SDLMod mod;			/**< current key modifiers */
	ushort unicode;			/**< translated character */
}

struct SDL_KeyboardEvent
{
	ubyte type;	 /**< SDL_KEYDOWN or SDL_KEYUP */
	ubyte which; /**< The keyboard device index */
	ubyte state; /**< SDL_PRESSED or SDL_RELEASED */
	SDL_keysym keysym;
}

union SDL_Event
{
	ubyte type;
//	SDL_ActiveEvent active;
	SDL_KeyboardEvent key;
//	SDL_MouseMotionEvent motion;
//	SDL_MouseButtonEvent button;
//	SDL_JoyAxisEvent jaxis;
//	SDL_JoyBallEvent jball;
//	SDL_JoyHatEvent jhat;
//	SDL_JoyButtonEvent jbutton;
//	SDL_ResizeEvent resize;
//	SDL_ExposeEvent expose;
	SDL_QuitEvent quit;
	SDL_FakeEvent fake;
//	SDL_UserEvent user;
//	SDL_SysWMEvent syswm;
}

extern (C)
int SDL_WaitEvent(SDL_Event* event);

extern (C)
int SDL_PollEvent(SDL_Event* event);

extern(C)
int SDL_EnableKeyRepeat(int delay, int interval);

