package arctic;

import arctic.ArcticBlock;

/**
 * This file contains "high-level" interface to Arctic. It contains a range of
 * factory function which build useful ArcticBlocks, like lego-bricks.
 */
class Arctic {

	/// A text button
	static public function makeSimpleButton(text : String, onClick : Void -> Void, ?size : Float) : ArcticBlock {
		var t = Border(5, 5, Text(wrapWithDefaultFont(text, size)));
		return Button(t, Background(0xf0f0f0, t, 70.0, if (size != null) size / 4 else 5.0), onClick);
	}
	
	/// Associate a tooltip with a block
	static public function makeTooltip(block : ArcticBlock, text : String) : ArcticBlock {
		return Cursor(block, Offset(-30, -20, Background(0xFFFCA9, Border(5, 5, Text(wrapWithDefaultFont(text))), 100, 3)), true);
	}

	/// A block which looks like a page in a tear-off calendar on the given date
	static public function makeDateView(date : Date) : ArcticBlock {
		var months = [ "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" ];
		var days = [ "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday" ];
		var day = days[Math.floor(3 + date.getTime() / (1000 * 60 * 60 * 24)) % 7];
		var text = "<font color='#000000' face='arial'><p align='center'><b>" + months[date.getMonth()]
				+ "</b><br><p align='center'><b><font size='32'>" + date.getDate() + "</font></b>"
				+ "<br><p align='center'><b>" + day + "</b></font>";
		return Background(0x000000, Border(1, 1, Background(0xFFFCA9, ConstrainWidth(75, 75, ConstrainHeight(75, 75, Text(text))))));
	}
	
	/**
	 * Make a block dragable by the mouse in the given directions.
	 * If stayWithinSize is true, the movement is constrained to the available area
	 * of the block (and this block becomes size greedy in the directions we allow motion in).
	 * This block can be used to make many things, including dialogs.
	 * onDrag is called whenever we drag, telling the total X and Y offsets.
	 */
	static public function makeDragable(stayWithinSize : Bool, sideMotionAllowed : Bool, upDownMotionAllowed : Bool, 
					block : ArcticBlock, ?onDrag : Float -> Float -> Void) {
		// Local closured variables to remember drag offset
		var dragX = 0.0;
		var dragY = 0.0;
		var ourOnInit = function (onDragFun) {
			onDragFun(dragX, dragY);
		};
		var ourOnDrag = function (dx : Float, dy : Float) : Void {
			dragX = dx;
			dragY = dy;
			if (onDrag != null) {
				onDrag(dx, dy);
			}
		}
		return Dragable(stayWithinSize, sideMotionAllowed, upDownMotionAllowed, block, ourOnDrag, ourOnInit);
	}

	/// Add a check-box in front on the given block
	static public function makeCheckBox(block : ArcticBlock, ?onCheck : Bool -> Void, ?defaultSelected : Bool) : ArcticBlock {
		// Local closured variables to remember state
		var selected = defaultSelected;
		if (selected == null) {
			selected = false;
		}
		var ourOnInit = function (onCheckFun) {
			onCheckFun(selected);
		};
		var ourOnCheck = function (state : Bool) : Void {
			selected = state;
			if (onCheck != null) {
				onCheck(selected);
			}
		}

		// Callback fn for the CustomBlock to draw Radio button
		var build = function(state : Bool, parentMc : Dynamic, availableWidth : Float, availableHeight : Float) : Dynamic {
			var size = 12;
			DrawUtils.drawRectangle(parentMc, (availableWidth - size) / 2.0, (availableHeight - size) / 2.0, size, size, 2, 0x000000, 0xf0f0f0, 0);
			if (state) {
				size -= 4;
				DrawUtils.drawRectangle(parentMc, (availableWidth - size) / 2.0, (availableHeight - size) / 2.0, size, size, 2, 0x000000, 0x000000);
			}
			return parentMc;
		}

		var notSelectedBlock = ColumnStack( [ CustomBlock(false, null, build), block ] );
		var selectedBlock = ColumnStack( [ CustomBlock(true, null, build), block ] );
		return ToggleButton(selectedBlock, notSelectedBlock, selected, ourOnCheck, ourOnInit);
	}
	
	/// Make a radio-group to choose between the given texts
	static public function makeRadioButtonGroup(texts : Array<String>, onSelect : Int -> Void, ?defaultSelected : Int, ?textSize: Float) : ArcticBlock {
		var stateChooser = [];
		var currentRadio = defaultSelected;
		if (currentRadio == null) {
			currentRadio = 0;
		}
		if (textSize == null) {
			textSize = 12;
		}
		var onInit = function (setState) {
			if (stateChooser.length == texts.length) {
				// Called again on reconstruction: We clear out the old functions
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

		// Callback fn for the CustomBlock to draw Radio button
		var build = function(state : Bool, parentMc : Dynamic, availableWidth : Float, availableHeight : Float) : Dynamic {
			var radius = 6;
			DrawUtils.drawCircle(parentMc, availableWidth/2.0, availableHeight/2.0, radius, 0x000000, 0xf0f0f0, 0);
			if (state) {
				DrawUtils.drawCircle(parentMc, availableWidth/2.0, availableHeight/2.0, radius - 3.0, 0x000000, 0x000000);
			}
			return parentMc;
		}
		
		var toggleButtons : Array<ArcticBlock> = [];
		var i = 0;
		for (text in texts) {
			var selected = Border(1, 1, ColumnStack([CustomBlock(true, null, build),
													 Text(wrapWithDefaultFont(text, textSize))]));
			var unselected = Border(1, 1, ColumnStack([CustomBlock(false, null, build),
													   Text(wrapWithDefaultFont(text, textSize))]));
			var l = i;
			var sel = function (b) { onSelectHandler(l); };
			toggleButtons.push(ToggleButton(selected, unselected, false, sel, onInit));
			++i;
		}
		return LineStack(toggleButtons);
	}
	
	static public function wrapWithDefaultFont(text : String, ?size : Float, ?color : String) : String {
		return "<font face='arial'" + (if (size != null) { " size='" + size + "'"; } else "" ) + 
			   (if (color != null) { " color='" + color + "'"; } else "" ) + ">" + text + "</font>";
	}
}
