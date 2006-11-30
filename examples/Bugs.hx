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
			screen = 
				Border( 100, 100, 
				ColumnStack( [
					Arctic.makeTooltip( Text("This text has a tooltip."), "This tooltip should come on top of everything"),
					Text("Tooltip should not go beneath this stuff"),
					Arctic.makeSimpleButton( "Next bug", function() { me.next(); } )
				] ) );
			case 1:
			screen = 
				ColumnStack( [
					Arctic.makeDragable(true, true, true, Background(0x8080ff, Border(10, 10, TextInput("Selection with mouse does not work", 200, 20)))),
					Arctic.makeSimpleButton( "Next bug", function() { me.next(); } )
				]);
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


