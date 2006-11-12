package arctic;

import arctic.ArcticBlock;

#if flash9
import flash.display.MovieClip;
import flash.geom.Rectangle;
import flash.text.TextField;
import flash.text.TextFieldType;
import flash.events.FocusEvent;
#else true
import flash.MovieClip;
import flash.geom.Rectangle;
import flash.TextField;
import flash.TextFormat;
import flash.Mouse;
#end


/**
 * The main class in Arctic which builds a user interface from an ArcticBlock.
 * Construct the ArcticBlock representing your user interface and call
 * display() with a movieclip to construct it.
 */
class ArcticView {

	public function new(gui0 : ArcticBlock) {
		gui = gui0;
		parent = null;
		base = null;
		useStageSize = false;
		updates = new Hash<ArcticBlock>();
	}

	public var gui : ArcticBlock;
	public var parent : MovieClip;
	private var base : MovieClip;
	private var useStageSize : Bool;
    
	/**
	 * Builds the user interface on the movieclip given. If useStageSize is true
	 * the user interface will automatically resize to the size of the stage.
	 */
	public function display(p : MovieClip, useStageSize0 : Bool) : MovieClip {
		useStageSize = useStageSize0;
		if (useStageSize) {
			stageSize(p);
		}
		parent = p;
		refresh();

		if (useStageSize) {
			// Make sure we follow screen resizes
			#if flash9
				p.stage.scaleMode = flash.display.StageScaleMode.NO_SCALE;
				p.stage.align = flash.display.StageAlign.TOP_LEFT;
				var t = this;
				resizeHandler = function( event : flash.events.Event ) { t.onResize();}; 
				p.stage.addEventListener( flash.events.Event.RESIZE, resizeHandler ); 
			#else flash
				flash.Stage.scaleMode = "noScale";
				flash.Stage.addListener(this);
			#end
		}
        return base;
	}

	#if flash9
	private var resizeHandler : Dynamic;
	#end
	
	/**
	 * This removes and destroys the view. You have to use this to clean up
	 * properly.
	 */
	public function destroy() {
		remove();
		gui = null;
		showMouse();
		if (useStageSize) {
			#if flash9
				parent.stage.removeEventListener(flash.events.Event.RESIZE, resizeHandler);
			#else flash
				flash.Stage.removeListener(this);
			#end
		}
	}
	
	public function onResize() {
		if (base != null) {
			remove();
		}
		stageSize(parent);
		refresh();
	}

	public function refresh() {
		if (base != null) {
			remove();
		}
		movieClips = [];
		idMovieClip = new Hash<ArcticMovieClip>();
		showMouse();
		#if flash9
			base = build(gui, parent, parent.width, parent.height);
		#else flash
			base = build(gui, parent, parent._width, parent._height);
		#end
	}

	/**
	 * Use this to change the named block to the new block. You have to
	 * call refresh yourself afterwards to update the screen. See the
	 * dynamic example to see how this is done.
	 */
	public function update(id : String, block : ArcticBlock) {
		updates.set(id, block);
	}
	
	/**
	* Get access to the raw movieclip for the named element.
	* Notice! This movieclip is destroyed on resize, and thus you have to
	* do call this method again to do the special stuff you do again.
	*/
	public function getRawMovieClip(id : String) : ArcticMovieClip {
		return idMovieClip.get(id);
	}
	
	/**
	 * Removes the visual element - notice, however that if usestage is true, the view is reconstructed on resize.
	 * Use destroy() if you want to get rid of this display for good
	 */
	private function remove() {
		if (base == null) {
			return;
		}
		for (m in movieClips) {
			#if flash9
				m.parent.removeChild(m);
			#else flash
				m.removeMovieClip();
			#end
		}
		movieClips = [];
		idMovieClip = new Hash<ArcticMovieClip>();
/*		#if flash9
			parent.removeChild(base);
		#else flash
			base.removeMovieClip();
		#end*/
		base = null;
	}
	
