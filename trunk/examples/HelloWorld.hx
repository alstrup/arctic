import arctic.Arctic;
import arctic.ArcticView;
import arctic.ArcticBlock;
import arctic.ArcticMC;

class HelloWorld {
	static public function main() {
		#if neko
		neash.Lib.Init("Hello, Arctic", 400, 400);
		#end
		new HelloWorld(ArcticMC.getCurrentClip());
		#if neko
		neash.Lib.Run();
		#end
	}
	
	public function new(parent : ArcticMovieClip) {
		// To make a screen, first build the data structure representing the contents
		var helloWorld = Arctic.makeSimpleButton("Hello world",  remove, 50);

		// Then construct the arctic view object
		arcticView = new ArcticView( helloWorld, parent );
		// And finally display on the given movieclip
		var root = arcticView.display(true);
	}
	public function remove() {
		// Clear out the screen
		arcticView.destroy();
	}
	public var arcticView : ArcticView;
}

/*
More versions from the manual:

		var helloWorld = ColumnStack( [ Filler,
			Arctic.makeSimpleButton("Hello world", remove, 50),
			Filler ] );

		var helloWorld = LineStack( [
			Filler, 
			ColumnStack( [ 
				Filler,
				Arctic.makeSimpleButton("Hello world", remove, 50),
				Filler ] ),
			Filler ] );

		var helloWorld = LineStack( [
			Arctic.makeText("Some text in <b>HTML</b> is nice", 16, "#0000ff"),
			Filler, 
			ColumnStack( [ 
				Filler,
				Arctic.makeSimpleButton("Hello world", remove, 50),
				Filler ] ),
			Filler ] );

		var helloWorld = Background(0xdddddd,
			LineStack( [
				Arctic.makeText("Some text in <b>HTML</b> is nice", 16, "#0000ff"),
				Filler, 
				ColumnStack( [ 
					Filler,
					Arctic.makeSimpleButton("Hello world", remove, 50),
					Filler ] ),
				Filler ] )
			, 100.0, 20);
*/
