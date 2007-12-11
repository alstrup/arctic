import arctic.Arctic;
import arctic.ArcticMC;
import arctic.ArcticBlock;
import arctic.ArcticView;

class ArcticTest {
	static public function main() {
		new ArcticTest(flash.Lib.current);
	}
	
	public function new(parent_ : ArcticMovieClip) {
		parent = parent_;

		showHelloWorld1();
		//nextWorld();
		//draggable();
		//wideText();
		//wrappingLayout();
		//maskBlock();
	}

	public function showHelloWorld1() {
		// To make a screen, first build the data structure representing the contents
		var helloWorld = Arctic.makeSimpleButton("Hello world", showHelloWorld2, 50);
		// Then construct the arctic object
		arcticView = new ArcticView( helloWorld, parent );
		// And finally display on the given movieclip
		var root = arcticView.display(true);
	}
	
	public function showHelloWorld2() {
		// Clear out the old screen
		if (arcticView != null) { arcticView.destroy(); }
		
		// To make a nicer screen, we use a background and some more layout
		var helloWorld = GradientBackground( "radial", [ 0xffceff, 0xff77ee], 0.2, 0.4,
							LineStack( [ 
								Filler, 
								ColumnStack( [
									Filler,
									Filter(
										DropShadow(7, 45, 0x777777, 0.5),
										Arctic.makeText("Hello world!", 40, null, "arial")
									),
									Filler ]
								),
								Filler,
								ColumnStack( [
									Filler,
									Arctic.makeTooltip(
										Arctic.makeSimpleButton("Continue", nextWorld, 25),
										"Click here to continue"
									)
								] )
							] )
						);
		// Then construct the arctic object
		arcticView = new ArcticView(helloWorld, parent);
		// And finally display on the given movieclip
		var root = arcticView.display(true);
	}
	
