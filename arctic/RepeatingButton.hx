package arctic;
import arctic.ArcticBlock;

class RepeatingButton {
	/// This constructs a button which repeatedly triggers the action as long as the mouse is pressed
	static public function make(base : ArcticBlock, hover : ArcticBlock, action : Void -> Void, time : Int) : ArcticBlock {

		var timer : haxe.Timer = null;
		var ourHandler = function (x : Float, y : Float, down : Bool, inside : Bool) {
			if (!down) {
				if (timer != null) {
					timer.stop();
					timer = null;
				}
				return;
			}
			if (!inside || timer != null) {
				return;
			}
			timer = new haxe.Timer(time);
			timer.run = action;
		}
		
		return Button(base, hover, action, ourHandler);
	}
}
