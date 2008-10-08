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

	/// For controlling text: Should it be advanced rendered?
	static public var textSharpness : Null<Float> = null;
	static public var textGridFit = 0;

	/// For redirecting all net requests
	static public var baseurl = "";

	/// Make a text using the given parameters. Default color is black. If font is omitted, the default font is used
	static public function makeText(text : String, ?size : Float, ?color : String, ?font : String, ?isEmbedded : Bool, ?wordWrap : Null<Bool>, ?selectable: Null<Bool>) {
		return Text(wrapWithDefaultFont(text, size, color, font), if (isEmbedded == null) isDefaultFontEmbedded else isEmbedded, wordWrap, selectable);
	}
	
	/// A text button
	static public function makeSimpleButton(text : String, onClick : Void -> Void, ?fontsize : Float) : ArcticBlock {
		var t = Border(10, 5, makeText(text, fontsize));
		return Button(t, Background(0xf0f0f0, t, 70.0, if (fontsize != null) fontsize / 4 else 5.0), onClick);
	}
	
	static public function fixSize(width : Float, height : Float, block : ArcticBlock) : ArcticBlock {
		return ConstrainWidth(width, width, ConstrainHeight(height, height, block));
	}
	
	/// This constructs a button which repeatedly triggers the action as long as the mouse is pressed
	static public function makeRepeatingButton(base : ArcticBlock, hover : ArcticBlock, action : Void -> Void, interval : Int) : ArcticBlock {
		#if neko
		var timer : neash.Timer = null;
		#else flash
		var timer : haxe.Timer = null;
		#end
		var ourHandler = function (x : Float, y : Float, down, inside : Bool) {
			var delay = 4;
			if (!down) {
				if (timer != null) {
					timer.stop();
					timer = null;
					if (delay == 4) {
						// Make sure we at least call action once
						action();
					}
				}
				return;
			}
			if (!inside || timer != null) {
				return;
			}
			#if neko
			timer = new neash.Timer(interval);
			#else flash
			timer = new haxe.Timer(interval);
			#end
			timer.run = function() { 
				if (delay == 4) action(); 
				if (delay > 0) delay--; 
				else action(); 
			}
		}
		return Button(base, hover, null, ourHandler);
	}
	
	/**
	 * A helper to construct a switch-block. Notice that the switchFn is NOT valid on return.
	 * It will first be initialized when the view is displayed.
	 */
	static public function makeSwitch(blocks : Array<ArcticBlock>, ?initial : Int) : { block : ArcticBlock, switchFn : Int -> Void } {
		var result = {
			block : null,
			switchFn : null
		};
		var getSwitchFn = function (fn) { result.switchFn = fn; };
		result.block = Switch( blocks, if (initial != null) initial else 0, getSwitchFn);
		return result;
	}
	
	/// Make a button with a pressed state
	static public function makePressButton(normal : ArcticBlock, hover : ArcticBlock, pressed : ArcticBlock, onClick : Void -> Void) : ArcticBlock {
		var switchFn : Int -> Void;
		var captureSwitchFn : ( Int -> Void ) -> Void = function ( fn : Int -> Void) : Void {
			switchFn = fn;
		}
		var advancedHandler = function(x : Float, y : Float, pressed : Bool, inside : Bool) : Void {
			switchFn(pressed ? 1 : 0);
		}
		return Button( normal, Switch( [ hover, pressed ], 0, captureSwitchFn), onClick, advancedHandler);
	}
	
	/// Associate a tooltip with a block - with an optional forced width for long tooltips that need word wrapping
	static public function makeTooltip(block : ArcticBlock, text : String, ?width : Float) : ArcticBlock {
		var t;
		if (width != null) {
			t = ConstrainWidth(-width, width, makeText(text, null, null, null, null, true));
		} else {
			t = makeText(text);
		}
		return Cursor(block, Offset(-30, -20, Background(0xFFFCA9, Border(5, 5, t), 100, 3)), true);
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
	 * This will *not* trigger a call to any supplied onDrag function.
	 */
	static public function makeDragable(stayWithinBlock : Bool, sideMotionAllowed : Bool, upDownMotionAllowed : Bool, 
					block : ArcticBlock, ?onDrag : DragInfo -> Void, ?initialXOffset : Float, ?initialYOffset : Float, ?onStopDrag: Void -> Void) {
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
			block: Dragable(stayWithinBlock, sideMotionAllowed, upDownMotionAllowed, block, ourOnDrag, ourOnInit, onStopDrag),
			setPositionFn: setPositionFn
		};
	}

	/**
	 * Make a slider with it's own coordinate system. The call-back gives results in slider coordinates
	 * Compared to a dragable, this component preserves the relative position of the handle after resizes.
	 * This is suitable for normal sliders, but can also be used for making dragable dialogs.
	 * You can change the position of the handle by calling the returned setPositionFn. This will *not*
	 * trigger a call to any supplied onDrag function.
	 * The last parameter, useClickHandler, defines whether clicks outside the handle should move the slider.
	 * The default is true.
	 */
	static public function makeSlider(minimumX : Float, maximumX : Float, minimumY : Float, maximumY : Float, handleBlock : ArcticBlock,
							onDrag : Float -> Float -> Void, ?initialX : Float, ?initialY : Float, ?useClickHandler : Bool) {
		// The current position in slider coordinate system
		var currentX = if (initialX == null) minimumX else initialX;
		var currentY = if (initialY == null) minimumY else initialY;
		
		/// When onInit is called on construction time, we capture the DragInfo and move function in this local variable...
		var moverInfo : { di: DragInfo, setPositionFn : Float -> Float -> Void };

		/// Converts current slider coordinates to pixel coordinates
		var convertToPixels = function () : { x : Float, y : Float } {
			var result = {
				x : 0.0,
				y : 0.0
			};
			if (minimumX != maximumX) {
				result.x = (currentX - minimumX) / (maximumX - minimumX) * moverInfo.di.totalWidth;
			}
			if (minimumY != maximumY) {
				result.y = (currentY - minimumY) / (maximumY - minimumY) * moverInfo.di.totalHeight;
			}
			return result;
		}
		
		/// Called when the slider is physically constructed with metrics info and a function to move the slider
		var ourOnInit = function (di : DragInfo, onDragFun) {
			moverInfo = { di: di, setPositionFn : onDragFun };
			var pixels = convertToPixels();
			onDragFun(pixels.x, pixels.y);
		};

		/// This function can move the slider
		var setPositionFn = function (x : Float, y : Float) : Void {
			// Update position in slider coordinate system
			currentX = Math.min(maximumX, Math.max(minimumX, x));
			currentY = Math.min(maximumY, Math.max(minimumY, y));
			var pixels = convertToPixels();
			moverInfo.setPositionFn(pixels.x, pixels.y);
		}
		
		var ourOnDrag = function (di : DragInfo) : Void {
			if (minimumX != maximumX) {
				currentX = di.x / di.totalWidth * (maximumX - minimumX) + minimumX;
			}
			if (minimumY != maximumY) {
				currentY = di.y / di.totalHeight * (maximumY - minimumY) + minimumY;
			}
			if (onDrag != null) {
				onDrag(currentX, currentY);
			}
		}
		
		var clickHandler = null;
		if (useClickHandler != false) {
			clickHandler = function (x, y, up, hit) {
				if (!up) {
					return;
				}
				var di = moverInfo.di;
				if (x < 0.0 || x > di.width + di.totalWidth || y < 0.0 || y > di.height + di.totalHeight) {
					return;
				}
				var pixels = convertToPixels();
				var w = di.width / di.totalWidth * (maximumX - minimumX);
				var h = di.height / di.totalHeight * (maximumY - minimumY);
				var move = false;
				if (x < pixels.x) {
					currentX -= w;
					move = true;
				} else if ((pixels.x + di.width) < x) {
					currentX += w;
					move = true;
				}
				if (y < pixels.y) {
					currentY -= h;
					move = true;
				} else if ((pixels.y + di.height) < y) {
					currentY += h;
					move = true;
				}
				if (move) {
					setPositionFn(currentX, currentY);
					if (onDrag != null) {
						onDrag(currentX, currentY);
					}
				}
			}
		}
		
		var block = OnTop(
			Button( Background(0x000000, Fixed(0,0)), Background(0x000000, Fixed(0,0)), null, clickHandler),
			Dragable(true, minimumX != maximumX, minimumY != maximumY, handleBlock, ourOnDrag, ourOnInit)
		);
		return { 
			block: block, 
			setPositionFn : setPositionFn 
		};
	}

	/**
	 * Add a check-box in front on the given block. 
	 * You can change the state of the check box like this:
	 *   var myCheckbox = makeCheckbox(Text("Test"));
	 *   ...
	 *   // construct view with myCheckbox.block somewhere
	 *   ...
	 * 
	 *   // Change state of check box
	 *   myCheckbox.state = true;
	 * Notice that the boxes in front of the text are fairly slow to draw on the screen!
	 */
	static public function makeCheckbox(block : ArcticBlock, ?onCheck : Bool -> Void, ?defaultSelected : Bool) : ArcticState<Bool> {
		
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
		return checkBox;
	}
	
	/**
	* Make a radio-group to choose between the given texts.
	* Returns the final block and a function that can be used to change the currently selected item.
	*/
	static public function makeTextChoice(texts : Array<String>, onSelect : Int -> String -> Void, ?defaultSelected : Int, ?textSize: Float) : 
			{ block: ArcticBlock, selectFn: Int -> Void } {
		var group = makeTextChoiceBlocks(texts, onSelect, defaultSelected, textSize);
		return { block: LineStack(group.blocks), selectFn : group.selectFn };
	}
	
	/**
	 * Make a radio-group to choose between the given texts.
	 * Returns the array of blocks and a function that can be used to change the currently selected item.
	 * Caller's problem to arrange the layout of blocks - see makeTextChoice above for an example.
	 * Notice that the circles are fairly slow to draw on the screen!
	 */
	static public function makeTextChoiceBlocks(texts : Array<String>, onSelect : Int -> String -> Void, ?defaultSelected : Int, ?textSize: Float) : 
		{ blocks: Array<ArcticBlock>, selectFn: Int -> Void } {
			
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
		
		return { blocks: group.blocks, selectFn: group.selectFn }
	}
	
	/**
	 * Make a radio-group to choose between the given blocks.
	 * Returns an array of coupled blocks, and a function which can be used to change the
	 * current selected item.
	 * Notice that the circles are fairly slow to draw on the screen!
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
	#if flash9
	static public function makeAutoCompleteInput(html : String, autos:Array < String > , width : Null < Float > , height : Null < Float > , ?validator : String -> Bool, ?style : Dynamic, ?maxChars : Null < Int > , ?numeric : Null < Bool > , ?bgColor : Null < Int > , ?focus : Null < Bool > , ?embeddedFont : Null < Bool > , ?onInit : (TextInputModel -> TextInputModel) -> Void, ?onInitEvents: (TextInputEvents -> Void) -> Void) {
		var autoCompleteBlock = new MutableBlock(Fixed(0, 0));
		var contentFn :	TextInputModel->TextInputModel = null;
				
		//content iface getter
		var myonInit = function (contentIface : TextInputModel->TextInputModel) {
			contentFn = contentIface;
		}
		
		//events iface getter
		var myonInitEvents = function (eventIface: TextInputEvents->Void) {
			var onTextChanged = function (notify:Dynamic, text:String) {
				text = StringTools.trim(text);
				var variants:Array<String> = [];
				if (text.length > 0) {
					for (w in autos) {
						if (w.length >= text.length && w.substr(0, text.length) == text) {
							variants.push(w);
						}
					}
				}
				if (variants.length <= 1) {
					autoCompleteBlock.block = Fixed(0, 0);
				}
				else {
					var buttonArr = [];
					var buttonHeight = 20;
					var makeACButton = function (w:String):ArcticBlock {
						return 
						Button(
							ConstrainHeight(buttonHeight, buttonHeight, Border(5, 0, Text(w))),
							ConstrainHeight(buttonHeight, buttonHeight, Border(5, 0, Text(w))),
							function () {
								if (contentFn != null) {
									var ti:TextInputModel = {
										html: w,
										text: w,
										focus: true,
										selStart: text.length,
										selEnd: w.length,
										cursorPos: text.length,
										disabled: false
									}
									contentFn(ti);
									if (notify != null)
										notify(w);
								}
							}
						);
					}
					
					for (w in variants) {
						buttonArr.push([makeACButton(w)]);
					}
					
					autoCompleteBlock.block = Offset(0, -buttonArr.length*buttonHeight, Background(0xffffff, Grid(buttonArr, null, null, null, 1, 0x8b8b8b)));
				}
			}
			
			var eventListeners = {
				onChange: function() { if (contentFn != null) onTextChanged(callback(onTextChanged, null), contentFn(null).text); },
				onSetFocus: null,
				onKillFocus: null,
				onPress: null,
				onRelease: null
			}
			eventIface(eventListeners);
		}
		
		var makeproxy = function  (a, b, c) { 
			if (a != null) 
				a(c); 
			if (b != null) 
				b(c);
		}
		
		var makeproxyEvents = function  (a, b, c) { 
			if (a != null) 
				a(c); 
			if (b != null) 
				b(c);
		}
		
		return 
		OnTopView(
				TextInput(html, width, height, validator, style, maxChars, numeric, bgColor, focus, embeddedFont, callback(makeproxy, myonInit, onInit), callback(makeproxyEvents, myonInitEvents, onInitEvents)),
				Mutable(autoCompleteBlock)
			);
	}
	#end
	

	static public function wrapWithDefaultFont(text : String, ?size : Float, ?color : String, ?font : String) : String {
		return "<font face='" + (if (font == null) defaultFont else font) + "'" + (if (size != null) { " size='" + size + "'"; } else "" ) + 
			   (if (color != null) { " color='" + color + "'"; } else "" ) + ">" + text + "</font>";
	}
}