	public function nextWorld() {
		// This is called when "Continue" is clicked above
		if (arcticView != null) { arcticView.destroy(); }

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
							Border(10, 35, Arctic.makeText(c.time, 28, null, "arial") ),
							Border(5, 5, Picture("images/" + c.icon + ".jpg", 80, 100, 1.0) ),
							LineStack( [
								Text("<font face='arial' size='18'><b>" + c.name + "</b><br/><font size='16'>" + c.reason + "</font></font>"),
								TextInput("<font face='arial'>Write comments here</font>", 400, 20, function (s) { trace(s); return true; }) 
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
									Frame(1, 0x777777, Arctic.makeDateView(Date.now()), 2, 100, 2, 2), 
									Border( 20, 20, 
										Arctic.makeText("<b>Today's appointments</b>", 24, "#ffffff", "arial")
									)
								] )
							),
							LineStack( consultationBlocks ),
							Border( 10, 10,
								Arctic.makeTextChoice([ "See custom block", "See dragable blocks", "See wide text", "See wrapping layout", "See advanced text control", "See mask block" ], function(i : Int, text : String) { me.radioChoice = i; }, 0, 20).block
							),
							Border( 10, 10, Arctic.makeCheckbox( Arctic.makeText("Check box without effect", 20)).block ),
							ColumnStack( [
								Filler,
								Arctic.makeSimpleButton("Continue",  screen1next, 25)
							] )
							]
						)
					)
				)
			);
		radioChoice = 0;

		arcticView = new ArcticView(gui, parent);
		var root = arcticView.display(true);
	}

	public function screen1next() {
		if (arcticView != null) { arcticView.destroy(); }
		
		switch (radioChoice) {
			case 0: customBlock();
			case 1: draggable();
			case 2: wideText();
			case 3: wrappingLayout();
			case 4: advancedTextControl();
			case 5: maskBlock();
			default: 0;
		}
	}
	
	public function customBlock() {
		if (arcticView != null) { arcticView.destroy(); }
	
		// A custom block needs a function which can tell Arctic the size and desired resizing behaviour,
		// and paint & construct the block when ready
		var build = function(data : Int, mode : BuildMode, parentMc : ArcticMovieClip, availableWidth : Float, availableHeight : Float, existingMc : ArcticMovieClip) {
			if (mode != Metrics) {
				// This is used both for creation and update
				var g = ArcticMC.getGraphics(parentMc);
				g.clear();
				g.beginFill(data);
				g.moveTo(50, 0);
				g.lineTo(100, 100);
				g.lineTo(0, 100);
				g.lineTo(50, 0);
				g.endFill();
			}
			return { clip: parentMc, width: 100.0, height: 100.0, growHeight : false, growWidth : false };
		}
		
		var custom = Background( 0x000000,
						Border( 10, 10, 
							LineStack( [ 
								// The first custom block is inserted here - the payload data is the color of our custom block
								CustomBlock( 0xff0000, build ), 
								// The middle one
								CustomBlock( 0xffff00, build), 
								// The final one
								CustomBlock( 0x00ff00, build) 
							] )
						)
					);
			
		arcticView = new ArcticView(custom, parent);
		var root = arcticView.display(true);
	}
	
	public function draggable() {
		if (arcticView != null) { arcticView.destroy(); }

		// Small example showing the different kinds of draggable blocks possible in Arctic
		var makeText = function (text) {
			return Background(0x202020, Border(5, 5, Arctic.makeText(text, 20, "#ffffff", "arial")), 100, 5);
		}
		var doTrace = function(s) {
		//	trace(s);
		};
		var sliderfun = function(x : Float, y : Float) { doTrace(x + "," + y); };
		var dragfun = function(di : DragInfo) { doTrace("x: " + di.x + "/" + di.totalWidth + " y: " + di.y + "/" + di.totalHeight); };
		var drag = LineStack( [
					Background(0x808080, Arctic.makeSlider(0, 100, 0, 0, makeText("I can be dragged from side to side within my area"), sliderfun).block ),
					Background(0xa0a080, Arctic.makeSlider(-100, 100, 10, 20, makeText("I can be dragged within my area"), sliderfun, 0, 15 ).block ),
					Background(0xc0c0c0, Arctic.makeDragable(true, false, true, makeText("I can be dragged up and down within my area"), dragfun, 0, 200 ).block ),
					Arctic.makeDragable(false, true, true, makeText("I can be dragged anywhere"), dragfun ).block
				] );
		arcticView = new ArcticView(drag, parent);
		var root = arcticView.display(true);
	}
	
	public function wideText() {
		if (arcticView != null) { arcticView.destroy(); }
		var gui = 
		Background(0x00ff00,
			LineStack([
				Filler,
				ColumnStack( [ 
					Filler, 
					Background(0xff0000, 
						Arctic.makeText("Arctic is a simple haXe GUI framework which allows you to create user interfaces for flash applications. It is unique by supporting both Flash 8 and Flash 9 targets using the same client code.", 20, "#ffffff", null, null, true)
					),
					Filler 
				] ),
				Filler
			])
		);
		arcticView = new ArcticView(gui, parent);
//		arcticView.debug = true;
		var root = arcticView.display(true);
	}
	
	public function wrappingLayout() {
		if (arcticView != null) { arcticView.destroy(); }
		var blocks1 = [];
		var blocks2 = [];
		for (i in 1...15) {
			blocks1.push(Background(0x0000FF, Fixed(50, 50)));
			blocks2.push(Background(0xFF0000, Fixed(10 * (16 - i), 10*i)));
		}
		var gui = LineStack([
					Background(0xAAAAAA, Wrap(blocks1, 200, 20, 5)),
					Fixed(0, 50), 
					Background(0xAAAAAA, Wrap(blocks2, null, 5, 20, Background(0xFFFF00, Filler))),
					Arctic.makeSimpleButton("Continue",  nextWorld, 25)
				]);
		arcticView = new ArcticView(gui, parent);
		arcticView.display(true);
	}
	
	public function advancedTextControl() {
		if (arcticView != null) { arcticView.destroy(); }

		var controlFun: TextInputModel -> TextInputModel;
		
		var gui = LineStack([
				Filler,
				ColumnStack([
					Filler,
					TextInput(Arctic.wrapWithDefaultFont("Text is not focused. Click 'Focus & select' to focus and make selection\nNote that text can span multiple lines and grow as you type", 20), 700, null, null, null, null, null, 0xFF0000, null, null,
						function (fun) { controlFun = fun; }), 
					Filler
				]),
				ColumnStack([
					Filler,
					Arctic.makeSimpleButton("Focus & select", function () {
						var status = controlFun(null);
						var quarter = Math.floor(status.text.length / 4);
						controlFun( { html: null, text: null, focus: true, selStart: quarter, selEnd: quarter * 3, cursorPos: null, disabled: false } );
					}, 25), 
					Arctic.makeSimpleButton("Continue", nextWorld, 25),
					Filler
				]),
				Filler
			]);
			
		arcticView = new ArcticView(gui, parent);
		arcticView.display(true);
	}
	
	public function maskBlock() {
		if (arcticView != null) { arcticView.destroy(); }

		var gui = Align(0.5, 0.5, Mask(
			LineStack([ 
				Background(0x800000, Arctic.makeSimpleButton("Continue", nextWorld, 25)),
				Background(0x008000, Filler),
				Background(0x000080, Fixed(100, 10)),
			]),
			Background(0xffffff, LineStack([Fixed(100, 20), Filler]), 100, 30)
		));
		arcticView = new ArcticView(gui, parent);
		arcticView.display(true);
	}

	var arcticView : ArcticView;
	var radioChoice : Int;
	
	var parent : ArcticMovieClip;
	var screen1 : ArcticBlock;
	var screen2 : ArcticBlock;
	var screen3 : ArcticBlock;
}
