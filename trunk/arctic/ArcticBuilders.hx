package arctic;

import arctic.ArcticBlock;

class ArcticBuilders {

	static public function makeSimpleButton(text : String, onClick : Void -> Void, ?size : Float) : ArcticBlock {
		var t = Border(5, 5, Text(wrapWithDefaultFont(text, size)));
		return Button(t, Background(0xf0f0f0, t, 70.0, if (size != null) size / 4 else 5.0), onClick);
	}

	static public function makeDateView(date : Date) : ArcticBlock {
		var months = [ "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" ];
		var days = [ "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday" ];
		var day = days[Math.floor(3 + date.getTime() / (1000 * 60 * 60 * 24)) % 7];
		var text = "<font color='#000000' face='arial'><p align='center'><b>" + months[date.getMonth()]
				+ "</b><br><p align='center'><b><font size='32'>" + date.getDate() + "</font></b>"
				+ "<br><p align='center'><b>" + day + "</b></font>";
		return Background(0x000000, Border(1, 1, Background(0xFFFCA9, ConstrainWidth(75, 75, ConstrainHeight(75, 75, Text(text))))));
	}
	
	static public function makeRadioButtonGroup(texts : Array<String>, onSelect : Int -> Void, ?defaultSelected : Int, ?size: Float) : ArcticBlock {
		var stateChooser = [];
		var currentRadio = defaultSelected;
		if (currentRadio == null) {
			currentRadio = 0;
		}
		if (size == null) {
			size = 12;
		}
		var onInit = function (setState) {
			if (stateChooser.length == texts.length) {
				// Called again on reconsturction: We clear out the old functions
				stateChooser = [];
			}
			stateChooser.push(setState); 
			if (stateChooser.length - 1 == currentRadio) {
				setState(true);
			}
		};
		var onSelectHandler = function (index : Int) {
			for (i in 0...stateChooser.length) {
				stateChooser[i](i == index);
			}
			currentRadio = index;
			if (onSelect != null) {
				onSelect(index);
			}
		}

		// Callback fns for the CustomBlock to draw Radio button
		var calcMetrics = function(state : Bool) : Metrics {
			return { width: 15, height : 15, growHeight : false, growWidth : false };
		}
		var build = function(state : Bool, parentMc : Dynamic, availableWidth : Float, availableHeight : Float) : Dynamic {
			DrawUtils.drawCircle(parentMc, availableWidth/2.0, availableHeight/2.0, 6.0, 0x000000);
			if (state) {
				DrawUtils.drawCircle(parentMc, availableWidth/2.0, availableHeight/2.0, 3.0, 0x000000, 0x000000);
			}
			return parentMc;
		}
		
		var toggleButtons : Array<ArcticBlock> = [];
		var i = 0;
		for (text in texts) {
			var selected = Border(1, 1, ColumnStack([CustomBlock(true, calcMetrics, build),
													 Text(wrapWithDefaultFont(text, size))]));
			var unselected = Border(1, 1, ColumnStack([CustomBlock(false, calcMetrics, build),
													   Text(wrapWithDefaultFont(text, size))]));
			var l = i;
			var sel = function (b) { onSelectHandler(l); };
			toggleButtons.push(ToggleButton(selected, unselected, false, sel, onInit));
			++i;
		}
		return LineStack(toggleButtons);
	}
	
	static public function wrapWithDefaultFont(text : String, ?size : Float) : String {
		return "<font face='arial'" + (if (size != null) { " size='" + size + "'"; } else "" ) + ">" + text + "</font>";
	}
}
