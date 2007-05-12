import arctic.Arctic;
import arctic.ArcticBlock;
import arctic.ArcticView;
import arctic.ArcticMC;

class Piano {
	static public function main() {
		new Piano();
	}
	
	public function new() {
		var ui = 
			LineStack( [
				Fixed(0, 10),
				Border( 20, 0,
					Picture("staff.swf", 0.25 * 420.0, 0.25 * 420.0, 1.0)
				),
				Fixed(0, 10),
				Background( 0x1C1B1C, 
					Border(20, 2,
						Picture("keys.swf", 0.2 * 800.0, 0.2 * 640.0, 1.0)
					)
				)
			]);
		
		view = new ArcticView(ui, flash.Lib.current);
		view.display(true);
	}
	
	private var view : ArcticView;
}
