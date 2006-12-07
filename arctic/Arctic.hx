package arctic;

import arctic.ArcticBlock;

/**
 * This file contains "high-level" interface to Arctic. It contains a range of
 * factory function which build useful ArcticBlocks, like lego-bricks.
 */
class Arctic {

	/// The default font used in the helpers here
	static public var defaultFont = "arial";
	/// Is the default font an embedded font?
	static public var isDefaultFontEmbedded = false;

	/// Make a text using the given parameters. Default color is black. If font is omitted, the default font is used
	static public function makeText(text : String, ?size : Float, ?color : String, ?font : String, ?isEmbedded : Bool) {
		return Text(wrapWithDefaultFont(text, size, color, font), if (isEmbedded == null) isDefaultFontEmbedded else isEmbedded);
	}
	
	/// A text button
	static public function makeSimpleButton(text : String, onClick : Void -> Void, ?fontsize : Float) : ArcticBlock {
		var t = Border(5, 5, makeText(text, fontsize));
		return Button(t, Background(0xf0f0f0, t, 70.0, if (fontsize != null) fontsize / 4 else 5.0), onClick);
	}
	
	/// Associate a tooltip with a block
	static public function makeTooltip(block : ArcticBlock, text : String) : ArcticBlock {
		return Cursor(block, Offset(-30, -20, Background(0xFFFCA9, Border(5, 5, makeText(text)), 100, 3)), true);
	}

	/// A block which looks like a page in a tear-off calendar on the given date
	static public function makeDateView(date : Date) : ArcticBlock {
		var months = [ "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" ];
		var days = [ "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday" ];
		var day = days[Math.floor(3 + date.getTime() / (1000 * 60 * 60 * 24)) % 7];
		var text = "<font color='#9CAACE' face='" + defaultFont + "'><p align='center'><b>" + months[date.getMonth()]
				+ "</b><br><p align='center'><b><font size='32'>" + date.getDate() + "</font></b>"
				+ "<br><p align='center'><b>" + day + "</b></font>";
		return Background(0x000000, Border(0, 0, Background(0x3B4C77, ConstrainWidth(75, 75, ConstrainHeight(75, 75, 
			LineStack([ 
				Filler,
				ColumnStack([Filler,Text(text, isDefaultFontEmbedded), Filler]),
				Filler ]
			))))));
	}
	
	/**
	 * Make a block dragable by the mouse in the given directions.
	 * If stayWithinBlock is true, the movement is constrained to the available area
	 * of the block (and this block becomes size greedy in the directions we allow motion in).
	 * This block can be used to make many things, including dialogs.
	 * onDrag is called whenever we drag, telling the total X and Y offsets.
	 */
	static public function makeDragable(stayWithinBlock : Bool, sideMotionAllowed : Bool, upDownMotionAllowed : Bool, 
					block : ArcticBlock, ?onDrag : Float -> Float -> Void, ?initialXOffset : Float, ?initialYOffset : Float) {
		// Local closured variables to remember drag offset
		var dragX = if (initialXOffset == null || !sideMotionAllowed) 0.0 else initialXOffset;
		var dragY = if (initialYOffset == null || !upDownMotionAllowed) 0.0 else initialYOffset;
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
		return Dragable(stayWithinBlock, sideMotionAllowed, upDownMotionAllowed, block, ourOnDrag, ourOnInit);
	}

	/// Add a check-box in front on the given block
	static public function makeCheckbox(block : ArcticBlock, ?onCheck : Bool -> Void, ?defaultSelected : Bool) : ArcticBlock {
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
		var calcMetrics = function(data) {
			return { width: 13, height: 13, growWidth : false, growHeight : false };
		}
		var build = function(state : Bool, parentMc : ArcticMovieClip, availableWidth : Float, availableHeight : Float, existingMc : ArcticMovieClip) : Dynamic {
			var size = 12;
			DrawUtils.drawRectangle(parentMc, (availableWidth - size) / 2.0, (availableHeight - size) / 2.0, size, size, 2, 0x000000, 0xf0f0f0, 0);
			if (state) {
				size -= 4;
				DrawUtils.drawRectangle(parentMc, (availableWidth - size) / 2.0, (availableHeight - size) / 2.0, size, size, 2, 0x000000, 0x000000);
			}
			return parentMc;
		}

		var notSelectedBlock = ColumnStack( [ CustomBlock(false, calcMetrics, build), block ] );
		var selectedBlock = ColumnStack( [ CustomBlock(true, calcMetrics, build), block ] );
		return ToggleButton(selectedBlock, notSelectedBlock, selected, ourOnCheck, ourOnInit);
	}
	
