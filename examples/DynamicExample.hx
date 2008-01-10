import arctic.Arctic;
import arctic.ArcticView;
import arctic.ArcticBlock;

class DynamicExample  {

	static public function main() {
		new DynamicExample(flash.Lib.current);
	}
	
	public function new(parent_ : ArcticMovieClip) {
		parent = parent_;
		
		showDialog();
	}

	private function showDialog() {
		// To make a screen, first build the data structure representing the contents
		var me = this;

		rows = [];
		rowsBlock = new MutableBlock(Filler);
		var screen = Border(100, 20, Background(0xf08000, 
			LineStack( [ 
				Mutable(rowsBlock),
				Arctic.makeSimpleButton("Add row", addRow, 50),
				Arctic.makeSimpleButton("Next screen", nextScreen, 50) 
			] ) ) );

		// Then construct the arctic object
		arcticView = new ArcticView( screen, parent );
		// And finally display on the given movieclip
		var root = arcticView.display(true);
	}
	
	private function addRow() {
		rows.push("Another line " + rows.length);
		var elements = [];
		for (r in rows) {
			elements.push(Arctic.makeText(r, 100));
		}
		elements.push(Filler);
		rowsBlock.block = LineStack(elements, rows.length);
		arcticView.refresh(false);
	}
	
	private function nextScreen() {
		arcticView.destroy();
		arcticView = null;
		
		grid();
	}
/*	
	private function mutable() {
		var counter = new ArcticState(0, function(number : Int) : ArcticBlock {
				return Arctic.makeText("Number: " + number);
			});
		var texter = new ArcticState("A", function(text : String) : ArcticBlock {
				return ColumnStack([ Filler, Arctic.makeText("Text: " + text) ]);
			});
		var example = LineStack( [ 
				counter.block, 
				Arctic.makeSimpleButton( "Increase counter", function () { counter.state++; } ),
				texter.block,
				Arctic.makeSimpleButton( "More text", function () { texter.state += "A"; } ),
			] );
	}
*/
	private function grid() {
		var screen = Background(0x808080, Border( 1, 1, Grid( [ 
			[ Text("First cell"), Text("Second cell"), Filler ],
			[ Text("Second line"), Filler, Text("Test") ], 
			[ Text("Third line"), Text("Some text"), Text("Last") ]
		], false, 0xFFFF00 ) ) );
		
		// Then construct the arctic object
		arcticView = new ArcticView( screen, parent );
		var root = arcticView.display(true);
	}
	
	private var rows : Array<String>;
	private var rowsBlock : MutableBlock;
	private var arcticView : ArcticView;
	private var parent : ArcticMovieClip;
}
