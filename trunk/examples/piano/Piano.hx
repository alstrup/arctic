import arctic.Arctic;
import arctic.ArcticBlock;
import arctic.ArcticView;
import arctic.ArcticMC;

class Piano {
	static public function main() {
		new Piano();
	}
	
	public function new() {
		
		// c#: 10,0 -> 35,90
		// d#: 35,0 -> 64,90
		
		var me = this;
		var blackkey = function(note) {
			return Button(Background(0x808080, Fixed(25, 78), 0), Background(0xffffff, Fixed(25, 78), 50),
					callback(me.press, note));
		}
		var key = function(note, width) {
			return Button(Background(0x808080, Fixed(width, 45), 0), Background(0x000000, Fixed(width, 45), 50),
					callback(me.press, note));
		}
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
		
		var ui = 
			LineStack( [
				Fixed(0, 10),
				Border( 20, 0,
					Picture("staff.swf", 0.25 * 420.0, 0.25 * 420.0, 1.0)
				),
				Fixed(0, 10),
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
		view.display(true);
	}
	
	private function press(k) {
		trace(k);
	}
	
	private var view : ArcticView;
}
