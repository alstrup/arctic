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
					blackkey(0),
					blackkey(1),
					Fixed(8, 0),
					blackkey(3),
					blackkey(4),
					blackkey(5),
				]),
				ColumnStack( [
					key(0, 25),
					key(1, 23),
					key(2, 23),
					key(3, 22),
					key(4, 21),
					key(5, 23),
					key(6, 23)
				])
			]);
		
		noteBlock = new ArcticState(null, getNoteBlock);
		
		scoreDisplay = new ArcticState("", function(s : String) {
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
				Background( 0x1C1B1C, 
					Border(20, 2,
						OnTop(
							Picture("keys.swf", 0.2 * 800.0, 0.2 * 640.0, 1.0),
							keys
						)
					)
				),
				scoreDisplay.block
			]);
		
		view = new ArcticView(ui, flash.Lib.current);
		start = haxe.Timer.stamp();
		view.display(true);
		restart();
		scoreDisplay.state = "Select level (" + Std.string(haxe.Timer.stamp() - start) + ")";
	}
		
	private function restart() {
		level = null;
		score = 0;
		count = 0;
		errorCount = 0;
	}
	
	private function press(note, sharp) {
		var now = haxe.Timer.stamp();
		if (level == null) {
			level = note;
			if (sharp) {
				level += 7;
			}
			if (level == 0) {
				level = 1;
			}
			scoreDisplay.state = "Go!";
		} else {
			var correct = (noteBlock.state % 7) == note;
			var answerTime = now - start;
			score -= answerTime;
			if (correct) {
				score += 1;
			} else {
				errorCount++;
			}
			count++;
			var roundScore = Math.round(score * 100.0) / 100.0;
			var roundTime = Math.round(answerTime * 10.0) / 10.0;
			
			if (count == 10) {
				scoreDisplay.state = '<font color="#0000ff">Final score: '
					+ roundScore
					+ ". Errors: " + errorCount
					+ '</font>';
				noteBlock.state = null;
				restart();
				return;
			}
			
			scoreDisplay.state = 
				'<font color="' + (correct ? "#00ff00" : "#ff0000") + '">'
				+ "Score: " 
				+ roundScore 
				+ ", count " + count + ", time " + roundTime
				+ "</font>";
		}
		
		var newNote = 0;
		while ((newNote = Std.random(level + 1)) == noteBlock.state) {
		}
		noteBlock.state = newNote;
		start = haxe.Timer.stamp();
	}
	
	private function getNoteBlock(note : Null<Int>) : ArcticBlock {
		if (note == null) return Fixed(0,0);
		var line = 12 - note;
/*		var sharp = (note.length == 2);
		var line = 6 + switch (note.charAt(0)) {
			case "c": 6;
			case "d": 5;
			case "e": 4;
			case "f": 3;
			case "g": 2;
			case "a": 1;
			case "h": 0;
		};*/
		if (line < 7) {
			return Offset(60, (line + 2) * 0.5 * 9 + 0.5 * 2,
				Picture("note1.swf", 0.5 * 32.0, 0.5 * 87.0, 1.0)
			);
		} else if (line == 12) {
			return OnTop(
				Offset(58, 37 + 9 + 10 + 10 + 9, Background(0x000000, Fixed(20, 1))),
				Offset(60, (line - 4) * 0.5 * 9 + 0.5 * 2,
					Picture("note2.swf", 0.5 * 32.0, 0.5 * 87.0, 1.0)
				)
			);
		} else {
			return Offset(60, (line - 4) * 0.5 * 9 + 0.5 * 2,
				Picture("note2.swf", 0.5 * 32.0, 0.5 * 87.0, 1.0)
			);
		}
	}
	
	private function blackkey(note) {
		return Button(Background(0x808080, Fixed(25, 78), 0), Background(0xffffff, Fixed(25, 78), 50),
				callback(press, note, true));
	}
	private function key(note, width) {
		return Button(Background(0x808080, Fixed(width, 45), 0), Background(0x000000, Fixed(width, 45), 50),
				callback(press, note, false));
	}

	private var view : ArcticView;
	private var noteBlock : ArcticState<Int>;
	private var scoreDisplay : ArcticState<String>;

	/// What level should we go to?
	private var level : Null<Int>;
	
	private var score : Float;
	private var start : Float;
	private var count : Int;
	private var errorCount : Int;
}

