import arctic.Arctic;
import arctic.ArcticView;
import arctic.ArcticBlock;

class Bugs {
	static public function main() {
		new Bugs(flash.Lib.current);
	}
	
	public function new(parent0 : ArcticMovieClip) {
		parent = parent0;
		count = 0;
		next();
	}
	public function next() : Void {
		if (arcticView != null) {
			arcticView.destroy();
		}
		
		// To make a screen, first build the data structure representing the contents
		var me = this;
		var screen;
		
		switch (count) {
			case 0:
			// Tooltips were underneath following elements
			screen = 
				Border( 50, 100, 
				ColumnStack( [
					Arctic.makeTooltip( Text("This text has a tooltip."), "This tooltip should come on top of everything"),
					Text("Don't go beneath this stuff"),
					Arctic.makeSimpleButton( "Next bug", function() { me.next(); } )
				] ) );
			case 1:
			// Not possible to select text in textinput nested in dragable
			screen = 
				LineStack( [
					Arctic.makeDragable(true, true, true, Background(0x8080ff, Border(10, 10, TextInput("Selection with mouse should work", 200, 20)))),
					Arctic.makeDragable(true, true, true, Background(0x8080ff, Border(10, 10, TextInput("Selection with mouse should work", 200, 20)))),
					Arctic.makeSimpleButton( "Next bug", function() { me.next(); } )
				]);
			case 2:
			// Nested dragables were dually dragged
			screen = 
				LineStack( [
					Arctic.makeDragable(true, true, true, ConstrainWidth(300, 300, ConstrainHeight(100, 100, Background(0x8080ff, Border(10, 10, Arctic.makeDragable(true, true, true, Background(0x80ff80, Border(10, 10, TextInput("Selection with mouse should work", 200, 20))))))))),
					Arctic.makeSimpleButton( "Next bug", function() { me.next(); } )
				]);
			default:
			screen = Text("The end");
		}
		 // Then construct the arctic object
		arcticView = new ArcticView( screen );
		// And finally display on the given movieclip
		var root = arcticView.display(parent, true);
		++count;
	}
	public var arcticView : ArcticView;
	public var count : Int;
	public var parent : ArcticMovieClip;
}
