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
		var screen = Border (10, 10, Background(0xf08000, 
			LineStack( [ 
				Id("elements", Filler), 
				Arctic.makeSimpleButton("Add row",  function() { me.addRow(); }, 50),
				Arctic.makeSimpleButton("Close",  function() { me.remove(); }, 50) 
			] ) ) );
		// Then construct the arctic object
		arcticView = new ArcticView( screen );
		// And finally display on the given movieclip
		ArcticView.setSize(parent, 100, 100);
		var root = arcticView.display(parent, true);
	}
	
	private function addRow() {
		rows.push("Another line");
		var elements = [];
		for (r in rows) {
			elements.push(Text(r));
		}
		elements.push(Filler);
		arcticView.update("elements", LineStack(elements));
		arcticView.refresh();
	}
	
	private function remove() {
		arcticView.destroy();
		arcticView = null;
	}
	
	private var rows : Array<String>;
	private var arcticView : ArcticView;
	private var parent : MovieClip;
}
