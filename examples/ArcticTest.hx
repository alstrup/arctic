#if flash9
import flash.display.MovieClip;
#else flash
import flash.MovieClip;
#end

import arctic.Arctic;
import arctic.ArcticBlock;
import arctic.ArcticBuilders;

class ArcticTest {
	static public function main() {
		new ArcticTest(flash.Lib.current);
	}
	
	public function new(parent_ : MovieClip) {
		parent = parent_;
		
		showHelloWorld1();
	}

	public function showHelloWorld1() {
		// To make a screen, first build the data structure representing the contents
		var me = this;
		var helloWorld = ArcticBuilders.makeSimpleButton("Hello world",  function() { me.showHelloWorld2(); }, 50);
		// Then construct the arctic object
		arctic = new Arctic(helloWorld);
		// And finally display on the given movieclip
		var root = arctic.display(parent, true);
	}
	
	public function showHelloWorld2() {
		// Clear out the old screen
		arctic.destroy();
		
		// To make a nicer screen, we use a background and some more layout
		var me = this;
		var helloWorld = GradientBackground( "radial", [ 0xffceff, 0xff77ee], 0.2, 0.4,
							LineStack( [ 
								Filler, 
								ColumnStack( [
									Filler,
									Text("<font face='arial' size='40'>Hello world!</font>"),
									Filler ]
								),
								Filler,
								ColumnStack( [
									Filler,
									ArcticBuilders.makeSimpleButton("Continue",  function() { me.nextWorld(); }, 25)
								] )
							] )
						);
		// Then construct the arctic object
		arctic = new Arctic(helloWorld);
		// And finally display on the given movieclip
		var root = arctic.display(parent, true);
	}
	
	public function nextWorld() {
		// This is called when "Continue" is clicked above
		arctic.destroy();

		// Again, build the screen as a data structure of ArcticBlocks, through a couple of intermediate data structures
		// This illustrates the "lego"-construction of user interfaces when you use Arctic

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
							LineStack( [
								Text("<font face='arial' size='18'><b>" + c.name + "</b><br/><font size='16'>" + c.reason + "</font></font>"),
								TextInput("<font face='arial'>Write comments here</font>", 400, 20, null) 
							] ),
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
									ArcticBuilders.makeDateView(Date.now()), 
									Border( 20, 20, 
										Text("<b><font face='arial' size='24' color='#ffffff'>Today's appointments</font></b>")
									)
								] )
							),
							LineStack( consultationBlocks ),
							Border( 10, 10,
								ArcticBuilders.makeRadioButtonGroup([ "Visit", "Reschedule" ], function(i : Int) { me.radioChoice = i; }, 0, 20)
							),
							ColumnStack( [
								Filler,
								ArcticBuilders.makeSimpleButton("Continue",  function() { me.screen1next(); }, 25)
							] )
							]
						)
					)
				)
			);
		radioChoice = 0;

		arctic = new Arctic(gui);
		var root = arctic.display(parent, true);
	}

	public function screen1next() {
		arctic.destroy();
		
		if (radioChoice == 0) {
			visit();
		} else {
			reschedule();
		}
	}
	
	public function visit() {
		arctic.destroy();
		
		var calcMetrics = function(data : Int) : Metrics {
			return { width: 100, height : 100, growHeight : false, growWidth : false };
		}
		var build = function(data : Int, parentMc : ArcticMovieClip, availableWidth : Float, availableHeight : Float) : ArcticMovieClip {
			#if flash9
				parentMc.graphics.beginFill(data);
				parentMc.graphics.moveTo(50, 0);
				parentMc.graphics.lineTo(100, 100);
				parentMc.graphics.lineTo(0, 100);
				parentMc.graphics.lineTo(50, 0);
				parentMc.graphics.endFill();
			#else flash
				parentMc.beginFill(data);
				parentMc.moveTo(50, 0);
				parentMc.lineTo(100, 100);
				parentMc.lineTo(0, 100);
				parentMc.lineTo(50, 0);
				parentMc.endFill();
			#end
			return parentMc;
		}
		
		var custom = Background( 0x000000,
						Border( 10, 10, 
							LineStack( [ 
								CustomBlock( 0xff0000, calcMetrics, build ), 
								// Notice that we give it null as metrics here
								// Then, arctic will build the block to get the metrics
								CustomBlock( 0xffff00, null, build), 
								CustomBlock( 0x00ff00, calcMetrics, build) 
							] )
						)
					);
			
		arctic = new Arctic(custom);
		var root = arctic.display(parent, true);
	}
	
	public function reschedule() {
		trace("Reschedule");
	}

	public var arctic : Arctic;
	public var radioChoice : Int;
	
	public var parent : MovieClip;
	public var screen1 : ArcticBlock;
	public var screen2 : ArcticBlock;
	public var screen3 : ArcticBlock;
}
