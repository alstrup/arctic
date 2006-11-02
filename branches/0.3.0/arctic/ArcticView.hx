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
#end

typedef ScrollMetrics = { startX : Float, startY : Float, 
                         endY : Float, scrollHeight : Float, toScroll : Float, 
                         clipHeight : Float }

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
	}

	public var gui : ArcticBlock;
	public var parent : MovieClip;
	private var base : MovieClip;
	private var useStageSize : Bool;
    
    /// Increasing this value will reduce the speed of the scroll bar and vice versa
    static private var SCROLL_DELAY : Int = 100;

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
	 * This removes and destroys the view.
	 */
	public function destroy() {
		remove();
		gui = null;
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
		#if flash9
			base = build(gui, parent, parent.width, parent.height);
		#else flash
			base = build(gui, parent, parent._width, parent._height);
		#end
	}

	/**
	 * Removes the visual element - notice, however that if usestage is true, the view is reconstructed on resize.
	 * Use destroy() if you want to get rid of this display for good
	 */
	private function remove() {
		if (base == null) {
			return;
		}
		#if flash9
			parent.removeChild(base);
		#else flash
			base.removeMovieClip();
		#end
		base = null;
	}

    private function build(gui : ArcticBlock, p : MovieClip, 
                    availableWidth : Float, availableHeight : Float) : MovieClip {
		#if flash9
			var clip = new MovieClip();
			p.addChild(clip);
		#else flash
			var d = p.getNextHighestDepth();
			var clip = p.createEmptyMovieClip("c" + d, d);
		#end
		clip.tabEnabled = false;
		
		switch (gui) {
		case Border(x, y, block):
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
				if (null != numeric && numeric) { 
					txtInput.restrict = "0-9";
					var txtFormat = txtInput.defaultTextFormat;
					txtFormat.align = "right";
					txtInput.defaultTextFormat = txtFormat;
				}
			#else flash
				var txtInput = clip.createTextField("ti", clip.getNextHighestDepth(), 0, 0, width, height);
				if (null != numeric && numeric) { 
					txtInput.restrict = "0-9";
					var txtFormat = txtInput.getTextFormat();
					txtFormat.align = "right";
					txtInput.setNewTextFormat(txtFormat);
				}
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
			#if flash9
				txtInput.htmlText = html;
				var listener = function (e:FocusEvent) { validate(); };
				txtInput.addEventListener(FocusEvent.FOCUS_OUT , listener);
				txtInput.type = TextFieldType.INPUT;
				clip.addChild(txtInput);
			#else flash
				txtInput.html = true;
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

		case LineStack(blocks):
			// The number of children which wants to grow (including our own fillers)
			var numberOfTallChildren = 0;
			var childMetrics = [];
			var height = 0.0;
			for (r in blocks) {
				var m = calcMetrics(r);
				childMetrics.push(m);
				if (m.growHeight) {
					numberOfTallChildren++;
				}
				height += m.height;
			}

			// Next, determine how much space children get
            var freeSpace = availableHeight - height;
			if (freeSpace < 0) {
				// Hmm, we should do a scrollbar instead
				freeSpace = 0;
			}
			if (numberOfTallChildren > 0) {
				freeSpace = freeSpace / numberOfTallChildren;
			} else {
				freeSpace = 0;
			}

			var y = 0.0;
			var i = 0;
            var children = [];
			for (l in blocks) {
				var h = childMetrics[i].height + if (childMetrics[i].growHeight) freeSpace else 0;
                var child = build(l, clip, availableWidth, h);
				#if flash9
					child.y = y;
				#else flash
					child._y = y;
				#end
                children.push(child);				
				y += h;
   				++i;
			}

			if (availableHeight - height < 0) {
				var size = getSize(clip);
				// Scrollbar
				#if flash9
					drawScrollBar(clip, size.width, availableHeight);
				#else flash
					drawScrollBar(clip, size.width, availableHeight);
				#end
			}
			return clip;
		
		case ScrollBar(block, availableWidth, availableHeight):
            var child = build(block, clip, availableWidth, availableHeight);            
            drawScrollBar(child, availableWidth, availableHeight);
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
				#if flash9
					child.x += dx;
					child.y += dy;
				#else flash
					child._x += dx;
					child._y += dy;
				#end
				totalDx = dx;
				totalDy = dy;
			}; 
			var dragX = 0.0;
			var dragY = 0.0;
			#if flash9
				var firstTime = true;
				var mouseMove = function(s) {
					if (!clip.visible) {
						return;
					}
					if (sideMotion) {
						var dx = flash.Lib.current.mouseX - dragX;
						var newTotalDx = totalDx + dx;
						if (!stayWithin || (newTotalDx >= 0 && newTotalDx <= availableWidth - childSize.width)) {
							child.x += dx;
							totalDx = newTotalDx;
						}
					}
					if (upDownMotion) {
						var dy = flash.Lib.current.mouseY - dragY;
						var newTotalDy = totalDy + dy;
						if (!stayWithin || (newTotalDy >= 0 && newTotalDy <= availableHeight - childSize.height)) {
							child.y += dy;
							totalDy = newTotalDy;
						}
					}
					if (onDrag != null) {
						onDrag(totalDx, totalDy);
					}
					dragX = flash.Lib.current.mouseX;
					dragY = flash.Lib.current.mouseY;
				}
				var mouseUp = 
					function(s) {
						flash.Lib.current.removeEventListener( flash.events.MouseEvent.MOUSE_MOVE, mouseMove );
					};
				clip.addEventListener( flash.events.MouseEvent.MOUSE_DOWN, 
					function (s) { 
						if (child.hitTestPoint(flash.Lib.current.mouseX, flash.Lib.current.mouseY, true)) {
							dragX = flash.Lib.current.mouseX;
							dragY = flash.Lib.current.mouseY;
							
							flash.Lib.current.addEventListener( flash.events.MouseEvent.MOUSE_MOVE, mouseMove );
							if (firstTime) {
								flash.Lib.current.addEventListener( flash.events.MouseEvent.MOUSE_UP, mouseUp );
								firstTime = false;
							}
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
								if (sideMotion) {
									var dx = flash.Lib.current._xmouse - dragX;
									var newTotalDx = totalDx + dx;
									if (!stayWithin || (newTotalDx >= 0 && newTotalDx <= availableWidth - childSize.width)) {
										child._x += dx;
										totalDx = newTotalDx;
									}
								}
								if (upDownMotion) {
									var dy = flash.Lib.current._ymouse - dragY;
									var newTotalDy = totalDy + dy;
									if (!stayWithin || (newTotalDy >= 0 && newTotalDy <= availableHeight - childSize.height)) {
										child._y += dy;
										totalDy = newTotalDy;
									}
								}
								if (onDrag != null) {
									onDrag(totalDx, totalDy);
								}
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
			#end

			if (null != onInit) {
				onInit(setOffset);
			}
			return clip;

		case CustomBlock(data, calcMetricsFun, buildFun):
			return buildFun(data, clip, availableWidth, availableHeight);
		}
		
		return clip;
	}

	private function calcMetrics(c : ArcticBlock) : Metrics {
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
		case LineStack(blocks):
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
		case CustomBlock(data, calcMetricsFun, buildFun):
			if (calcMetricsFun != null) {
				return calcMetricsFun(data);
			}
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

    // This method draws a scrollbar given a movie clip. 
    // This movieclips should have a parent, which will also be the parent of the scroll bar 
    // rendered.
    // This can be seperated out and written as a seperate class - ideally it should use ArcticBlocks to construct itself
    private function drawScrollBar(clip : MovieClip, availableWidth : Float,
                                                         availableHeight : Float) {
        #if flash9 
            drawScrollBarForFlash9(clip, availableWidth, availableHeight);
        #else flash
            if (clip._height <= availableHeight) {
                return;
            }
            var parent = clip._parent;
            var d = parent.getNextHighestDepth();
            var scrollBar = parent.createEmptyMovieClip("c" + d, d);
            var clipRect = new Rectangle<Float>(0, 0 , 
                                                   availableWidth, availableHeight);
            clip.scrollRect = clipRect;
            var squareHeight = 10;

            d = scrollBar.getNextHighestDepth();
            var upperChild = scrollBar.createEmptyMovieClip("scrollBarUpperChild" + d, d);

            // Upper scroll bar handle
            //Drawing upper white squate    
            upperChild.beginFill(0x000000);
            upperChild.moveTo(0,  0 );
            upperChild.lineTo(0,  0 );
            upperChild.lineTo(12, 0 );
            upperChild.lineTo(12, squareHeight );
            upperChild.lineTo(0, squareHeight );
            upperChild.endFill();
            
            var height =  7;

            //Drawing upper scrollbar triangle
            upperChild.beginFill(0xFFFFFF);
            upperChild.moveTo(2 , height );
            upperChild.lineTo(2 , height );
            upperChild.lineTo(2 + 8 , height );
            upperChild.lineTo(2 + 4 , height - 4 );
            upperChild.endFill();

            var scrollHeight = availableHeight - (squareHeight * 2);

            d = scrollBar.getNextHighestDepth();
            var scrollOutline = scrollBar.createEmptyMovieClip("scrollBarOutline" + d, d);
            
            drawLine(scrollOutline, 0, 0, 0.2, scrollHeight, 0x000000);
            drawLine(scrollOutline, 10, 0, 0.3, scrollHeight, 0x000000);

            scrollOutline._y = upperChild._height;

            d = scrollBar.getNextHighestDepth();
            var scrollHand = scrollBar.createEmptyMovieClip("scrollHand" + d, d);
            var scrollHandHeight = 10;
            drawLine(scrollHand, 0, 0, 8, scrollHandHeight - 0.5, 0x000000);
  
            var scrollMet = { startX : 0.0, startY : 0.0, endY : 0.0, 
                            scrollHeight : 0.0, toScroll : 0.0, clipHeight : 0.0 };
            scrollMet.startX = 1.3;
            scrollMet.startY = upperChild._height + 0.5;
            scrollMet.scrollHeight = scrollHeight - scrollHandHeight - 1;
            scrollMet.toScroll = (clip._height / scrollMet.scrollHeight);
            scrollMet.clipHeight = clip._height;
            scrollMet.endY = scrollMet.startY + scrollMet.scrollHeight - 0.5;

            scrollHand._y = upperChild._height + 0.5;
            scrollHand._x = 1.3;

            d = scrollBar.getNextHighestDepth();
            var lowerChild = scrollBar.createEmptyMovieClip("scrollBarLowerChild" + d, d);

            lowerChild.beginFill(0x000000);

            //Drawing lower white square 
            lowerChild.moveTo(0, 0 );
            lowerChild.lineTo(0, 0 );
            lowerChild.lineTo(12, 0);
            lowerChild.lineTo(12, squareHeight);
            lowerChild.lineTo(0,  squareHeight);
            lowerChild.endFill();
            
            height = 3;
            //Drawing lower scrollbar triangle
            lowerChild.beginFill(0xFFFFFF);
            lowerChild.moveTo(2 , height );
            lowerChild.lineTo(2, height );
            lowerChild.lineTo(2 + 8, height );
            lowerChild.lineTo(2 + 4, height + 4 );
            lowerChild.endFill();
            //lowerChild._x = 10;
            lowerChild._y = availableHeight - 10 ;

            var dragged = false;
            scrollBar.onMouseDown = function () {
                var mouseInside = scrollHand.hitTest(flash.Lib.current._xmouse, 
                                                  flash.Lib.current._ymouse, false);
                
                var inScrollOutline = scrollOutline.hitTest(flash.Lib.current._xmouse, 
                                                  flash.Lib.current._ymouse, false);
                var inLowerChild = lowerChild.hitTest(flash.Lib.current._xmouse, 
                                                  flash.Lib.current._ymouse, false);
                var inUpperChild = upperChild.hitTest(flash.Lib.current._xmouse, 
                                                  flash.Lib.current._ymouse, false);

                if (mouseInside) {
                    scrollHand.startDrag(false , scrollMet.startX , 
                                                    scrollMet.startY ,
                                                    scrollMet.startX , 
                                                    scrollHeight );
                    dragged = true;
                    Reflect.setField(Bool, "dragging", true);
                    scrollTimer(clip, scrollHand, clipRect, scrollMet);
                } else if (inScrollOutline) {
                    var scrollToY = flash.Lib.current._ymouse;
                    scrollToY = scrollToY - 139;//scrollBar._y;
                    scrollToY = scrollBar._ymouse;
                    var startY = scrollMet.startY;
                    if (scrollToY < startY ) {
                        scrollToY = scrollMet.startY;
                    } else if (scrollToY >= scrollMet.endY) {
                        scrollToY = scrollMet.endY;
                    }
                    scrollHand._y = scrollToY;
                    scroll(clip, scrollHand, clipRect, scrollMet);
                } else if ( inLowerChild) {
                    Reflect.setField(Bool, "scrollPressed", true);
                    scrollByOne(clip, scrollHand, clipRect, scrollMet, true);
                } else if (inUpperChild) {
                    Reflect.setField(Bool, "scrollPressed", true);
                    scrollByOne(clip, scrollHand, clipRect, scrollMet, false);
                }
            }

            scrollBar.onMouseUp = function() {
                var dragged = Reflect.field(Bool, "dragging");
                if (dragged) {
                    scrollHand.stopDrag();                
                    Reflect.setField(Bool, "dragging", false);
                }
                var scrollPressed = Reflect.field(Bool, "scrollPressed");
                if (scrollPressed) {
                    Reflect.setField(Bool, "scrollPressed", false);
                }            
            }

            scrollBar._x = availableWidth - 2;
            scrollBar._y = clip._y;
        #end
       }


    #if flash9
       static public function scrollTimer(clip : MovieClip, scrollHand : MovieClip, 
                            rect : Rectangle, scrollMet : ScrollMetrics) {          
    #else flash
       static public function scrollTimer(clip : MovieClip, scrollHand : MovieClip, 
                        rect : Rectangle<Float>, scrollMet : ScrollMetrics) {
    #end
            var interval = new haxe.Timer(100);                
            interval.run = function () {
                var dragged = Reflect.field(Bool, "dragging");
                scroll(clip, scrollHand, rect, scrollMet);
                if ( !dragged ) {
                    interval.stop();
                }
            }
        }


    #if flash9
        static private function scrollByOne(clip : MovieClip, 
                             scrollHand : MovieClip, rect : Rectangle, 
                             scrollMet : ScrollMetrics, scrollDown : Bool) {
            var interval = new haxe.Timer(15);                
            interval.run = function () {
                var scrollPressed = Reflect.field(Bool, "scrollPressed");
                if (scrollDown) {
                    if ( (scrollHand.y + 1) <= scrollMet.endY ) {
                          scrollHand.y++;
                    }
                } else {
                    if ( (scrollHand.y - 1 ) >= scrollMet.startY ) {
                          scrollHand.y--;
                    }
                }

   #else flash
        static private function scrollByOne(clip : MovieClip, scrollHand : MovieClip, 
                      rect : Rectangle < Float >, scrollMet : ScrollMetrics,                                                                     scrollDown : Bool) {
            var interval = new haxe.Timer(15);                
            interval.run = function () {
                var scrollPressed = Reflect.field(Bool, "scrollPressed");
                if (scrollDown) {
                    if ( (scrollHand._y + 1) <= scrollMet.endY ) {
                          scrollHand._y++;
                    }
                } else {
                    if ( (scrollHand._y - 1 ) >= scrollMet.startY ) {
                          scrollHand._y--;
                    }
                }
    #end
                scroll(clip, scrollHand, rect, scrollMet);
                if ( !scrollPressed ) {
                    interval.stop();
                }
            }
        }



    #if flash9
        static private function scroll(clip : MovieClip, scrollHand : MovieClip, 
                rect : Rectangle, scrollMet : ScrollMetrics ) {   
             if ( scrollHand.y < scrollMet.startY ) {
             	scrollHand.y = scrollMet.startY;
             }
             
	     if ( scrollHand.y > scrollMet.endY ) {
             	scrollHand.y = scrollMet.endY;
             }
             
             if ( (scrollHand.y >= scrollMet.startY )  && (scrollHand.y <= scrollMet.endY)) {
                var diff = scrollHand.y - scrollMet.startY;

    #else flash
        static private function scroll(clip : MovieClip, scrollHand : MovieClip, 
                    rect : Rectangle < Float >, scrollMet : ScrollMetrics) {
             if ( scrollHand._y < scrollMet.startY ) {
             	scrollHand._y = scrollMet.startY;
             }
             
	     if ( scrollHand._y > scrollMet.endY ) {
             	scrollHand._y = scrollMet.endY;
             }
             
             if ( (scrollHand._y >= scrollMet.startY )  && (scrollHand._y <= scrollMet.endY)) {
                var diff = scrollHand._y - scrollMet.startY;
    #end
                var increment = scrollMet.toScroll * diff;
                if (increment < (scrollMet.clipHeight - 10) ) {
                    rect.y = increment;
                    clip.scrollRect = rect;
                } else {
                    rect.y = scrollMet.clipHeight - 10;
                    clip.scrollRect = rect;
                }
            }
        }


    #if flash9
        static private function drawLine(clip : MovieClip, startX : Float, 
              startY : Float, lineWidth : Float , lineHeight : Float, rgb : Int) { 

            clip.graphics.beginFill(rgb);
            clip.graphics.moveTo(startX + 0.2,  startY );
            clip.graphics.lineTo(startX + 0.2 + lineWidth, startY );
            clip.graphics.lineTo(startX + 0.2 + lineWidth, startY + lineHeight );
            clip.graphics.lineTo(startX + 0.2, startY + lineHeight );
            clip.graphics.endFill();
        }
    #else flash
        static private function drawLine(clip : MovieClip, startX : Float, 
              startY : Float, lineWidth : Float , lineHeight : Float, rgb : Int) { 
            
            //Drawing lower scrollbar triangle
            clip.beginFill(rgb);
            clip.moveTo(startX + 0.2,  startY );
            clip.lineTo(startX + 0.2 + lineWidth, startY );
            clip.lineTo(startX + 0.2 + lineWidth, startY + lineHeight );
            clip.lineTo(startX + 0.2, startY + lineHeight );
            clip.endFill();

        }
    #end

    #if flash9 
        private function drawScrollBarForFlash9(clip : MovieClip, availableWidth : Float,
                                                         availableHeight : Float) {
            if (clip.height <= availableHeight) {
                return;
            }
            var parent = clip.parent;
            var scrollBar = new MovieClip();
            parent.addChild(scrollBar);
            var clipRect = new Rectangle(0, 0 , availableWidth, availableHeight);
            clip.scrollRect = clipRect;
            var squareHeight = 10;

            var upperChild = new MovieClip();
            scrollBar.addChild(upperChild);

            // Upper scroll bar handle
            //Drawing upper white squate    
            upperChild.graphics.beginFill(0x000000);
            upperChild.graphics.moveTo(0,  0 );
            upperChild.graphics.lineTo(0,  0 );
            upperChild.graphics.lineTo(12, 0 );
            upperChild.graphics.lineTo(12, squareHeight );
            upperChild.graphics.lineTo(0, squareHeight );
            upperChild.graphics.endFill();
            
            var height =  7;

            //Drawing upper scrollbar triangle
            upperChild.graphics.beginFill(0xFFFFFF);
            upperChild.graphics.moveTo(2 , height );
            upperChild.graphics.lineTo(2 , height );
            upperChild.graphics.lineTo(2 + 8 , height );
            upperChild.graphics.lineTo(2 + 4 , height - 4 );
            upperChild.graphics.endFill();

            var scrollHeight = availableHeight - (squareHeight * 2);

            var scrollOutline = new MovieClip();
            scrollBar.addChild(scrollOutline);
            
//            drawLine(scrollOutline, 0, 0, 0.2, scrollHeight, 0x000000);
//            drawLine(scrollOutline, 10, 0, 0.3, scrollHeight, 0x000000);
            
            drawLine(scrollOutline, 0, 0, 10, scrollHeight, 0xFFFFFF);
            scrollOutline.y = upperChild.height;

            var scrollHand = new MovieClip();
            scrollBar.addChild(scrollHand);
            var scrollHandHeight = 10;
            drawLine(scrollHand, 0, 0, 8, scrollHandHeight - 0.5, 0x000000);
  
            var scrollMet = { startX : 0.0, startY : 0.0, endY : 0.0, 
                            scrollHeight : 0.0, toScroll : 0.0, clipHeight : 0.0 };
            scrollMet.startX = 1.2;
            scrollMet.startY = upperChild.height + 0.5;
            scrollMet.scrollHeight = scrollHeight - scrollHandHeight - 1;
            scrollMet.toScroll = (clip.height / scrollMet.scrollHeight);
            scrollMet.clipHeight = clip.height;
            scrollMet.endY = scrollMet.startY + scrollMet.scrollHeight - 0.5;

            scrollHand.y = upperChild.height + 0.5;
            scrollHand.x = 1.2;

            var lowerChild = new MovieClip();
            scrollBar.addChild(lowerChild);


            lowerChild.graphics.beginFill(0x000000);

            //Drawing lower white square 
            lowerChild.graphics.moveTo(0, 0 );
            lowerChild.graphics.lineTo(0, 0 );
            lowerChild.graphics.lineTo(12, 0);
            lowerChild.graphics.lineTo(12, squareHeight);
            lowerChild.graphics.lineTo(0,  squareHeight);
            lowerChild.graphics.endFill();
            
            height = 3;
            //Drawing lower scrollbar triangle
            lowerChild.graphics.beginFill(0xFFFFFF);
            lowerChild.graphics.moveTo(2 , height );
            lowerChild.graphics.lineTo(2, height );
            lowerChild.graphics.lineTo(2 + 8, height );
            lowerChild.graphics.lineTo(2 + 4, height + 4 );
            lowerChild.graphics.endFill();
            //lowerChild._x = 10;
            lowerChild.y = availableHeight - 10 ;

    		scrollHand.addEventListener(
                flash.events.MouseEvent.MOUSE_DOWN, 
                function (s) {
                    scrollHand.startDrag(false , new Rectangle(
                                                    scrollMet.startX , 
                                                    scrollMet.startY ,
                                                    scrollMet.startX , 
                                            scrollMet.scrollHeight) );
                    Reflect.setField(Bool, "dragging", true);
                    scrollTimer(clip, scrollHand, clipRect, scrollMet);
                 } ); 


    		scrollHand.addEventListener(
                flash.events.MouseEvent.MOUSE_UP, 
                function (s) {
                    var dragged = Reflect.field(Bool, "dragging");
                    if (dragged) {
                        scrollHand.stopDrag();                
                        Reflect.setField(Bool, "dragging", false);
                    }
                 } ); 


    		scrollOutline.addEventListener(
                flash.events.MouseEvent.MOUSE_DOWN, 
                function (s) {
                    //var scrollToY = scrollBar._ymouse;
                     var scrollToY = s.localY;
                    var startY = scrollMet.startY;
                    if (scrollToY < startY ) {
                        scrollToY = scrollMet.startY;
                    } else if (scrollToY >= scrollMet.endY) {
                        scrollToY = scrollMet.endY;
                    }
                    scrollHand.y = scrollToY;
                    scroll(clip, scrollHand, clipRect, scrollMet);
                 } ); 



    		lowerChild.addEventListener(
                flash.events.MouseEvent.MOUSE_DOWN, 
                function (s) {
                    Reflect.setField(Bool, "scrollPressed", true);
                    scrollByOne(clip, scrollHand, clipRect, scrollMet, true);
                } ); 


    		lowerChild.addEventListener(
                flash.events.MouseEvent.MOUSE_UP, 
                function (s) {
                    var scrollPressed = Reflect.field(Bool, "scrollPressed");
                    if (scrollPressed) {
                        Reflect.setField(Bool, "scrollPressed", false);
                    }            
                 } ); 

    		upperChild.addEventListener(
                flash.events.MouseEvent.MOUSE_DOWN, 
                function (s) {
                    Reflect.setField(Bool, "scrollPressed", true);
                    scrollByOne(clip, scrollHand, clipRect, scrollMet, false);
                } ); 


    		upperChild.addEventListener(
                flash.events.MouseEvent.MOUSE_UP, 
                function (s) {
                    var scrollPressed = Reflect.field(Bool, "scrollPressed");
                    if (scrollPressed) {
                        Reflect.setField(Bool, "scrollPressed", false);
                    }            
                 } ); 


            scrollBar.x = availableWidth - 2;
            scrollBar.y = clip.y;

       }
        #end
}
