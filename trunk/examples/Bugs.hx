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
		var fullsize = true;
		switch (count) {
			case 0:
			// Tooltips were underneath following elements
			screen = 
				Border( 50, 100, 
				ColumnStack( [
					Arctic.makeTooltip( Text("This text has a tooltip."), "This tooltip should come on top of everything"),
					Text("Don't go beneath this stuff"),
					Arctic.makeSimpleButton( "Next bug", next )
				] ) );
			case 1:
			// Not possible to select text in textinput nested in dragable
			screen = 
				LineStack( [
					Arctic.makeDragable(true, true, true, Background(0x8080ff, Border(10, 10, TextInput("Selection with mouse should work", 200, 20)))),
					Arctic.makeDragable(true, true, true, Background(0x8080ff, Border(10, 10, TextInput("Selection with mouse should work", 200, 20)))),
					Arctic.makeSimpleButton( "Next bug", next )
				]);
			case 2:
			// Nested dragables were dually dragged
			screen = 
				LineStack( [
					Arctic.makeDragable(true, true, true, ConstrainWidth(300, 300, ConstrainHeight(100, 100, Background(0x8080ff, Border(10, 10, Arctic.makeDragable(true, true, true, Background(0x80ff80, Border(10, 10, TextInput("Selection with mouse should work", 200, 20))))))))),
					Arctic.makeSimpleButton( "Next bug", next )
				]);
			case 3:
			// Nested LineStack become too big:
			screen = Border(0, 120, Background(0xf08000, 
				LineStack( [ 
					LineStack( [ Arctic.makeText("Text", 100), Filler ] ),
					Arctic.makeSimpleButton( "Next bug", next )
				] )));
			case 4:
			// Text radio-choice does not work
			screen = 
					LineStack( [ 
						Arctic.makeTextChoice([ "See custom block", "See dragable blocks" ], function(i : Int, text : String) { }, 0, 20).block,
						Arctic.makeSimpleButton( "Next bug", next )
					]);
			case 5:
			// This should be a clickable 20x20 red box
			screen = LineStack( [ Background(0xff0000, ColumnStack( [ Button(Fixed(20, 20), Fixed(20, 20), next), Filler ] )) ] );
			fullsize = false;
			case 6:
			// On resize, this should work correctly such that the scrollbar comes and disappears correctly
			screen = LineStack( [ Arctic.makeText("Text", 200), Arctic.makeSimpleButton( "Next bug", next ) ] );
			default:
			screen = Text("The end");
		}
		 // Then construct the arctic object
		arcticView = new ArcticView( screen, parent );
		if (!fullsize) {
			arcticView.adjustToFit(0, 0);
		}
		// And finally display on the given movieclip
		var root = arcticView.display(fullsize);
		++count;
	}
	public var arcticView : ArcticView;
	public var count : Int;
	public var parent : ArcticMovieClip;
}