	// We collect all generated movieclips here, so we can be sure to remove all when done
	private var movieClips : Array<ArcticMovieClip>;

	/// We record updates of blocks here.
	private var updates : Hash<ArcticBlock>;
	
	/// And the movieclips for ids here
	private var idMovieClip : Hash<ArcticMovieClip>;
	
    private function build(gui : ArcticBlock, p : MovieClip, 
                    availableWidth : Float, availableHeight : Float) : MovieClip {

//		trace("build " + availableWidth + "," + availableHeight + ": " + gui);
		#if flash9
			var clip = new MovieClip();
			p.addChild(clip);
		#else flash
			var d = p.getNextHighestDepth();
			var clip = p.createEmptyMovieClip("c" + d, d);
		#end
		movieClips.push(clip);
		clip.tabEnabled = false;
		
		switch (gui) {
		case Border(x, y, block):
			if (availableWidth < 2 * x) {
				x = availableWidth / 2;
			}
			if (availableHeight < 2 * y) {
				y = availableHeight / 2;
			}
			var child = build(block, clip, availableWidth - 2 * x, availableHeight - 2 * y);
			var size = getSize(child);
			#if flash9
				child.x = x;
				child.y = y;
			#else flash
				child._x = x;
				child._y = y;
			#end
			setSize(clip, size.width + 2 * x, size.height + 2 * y);
			return clip;

		case Background(color, block, alpha, roundRadius):
			var child = build(block, clip, availableWidth, availableHeight);
			var size = getSize(child);
			#if flash9
				clip.graphics.beginFill(color, if (alpha != null) alpha else 100.0);
				DrawUtils.drawRect(clip, 0, 0, size.width, size.height, roundRadius);
				clip.graphics.endFill();
			#else flash
				clip.beginFill(color, if (alpha != null) alpha else 100.0);
				DrawUtils.drawRect(clip, 0, 0, size.width, size.height, roundRadius);
				clip.endFill();
			#end
			return clip;

		case GradientBackground(type, colors, xOffset, yOffset, block, alpha, roundRadius):
			var child = build(block, clip, availableWidth, availableHeight);
			var size = getSize(child);
			#if flash9
				var matrix = new  flash.geom.Matrix();
				matrix.createGradientBox(size.width, size.height, 0, size.width * xOffset, size.height * yOffset);
				clip.graphics.beginGradientFill(flash.display.GradientType.RADIAL, colors, [100.0, 100.0], [0.0, 255.0], matrix);
				DrawUtils.drawRect(clip, 0, 0, child.width, child.height, roundRadius);
				clip.graphics.endFill();
			#else flash
				var matrix = {	a:size.width, b:0, c:0, 
								d:0, e:size.height, f: 0, 
								g:size.width * xOffset, h:size.height * yOffset, i:0}; // Center
				clip.beginGradientFill(type, colors, [100.0, 100.0], [0.0, 255.0], matrix);
				DrawUtils.drawRect(clip, 0, 0, size.width, size.height, roundRadius);
				clip.endFill();
			#end
			return clip;

		case Text(html):
			#if flash9
				var tf = new flash.text.TextField();
				tf.autoSize = flash.text.TextFieldAutoSize.LEFT;
				tf.selectable = false;
				tf.multiline = true;
				tf.htmlText = html;
				clip.addChild(tf);
			#else flash
				var tf = clip.createTextField("tf", clip.getNextHighestDepth(), 0, 0, 100, 100);
				tf.autoSize = true;
				tf.html = true;
				tf.selectable = false;
				tf.multiline = true;
				tf.htmlText = html;
			#end
			return clip;

		case TextInput(html, width, height, validator, maxChars, numeric, bgColor) :
			#if flash9
				var txtInput = new flash.text.TextField();
				txtInput.width = width;
				txtInput.height = height;
			#else flash
				var txtInput = clip.createTextField("ti", clip.getNextHighestDepth(), 0, 0, width, height);
				txtInput.html = true;
			#end
				txtInput.tabEnabled = true;
				setSize(clip, width, height);
				if (null != maxChars) {
					txtInput.maxChars = maxChars;
				}
				if (null != bgColor) {
					txtInput.background = true;
					txtInput.backgroundColor = bgColor;
				}
				txtInput.border = true;
				var validate = function() {
					if (validator == null) {
						return;
					}
					var isValid = validator(txtInput.text);
					if (isValid) {
						txtInput.background = (null != bgColor);
						if (txtInput.background) {
							txtInput.backgroundColor = bgColor;
						}
					} else {
						txtInput.background = true;
						txtInput.backgroundColor = 0xff0000;
					}
				}
				txtInput.htmlText = html;
				// Retreive the format of the initial text
				var txtFormat = txtInput.getTextFormat();
				if (null != numeric && numeric) {
					txtInput.restrict = "0-9";
					txtFormat.align = "right";
				}
			#if flash9
				txtInput.defaultTextFormat = txtFormat;
				// Set the text again to enforce the formatting
				txtInput.htmlText = html;
				var listener = function (e:FocusEvent) { validate(); };
				txtInput.addEventListener(FocusEvent.FOCUS_OUT , listener);
				txtInput.type = TextFieldType.INPUT;
				clip.addChild(txtInput);
			#else flash
				txtInput.setNewTextFormat(txtFormat);
				// Set the text again to enforce the formatting
				txtInput.htmlText = html;
				var listener = {
					// TODO : Don't know why 'onKillFocus' event is not working.  'onChanged' will be annoying.
					onChanged : function (txtFld : TextField) {	validate();	}
				};
				txtInput.addListener(listener);
				txtInput.type = "input";
			#end
			return clip;

		case Picture(url, w, h, scaling):
			#if flash9
				var loader = new flash.display.Loader();
				var request = new flash.net.URLRequest(url);
				loader.load(request);
				clip.addChild(loader);
				var s = scaling;
				clip.scaleX = s;
				clip.scaleY = s;
			#else flash
				var loader = new flash.MovieClipLoader();
				loader.loadClip(url, clip);
				var s = scaling * 100.0;
				clip._xscale = s;
				clip._yscale = s;
			#end
			setSize(clip, w / scaling, h / scaling);
			return clip;

		case Button(block, hover, action):
				var child = build(block, clip, availableWidth, availableHeight);
				var hover = build(hover, clip, availableWidth, availableHeight);
			#if flash9
				child.buttonMode = true;
				child.mouseChildren = false;
				hover.buttonMode = true;
				hover.mouseChildren = false;
				hover.visible = false;
				clip.addEventListener( flash.events.MouseEvent.MOUSE_UP, function (s) { if (action != null) action(); } ); 
				clip.addEventListener( flash.events.MouseEvent.MOUSE_OVER, 
					function (s) {
						child.visible = false;
						hover.visible = true;
					}
				);
				clip.addEventListener( flash.events.MouseEvent.MOUSE_OUT, 
					function (s) { 
						child.visible = true;
						hover.visible = false;
					}
				);
			#else flash
				hover._visible = false;
				clip.onRelease = action;
				clip.onMouseMove = function() {
					var mouseInside = clip.hitTest(flash.Lib.current._xmouse, flash.Lib.current._ymouse, false);
					if (mouseInside) {
						child._visible = false;
						hover._visible = true;
					} else {
						child._visible = true;
						hover._visible = false;
					}
				};
			#end
			return clip;

		case ToggleButton(selected, unselected, initialState, onChange, onInit):
				var sel = build(selected, clip, availableWidth, availableHeight);
				var unsel = build(unselected, clip, availableWidth, availableHeight);
			#if flash9
				unsel.buttonMode = true;
				unsel.mouseChildren = false;
				sel.buttonMode = true;
				sel.mouseChildren = false;
				sel.visible = initialState;
				unsel.visible = !initialState;
				var setState = function (newState : Bool) { sel.visible = newState; unsel.visible = !newState; }; 
				if (null != onInit) {
					onInit(setState);
				}
				clip.addEventListener(flash.events.MouseEvent.MOUSE_UP, function(s) {
						if (null != onChange) {
							setState(!sel.visible);
							onChange(sel.visible);
						}
					});
			#else flash
				sel._visible = initialState;
				unsel._visible = !initialState;
				var setState = function (newState : Bool) { sel._visible = newState; unsel._visible = !newState; }; 
				if (null != onInit) {
					onInit(setState);
				}
				clip.onPress = function() {
					if (null != onChange) {
						setState(!sel._visible);
						onChange(sel._visible);
					}
				};
			#end
			return clip;

		case Filler:
			setSize(clip, availableWidth, availableHeight);
			return clip;

        case ConstrainWidth(minimumWidth, maximumWidth, block) :
            var child = build(block, clip, Math.max( minimumWidth, Math.min(availableWidth, maximumWidth) ), availableHeight);
			var size = getSize(child);
			if (size.width < minimumWidth) {
				setSize(clip, minimumWidth, size.height);
			}
			if (size.width > maximumWidth) {
				clipSize(clip, maximumWidth, size.height);
			}
            return clip;

        case ConstrainHeight(minimumHeight, maximumHeight, block) :
			var child = build(block, clip, availableWidth, Math.max( minimumHeight, Math.min(availableHeight, maximumHeight) ) );
			var size = getSize(child);
			if (size.height < minimumHeight) {
				setSize(clip, size.width, minimumHeight);
			}
			if (size.height > maximumHeight) {
				clipSize(clip, size.width, maximumHeight);
			}
            return clip;

		case ColumnStack(blocks):
			// The number of children which wants to grow (including our own fillers)
			var numberOfWideChildren = 0;
			var childMetrics = [];
			var width = 0.0;
			for (r in blocks) {
				var m = calcMetrics(r);
				childMetrics.push(m);
				if (m.growWidth) {
					numberOfWideChildren++;
				}
				width += m.width;
			}

			// Next, determine how much space children get
            var freeSpace = availableWidth - width;
			if (freeSpace < 0) {
				// Hmm, we should do a scrollbar instead
				freeSpace = 0;
			}
			if (numberOfWideChildren > 0) {
				freeSpace = freeSpace / numberOfWideChildren;
			} else {
				freeSpace = 0;
			}

			var x = 0.0;
			var i = 0;
            var children = [];
			for (l in blocks) {
				var w = childMetrics[i].width + if (childMetrics[i].growWidth) freeSpace else 0;
                var child = build(l, clip, w, availableHeight);
				#if flash9
					child.x = x;
				#else flash
					child._x = x;
				#end
                children.push(child);				
				x += w;
   				++i;
			}
			
			return clip;

		case LineStack(blocks, ensureVisibleIndex):
			#if flash9
				var child = new MovieClip();
				clip.addChild(child);
			#else flash
				var d = clip.getNextHighestDepth();
				var child = clip.createEmptyMovieClip("c" + d, d);
			#end
			movieClips.push(child);
			child.tabEnabled = false;

			// The number of children which wants to grow (including our own fillers)
			var numberOfTallChildren = 0;
			var childMetrics = [];
			var height = 0.0;
			var growChildrensHeight = 0.0;  // How high are the children that grow?
			for (r in blocks) {
				var m = calcMetrics(r);
				childMetrics.push(m);
				if (m.growHeight) {
					numberOfTallChildren++;
					growChildrensHeight += m.height;
				}
				height += m.height;
			}

			// Next, determine how much space children get
            var freeSpace = availableHeight - height;
			if (freeSpace < 0) {
				// Hm, there is not enough room. 
				// We need to see if the free children can absorb it
				if (-freeSpace > growChildrensHeight) {
					// We need to add a scrollbar ourselves so make room for it
					availableWidth -= 12;
				}
			}
			var freeSpacePerChild = 0.0;
			if (numberOfTallChildren > 0) {
				freeSpacePerChild = freeSpace / numberOfTallChildren;
			}

			var ensureY = 0.0;
			var y = 0.0;
			var i = 0;
            var children = [];
			for (l in blocks) {
				var h = childMetrics[i].height + if (childMetrics[i].growHeight) freeSpacePerChild else 0;
				h = Math.max(0, h);
                var line = build(l, child, availableWidth, h);
				#if flash9
					line.y = y;
				#else flash
					line._y = y;
				#end
				if (i == ensureVisibleIndex) {
					ensureY = y;
				}
                children.push(line);				
				y += h;
   				++i;
			}
			
			if (freeSpace < 0) {
				if (-freeSpace > growChildrensHeight) {
					availableWidth += 12;
					var size = getSize(child);
					// Scrollbar
					#if flash9
						Scrollbar.drawScrollBar(clip, child, availableWidth, availableHeight, ensureY);
					#else flash
						Scrollbar.drawScrollBar(clip, child, availableWidth, availableHeight, ensureY);
					#end
				}
			}
			return clip;
		
		case ScrollBar(block, availableWidth, availableHeight):
            var child = build(block, clip, availableWidth, availableHeight);            
            Scrollbar.drawScrollBar(clip, child, availableWidth, availableHeight, 0);
            return clip;

		case Dragable(stayWithin, sideMotion, upDownMotion, block, onDrag, onInit):
			var totalDx = 0.0;
			var totalDy = 0.0;
            var child = build(block, clip, availableWidth, availableHeight);
			var childSize = getSize(child);
			if (stayWithin) {
				setSize(clip, availableWidth, availableHeight);
			}
			
			var setOffset = function (dx : Float, dy : Float) {
				if (stayWithin) {
					dx = Math.min(availableWidth - childSize.width, dx);
					dy = Math.min(availableHeight - childSize.height, dy);
				}
				moveClip(child, dx, dy);
				totalDx = dx;
				totalDy = dy;
			}; 
			var dragX = -1.0;
			var dragY = -1.0;
			
			var doDrag = function (dx : Float, dy : Float) {
				if (!sideMotion) {
					dx = 0;
				}
				if (!upDownMotion) {
					dy = 0;
				}
				var motion = false;
					if (sideMotion) {
						while (Math.abs(dx) > 0) {
							var newTotalDx = totalDx + dx;
							if (!stayWithin || (newTotalDx >= 0 && newTotalDx <= availableWidth - childSize.width)) {
								moveClip(child, dx, 0);
								totalDx = newTotalDx;
								motion = true;
								break;
							}
							// We just try a smaller drag
							if (dx > 0) {
								dx--;
							} else {
								dx++;
							}
						}
					}
					if (upDownMotion) {
						while (Math.abs(dy) > 0) {
							var newTotalDy = totalDy + dy;
							if (!stayWithin || (newTotalDy >= 0 && newTotalDy <= availableHeight - childSize.height)) {
								moveClip(child, 0, dy);
								totalDy = newTotalDy;
								motion = true;
								break;
							}
							// We just try a smaller drag
							if (dy > 0) {
								dy--;
							} else {
								dy++;
							}
						}
					}
					if (motion) {
						if (onDrag != null) {
							onDrag(totalDx, totalDy);
						}
					}
			}
			
			#if flash9
				var firstTime = true;
				var mouseMove = function(s) {
					if (!clip.visible) {
						return;
					}
					var dx = clip.stage.mouseX - dragX;
					var dy = clip.stage.mouseY - dragY;
					doDrag(dx, dy);
					dragX = clip.stage.mouseX;
					dragY = clip.stage.mouseY;
				}
				var mouseUp = 
					function(s) {
						if (dragX == -1) {
							return;
						}
						clip.stage.removeEventListener( flash.events.MouseEvent.MOUSE_MOVE, mouseMove );
						dragX = -1;
						dragY = -1;
					};
				clip.addEventListener( flash.events.MouseEvent.MOUSE_DOWN, 
					function (s) { 
						if (child.hitTestPoint(flash.Lib.current.mouseX, flash.Lib.current.mouseY, true)) {
							dragX = clip.stage.mouseX;
							dragY = clip.stage.mouseY;
							
							clip.stage.addEventListener( flash.events.MouseEvent.MOUSE_MOVE, mouseMove );
							if (firstTime) {
								clip.stage.addEventListener( flash.events.MouseEvent.MOUSE_UP, mouseUp );
								firstTime = false;
							}
						}
					}
				);
				// Ideally, it should be on the parent, but limited to the area relevant
				// (except for dragables that should not stay within where we probably do 
				// not want mouse wheel events to move anything)
				clip.addEventListener( flash.events.MouseEvent.MOUSE_WHEEL,
					function (s) {
						if (upDownMotion) {
							doDrag(0, -10 * s.delta);
						} else if (sideMotion) {
							doDrag(-10 * s.delta, 0);
						}
					}
				);
			#else flash
				clip.onMouseDown = function() {
					if (child.hitTest(flash.Lib.current._xmouse, flash.Lib.current._ymouse)) {
						dragX = flash.Lib.current._xmouse;
						dragY = flash.Lib.current._ymouse;
						if (clip.onMouseMove == null) {
							clip.onMouseMove = function() {
								if (!clip._visible) {
									return;
								}
								var dx = flash.Lib.current._xmouse - dragX;
								var dy = flash.Lib.current._ymouse - dragY;
								doDrag(dx, dy);
								dragX = flash.Lib.current._xmouse;
								dragY = flash.Lib.current._ymouse;
							};
						}
						if (clip.onMouseUp == null) {
							clip.onMouseUp = function() {
								clip.onMouseMove = null;
								clip.onMouseUp = null;
							};
						}
					}
				};
				var mouseWheelListener = { 
					onMouseDown : function() {},
					onMouseMove : function() {},
					onMouseUp : function() {},
					onMouseWheel : function ( delta : Float, target ) {
						if (child.hitTest(flash.Lib.current._xmouse, flash.Lib.current._ymouse)) {
							if (upDownMotion) {
								doDrag(0, -10 * delta);
							} else if (sideMotion) {
								doDrag(-10 * delta, 0);
							}
						}
					}
				};
				// TODO: We should remove this one again when the clip dies -
				flash.Mouse.addListener(mouseWheelListener);
				
			#end

			if (null != onInit) {
				onInit(setOffset);
			}
			return clip;
		
		case Cursor(block, cursor, keepNormalCursor) :
			var child = build(block, clip, availableWidth, availableHeight);
			var cursorMc = build(cursor, clip, 0, 0);
			var keep = if (keepNormalCursor == null) true else keepNormalCursor;
			#if flash9
			cursorMc.visible = child.hitTestPoint(flash.Lib.current.mouseX, flash.Lib.current.mouseY, true);
			clip.stage.addEventListener( flash.events.MouseEvent.MOUSE_MOVE, 
				function (s) {
					if (child.hitTestPoint(flash.Lib.current.mouseX, flash.Lib.current.mouseY, true)) {
						cursorMc.visible = true;
						cursorMc.x = clip.mouseX;
						cursorMc.y = clip.mouseY;
						showMouse(keep);
						return;
					} else {
						cursorMc.visible = false;
						showMouse();
					}
				}
			);
			#else flash
			cursorMc._visible = child.hitTest(flash.Lib.current._xmouse, flash.Lib.current._ymouse);

			if (clip.onMouseMove == null) {
				clip.onMouseMove = function() {
					if (child.hitTest(flash.Lib.current._xmouse, flash.Lib.current._ymouse)) {
						cursorMc._visible = true;
						cursorMc._x = clip._xmouse;
						cursorMc._y = clip._ymouse;
						showMouse(keep);
						return;
					} else {
						cursorMc._visible = false;
						showMouse();
					}
				};
			}
			#end
			
			return clip;

		case Offset(dx, dy, block) :
			var child = build(block, clip, availableWidth, availableHeight);
			moveClip(child, dx, dy);
			return clip;
			
		case OnTop(base, overlay) :
			var child = build(base, clip, availableWidth, availableHeight);
			var over = build(overlay, clip, availableWidth, availableHeight);
			return clip;
		 
		case Id(id, block) :
			if (updates.exists(id)) {
				var child = build(updates.get(id), clip, availableWidth, availableHeight);
				idMovieClip.set(id, child);
				return clip;
			}
			var child = build(block, clip, availableWidth, availableHeight);
			idMovieClip.set(id, child);
			return clip;

		case CustomBlock(data, calcMetricsFun, buildFun):
			return buildFun(data, clip, availableWidth, availableHeight);
		}
		
		return clip;
	}

