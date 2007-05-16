import arctic.Arctic;
import arctic.ArcticBlock;
import arctic.ArcticView;
import arctic.ArcticMC;
import arctic.ArcticState;

class Piano {
	static public function main() {
		new Piano();
	}
	
	public function new() {
		var keys =
			LineStack( [
				Fixed(0, 5),
				ColumnStack( [ 
					Fixed(15, 0),
					blackkey("c#"),
					blackkey("d#"),
					Fixed(8, 0),
					blackkey("f#"),
					blackkey("g#"),
					blackkey("a#"),
				]),
				ColumnStack( [
					key("c", 25),
					key("d", 23),
					key("e", 23),
					key("f", 22),
					key("g", 21),
					key("a", 23),
					key("h", 23)
				])
			]);
		
		noteBlock = new ArcticState(null, getNoteBlock);
			
		noteDisplay = new ArcticState("", function(s : String) {
			return Arctic.makeText(s);
		});
		
		var ui = 
			LineStack( [
				Fixed(0, 10),
				ColumnStack( [
					Fixed(10, 0),
					OnTop(
						Picture("gstaff.swf", 0.5 * 408.0, 0.5 * 182.0, 1.0),
						noteBlock.block
					),
				] ),
				noteDisplay.block,
				Fixed(0, 30),
				Background( 0x1C1B1C, 
					Border(20, 2,
						OnTop(
							Picture("keys.swf", 0.2 * 800.0, 0.2 * 640.0, 1.0),
							keys
						)
					)
				)
			]);
		
		view = new ArcticView(ui, flash.Lib.current);
		var start = haxe.Timer.stamp();
		view.display(true);
		noteDisplay.state = Std.string(haxe.Timer.stamp() - start);
	}
	
	private function press(note) {
		noteBlock.state = note;
		noteDisplay.state = note;
	}
	
	private function getNoteBlock(note : String) : ArcticBlock {
		if (note == null) return Fixed(0,0);
		var sharp = (note.length == 2);
		var line = 6 + switch (note.charAt(0)) {
			case "c": 6;
			case "d": 5;
			case "e": 4;
			case "f": 3;
			case "g": 2;
			case "a": 1;
			case "h": 0;
		};
		if (line < 7) {
			return Offset(60, (line + 2) * 0.5 * 9 + 0.5 * 2,
				Picture("note1.swf", 0.5 * 32.0, 0.5 * 87.0, 1.0)
			);
		} else {
			return Offset(60, (line - 4) * 0.5 * 9 + 0.5 * 2,
				Picture("note2.swf", 0.5 * 32.0, 0.5 * 87.0, 1.0)
			);
		}
	}
	
	private function blackkey(note) {
		return Button(Background(0x808080, Fixed(25, 78), 0), Background(0xffffff, Fixed(25, 78), 50),
				callback(press, note));
	}
	private function key(note, width) {
		return Button(Background(0x808080, Fixed(width, 45), 0), Background(0x000000, Fixed(width, 45), 50),
				callback(press, note));
	}

	private var view : ArcticView;
	private var noteBlock : ArcticState<String>;
	private var noteDisplay : ArcticState<String>;
}

