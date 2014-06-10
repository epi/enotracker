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

import glib.Timeout;

import cairo.Context;
import cairo.Surface;

import gtk.Widget;
import gtk.DrawingArea;

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

		Menu menu = menuBar.append("_File");;

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

		mainBox.packStart(statusbar,false,true,0);
		add(mainBox);

		notebook.appendPage(new FooWidget(), "Cairo");
		setDefaultSize(800, 600);
	}
}

//private import gtkc.Loader;

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
}
