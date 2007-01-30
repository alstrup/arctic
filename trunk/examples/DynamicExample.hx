#if flash9
import flash.display.MovieClip;
#else flash
import flash.MovieClip;
#end

import arctic.Arctic;
import arctic.ArcticView;
import arctic.ArcticBlock;

class DynamicExample  {

	static public function main() {
		new DynamicExample(flash.Lib.current);
	}
	
	public function new(parent_ : MovieClip) {
		parent = parent_;
		
		showDialog();
	}

	private function showDialog() {
		// To make a screen, first build the data structure representing the contents
		var me = this;
		rows = [];
		var screen = Border(100, 20, Background(0xf08000, 
			LineStack( [ 
				Id("elements", Filler), 
				Arctic.makeSimpleButton("Add row",  function() { me.addRow(); }, 50),
				Arctic.makeSimpleButton("Close",  function() { me.remove(); }, 50) 
			] ) ) );

		// Then construct the arctic object
		arcticView = new ArcticView( screen, parent );
		// And finally display on the given movieclip
//		ArcticView.setSize(parent, 100, 100);
		var root = arcticView.display(true);
	}
	
	private function addRow() {
		rows.push("Another line " + rows.length);
		var elements = [];
		for (r in rows) {
			elements.push(Arctic.makeText(r, 100));
		}
		elements.push(Filler);
		arcticView.update("elements", LineStack(elements, rows.length) );
		arcticView.refresh();
	}
	
	private function remove() {
		arcticView.destroy();
		arcticView = null;
		
		grid();
	}
	
	private function grid() {
		var screen = Background(0x808080, Border( 1, 1, Grid( [ 
			[ Text("First cell"), Text("Second cell"), Filler ],
			[ Text("Second line"), Filler, Text("Last") ]
		]) ) );
		
		// Then construct the arctic object
		arcticView = new ArcticView( screen, parent );
		var root = arcticView.display(true);
	}
	
	private var rows : Array<String>;
	private var arcticView : ArcticView;
	private var parent : MovieClip;
}