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
		var fullsize = true;
		var nextButton = Arctic.makeSimpleButton( "Next bug", next );
		switch (count) {
			case 0:
			// Tooltips were underneath following elements
			screen = 
				Border( 50, 100, 
				ColumnStack( [
					Arctic.makeTooltip( Text("This text has a tooltip."), "This tooltip should come on top of everything"),
					Text("Don't go beneath this stuff"),
					nextButton
				] ) );
			case 1:
			// Not possible to select text in textinput nested in dragable
			screen = 
				LineStack( [
					Arctic.makeDragable(true, true, true, Background(0x8080ff, Border(10, 10, TextInput("Selection with mouse should work", 200, 20)))).block,
					Arctic.makeDragable(true, true, true, Background(0x8080ff, Border(10, 10, TextInput("Selection with mouse should work", 200, 20)))).block,
					nextButton
				]);
			case 2:
			// Nested dragables were dually dragged
			screen = 
				LineStack( [
					Arctic.makeDragable(true, true, true, ConstrainWidth(300, 300, ConstrainHeight(100, 100, Background(0x8080ff, Border(10, 10, Arctic.makeDragable(true, true, true, Background(0x80ff80, Border(10, 10, TextInput("Selection with mouse should work", 200, 20)))).block))))).block,
					nextButton
				]);
			case 3:
			// Nested LineStack become too big:
			screen = Border(20, 120, Background(0xf08000, 
				LineStack( [ 
					LineStack( [ Arctic.makeText("Text", 50), Filler ] ),
					nextButton
				] )));
			case 4:
			// Text radio-choice does not work
			screen = 
					LineStack( [ 
						Arctic.makeTextChoice([ "See custom block", "See dragable blocks" ], function(i : Int, text : String) { }, 0, 20).block,
						nextButton
					]);
			case 5:
			// This should be a clickable 20x20 red box
			// TODO: This does not work with Flash 9!
			screen = Background(0xff0000, Button(Fixed(20, 20), Fixed(20, 20), next) );
//			screen = LineStack( [ Background(0xff0000, ColumnStack( [ Button(Fixed(20, 20), Fixed(20, 20), next), Filler ] )) ] );
			fullsize = false;
			case 6:
			// On resize, this should work correctly such that the scrollbar comes and disappears correctly
			screen = LineStack( [ Arctic.makeText("Text", 200), nextButton ] );
			case 7:
			// This should be a red 50x50 box with a green 10x10 box below - the fillers become 0 height, because we do not fullsize it
			screen = LineStack( [
								  LineStack( [ Filler, Background(0xff0000, Button(Fixed(50, 50), Fixed(50, 50), next)) ]),
								  LineStack( [ Filler, Background(0x00ff00, Fixed(10, 10)) ] )
					] );
			fullsize = false;
			case 8:
			// Should be in the bottom right corner
			screen = LineStack( [ Filler, ColumnStack( [ Filler, nextButton ] ) ] );
			case 9:
			// Innermost linestack should get scrollbar, not outermost
			screen = LineStack( [ 
						Background(0xff0000, Fixed(100, 100)),
						Background(0x00ff00, 
							LineStack( [
								nextButton,
								Filler,
								Background(0x0000ff, Fixed(100, 300))
							])
						),
						Filler,
						Background(0xff0000, Fixed(100, 100))
					]);
			case 10:
			// TextInputs should not go outside screen
			screen =
			Border(10,10,
				Background( 0x8888ff,
						ConstrainWidth(500,500,
							LineStack( [
								Text("<font face='arial' size='40'>Visual settings</font>"),
								Background(0xAAAAFF,
									ColumnStack( [
										Arctic.makeTooltip(
											Arctic.makeCheckbox( Fixed(0,0), function(state : Bool) { trace(state); } ).block,
											"Enable this feature (disable to use default)"),
										Text("<font face='arial' size='20'>Logo banner: </font>"),
										Filler,
										Id("LogoBannerInput",TextInput("", 150, 20, null, null, 100, false, 0xFFFFFF, false))
									] )
								),
								Background(0xCCCCFF,
									ColumnStack( [
										Arctic.makeTooltip(
											Arctic.makeCheckbox( Fixed(0,0)).block,
											"Enable this feature (disable to use default)"),
										Text("<font face='arial' size='20'>Logo banner: </font>"),
										Filler,
										TextInput("", 150, 20, null, null, 150, false, 0xFFFFFF, false)
									] )
								),
								Filler
							] )
						),
						100,20
				)
			);
			case 11:
			var alternatives = [];
			var push = function(s : String) {
				alternatives.push( {
					selected: Arctic.makeSimpleButton("*" + s, null),
					unselected: Arctic.makeSimpleButton( s, null),
					value : s
				});
			}
			push("1");
			push("2");
			push("3");
			var change = function(n : Int, s) {
				trace(n + " " + s);
			};
			screen = Align(0.5, 0.5, LineStack( Arctic.makeRadioButtonGroup(alternatives, change, 0).blocks.concat([nextButton]) ) );
			
			default:
			screen = Text("The end");
		}
		 // Then construct the arctic object
		arcticView = new ArcticView( screen, parent );
		#if false
			if (true) {
				arcticView.debug = true;
				arcticView.adjustToFit(400, 400);
				arcticView.debug = false;
			}
		#end
		if (!fullsize) {
			arcticView.adjustToFit(0, 0);
		}
		#if false
			arcticView.debug = true;
		#end
		// And finally display on the given movieclip
		var root = arcticView.display(fullsize);
		++count;
	}
	public var arcticView : ArcticView;
	public var count : Int;
	public var parent : ArcticMovieClip;
}
