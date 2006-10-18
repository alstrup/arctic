package arctic;

#if flash9
import flash.display.MovieClip;
#else flash
import flash.MovieClip;
#end

class ArcticDateView {
	public function new(parent : MovieClip, x : Float, y : Float, date : Date) {
		
		var months = [ "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" ];
		var days = [ "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday" ];

#if flash9
		var tf = new flash.text.TextField();
		tf.x = x;
		tf.y = y;
		tf.width = 75;
		tf.height = 75;
#else flash
		var text = parent.createEmptyMovieClip("text", parent.getNextHighestDepth());
		text.useHandCursor = false;
		text._x = x;
		text._y = y;
		text.tabEnabled = false;
		var tf = text.createTextField("tf", text.getNextHighestDepth(), 0, 0, 75, 75);
		tf.html = true;
#end
		tf.textColor = 0x000000;
		tf.multiline = true;
		tf.border = true;
		tf.selectable = false;
		// Calculate what weekday it is
		var day = days[Math.floor(3 + date.getTime() / (1000 * 60 * 60 * 24)) % 7];
		tf.htmlText = "<font face='arial'><p align='center'><b>" + months[date.getMonth()]
				+ "</b><br><p align='center'><b><font size='32'>" + date.getDate() + "</font></b>"
				+ "<br><p align='center'><b>" + day + "</b></font>";
		tf.background = true;
		tf.backgroundColor = 0xFFFCA9;
#if flash9
		parent.addChild(tf);
#end
	}
}
