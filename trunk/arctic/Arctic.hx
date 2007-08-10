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
	static public function makeText(text : String, ?size : Float, ?color : String, ?font : String, ?isEmbedded : Bool, ?wordWrap : Bool) {
		return Text(wrapWithDefaultFont(text, size, color, font), if (isEmbedded == null) isDefaultFontEmbedded else isEmbedded, wordWrap);
	}
	
	/// A text button
	static public function makeSimpleButton(text : String, onClick : Void -> Void, ?fontsize : Float) : ArcticBlock {
		var t = Border(10, 5, makeText(text, fontsize));
		return Button(t, Background(0xf0f0f0, t, 70.0, if (fontsize != null) fontsize / 4 else 5.0), onClick);
	}
	
	/// Associate a tooltip with a block
	static public function makeTooltip(block : ArcticBlock, text : String) : ArcticBlock {
		return Cursor(block, Offset(-30, -20, Background(0xFFFCA9, Border(5, 5, makeText(text)), 100, 3)), true);
	}

	/// A block which looks like a page in a tear-off calendar on the given date
	static public function makeDateView(date : Date, ?background : Int) : ArcticBlock {
		var months = [ "January", "February", "March", "April", "May", "June", "July", "August", "September", "October", "November", "December" ];
		var days = [ "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday" ];
		var day = days[Math.floor(3 + date.getTime() / (1000 * 60 * 60 * 24)) % 7];
		var text = "<font color='#ffffff' face='" + defaultFont + "'><p align='center'><b>" + months[date.getMonth()]
				+ "</b><br><p align='center'><b><font size='32'>" + date.getDate() + "</font></b>"
				+ "<br><p align='center'><b>" + day + "</b></font>";
		return Background(if (background == null) 0x3B4C77 else background, ConstrainWidth(75, 75, ConstrainHeight(75, 75, 
			LineStack([ 
				Filler,
				ColumnStack([Filler,Text(text, isDefaultFontEmbedded), Filler]),
				Filler ]
			))), 100, 5);
	}
	
	/**
	 * Make a block dragable by the mouse in the given directions.
	 * If stayWithinBlock is true, the movement is constrained to the available area
	 * of the block (and this block becomes size greedy in the directions we allow motion in).
	 * onDrag is called whenever we drag, telling the total X and Y offsets.
	 * You can change the position of the dragable by calling the returned setPositionFn.
	 */
	static public function makeDragable(stayWithinBlock : Bool, sideMotionAllowed : Bool, upDownMotionAllowed : Bool, 
					block : ArcticBlock, ?onDrag : DragInfo -> Void, ?initialXOffset : Float, ?initialYOffset : Float,
					?mouseWheel : Bool) {
		// Local closured variables to remember drag offset
		var dragX = if (initialXOffset == null || !sideMotionAllowed) 0.0 else initialXOffset;
		var dragY = if (initialYOffset == null || !upDownMotionAllowed) 0.0 else initialYOffset;
		// When onInit is called on construction time, we capture the DragInfo and move function in this local variable...
		var dragInfo : { di : DragInfo, setPositionFn : Float -> Float -> Void };
		var ourOnInit = function (di : DragInfo, onDragFun) {
			dragInfo = { di: di, setPositionFn: onDragFun };
			onDragFun(dragX, dragY);
		};
		var ourOnDrag = function (di : DragInfo) : Void {
			dragX = di.x;
			dragY = di.y;
			if (onDrag != null) {
				onDrag(di);
			}
		}
		/// ... which is captured in the closure of this function...
		var setPositionFn = function (x, y) { 
			dragX = x; 
			dragY = y; 
			dragInfo.setPositionFn(x, y); 
		}
		return { 
			block: Dragable(stayWithinBlock, sideMotionAllowed, upDownMotionAllowed, block, ourOnDrag, ourOnInit, mouseWheel),
			setPositionFn: setPositionFn
		};
	}

	/**
	 * Make a slider with it's own coordinate system. The call-back gives results in slider coordinates
	 * Compared to a dragable, this component preserves the relative position of the handle after resizes.
	 * This is suitable for normal sliders, but can also be used for making dragable dialogs.
	 */
	static public function makeSlider(minimumX : Float, maximumX : Float, minimumY : Float, maximumY : Float, handleBlock : ArcticBlock,
							onDrag : Float -> Float -> Void, ?initialX : Float, ?initialY : Float, ?mouseWheel : Bool) {
		// The current position in slider coordinate system
		var currentX = if (initialX == null) minimumX else initialX;
		var currentY = if (initialY == null) minimumY else initialY;
		
		/// When onInit is called on construction time, we capture the DragInfo and move function in this local variable...
		var moverInfo;

		var ourOnInit = function (di : DragInfo, onDragFun) {
			moverInfo = { di: di, setPositionFn : onDragFun };
			var currentXPixels = 0.0;
			if (minimumX != maximumX) {
				currentXPixels = (currentX - minimumX) / (maximumX - minimumX) * di.totalWidth;
			}
			var currentYPixels = 0.0;
			if (minimumY != maximumY) {
				currentYPixels = (currentY - minimumY) / (maximumY - minimumY) * di.totalHeight;
			}
			onDragFun(currentXPixels, currentYPixels);
		};

		/// ... which is captured in the closure of this function...
		var setPositionFn = function (x : Float, y : Float) {
			// Update position in slider coordinate system
			currentX = x;
			currentY = y;
			currentX = Math.min(maximumX, Math.max(minimumX, currentX));
			currentY = Math.min(maximumY, Math.max(minimumY, currentY));
			var currentXPixels = 0.0;
			if (minimumX != maximumX) {
				currentXPixels = (currentX - minimumX) / (maximumX - minimumX) * moverInfo.di.totalWidth;
			}
			var currentYPixels = 0.0;
			if (minimumY != maximumY) {
				currentYPixels = (currentY - minimumY) / (maximumY - minimumY) * moverInfo.di.totalHeight;
			}
			moverInfo.setPositionFn(currentXPixels, currentYPixels);
		}
		
		var ourOnDrag = function (di : DragInfo) : Void {
			var x = minimumX;
			if (minimumX != maximumX) {
				x = di.x / di.totalWidth * (maximumX - minimumX) + minimumX;
				currentX = x;
			}
			var y = minimumY;
			if (minimumY != maximumY) {
				y = di.y / di.totalHeight * (maximumY - minimumY) + minimumY;
				currentY = y;
			}
			if (onDrag != null) {
				onDrag(x, y);
			}
		}
		
		return { block: Dragable(true, minimumX != maximumX, minimumY != maximumY, handleBlock, ourOnDrag, ourOnInit, mouseWheel), setPositionFn : setPositionFn };
	}

	/// Add a check-box in front on the given block
	static public function makeCheckbox(block : ArcticBlock, ?onCheck : Bool -> Void, ?defaultSelected : Bool) : ArcticBlock {
		
		// Local closured variables to remember state
		var selected = defaultSelected;
		if (selected == null) {
			selected = false;
		}

		// Callback fn for the CustomBlock to draw Radio button
		var build = function(state : Bool, mode : BuildMode, parentMc : ArcticMovieClip, availableWidth : Float, availableHeight : Float, existingMc : ArcticMovieClip) {
			var size = 12;
			if (mode != Metrics) {
				DrawUtils.drawRectangle(parentMc, (availableWidth - size) / 2.0, (availableHeight - size) / 2.0, size, size, 2, 0x000000, 0xf0f0f0, 0);
				if (state) {
					size -= 4;
					DrawUtils.drawRectangle(parentMc, (availableWidth - size) / 2.0, (availableHeight - size) / 2.0, size, size, 2, 0x000000, 0x000000);
				}
			}
			return { clip: parentMc, width: 13.0, height: 13.0, growWidth : false, growHeight : false };
		}

		var notSelectedBlock = ColumnStack( [ CustomBlock(false, build), block ] );
		var selectedBlock = ColumnStack( [ CustomBlock(true, build), block ] );
				
		var checkBox = new ArcticState(selected, null);
		checkBox.setFunction(function(selected : Bool) {
			if (onCheck != null) {
				onCheck(selected);
			}
			if (selected) {
				return Button(selectedBlock, selectedBlock, function() {
					checkBox.state = false;
				});
			} else {
				return Button(notSelectedBlock, notSelectedBlock, function() {
					checkBox.state = true;
				});
			}
		});
		return checkBox.block;
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
		var build = function(state : Bool, mode : BuildMode, parentMc : ArcticMovieClip, availableWidth : Float, availableHeight : Float, existingMc : ArcticMovieClip) {
			var radius = 6;
			if (mode != Metrics) {
				if (mode == Create) {
					DrawUtils.drawCircle(parentMc, availableWidth/2.0, availableHeight/2.0, radius, 0x000000, 0xf0f0f0, 0);
					if (state) {
						DrawUtils.drawCircle(parentMc, availableWidth/2.0, availableHeight/2.0, radius - 3.0, 0x000000, 0x000000);
					}
				}
			}
			return { clip: parentMc, width: 13.0, height: 13.0, growWidth : false, growHeight : false };
		}
		
		var entries : Array<{ selected: ArcticBlock, unselected: ArcticBlock, value : String }> = [];
		var i = 0;
		for (text in texts) {
			var selected = Border(1, 1, ColumnStack([CustomBlock(true, build),
													 makeText(text, textSize)]));
			var unselected = Border(1, 1, ColumnStack([CustomBlock(false, build),
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
		var onSelectHandler = function (index : Null<Int>) : Void {
			if (index == null) {
				// remove selection
				Lambda.iter(stateChooser, function(f) { f(false); } );
				currentRadio = null;
				return;
			}
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
