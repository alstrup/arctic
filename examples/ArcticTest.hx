#if flash9
import flash.display.MovieClip;
#else flash
import flash.MovieClip;
#end

import arctic.Arctic;

class ArcticTest {
	static public function main() {
		new ArcticTest(flash.Lib.current);
	}
	
	public function new(parent_ : MovieClip) {
		var now = Date.now();
		var consultation = [
			{ name: "Mike Olson", icon: "head1", date: now, time: "08:30", reason: "Has developed a rash" },
			{ name: "Eliah Alström", icon: "head2", date: now, time: "09:00", reason: "Coughing" }
		];
		
		var consultationBlocks = [];
		for (c in consultation) {
			consultationBlocks.push(
				Border(5, 5,
					GradientBackground( "radial", [0xffffCE, 0xffee77], 0.2, 0.4,
						ColumnStack( [
							Border(10, 35, Text("<font face='arial' size='28'>" + c.time + "</font>") ),
							Border(5, 5, Picture("images/" + c.icon + ".jpg", 80, 100, 1.0) ),
							Text("<font face='arial' size='18'><b>" + c.name + "</b><br/><font size='16'>" + c.reason + "</font></font>"),
							Filler
						] )
					)
				)
			);
		}
		consultationBlocks.push(Filler);

		var me = this;
		var gui = 
			Background(0x555555, 
				Border(40, 40,
					GradientBackground( "radial", [0x9CAACE, 0x3B4C77], 0.2, 0.4,
						LineStack( [
							Border( 10, 10, 
								ColumnStack( [
									DateView(Date.now()), 
									Border( 20, 20, 
										Text("<b><font face='arial' size='24' color='#ffffff'>Today's appointments</font></b>")
									)
								] )
							),
							SelectList( consultationBlocks, function(line0 : Int) { me.line = line0; }),
							ColumnStack( [
								Filler,
								Button( Text("<font face='arial' size='24' color='#ffffff'>Continue</font>"), function() { me.next(); })
							] )
							]
						)
					)
				)
			);
		
		arctic = new Arctic(gui);
		var root = arctic.display(parent_, true);
	}

	public function next() {
		trace("Selected " + line);
		arctic.remove();
		arctic = null;
	}
	
	public var line : Int;
	
	public var arctic : Arctic;
}
