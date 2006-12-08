package arctic;

import arctic.ArcticBlock;

#if flash9
import flash.display.MovieClip;
import flash.geom.Rectangle;
import flash.text.TextField;
import flash.text.TextFieldType;
import flash.events.FocusEvent;
#else flash
import flash.MovieClip;
import flash.MovieClipLoader;
import flash.geom.Rectangle;
import flash.TextField;
import flash.TextFormat;
import flash.Mouse;
#end

/// Information we need at runtime to implement updating
typedef BlockInfo = {
	// Dragable needs to know how much space is available in the containing block
	available : { width: Float, height : Float },
	// Dragable needs to know how much we have moved so far
	totalDx : Float,
	totalDy : Float,
	// Dragable needs to know how big the draggable area is
	childSize : { width: Float, height : Float } 
}

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
		if (metricsCache == null) {
			metricsCache = new Hash<{ width: Float, height : Float } >();
		}
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
				var resizeHandler = function( event : flash.events.Event ) { t.onResize();}; 
				addStageEventListener(p.stage, flash.events.Event.RESIZE, resizeHandler ); 
			#else flash
				flash.Stage.addListener(this);
				flash.Stage.scaleMode = "noScale";
				flash.Stage.align = "TL";
			#end
		}
        return base;
	}

	#if flash9
	private var stageEventHandlers : Array<{ obj: flash.events.EventDispatcher, event : String, handler : Dynamic } >;
	#end
	
	/**
	 * This removes and destroys the view. You have to use this to clean up
	 * properly.
	 */
	public function destroy() {
		remove();
		gui = null;
		showMouse();
		
		#if flash9
			for (e in stageEventHandlers) {
				e.obj.removeEventListener(e.event, e.handler);
			}
		#end
		if (useStageSize) {
			#if flash9
			#else flash
				flash.Stage.removeListener(this);
			#end
		}
	}
	
	public function onResize() {
		if (false) {
			var stage = getStageSize(parent);
			base = build(gui, parent, stage.width, stage.height, false, 0);
		} else {
			if (base != null) {
				remove();
			}
			stageSize(parent);
			refresh();
		}
	}

	public function refresh() {
		if (base != null) {
			remove();
		}
		movieClips = [];
		activeClips = [];
		idMovieClip = new Hash<ArcticMovieClip>();
		showMouse();
		var size;
		if (useStageSize) {
			size = getStageSize(parent);
		} else {
			size = getSize(parent);
		}

		#if flash9
			stageEventHandlers = [];
		#end
		
		base = build(gui, parent, size.width, size.height, true, 0);
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
		activeClips = [];
		idMovieClip = new Hash<ArcticMovieClip>();
		base = null;
	}
	
	// We collect all generated movieclips here, so we can be sure to remove all when done
	private var movieClips : Array<ArcticMovieClip>;
	
	// Here we record active movieclips which are interested in events to implement nesting
	private var activeClips : Array<ArcticMovieClip>;

	/// We record updates of blocks here.
	private var updates : Hash<ArcticBlock>;
	
	/// And the movieclips for ids here
	private var idMovieClip : Hash<ArcticMovieClip>;
	
    private function build(gui : ArcticBlock, p : MovieClip, 
                    availableWidth : Float, availableHeight : Float, construct : Bool, childNo : Int) : MovieClip {

//		trace("build " + availableWidth + "," + availableHeight + ": " + gui);
		switch (gui) {
		case Border(x, y, block):
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
			if (availableWidth < 2 * x) {
				x = availableWidth / 2;
			}
			if (availableHeight < 2 * y) {
				y = availableHeight / 2;
			}
			var child = build(block, clip, availableWidth - 2 * x, availableHeight - 2 * y, construct, 0);
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
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
			var child = build(block, clip, availableWidth, availableHeight, construct, 0);
			var size = getSize(child);
			#if flash9
				clip.graphics.clear();
				clip.graphics.beginFill(color, if (alpha != null) alpha / 100.0 else 100.0);
				DrawUtils.drawRect(clip, 0, 0, size.width, size.height, roundRadius);
				clip.graphics.endFill();
			#else flash
				clip.clear();
				clip.beginFill(color, if (alpha != null) alpha else 100.0);
				DrawUtils.drawRect(clip, 0, 0, size.width, size.height, roundRadius);
				clip.endFill();
			#end
			return clip;

		case GradientBackground(type, colors, xOffset, yOffset, block, alpha, roundRadius):
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
			var child = build(block, clip, availableWidth, availableHeight, construct, 0);
			if (colors == null || colors.length == 0) {
				// Hm, this must be a mistake, but what the heck
				return clip;
			}
			var size = getSize(child);
			var ratios = [];
			var alphas = [];
			var dt = 255 / (colors.length - 1);
			var r = 0.0;
			for (i in 0...colors.length) {
				ratios.push(r);
				r += dt;
				if (alpha == null) {
					#if flash9
						alphas.push(1.0);
					#else flash
						alphas.push(100.0);
					#end
				}
			}
			#if flash9
				var matrix = new flash.geom.Matrix();
				matrix.createGradientBox(size.width, size.height, 0, size.width * xOffset, size.height * yOffset);
				if (alpha != null) {
					alphas = [];
					for (a in alpha) {
						alphas.push(a / 100.0);
					}
				}
				clip.graphics.clear();
				clip.graphics.beginGradientFill(flash.display.GradientType.RADIAL, colors, alphas, ratios, matrix);
				DrawUtils.drawRect(clip, 0, 0, child.width, child.height, roundRadius);
				clip.graphics.endFill();
			#else flash
				var matrix = new flash.geom.Matrix();
				if (alpha != null) {
					alphas = alpha;
				}
				clip.clear();
				matrix.createGradientBox(size.width, size.height, 0, size.width * xOffset, size.height * yOffset);
				clip.beginGradientFill(type, colors, alphas, ratios, matrix);
				DrawUtils.drawRect(clip, 0, 0, size.width, size.height, roundRadius);
				clip.endFill();
			#end
			return clip;

		case Text(html, embeddedFont):
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
			#if flash9
				var tf : flash.text.TextField;
				if (construct) {
					tf = new flash.text.TextField();
				} else {
					tf = cast(clip.getChildAt(0), flash.text.TextField);
				}
				if (embeddedFont) {
					tf.embedFonts = true;
				}
				tf.autoSize = flash.text.TextFieldAutoSize.LEFT;
				tf.selectable = false;
				tf.multiline = true;
				tf.htmlText = html;
				if (construct) {
					clip.addChild(tf);
				}
			#else flash
				var tf : flash.TextField;
				if (construct) {
					tf = clip.createTextField("tf", clip.getNextHighestDepth(), 0, 0, 100, 100);
					Reflect.setField(clip, "tf", tf);
				} else {
					tf = Reflect.field(clip, "tf");
				}
				if (embeddedFont) {
					tf.embedFonts = true;
				}
				tf.autoSize = true;
				tf.html = true;
				tf.selectable = false;
				tf.multiline = true;
				tf.htmlText = html;
			#end
			return clip;

		case TextInput(html, width, height, validator, style, maxChars, numeric, bgColor, focus) :
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
			if (construct) {
				activeClips.push(clip);
			}
			#if flash9
				var txtInput : flash.text.TextField;
				if (construct) {
					txtInput = new flash.text.TextField();
				} else {
					var t : Dynamic = clip.getChildAt(0);
					txtInput = t;
				}
				txtInput.width = width;
				txtInput.height = height;
			#else flash
				var txtInput : flash.TextField;
				if (construct) {
					txtInput = clip.createTextField("ti", clip.getNextHighestDepth(), 0, 0, width, height);
					Reflect.setField(clip, "ti", txtInput);
				} else {
					txtInput = Reflect.field(clip, "ti");
				}
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
				if (construct) {
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
						txtInput.addEventListener(FocusEvent.FOCUS_OUT, listener);
						clip.addChild(txtInput);
						txtInput.type = TextFieldType.INPUT;
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
					
					// Setting additional txtInput properties from the style object
					var fields = Reflect.fields(style);
					for (i in 0...fields.length){
						Reflect.setField(txtInput, fields[i], Reflect.field(style,fields[i]));
					}

					// Setting focus on txtInput 
					#if flash9
						if (focus != null && focus) clip.stage.focus = txtInput;
					#else flash
						if (focus != null && focus) flash.Selection.setFocus(txtInput);
					#end
				}
						
			return clip;

		case Picture(url, w, h, scaling):
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
			#if flash9
				if (construct) {
					var loader = new flash.display.Loader();
					var request = new flash.net.URLRequest(url);
					loader.load(request);
					clip.addChild(loader);
				}
				var s = scaling;
				clip.scaleX = s;
				clip.scaleY = s;
			#else flash
				if (construct) {
					var loader = new flash.MovieClipLoader();
					var r = loader.loadClip(url, clip);
				}
				var s = scaling * 100.0;
				clip._xscale = s;
				clip._yscale = s;
			#end
			setSize(clip, w / scaling, h / scaling);
			return clip;

		case Button(block, hover, action):
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
			var child = build(block, clip, availableWidth, availableHeight, construct, 0);
			var hover = build(hover, clip, availableWidth, availableHeight, construct, 1);
			#if flash9
				child.buttonMode = true;
				child.mouseChildren = false;
				hover.buttonMode = true;
				hover.mouseChildren = false;
				child.visible = true;
				hover.visible = false;
				if (construct) {
					clip.addEventListener(flash.events.MouseEvent.MOUSE_UP, function (s) { if (action != null) action(); } ); 
					addStageEventListener( clip.stage, flash.events.MouseEvent.MOUSE_MOVE, 
						function (s) {
							if (clip.hitTestPoint(flash.Lib.current.mouseX, flash.Lib.current.mouseY, true)) {
								child.visible = false;
								hover.visible = true;
							} else {
								child.visible = true;
								hover.visible = false;
							}
						}
					);
					addStageEventListener( clip.stage, flash.events.Event.MOUSE_LEAVE, function() {
						child.visible = true;
						hover.visible = false;
					});
				}
			#else flash
				child._visible = true;
				hover._visible = false;
				if (construct) {
					//clip.onRelease = action;
					clip.onMouseUp = function () {
						if (clip.hitTest(flash.Lib.current._xmouse, flash.Lib.current._ymouse, false)) {
							action();
						}
					}

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
					hover.onRollOut = function() { 
						child._visible = true;
						hover._visible = false;
					};
				}
			#end
			return clip;

		case ToggleButton(selected, unselected, initialState, onChange, onInit):
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
			var sel = build(selected, clip, availableWidth, availableHeight, construct, 0);
			var unsel = build(unselected, clip, availableWidth, availableHeight, construct, 1);
			#if flash9
				unsel.buttonMode = true;
				unsel.mouseChildren = false;
				sel.buttonMode = true;
				sel.mouseChildren = false;
				if (construct) {
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
				}
			#else flash
				if (construct) {
					sel._visible = initialState;
					unsel._visible = !initialState;
					var setState = function (newState : Bool) { sel._visible = newState; unsel._visible = !newState; }; 
					if (null != onInit) {
						onInit(setState);
					}
					/*
					clip.onPress = function () {
						setState(!sel._visible);
						if (null != onChange) {
							trace("Click");
							onChange(sel._visible);
						}
					};*/
					clip.onMouseDown = function() {
						if (null != onChange && clip.hitTest(flash.Lib.current._xmouse, flash.Lib.current._ymouse, false)) {
							setState(!sel._visible);
							onChange(sel._visible);
						}
					};
				}
			#end
			return clip;

		case Filler:
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
			setSize(clip, availableWidth, availableHeight);
			return clip;
		
		case Fixed(width, height):
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
			setSize(clip, width, height);
			return clip;

        case ConstrainWidth(minimumWidth, maximumWidth, block) :
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
            var child = build(block, clip, Math.max( minimumWidth, Math.min(availableWidth, maximumWidth) ), availableHeight, construct, 0);
			var size = getSize(child);
			if (size.width < minimumWidth) {
				setSize(clip, minimumWidth, size.height);
			}
			if (size.width > maximumWidth) {
				clipSize(clip, maximumWidth, size.height);
			}
            return clip;

        case ConstrainHeight(minimumHeight, maximumHeight, block) :
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
			var child = build(block, clip, availableWidth, Math.max( minimumHeight, Math.min(availableHeight, maximumHeight) ), construct, 0);
			var size = getSize(child);
			if (size.height < minimumHeight) {
				setSize(clip, size.width, minimumHeight);
			}
			if (size.height > maximumHeight) {
				clipSize(clip, size.width, maximumHeight);
			}
            return clip;

		case ColumnStack(blocks):
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
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
                var child = build(l, clip, w, availableHeight, construct, i);
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
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
			// Get child 0
			var child = getOrMakeClip(clip, construct, 0);

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
					// We need to add a scrollbar ourselves to make room for it
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
                var line = build(l, child, availableWidth, h, construct, i);
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
			if (i == ensureVisibleIndex) {
				ensureY = y;
			}
			
			if (freeSpace < 0) {
				if (-freeSpace > growChildrensHeight) {
					availableWidth += 12;
					// Scrollbar
					Scrollbar.drawScrollBar(clip, child, availableWidth, availableHeight, ensureY);
				} else {
					if (!construct) {
						Scrollbar.removeScrollbar(clip, child);
					}
				}
			} else {
				if (!construct) {
					Scrollbar.removeScrollbar(clip, child);
				}
			}
			return clip;
		
		case Grid(cells):
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
			var child = getOrMakeClip(clip, construct, 0);

			var gridMetrics = { width : 0.0, height : 0.0, growWidth : false, growHeight : false };
			var columnWidths = [];
			var lineHeights = [];
			var y = 0;
			for (line in cells) {
				var x = 0;
				var lineHeight = 0.0;
				for (block in line) {
					var m = calcMetrics(block);
					gridMetrics.growWidth = gridMetrics.growWidth || m.growWidth;
					gridMetrics.growHeight = gridMetrics.growHeight || m.growHeight;
					if (columnWidths.length <= x) {
						columnWidths.push(m.width);
					} else {
						if (columnWidths[x] < m.width) {
							columnWidths[x] = m.width;
						}
					}
					lineHeight = Math.max(lineHeight, m.height);
					++x;
				}
				if (lineHeights.length <= y) {
					lineHeights.push(lineHeight);
				} else {
					if (lineHeights[y] < lineHeight) {
						lineHeights[y] = lineHeight;
					}
				}
				++y;
			}
			
			var i = 0;
			y = 0;
			var yc = 0.0;
			for (line in cells) {
				var xc = 0.0;
				var x = 0;
				for (block in line) {
					var b = build(block, child, columnWidths[x], lineHeights[y], construct, i);
					#if flash9
						b.x = xc;
						b.y = yc;
					#else flash
						b._x = xc;
						b._y = yc;
					#end
					xc += columnWidths[x];
					++x;
					++i;
				}
				yc += lineHeights[y];
				++y;
			}
		
			return clip;
		
		case ScrollBar(block, availableWidth, availableHeight):
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
            var child = build(block, clip, availableWidth, availableHeight, construct, 0);
            Scrollbar.drawScrollBar(clip, child, availableWidth, availableHeight, 0);
            return clip;

		case Dragable(stayWithin, sideMotion, upDownMotion, block, onDrag, onInit):
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
			
            var child = build(block, clip, availableWidth, availableHeight, construct, 0);
			if (construct) {
				activeClips.push(child);
			}
			var currentChildSize = getSize(child);
			var info : BlockInfo;
			if (construct) {
				info = {
					available: { width: availableWidth, height: availableHeight },
					totalDx: 0.0,
					totalDy: 0.0,
					childSize: currentChildSize
				};
				setBlockInfo(child, info);
			} else {
				info = getBlockInfo(child);
				info.available = { width: availableWidth, height: availableHeight };
				info.childSize = currentChildSize;
			}
			if (stayWithin) {
				setSize(clip, availableWidth, availableHeight);
			}
			
			var me = this;
			var setOffset = function (dx : Float, dy : Float) {
				var info = me.getBlockInfo(child);
				if (stayWithin) {
					dx = Math.min(info.available.width - info.childSize.width, dx);
					dy = Math.min(info.available.height - info.childSize.height, dy);
				}
				moveClip(child, dx, dy);
				info.totalDx = dx;
				info.totalDy = dy;
			}; 
			
			if (!construct) {
				if (null != onInit) {
					// Reverse movement so it's back in a second
					moveClip(child, -info.totalDx, -info.totalDy);
					onInit(setOffset);
				}
				return clip;
			}
			
			var dragX = -1.0;
			var dragY = -1.0;
			
			var doDrag = function (dx : Float, dy : Float) {
				var info = me.getBlockInfo(child);
				if (!sideMotion) {
					dx = 0;
				}
				if (!upDownMotion) {
					dy = 0;
				}
				var motion = false;
					if (sideMotion) {
						while (Math.abs(dx) > 0) {
							var newTotalDx = info.totalDx + dx;
							if (!stayWithin || (newTotalDx >= 0 && newTotalDx <= info.available.width - info.childSize.width)) {
								moveClip(child, dx, 0);
								info.totalDx = newTotalDx;
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
							var newTotalDy = info.totalDy + dy;
							if (!stayWithin || (newTotalDy >= 0 && newTotalDy <= info.available.height - info.childSize.height)) {
								moveClip(child, 0, dy);
								info.totalDy = newTotalDy;
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
							onDrag(info.totalDx, info.totalDy);
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
				clip.addEventListener(flash.events.MouseEvent.MOUSE_DOWN, 
					function (s) { 
						if (me.getActiveClip() == child) {
							dragX = clip.stage.mouseX;
							dragY = clip.stage.mouseY;
							me.addStageEventListener( clip.stage, flash.events.MouseEvent.MOUSE_MOVE, mouseMove );
							if (firstTime) {
								me.addStageEventListener( clip.stage, flash.events.MouseEvent.MOUSE_UP, mouseUp );
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
					if (me.getActiveClip() == child) {
						// TODO: Check we do not hit a child which wants drags
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
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
			var child = build(block, clip, availableWidth, availableHeight, construct, 0);
			var me = this;
			var cursorMc = null;
			// We need to construct the cursor lazily because we want it to come on top of everything
			var cursorMcFn = function() { return me.build(cursor, me.parent, 0, 0, construct, 1);};
			var keep = if (keepNormalCursor == null) true else keepNormalCursor;
			#if flash9
				var onMove = function (s) {
					if (child.hitTestPoint(flash.Lib.current.mouseX, flash.Lib.current.mouseY, true)) {
						if (cursorMc == null) {
							cursorMc = cursorMcFn();
							cursorMcFn = null;
						}
						cursorMc.visible = true;
						cursorMc.x = me.parent.mouseX;
						cursorMc.y = me.parent.mouseY;
						showMouse(keep);
						return;
					} else {
						if (cursorMc != null) {
							cursorMc.visible = false;
						}
						showMouse();
					}
				};
				if (construct) {
					addStageEventListener( clip.stage, flash.events.MouseEvent.MOUSE_MOVE, onMove);
					addStageEventListener( clip.stage, flash.events.Event.MOUSE_LEAVE, function() { 
							cursorMc.visible = false;
							showMouse();
						}
					);
				}
				onMove(null);
			#else flash
				
				var onMove = function() {
							if (child.hitTest(flash.Lib.current._xmouse, flash.Lib.current._ymouse)) {
								if (cursorMc == null) {
									cursorMc = cursorMcFn();
									cursorMcFn = null;
								}
								cursorMc._visible = true;
								cursorMc._x = me.parent._xmouse;
								cursorMc._y = me.parent._ymouse;
								showMouse(keep);
								return;
							} else {
								if (cursorMc != null) {
									cursorMc._visible = false;
								}
								showMouse();
							}
						};
				if (construct) {
					if (clip.onMouseMove == null) {
						clip.onMouseMove = onMove;
					}
					if (clip.onRollOut == null) {
						clip.onRollOut = function() { 
							// TODO: We need to notify the children here as well, because Flash
							// does not propagate events down. This means that highlighters on
							// buttons are not turned off if they have a tooltip on them
							if (cursorMc != null) {
								cursorMc._visible = false;
							}
							showMouse();
						};
					}
				}
				onMove();
			#end
			
			return clip;

		case Offset(dx, dy, block) :
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
			var child = build(block, clip, availableWidth, availableHeight, construct, 0);
			if (construct) {
				moveClip(child, dx, dy);
			}
			return clip;
			
		case OnTop(base, overlay) :
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
			var child = build(base, clip, availableWidth, availableHeight, construct, 0);
			var over = build(overlay, clip, availableWidth, availableHeight, construct, 1);
			return clip;
		 
		case Id(id, block) :
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
			if (updates.exists(id)) {
				// TODO: Refine this to only send true if it's a new update
				var child = build(updates.get(id), clip, availableWidth, availableHeight, construct, 0);
				idMovieClip.set(id, child);
				return clip;
			}
			var child = build(block, clip, availableWidth, availableHeight, construct, 0);
			idMovieClip.set(id, child);
			return clip;

		case CustomBlock(data, calcMetricsFun, buildFun):
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
			if (construct) {
				return buildFun(data, clip, availableWidth, availableHeight, null);
			} else {
				return buildFun(data, clip, availableWidth, availableHeight, getOrMakeClip(clip, false, 0));
			}
		}
		return null;
	}

	private function calcMetrics(c : ArcticBlock) : Metrics {
#if false
		var m = doCalcMetrics(c);
		trace(m.width + "," + m.height + " " + m.growWidth + "," + m.growHeight + ":" + c);
		return m;
	}
	
	private function doCalcMetrics(c) {
#end
		var text = null;
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
		case Text(html, embeddedFont):
			if (metricsCache.exists(html)) {
				var m = metricsCache.get(html);
				return { width : m.width, height : m.height, growWidth : false, growHeight : false };
			}
			text = html;
			// Fall-through to creation
		case Picture(url, w, h, scaling):
			return { width : w, height : h, growWidth : false, growHeight : false };
		case Button(block, hover, action):
			return calcMetrics(block);
		case ToggleButton(selected, unselected, initialState, onChange, onInit):
			return calcMetrics(selected);
		case Filler:
			return { width : 0.0, height : 0.0, growWidth : true, growHeight : true };
		case Fixed(width, height):
			return { width : width, height : height, growWidth : false, growHeight : false };
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
		case TextInput(html, width, height, validator, style, maxChars, numeric, bgColor, focus):
			return { width : width, height : height, growWidth : false, growHeight : false };
		case ColumnStack(columns):
			var m = { width : 0.0, height : 0.0, growWidth : false, growHeight : false };
			for (c in columns) {
				var cm = calcMetrics(c);
				m.width += cm.width;
				m.height = Math.max(cm.height, m.height);
				m.growWidth = m.growWidth || cm.growWidth;
				// A filler here should in itself not impact height growth in this situation
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
				// A filler here should in itself not impact width growth in this situation
				if (c != Filler) {
					m.growWidth = m.growWidth || cm.growWidth;
				}
				m.growHeight = m.growHeight || cm.growHeight;
			}
			return m;

		case Grid(cells):
			var gridMetrics = { width : 0.0, height : 0.0, growWidth : false, growHeight : false };
			var columnWidths = [];
			var lineHeights = [];
			var y = 0;
			for (line in cells) {
				var x = 0;
				var lineHeight = 0.0;
				for (block in line) {
					var m = calcMetrics(block);
					gridMetrics.growWidth = gridMetrics.growWidth || m.growWidth;
					gridMetrics.growHeight = gridMetrics.growHeight || m.growHeight;
					if (columnWidths.length <= x) {
						columnWidths.push(m.width);
					} else {
						if (columnWidths[x] < m.width) {
							columnWidths[x] = m.width;
						}
					}
					lineHeight = Math.max(lineHeight, m.height);
					++x;
				}
				if (lineHeights.length <= y) {
					lineHeights.push(lineHeight);
				} else {
					if (lineHeights[y] < lineHeight) {
						lineHeights[y] = lineHeight;
					}
				}
				++y;
			}
			for (w in columnWidths) {
				gridMetrics.width += w;
			}
			for (h in lineHeights) {
				gridMetrics.height += h;
			}
			return gridMetrics;
		
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
			var mc = build(c, tempMovie, 0, 0, true, 0);
			var size = getSize(mc);
			var m = { width : size.width, height : size.height, growWidth: false, growHeight: false };
			parent.removeChild(tempMovie);
		#else flash
			var d = parent.getNextHighestDepth();
			var tempMovie = parent.createEmptyMovieClip("c" + d, d);
			var mc = build(c, tempMovie, 0, 0, true, 0);
			var size = getSize(mc);
			var m = { width : size.width, height : size.height, growWidth: false, growHeight: false };
			tempMovie.removeMovieClip();
//			mc.removeMovieClip();
		#end
		if (text != null) {
			metricsCache.set(text, { width: m.width, height : m.height });
		}
		return m;
	}
	
	static private var metricsCache : Hash< { width: Float, height : Float } >;

	/**
	 * Creates a clip (if construct is true) as childNo, otherwise gets existing movieclip at that point.
	 * If active is true, we also record any constructed clip in the array of active movieclips.
	 */ 
	private function getOrMakeClip(p : MovieClip, construct : Bool, childNo : Int) : MovieClip {
		if (construct) {
			#if flash9
				var clip = new MovieClip();
				p.addChild(clip);
				#if debug
					if (p.numChildren < childNo) {
						trace("Invariant broken: Expected clip to have at least " + childNo + " children");
					}
				#end
			#else flash
				var d = p.getNextHighestDepth();
				var clip = p.createEmptyMovieClip("c" + childNo, d);
				Reflect.setField(p, "c" + childNo, clip);
			#end
			movieClips.push(clip);
			clip.tabEnabled = false;
			return clip;
		} else {
			#if flash9
				if (p.numChildren < childNo) {
					// Fallback - should never happen
					return getOrMakeClip(p, true, childNo);
				} else {
					var d : Dynamic= p.getChildAt(childNo);
					return d;
				}
			#else flash
				if (Reflect.hasField(p, "c" + childNo)) {
					return Reflect.field(p, "c" + childNo);
				}
				// Fallback - should never happen
				return getOrMakeClip(p, true, childNo);
			#end
		}
	}

	private function getBlockInfo(clip : MovieClip) : BlockInfo {
		return Reflect.field(clip, "arcticInfo");
	}
	
	private function setBlockInfo(clip : MovieClip, info : BlockInfo) {
		Reflect.setField(clip, "arcticInfo", info);
	}
	
	/// Get the topmost active clip under the mouse
	private function getActiveClip() : MovieClip {
		#if flash9
			var x = flash.Lib.current.mouseX;
			var y = flash.Lib.current.mouseY;
		#else flash
			var x = flash.Lib.current._xmouse;
			var y = flash.Lib.current._ymouse;
		#end
		var i = 0;
		while (i < activeClips.length) {
			var clip = activeClips[i];
			#if flash9
				if (clip.hitTestPoint(x, y, true)) {
					return clip;
				}
			#else flash
				if (clip.hitTest(x, y, false)) {
					return clip;
				}
			#end
			++i;
		}
		return null;
	}
	
	
	#if flash9
	private function addStageEventListener(d : flash.events.EventDispatcher, event : String, handler : Dynamic) {
		d.addEventListener(event, handler);
		stageEventHandlers.push( { obj: d, event: event, handler: handler });
	}
	#end
	
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
	static public function getSize(clip : MovieClip) : { width : Float, height : Float } {
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
	
	static public function getStageSize(clip : MovieClip) : { width : Float, height : Float } {
		#if flash9
			return { width: clip.stage.stageWidth, height: clip.stage.stageHeight };
		#else flash
			return { width: flash.Stage.width, height: flash.Stage.height };
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
			if (show == null || show) {
				flash.ui.Mouse.show();
			} else {
				flash.ui.Mouse.hide();
			}
		#else flash
			if (show == null || show) {
				flash.Mouse.show();
			} else {
				flash.Mouse.hide();
			}
		#end
	}
	
}
