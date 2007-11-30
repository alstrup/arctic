import arctic.Arctic;
import arctic.ArcticBlock;
import arctic.ArcticDialogUi;

class Dialogs {
	static public function main() {
		new Dialogs(flash.Lib.current);
	}
	
	public function new(parent : ArcticMovieClip) {
		arctic.ArcticDialogManager.get().init(parent);

		// Construct ande open a simple dialog
		var dialog = new ArcticDialogUi("Simple dialog", Arctic.makeText("With simple contents"), 0.25, 0.25).open();
		
		// Construct a dialog where the title can be updated
		var dialog2 : ArcticDialogUi;
		var content = Arctic.makeSimpleButton("Click me to update title", function() { dialog2.title += "."; } );
		dialog2 = new ArcticDialogUi("Title", content, 0.75, 0.75);
		dialog2.open();

		// Construct a dialog with a scrollbar in it
		var dialog3 = new ArcticDialogUi("Dialog with scrollbar", 
			ConstrainHeight( 100, 100, 
				LineStack([ 
					Arctic.makeText("This window has a scrollbar..."),
					Fixed(10, 100),
					Arctic.makeText("...so that this can be found!")
				])
			), 0.25, 0.75).open();
	}
}