	/**
	* Make a radio-group to choose between the given texts.
	* Returns the final block and a function that can be used to change the currently selected item.
	*/
	static public function makeTextChoice(texts : Array<String>, onSelect : Int -> String -> Void, ?defaultSelected : Int, ?textSize: Float) : 
			{ block: ArcticBlock, selectFn: Int -> Void } {
		if (textSize == null) {
			textSize = 12;
		}
		// Callback fn for the CustomBlock to draw Radio button
		var calcMetrics = function(data) {
			return { width: 13, height: 13, growWidth : false, growHeight : false };
		}
		var build = function(state : Bool, parentMc : ArcticMovieClip, availableWidth : Float, availableHeight : Float, existingMc : ArcticMovieClip) : Dynamic {
			var radius = 6;
			DrawUtils.drawCircle(parentMc, availableWidth/2.0, availableHeight/2.0, radius, 0x000000, 0xf0f0f0, 0);
			if (state) {
				DrawUtils.drawCircle(parentMc, availableWidth/2.0, availableHeight/2.0, radius - 3.0, 0x000000, 0x000000);
			}
			return parentMc;
		}
		
		var entries : Array<{ selected: ArcticBlock, unselected: ArcticBlock, value : String }> = [];
		var i = 0;
		for (text in texts) {
			var selected = Border(1, 1, ColumnStack([CustomBlock(true, calcMetrics, build),
													 makeText(text, textSize)]));
			var unselected = Border(1, 1, ColumnStack([CustomBlock(false, calcMetrics, build),
													   makeText(text, textSize)]));
			entries.push( { selected: selected, unselected: unselected, value: text } );
		}
		var group = makeRadioButtonGroup(entries, onSelect, defaultSelected);
		return { block: LineStack(group.blocks), selectFn : group.selectFn };
	}
	
	/**
	 * Make a radio-group to choose between the given blocks.
	 * Returns an array of coupled blocks, and a function which can be used to change the
	 * current selected item.
	 */ 
	static public function makeRadioButtonGroup(entries : Array< { selected : ArcticBlock, unselected : ArcticBlock, value : Dynamic } >, onSelect : Int -> Dynamic -> Void, ?defaultSelected : Int) 
			: { blocks: Array<ArcticBlock>, selectFn : Int -> Void } {
		var stateChooser = [];
		var currentRadio = defaultSelected;
		if (currentRadio == null) {
			currentRadio = 0;
		}
		var onInit = function (setState) {
			if (stateChooser.length == entries.length) {
				// Called again on reconstruction: We clear out the old functions
				stateChooser = [];
			}
			stateChooser.push(setState); 
			if (stateChooser.length - 1 == currentRadio) {
				setState(true);
			}
		};
		var onSelectHandler = function (index : Int) : Void {
			for (i in 0...stateChooser.length) {
				stateChooser[i](i == index);
			}
			currentRadio = index;
			if (onSelect != null) {
				onSelect(index, entries[index].value);
			}
		}

		var selFn = function(i) : Bool -> Void {
			return function (b) { onSelectHandler(i); };
		}
		var toggleButtons : Array<ArcticBlock> = [];
		var i = 0;
		for (entry in entries) {
			toggleButtons.push(ToggleButton(entry.selected, entry.unselected, false, selFn(i), onInit));
			++i;
		}
		return { blocks:toggleButtons, selectFn : onSelectHandler };
	}

	static public function wrapWithDefaultFont(text : String, ?size : Float, ?color : String, ?font : String) : String {
		return "<font face='" + (if (font == null) defaultFont else font) + "'" + (if (size != null) { " size='" + size + "'"; } else "" ) + 
			   (if (color != null) { " color='" + color + "'"; } else "" ) + ">" + text + "</font>";
	}
}
