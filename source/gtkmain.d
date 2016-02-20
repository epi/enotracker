private import gtk.Main;
private import gtk.MainWindow;
private import gtk.MessageDialog;
private import gtk.Version;

import gtk.MenuBar;
import gtk.AccelGroup;
import gtk.Menu;
import gtk.MenuItem;
import gtk.Notebook;
import gtk.VBox;
import gtk.Widget;
import gtk.Statusbar;
import core.memory;

import std.stdio;
import std.math;
import std.datetime;
import std.string;

import glib.Timeout;

import cairo.Context;
import cairo.Surface;

import gtk.Widget;
import gtk.DrawingArea;

import ui.songeditor;
import model.song;

static import tmc;

class TmcSongRow : ISongRow
{
	this(tmc.Song song, size_t row)
	{
		_song = song;
		_row = row;
	}

	@property size_t length() const
	{
		return 8;
	}

	@property SongEntry opIndex(size_t i) const
	{
		tmc.SongEntry tse = _song[_row][i];
		return SongEntry(tse.pattn, tse.transp);
	}

	@property void opIndexAssign(size_t i, SongEntry se)
	{
		tmc.SongEntry tse = tmc.SongEntry(cast(ubyte) se.pattern, cast(ubyte) se.transposition);
		_song[_row][i] = tse;
	}

private:
	tmc.Song _song;
	size_t _row;
}

class TmcSongData : ISongData
{
	this(tmc.Song song)
	{
		_song = song;
		_rows.length = _song.length;
		foreach (i, ref row; _rows)
			row = new TmcSongRow(_song, i);
	}

	@property size_t length() const
	{
		return _song.length;
	}

	@property size_t maxLength() const
	{
		return 127;
	}

	@property bool allowsTransposition() const
	{
		return true;
	}

protected:
	inout(ISongRow) doOpIndex(size_t i) inout
	{
		return _rows[i];
	}

	void doInsertEmptyRows(size_t where, size_t count)
	{
		throw new Exception("Not implemented");
	}

	void doDeleteRows(size_t where, size_t count)
	{
		throw new Exception("Not implemented");
	}

private:
	TmcSongRow[] _rows;

	tmc.Song _song;
}

class FooWidget : DrawingArea
{
public:
	this()
	{
		//Attach our expose callback, which will draw the window.
		addOnDraw(&drawCallback);
	}

protected:
	//Override default signal handler:
	bool drawCallback(Scoped!Context cr, Widget widget)
	{
		GtkAllocation size;

		getAllocation(size);
//		cr.scale(size.width, size.height);
		cr.save();
			cr.setSourceRgba(0.3, 0.6, 0.2, 0.9);   // brownish green
			cr.paint();
		cr.restore();

		return true;
	}

	double m_radius = 0.40;
	double m_lineWidth = 0.065;

	Timeout m_timeout;
}

class TmcWindow : MainWindow
{
	this()
	{
		super("enotracker");
		setup();
		this.setResizable(true);
		this.setHasResizeGrip(true);
		showAll();

		string versionCompare = Version.checkVersion(3, 0, 0);

		if (versionCompare.length > 0)
		{
			MessageDialog d = new MessageDialog(
				this,
				GtkDialogFlags.MODAL,
				MessageType.WARNING,
				ButtonsType.OK,
				"GtkD : Gtk+ version missmatch\n" ~ versionCompare ~
				"\nYou might run into problems!"
				"\n\nPress OK to continue");
			d.run();
			d.destroy();
		}
	}

	void onMenuActivate(MenuItem menuItem)
	{
		string action = menuItem.getActionName();
		switch( action )
		{
	/*		case "help.about":
				GtkDAbout dlg = new GtkDAbout();
				dlg.addOnResponse(&onDialogResponse);
				dlg.showAll();
				break;*/
			default:
				MessageDialog d = new MessageDialog(
					this,
					GtkDialogFlags.MODAL,
					MessageType.INFO,
					ButtonsType.OK,
					"You pressed menu item "~action);
				d.run();
				d.destroy();
			break;
		}
	}

	Notebook setNotebook()
	{
		Notebook notebook = new Notebook();
		notebook.addOnSwitchPage(&onNotebookSwitchPage);
		notebook.setTabPos(PositionType.TOP);
		return notebook;
	}

	void onNotebookSwitchPage(Widget notePage, uint pageNumber, Notebook notebook)
	{
		//writefln("Notebook switch to page %s", pageNumber);
		// fullCollect helps finding objects that shouldn't have been collected
		GC.collect();
		//writefln("exiting Notebook switch to page %s", pageNumber);
	}

	MenuBar getMenuBar()
	{
		AccelGroup accelGroup = new AccelGroup();

		addAccelGroup(accelGroup);

		MenuBar menuBar = new MenuBar();

		Menu menu = menuBar.append("_File");

		MenuItem item = new MenuItem(&onMenuActivate, "_New","file.new", true, accelGroup, 'n');
//		item.addAccelerator("activate",accelGroup,'n',GdkModifierType.CONTROL_MASK,GtkAccelFlags.VISIBLE);

		menu.append(item);
		menu.append(new MenuItem(&onMenuActivate, "_Open","file.open", true, accelGroup, 'o'));
		menu.append(new MenuItem(&onMenuActivate, "_Close","file.close", true, accelGroup, 'c'));
		menu.append(new MenuItem(&onMenuActivate, "E_xit","file.exit", true, accelGroup, 'x'));

		menu = menuBar.append("_Edit");

		menu.append(new MenuItem(&onMenuActivate,"_Find","edit.find", true, accelGroup, 'f'));
		menu.append(new MenuItem(&onMenuActivate,"_Search","edit.search", true, accelGroup, 's'));

		menu = menuBar.append("_Help");
		menu.append(new MenuItem(&onMenuActivate,"_About","help.about", true, accelGroup, 'a',GdkModifierType.CONTROL_MASK|GdkModifierType.SHIFT_MASK));

		return menuBar;
	}

	void setup()
	{
		VBox mainBox = new VBox(false, 0);

		mainBox.packStart(getMenuBar(),false,false,0);
		Notebook notebook = setNotebook();
		notebook.setBorderWidth(0);
		mainBox.packStart(notebook,true,true,0);
		Statusbar statusbar = new Statusbar();
		auto i = statusbar.getContextId("dupa");
		statusbar.push(i, "Lorem ipsum dolor sit amet");
		stderr.writeln(this.getHasResizeGrip());
		mainBox.packStart(statusbar,false,true,0);
		add(mainBox);

		auto t = new tmc.TmcFile;
		t.load(cast(immutable(ubyte)[]) std.file.read("mods/JAMSESS.TMC"));
		auto se = new SongEditor(new TmcSongData(t.song));
		notebook.appendPage(se, "song");
		setDefaultSize(800, 600);
	}
}

//private import gtkc.Loader;

/+
void main(string[] args)
{
	//Linker.dumpLoadLibraries();
	//Linker.dumpFailedLoads();

	version(Windows)
	{
		// todo threads are still broken on windows...
		Main.init(args);
	}
	else
	{
		Main.initMultiThread(args);
	}

	auto window = new TmcWindow();

	debug(1)writefln("before Main.run");
	Main.run();
	debug(1)writefln("after Main.run");
}+/