	private function calcMetrics(c : ArcticBlock) : Metrics {
		var m = doCalcMetrics(c);
//		trace(m.width + "," + m.height + " " + m.growWidth + "," + m.growHeight + ":" + c);
		return m;
	}
	
	private function doCalcMetrics(c) {
		switch (c) {
		case Border(x, y, block):
			var m = calcMetrics(block);
			m.width += 2 * x;
			m.height += 2 * y;
			return m;
		case Background(color, block, alpha, roundRadius):
			return calcMetrics(block);
		case GradientBackground(type, colors, xOffset, yOffset, block, alpha, roundRadius):
			return calcMetrics(block);
		case Text(html):
			// Fall-through to creation
		case Picture(url, w, h, scaling):
			return { width : w, height : h, growWidth : false, growHeight : false };
		case Button(block, hover, action):
			return calcMetrics(block);
		case ToggleButton(selected, unselected, initialState, onChange, onInit):
			return calcMetrics(selected);
		case Filler:
			return { width : 0.0, height : 0.0, growWidth : true, growHeight : true };
        case ConstrainWidth(minimumWidth, maximumWidth, block) :
			var m = calcMetrics(block);
			m.width = Math.min(minimumWidth, Math.max(maximumWidth, m.width));
			m.growWidth = false;
			return m;
        case ConstrainHeight(minimumHeight, maximumHeight, block) :
			var m = calcMetrics(block);
			m.height = Math.min(minimumHeight, Math.max(maximumHeight, m.height));
			m.growHeight = false;
			return m;
		case TextInput(html, width, height, validator, maxChars, numeric, bgColor):
			return { width : width, height : height, growWidth : false, growHeight : false };
		case ColumnStack(columns):
			var m = { width : 0.0, height : 0.0, growWidth : false, growHeight : false };
			for (c in columns) {
				var cm = calcMetrics(c);
				m.width += cm.width;
				m.height = Math.max(cm.height, m.height);
				m.growWidth = m.growWidth || cm.growWidth;
				// A filler in should not impact height growth in this situation
				if (c != Filler) {
					m.growHeight = m.growHeight || cm.growHeight;
				}
			}
			return m;
		case LineStack(blocks, ensureVisibleIndex):
			var m = { width : 0.0, height : 0.0, growWidth : false, growHeight : false };
			for (c in blocks) {
				var cm = calcMetrics(c);
				m.width = Math.max(cm.width, m.width);
				m.height += cm.height;
				// A filler in should not impact width growth in this situation
				if (c != Filler) {
					m.growWidth = m.growWidth || cm.growWidth;
				}
				m.growHeight = m.growHeight || cm.growHeight;
			}
			return m;
	    case ScrollBar(block, availableWidth, availableHeight):
			var cm = calcMetrics(block);
			if (cm.height > availableHeight) {
				cm.height = availableHeight;
			}
			return cm;
		case Dragable(stayWithin, sideMotion, upDownMotion, block, onDrag, onInit):
			var m = calcMetrics(block);
			if (stayWithin) {
				if (sideMotion) {
					m.growWidth = true;
				}
				if (upDownMotion) {
					m.growHeight = true;
				}
			}
			return m;
		case Cursor(block, cursor, keepNormalCursor) :
			return calcMetrics(block);
		case Offset(dx, dy, block):
			return calcMetrics(block);
		case OnTop(base, overlay) :
			var m1 = calcMetrics(base);
			var m2 = calcMetrics(overlay);
			m1.width = Math.max(m1.width, m2.width);
			m1.height = Math.max(m1.height, m2.height);
			m1.growWidth = m1.growWidth || m2.growWidth;
			m1.growHeight = m1.growHeight || m2.growHeight;
			return m1;
		case Id(id, block) :
			if (updates.exists(id)) {
				return calcMetrics(updates.get(id));
			}
			return calcMetrics(block);
		case CustomBlock(data, calcMetricsFun, buildFun):
			if (calcMetricsFun != null) {
				return calcMetricsFun(data);
			}
			// Fall through to creation
		}

		// The sad fall-back scenario: Create the fucker and ask it, and then destroy it again
		#if flash9
			var tempMovie = new MovieClip();
			parent.addChild(tempMovie);
			var mc = build(c, tempMovie, 0, 0);
			var size = getSize(mc);
			var m = { width : size.width, height : size.height, growWidth: false, growHeight: false };
			parent.removeChild(tempMovie);
		#else flash
			var d = parent.getNextHighestDepth();
			var tempMovie = parent.createEmptyMovieClip("c" + d, d);
			var mc = build(c, tempMovie, 0, 0);
			var size = getSize(mc);
			var m = { width : size.width, height : size.height, growWidth: false, growHeight: false };
			mc.removeMovieClip();
		#end
		return m;
	}
	
	/**
	 * A helper function which forces a movieclip to have at least a certain size.
	 * Notice, that this will never shrink a movieclip. Use clipSize for that.
	 */
	static public function setSize(clip : MovieClip, width : Float, height : Float) {
		#if flash9
			// Set the size
			clip.graphics.clear();
			clip.graphics.moveTo(0,0);
			clip.graphics.lineTo(width, height);
		#else flash
			// Set the size
			clip.clear();
			clip.moveTo(0,0);
			clip.lineTo(width, height);
		#end
	}
	
	/// Will force a MovieClip to have a certain size - by clipping or enlarging
	static public function clipSize(clip : MovieClip, width : Float, height : Float) {
		setSize(clip, width, height);
		#if flash9
			if (clip.width > width || clip.height > height) {
				// We need to make it smaller - do a scrollRect
				clip.scrollRect = new Rectangle(0.0, 0.0, width, height);
				return;
			}
		#else flash
			if (clip._width > width || clip._height > height) {
				// We need to make it smaller - do a scrollRect
				clip.scrollRect = new Rectangle<Float>(0.0, 0.0, width, height);
				return;
			}
		#end
	}

	/// Get the size of a MovieClip, respecting clipping
	static public function getSize(clip : MovieClip) : { width: Float, height : Float } {
		if (clip.scrollRect != null) {
			return { width : clip.scrollRect.width, height : clip.scrollRect.height };
		}
		#if flash9
			return { width: clip.width, height : clip.height };
		#else flash
			return { width: clip._width, height : clip._height };
		#end
	}
	
	/// A helper function which sets the size of the clip to the size of the stage
	static public function stageSize(clip : MovieClip) {
		#if flash9
			setSize(clip, clip.stage.stageWidth, clip.stage.stageHeight);
		#else flash
			setSize(clip, flash.Stage.width, flash.Stage.height);
		#end
	}
	
	/// Move a movieclip
	static public function moveClip(clip : MovieClip, dx : Float, dy : Float) {
		#if flash9
			clip.x += dx;
			clip.y += dy;
		#else flash
			clip._x += dx;
			clip._y += dy;
		#end
	}
	
	/// Turn the normal cursor on or off
	static public function showMouse(?show : Bool) {
		#if flash9
		#else flash
			if (show == null || show) {
				flash.Mouse.show();
			} else {
				flash.Mouse.hide();
			}
		#end
	}
	
}
