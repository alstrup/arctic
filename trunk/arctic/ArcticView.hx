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
	childWidth : Float,
	childHeight : Float
}

/**
 * The main class in Arctic which builds a user interface from an ArcticBlock.
 * Construct the ArcticBlock representing your user interface and call
 * display() with a movieclip to construct it.
 * Building the user interface is a done in a depth first traversal of the
 * tree of blocks - see build. Some blocks might need to know the size of
 * their children to make layout themselves, which calcMetrics can find out.
 */
class ArcticView {

	/**
	* This prepares a user interface view of the given block on the given movieclip.
	* Nothing is displayed. Call display() to make the user interface visible.
	*/ 
	public function new(gui0 : ArcticBlock, parent0 : MovieClip) {
		gui = gui0;
		parent = parent0;
		base = null;
		useStageSize = false;
		updates = new Hash<ArcticBlock>();
		if (metricsCache == null) {
			metricsCache = new Hash<{ width: Float, height : Float } >();
		}
		#if flash9
			stageEventHandlers = [];
		#end
	}

	/// This is the block this view presents
	public var gui : ArcticBlock;
	/// The parent MovieClip which we put the view on
	public var parent : MovieClip;
	/// The root MovieClip we built for the view
	private var base : MovieClip;
	/// Whether or not we should track resizing of the Flash window
	private var useStageSize : Bool;
	
	/// This resizes the hosting movieclip to make room for our GUI block minimumsize, plus some extra space
	public function adjustToFit(extraWidth : Float, extraHeight : Float) : Void {
		var w = calcMetrics(gui, 0, 0);
		setSize(parent, w.width + extraWidth, w.height + extraHeight);
	}
	
	/**
	 * Builds the user interface. If useStageSize is true the user interface will 
	 * automatically resize to the size of the stage. If not, the user interface will
	 * be sized according to the size of the parent movieclip. You can use
	 * adjustToFit() to resize the parent to the minimum space required for the
	 * block.
	 */
	public function display(useStageSize0 : Bool) : MovieClip {
		useStageSize = useStageSize0;
		if (useStageSize) {
			stageSize(parent);
		}
		
		refresh(true);

		if (useStageSize) {
			// Make sure we follow screen resizes
			#if flash9
				parent.stage.scaleMode = flash.display.StageScaleMode.NO_SCALE;
				parent.stage.align = flash.display.StageAlign.TOP_LEFT;
				var t = this;
				addStageEventListener(parent.stage, flash.events.Event.RESIZE, function( event : flash.events.Event ) { t.onResize();} ); 
			#else flash
				flash.Stage.addListener(this);
				flash.Stage.scaleMode = "noScale";
				flash.Stage.align = "TL";
			#end
		}
        return base;
	}

	#if flash9
	/// We record all the event handlers we register so that we can clean them up again when destroyed
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
			stageEventHandlers = [];
		#end
		if (useStageSize) {
			#if flash9
			#else flash
				flash.Stage.removeListener(this);
			#end
		}
	}
	
	/// Our resize handler is called by Flash when the Flash movie is resized
	public function onResize() {
		if (true) {
			/// This is smart refresh, where we reuse MovieClips to reduce flicker
			var stage = getStageSize(parent);
			var result = build(gui, parent, stage.width, stage.height, false, 0);
			base = result.clip;
		} else {
			/// This is dumb refresh, where we rebuilt everything from scratch
			if (base != null) {
				remove();
			}
			stageSize(parent);
			refresh(true);
		}
	}

	/**
	* This will update the user interface. Useful if you have updated
	* the GUI using update() below. If you pass true, everything is built
	* from scratch.
	*/ 
	public function refresh(rebuild : Bool) {
		if (rebuild && base != null) {
			remove();
		}
		if (rebuild) {
			movieClips = [];
			activeClips = [];
			idMovieClip = new Hash<ArcticMovieClip>();
			showMouse();
		}
		var size;
		if (useStageSize) {
			size = getStageSize(parent);
		} else {
			size = getSize(parent);
		}

		var result = build(gui, parent, size.width, size.height, rebuild, 0);
		base = result.clip;
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
	* Get access to the raw movieclip for the named block.
	* Notice! This movieclip is destroyed on refresh, and thus you have to
	* do call this method again to do the special stuff you do again
	* on the new clip for the named block.
	*/
	public function getRawMovieClip(id : String) : ArcticMovieClip {
		return idMovieClip.get(id);
	}
	
	/**
	 * Removes the visual element - notice, however that if useStage is true, 
	 * the view is reconstructed on resize. Use destroy() if you want to get 
	 * rid of this display for good
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
	
	/// And the movieclips for named ids here
	private var idMovieClip : Hash<ArcticMovieClip>;

	/**
	 * This constructs or updates all the movieclips used to display the given block on the
	 * given movieclip. It will potentially fill out the available space passed. The
	 * childNo parameter is bookkeeping to who which sibling MovieClip corresponds to the
	 * root movieclip.
	 * We return the resulting root clip, along with the size of it. (We can not rely
	 * on Flash to tell the size, especially when scrollbars using Flash scrollRect
	 * feature are involved).
	 * The algorithm is a simple recursive depth first traversal of the blocks.
	 */
    private function build(gui : ArcticBlock, p : MovieClip, 
                    availableWidth : Float, availableHeight : Float, construct : Bool, childNo : Int) : { clip: MovieClip, width : Float, height : Float } {
#if false
		var clip = doBuild(gui, p, availableWidth, availableHeight, construct, childNo);
		var metrics = calcMetrics(gui, availableWidth, availableHeight);
		if (clip.width > availableWidth) {
			trace("Too wide: " + clip.width + " should be max " + availableWidth + " with " + gui);
		}
		if (clip.height > availableHeight) {
			trace("Too high: " + clip.width + " should be max " + availableWidth + " with " + gui);
		}
		if (clip.width != metrics.width) {
			trace("Metrics wrong: Is "+ clip.width + " wide but metrics say " + metrics.width + " (" + availableWidth +" available) with " + gui);
		}
		if (clip.height != metrics.height) {
			trace("Metrics wrong: Is "+ clip.height + " high but metrics say " + metrics.height + " (" + availableHeight + " available) with " + gui);
		}
		return clip;
	}
	
	private function doBuild(gui : ArcticBlock, p : MovieClip, 
                    availableWidth : Float, availableHeight : Float, construct : Bool, childNo : Int) : { clip: MovieClip, width : Float, height : Float } {
#end
//		trace("build " + availableWidth + "," + availableHeight + ": " + gui + " (might be called from calcMetrics!)");
		if (this == null) {
			// This should not happen, but just to be safe
			return { clip: null, width: 0.0, height: 0.0 };
		}
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
			#if flash9
				child.clip.x = x;
				child.clip.y = y;
			#else flash
				child.clip._x = x;
				child.clip._y = y;
			#end
			var w = child.width + 2 * x;
			var h = child.height + 2 * y;
			setSize(clip, w, h);
			return { clip: clip, width: w, height: h };
		
		case Frame(block, thickness, color, roundRadius, alpha, xspacing, yspacing):
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);			
			if (xspacing == null) xspacing = 0;
			if (yspacing == null) yspacing = 0;
			if (thickness == null) thickness = 0;
			var x = xspacing + thickness;
			var y = yspacing + thickness;
			if (x != 0 || y != 0) {
				block = Border(x, y, block);
			}	
			var child = build(block, clip, availableWidth, availableHeight, construct, 0);
			if (thickness != 0) {
				var delta = thickness / 2;
				#if flash9
					clip.graphics.clear();
					clip.graphics.lineStyle(thickness, color, if (alpha != null) alpha / 100.0 else 1.0);
				#else flash
					clip.clear();
					clip.lineStyle(thickness, color, if (alpha != null) alpha else 100);
				#end
				DrawUtils.drawRect(clip, delta, delta, child.width - thickness, child.height - thickness, roundRadius);
			}
			return { clip: clip, width: child.width, height: child.height };
		
		case Shadow(block, distance, angle, color, alpha):
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
			var child = build(block, clip, availableWidth, availableHeight, construct, 0);
			if (construct) {
				// TODO: We do not support changing of Shadow parameters in an update
				var dropShadow = new flash.filters.DropShadowFilter(distance, angle, color, alpha);
				// we must use a temporary array (see documentation)
				var _filters = clip.filters;
				_filters.push(dropShadow);
				clip.filters = _filters;
			}
			return { clip: clip, width: child.width, height: child.height };
			
		case Background(color, block, alpha, roundRadius):
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
			var child = build(block, clip, availableWidth, availableHeight, construct, 0);
			// a fill will not be created if the color is equal to null
			#if flash9
				clip.graphics.clear();
				if (color != null) {
					clip.graphics.beginFill(color, if (alpha != null) alpha / 100.0 else 100.0);
					DrawUtils.drawRect(clip, 0, 0, child.width, child.height, roundRadius);
					clip.graphics.endFill();
				}
			#else flash
				clip.clear();
				if (color != null) {
					clip.beginFill(color, if (alpha != null) alpha else 100.0);
					DrawUtils.drawRect(clip, 0, 0, child.width, child.height, roundRadius);
					clip.endFill();
				}
			#end
			return { clip: clip, width: child.width, height: child.height };

		case GradientBackground(type, colors, xOffset, yOffset, block, alpha, roundRadius, rotation):
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
			var child = build(block, clip, availableWidth, availableHeight, construct, 0);
			if (colors == null || colors.length == 0) {
				// Hm, this must be a mistake, but better safe than sorry
				return { clip: clip, width: child.width, height: child.height };
			}
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
			if (rotation == null) rotation = 0;
			#if flash9
				var matrix = new flash.geom.Matrix();
				matrix.createGradientBox(child.width, child.height, rotation, child.width * xOffset, child.height * yOffset);
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
				matrix.createGradientBox(child.width, child.height, rotation, child.width * xOffset, child.height * yOffset);
				clip.beginGradientFill(type, colors, alphas, ratios, matrix);
				DrawUtils.drawRect(clip, 0, 0, child.width, child.height, roundRadius);
				clip.endFill();
			#end
			return { clip: clip, width: child.width, height: child.height };

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
			var s = getSize(clip);
			return { clip: clip, width: s.width, height: s.height };

		case TextInput(html, width, height, validator, style, maxChars, numeric, bgColor, focus, embeddedFont) :
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
				if (embeddedFont) {
					txtInput.embedFonts = true;
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
				if (embeddedFont) {
					txtInput.embedFonts = true;
				}
				txtInput.tabEnabled = true;
				setSize(clip, width, height);
				if (null != maxChars) {
					txtInput.maxChars = maxChars;
				}
				if (null != bgColor) {
					txtInput.background = true;
					txtInput.backgroundColor = bgColor;
				}
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

			var s = getSize(clip);
			return { clip: clip, width: s.width, height: s.height };

		case Picture(url, w, h, scaling, resource):
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
			#if flash9
				// TODO: Resource version probably does not work
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
				var s = scaling * 100.0;
				if (resource) {
					var child;
					if (construct) {
						child = clip.attachMovie(url, "picture", clip.getNextHighestDepth());
						Reflect.setField(clip, "picture", child);
					} else {
						child = Reflect.field(clip, "picture");
					}
					child._xscale = s;
					child._yscale = s;
				} else {
					if (construct) {
						var loader = new flash.MovieClipLoader();
						var r = loader.loadClip(url, clip);
					}
					clip._xscale = s;
					clip._yscale = s;
				}
			#end
			setSize(clip, w, h);
			return { clip: clip, width: w, height: h };

		case Button(block, hover, action):
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
			var child = build(block, clip, availableWidth, availableHeight, construct, 0);
			var hover = build(hover, clip, availableWidth, availableHeight, construct, 1);
			#if flash9
				child.clip.buttonMode = true;
				child.clip.mouseChildren = false;
				hover.clip.buttonMode = true;
				hover.clip.mouseChildren = false;
				child.clip.visible = true;
				hover.clip.visible = false;
				if (construct) {
					clip.addEventListener(flash.events.MouseEvent.MOUSE_UP, function (s) { if (action != null) action(); } ); 
					addStageEventListener( clip.stage, flash.events.MouseEvent.MOUSE_MOVE, 
						function (s) {
							if (clip.hitTestPoint(flash.Lib.current.mouseX, flash.Lib.current.mouseY, true)) {
								child.clip.visible = false;
								hover.clip.visible = true;
							} else {
								child.clip.visible = true;
								hover.clip.visible = false;
							}
						}
					);
					addStageEventListener( clip.stage, flash.events.Event.MOUSE_LEAVE, function() {
						child.clip.visible = true;
						hover.clip.visible = false;
					});
				}
			#else flash
				child.clip._visible = true;
				hover.clip._visible = false;
				if (construct) {
					//clip.onRelease = action;
					clip.onMouseUp = function () {
						if (clip.hitTest(flash.Lib.current._xmouse, flash.Lib.current._ymouse, false) && isActive(clip)) {
							action();
						}
					}

					clip.onMouseMove = function() {
						var mouseInside = clip.hitTest(flash.Lib.current._xmouse, flash.Lib.current._ymouse, false);
						if (mouseInside) {
							child.clip._visible = false;
							hover.clip._visible = true;
						} else {
							child.clip._visible = true;
							hover.clip._visible = false;
						}
					};
					hover.clip.onRollOut = function() { 
						child.clip._visible = true;
						hover.clip._visible = false;
					};
				}
			#end
			return { clip: clip, width: Math.max(child.width, hover.width), height: Math.max(child.height, hover.height) };

		case ToggleButton(selected, unselected, initialState, onChange, onInit):
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
			var sel = build(selected, clip, availableWidth, availableHeight, construct, 0);
			var unsel = build(unselected, clip, availableWidth, availableHeight, construct, 1);
			#if flash9
				unsel.clip.buttonMode = true;
				unsel.clip.mouseChildren = false;
				sel.clip.buttonMode = true;
				sel.clip.mouseChildren = false;
				if (construct) {
					sel.clip.visible = initialState;
					unsel.clip.visible = !initialState;
					var setState = function (newState : Bool) { sel.clip.visible = newState; unsel.clip.visible = !newState; }; 
					if (null != onInit) {
						onInit(setState);
					}
					clip.addEventListener(flash.events.MouseEvent.MOUSE_UP, function(s) {
							if (null != onChange) {
								setState(!sel.clip.visible);
								onChange(sel.clip.visible);
							}
						});
				}
			#else flash
				if (construct) {
					sel.clip._visible = initialState;
					unsel.clip._visible = !initialState;
					var setState = function (newState : Bool) { sel.clip._visible = newState; unsel.clip._visible = !newState; }; 
					if (null != onInit) {
						onInit(setState);
					}
					clip.onMouseUp = function() {
						if (null != onChange && clip.hitTest(flash.Lib.current._xmouse, flash.Lib.current._ymouse, false) && isActive(clip)) {
							setState(!sel.clip._visible);
							onChange(sel.clip._visible);
						}
					};
				}
			#end
			return { clip: clip, width: Math.max(sel.width, unsel.width), height: Math.max(sel.height, unsel.height) };

		case Filler:
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
			setSize(clip, availableWidth, availableHeight);
			return { clip: clip, width: availableWidth, height: availableHeight };
		
		case Fixed(width, height):
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
			setSize(clip, width, height);
			return { clip: clip, width: width, height: height };

        case ConstrainWidth(minimumWidth, maximumWidth, block) :
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
            var child = build(block, clip, Math.max( minimumWidth, Math.min(availableWidth, maximumWidth) ), availableHeight, construct, 0);
			if (child.width < minimumWidth) {
				setSize(clip, minimumWidth, child.height);
				child.width = minimumWidth;
			}
			if (child.width > maximumWidth) {
				clipSize(clip, maximumWidth, child.height);
				child.width = maximumWidth;
			}
            return { clip: clip, width: child.width, height: child.height };

        case ConstrainHeight(minimumHeight, maximumHeight, block) :
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
			var child = build(block, clip, availableWidth, Math.max( minimumHeight, Math.min(availableHeight, maximumHeight) ), construct, 0);
			if (child.height < minimumHeight) {
				setSize(clip, child.width, minimumHeight);
				child.height = minimumHeight;
			}
			if (child.height > maximumHeight) {
				clipSize(clip, child.width, maximumHeight);
				child.height = maximumHeight;
			}
            return { clip: clip, width: child.width, height: child.height };

		case ColumnStack(blocks):
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
			// The number of children which wants to grow (including our own fillers)
			var numberOfWideChildren = 0;
			var childMetrics = [];
			var width = 0.0;
			for (r in blocks) {
				// We want the minimum size, so do not give any extra width to this
				var m = calcMetrics(r, 0, availableHeight);
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

			var h = 0.0;
			var x = 0.0;
			var i = 0;
            var children = [];
			for (l in blocks) {
				var w = childMetrics[i].width + if (childMetrics[i].growWidth) freeSpace else 0;
                var child = build(l, clip, w, availableHeight, construct, i);
				#if flash9
					child.clip.x = x;
				#else flash
					child.clip._x = x;
				#end
                children.push(child);				
				x += child.width;
				h = Math.max(h, child.height);
   				++i;
			}
			
			return { clip: clip, width: x, height: h };

		case LineStack(blocks, ensureVisibleIndex):
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
			// Get child 0
			var child = getOrMakeClip(clip, construct, 0);

			// The number of children which wants to grow (including our own fillers)
			var numberOfTallChildren = 0;
			var childMetrics = [];
			var minimumHeight = 0.0;
			for (r in blocks) {
				// We want the minimum size, so do not give any extra height to this
				var m = calcMetrics(r, availableWidth, 0);
				childMetrics.push(m);
				if (m.growHeight) {
					numberOfTallChildren++;
				}
				minimumHeight += m.height;
			}

			// Next, determine how much space children get
            var freeSpace = availableHeight - minimumHeight;
			var freeSpacePerChild = 0.0;
			if (numberOfTallChildren > 0) {
				freeSpacePerChild = freeSpace / numberOfTallChildren;
			}

			var ensureY = 0.0;
			var w = 0.0;
			var y = 0.0;
			var i = 0;
            var children = [];
			for (l in blocks) {
				var h = childMetrics[i].height + if (childMetrics[i].growHeight) freeSpacePerChild else 0;
				h = Math.max(0, h);
                var line = build(l, child, availableWidth, h, construct, i);
				#if flash9
					line.clip.y = y;
				#else flash
					line.clip._y = y;
				#end
				if (i == ensureVisibleIndex) {
					ensureY = y;
				}
                children.push(line);
				y += line.height;
				w = Math.max(w, line.width);
   				++i;
			}
			if (i == ensureVisibleIndex) {
				ensureY = y;
			}
			
			if (y > availableHeight && availableHeight >= 10) {
				// Scrollbar
				w += 12;
				Scrollbar.drawScrollBar(clip, child, w, availableHeight, y, ensureY);
				y = availableHeight;
			} else {
				if (!construct) {
					Scrollbar.removeScrollbar(clip, child);
				}
			}
			return { clip: clip, width: w, height: y };
		
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
					// We want the minimum size, so do not give any extra space to this
					var m = calcMetrics(block, 0, 0);
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
				var x = 0;
				var xc = 0.0;
				for (block in line) {
					var b = build(block, child, columnWidths[x], lineHeights[y], construct, i);
					#if flash9
						b.clip.x = xc;
						b.clip.y = yc;
					#else flash
						b.clip._x = xc;
						b.clip._y = yc;
					#end
					xc += Math.max(b.width, columnWidths[x]);
					++x;
					++i;
				}
				yc += lineHeights[y];
				++y;
			}
			var width = 0.0;
			for (w in columnWidths) {
				width += w;
			}
			var height = 0.0;
			for (h in lineHeights) {
				height += h;
			}
		
			return { clip: clip, width: width, height: height };

		case ScrollBar(block, availableWidth, availableHeight):
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
            var child = build(block, clip, availableWidth, availableHeight, construct, 0);
            Scrollbar.drawScrollBar(clip, child.clip, availableWidth, availableHeight, child.height, 0);
            return { clip: clip, width: availableWidth, height: availableHeight };

		case Dragable(stayWithin, sideMotion, upDownMotion, block, onDrag, onInit):
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
			
            var child = build(block, clip, availableWidth, availableHeight, construct, 0);
			if (construct) {
				activeClips.push(child.clip);
			}

			var width = child.width;
			var height = child.height;
			if (stayWithin) {
				if (sideMotion) {
					width = Math.max(width, availableWidth);
				}
				if (upDownMotion) {
					height = Math.max(height, availableHeight);
				}
			}
			
			var info : BlockInfo;
			if (construct) {
				info = {
					available: { width: availableWidth, height: availableHeight },
					totalDx: 0.0,
					totalDy: 0.0,
					childWidth: child.width,
					childHeight: child.height
				};
				setBlockInfo(child.clip, info);
			} else {
				info = getBlockInfo(child.clip);
				info.available = { width: availableWidth, height: availableHeight };
				info.childWidth = child.width;
				info.childHeight = child.height;
			}
			if (stayWithin) {
				setSize(clip, availableWidth, availableHeight);
			}
			
			var me = this;
			var setOffset = function (dx : Float, dy : Float) {
				var info = me.getBlockInfo(child.clip);
				if (stayWithin) {
					dx = Math.min(info.available.width - info.childWidth, dx);
					dy = Math.min(info.available.height - info.childHeight, dy);
				}
				moveClip(child.clip, dx, dy);
				info.totalDx = dx;
				info.totalDy = dy;
			}; 
			
			if (!construct) {
				if (null != onInit) {
					// Reverse movement so it's back in a second
					moveClip(child.clip, -info.totalDx, -info.totalDy);
					onInit(setOffset);
				}
				return { clip: clip, width: width, height: height};
			}
			
			var dragX = -1.0;
			var dragY = -1.0;
			
			var doDrag = function (dx : Float, dy : Float) {
				var info = me.getBlockInfo(child.clip);
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
						if (!stayWithin || (newTotalDx >= 0 && newTotalDx <= info.available.width - info.childWidth)) {
							moveClip(child.clip, dx, 0);
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
						if (!stayWithin || (newTotalDy >= 0 && newTotalDy <= info.available.height - info.childHeight)) {
							moveClip(child.clip, 0, dy);
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
						if (me.getActiveClip() == child.clip) {
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
					if (me.getActiveClip() == child.clip) {
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
						if (child.clip.hitTest(flash.Lib.current._xmouse, flash.Lib.current._ymouse)) {
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
			return { clip: clip, width: width, height: height };
		
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
					if (child.clip.hitTestPoint(flash.Lib.current.mouseX, flash.Lib.current.mouseY, true)) {
						if (cursorMc == null) {
							cursorMc = cursorMcFn();
							cursorMcFn = null;
						}
						cursorMc.clip.visible = true;
						cursorMc.clip.x = me.parent.mouseX;
						cursorMc.clip.y = me.parent.mouseY;
						showMouse(keep);
						return;
					} else {
						if (cursorMc != null) {
							cursorMc.clip.visible = false;
						}
						showMouse();
					}
				};
				if (construct) {
					addStageEventListener( clip.stage, flash.events.MouseEvent.MOUSE_MOVE, onMove);
					addStageEventListener( clip.stage, flash.events.Event.MOUSE_LEAVE, function() {
							if (cursorMc != null) {
								cursorMc.clip.visible = false;
							}
							showMouse();
						}
					);
				}
				onMove(null);
			#else flash
				
				var onMove = function() {
							if (child.clip.hitTest(flash.Lib.current._xmouse, flash.Lib.current._ymouse)) {
								if (cursorMc == null) {
									cursorMc = cursorMcFn();
									cursorMcFn = null;
								}
								cursorMc.clip._visible = true;
								cursorMc.clip._x = me.parent._xmouse;
								cursorMc.clip._y = me.parent._ymouse;
								showMouse(keep);
								return;
							} else {
								if (cursorMc != null) {
									cursorMc.clip._visible = false;
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
								cursorMc.clip._visible = false;
							}
							showMouse();
						};
					}
				}
				onMove();
			#end
			
			return { clip: clip, width: child.width, height: child.height };

		case Offset(dx, dy, block) :
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
			var child = build(block, clip, availableWidth, availableHeight, construct, 0);
			if (construct) {
				moveClip(child.clip, dx, dy);
			}
			return { clip: clip, width: child.width, height: child.height };
			
		case OnTop(base, overlay) :
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
			var child = build(base, clip, availableWidth, availableHeight, construct, 0);
			var over = build(overlay, clip, availableWidth, availableHeight, construct, 1);
			return { clip: clip, width: Math.max(child.width, over.width), height: Math.max(child.height, over.height) };
		 
		case Id(id, block) :
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
			if (updates.exists(id)) {
				// TODO: Refine this to only send true if it's a new update
				var child = build(updates.get(id), clip, availableWidth, availableHeight, construct, 0);
				idMovieClip.set(id, child.clip);
				return { clip: clip, width: child.width, height: child.height };
			}
			var child = build(block, clip, availableWidth, availableHeight, construct, 0);
			idMovieClip.set(id, child.clip);
			return { clip: clip, width: child.width, height: child.height };

		case CustomBlock(data, calcMetricsFun, buildFun):
			var clip : MovieClip = getOrMakeClip(p, construct, childNo);
			if (construct) {
				var result = buildFun(data, clip, availableWidth, availableHeight, null);
				Reflect.setField(clip, "customClip", result.clip);
				return result;
			} else {
				var clip = Reflect.field(clip, "customClip");
				return buildFun(data, clip, availableWidth, availableHeight, clip);
			}
		}
		return null;
	}

	/**
	 * This calculates the size of the given blocks, when the given space is available
	 * for layout.
	 * Special case: If availableWidth & availableHeight is 0, we calculate the minimum
	 * size required to display the block (i.e. without using scrollbars).
	 * For some blocks (like Text), we find the size of the block by temporarily constructing it,
	 * because Flash does not provide reliable APIs for getting the size in other ways.
	 * We cache the metrics for Text blocks, though.
	 */
	private function calcMetrics(c : ArcticBlock, availableWidth : Float, availableHeight : Float) : Metrics {
#if false
		var m = doCalcMetrics(c, availableWidth, availableHeight);
		trace("calcMetrics: " + m.width + "," + m.height + " " + m.growWidth + "," + m.growHeight + " avail: " + availableWidth + "," + availableHeight + ":" + c);
		return m;
	}
	
	private function doCalcMetrics(c : ArcticBlock, availableWidth : Float, availableHeight : Float) : Metrics {
#end
		var text = null;
		switch (c) {
		case Border(x, y, block):
			var m = calcMetrics(block, availableWidth, availableHeight);
			m.width += 2 * x;
			m.height += 2 * y;
			return m;
		case Frame(block, thickness, color, roundRadius, alpha, xspacing, yspacing):		
			if (xspacing == null) xspacing = 0;
			if (yspacing == null) yspacing = 0;
			if (thickness == null) thickness = 0;
			var x = xspacing + thickness;
			var y = yspacing + thickness;
			if (x != 0 || y != 0) {
				block = Border(x, y, block);
			}
			return calcMetrics(block, availableWidth, availableHeight);
		case Shadow(block, distance, angle, color, alpha):
			return calcMetrics(block, availableWidth, availableHeight);
		case Background(color, block, alpha, roundRadius):
			return calcMetrics(block, availableWidth, availableHeight);
		case GradientBackground(type, colors, xOffset, yOffset, block, alpha, roundRadius, rotation):
			return calcMetrics(block, availableWidth, availableHeight);
		case Text(html, embeddedFont):
			if (metricsCache.exists(html)) {
				var m = metricsCache.get(html);
				return { width : m.width, height : m.height, growWidth : false, growHeight : false };
			}
			text = html;
			// Fall-through to creation
		case Picture(url, w, h, scaling, resource):
			return { width : w, height : h, growWidth : false, growHeight : false };
		case Button(block, hover, action):
			return calcMetrics(block, availableWidth, availableHeight);
		case ToggleButton(selected, unselected, initialState, onChange, onInit):
			return calcMetrics(selected, availableWidth, availableHeight);
		case Filler:
			return { width : availableWidth, height : availableHeight, growWidth : true, growHeight : true };
		case Fixed(width, height):
			return { width : width, height : height, growWidth : false, growHeight : false };
        case ConstrainWidth(minimumWidth, maximumWidth, block) :
			var m = calcMetrics(block, Math.min(availableWidth, minimumWidth), availableHeight);
			m.width = Math.min(minimumWidth, Math.max(maximumWidth, m.width));
			m.growWidth = false;
			return m;
        case ConstrainHeight(minimumHeight, maximumHeight, block) :
			var m = calcMetrics(block, availableWidth, Math.min(maximumHeight, availableHeight));
			m.height = Math.min(minimumHeight, Math.max(maximumHeight, m.height));
			m.growHeight = false;
			return m;
		case TextInput(html, width, height, validator, style, maxChars, numeric, bgColor, focus, embedFont):
			return { width : width, height : height, growWidth : false, growHeight : false };
		case ColumnStack(columns):
			var m = { width : 0.0, height : 0.0, growWidth : false, growHeight : false };
			for (c in columns) {
				var cm = calcMetrics(c, 0, availableHeight);
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
				var cm = calcMetrics(c, availableWidth, 0);
				m.width = Math.max(cm.width, m.width);
				m.height += cm.height;
				// A filler here should in itself not impact width growth in this situation
				if (c != Filler) {
					m.growWidth = m.growWidth || cm.growWidth;
				}
				m.growHeight = m.growHeight || cm.growHeight;
			}
			// If we are higher, a scrollbar is added, so the resulting height is never more than availableHeight
			// except if there is no height available for the scrollbar
			if (m.height > availableHeight && availableHeight >= 10) {
				m.width += 12;
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
					var m = calcMetrics(block, 0, 0);
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
			var cm = calcMetrics(block, availableWidth, availableHeight);
			if (cm.height > availableHeight) {
				cm.height = availableHeight;
			}
			return cm;
		case Dragable(stayWithin, sideMotion, upDownMotion, block, onDrag, onInit):
			var m = calcMetrics(block, availableWidth, availableHeight);
			if (stayWithin) {
				if (sideMotion) {
					m.growWidth = true;
					m.width = Math.max(m.width, availableWidth);
				}
				if (upDownMotion) {
					m.growHeight = true;
					m.height = Math.max(m.height, availableHeight);
				}
			}
			return m;
		case Cursor(block, cursor, keepNormalCursor) :
			return calcMetrics(block, availableWidth, availableHeight);
		case Offset(dx, dy, block):
			return calcMetrics(block, availableWidth, availableHeight);
		case OnTop(base, overlay) :
			var m1 = calcMetrics(base, availableWidth, availableHeight);
			var m2 = calcMetrics(overlay, availableWidth, availableHeight);
			m1.width = Math.max(m1.width, m2.width);
			m1.height = Math.max(m1.height, m2.height);
			m1.growWidth = m1.growWidth || m2.growWidth;
			m1.growHeight = m1.growHeight || m2.growHeight;
			return m1;
		case Id(id, block) :
			if (updates.exists(id)) {
				return calcMetrics(updates.get(id), availableWidth, availableHeight);
			}
			return calcMetrics(block, availableWidth, availableHeight);
		case CustomBlock(data, calcMetricsFun, buildFun):
			if (calcMetricsFun != null) {
				return calcMetricsFun(data, availableWidth, availableHeight);
			}
			// Fall through to creation
		}

		// The sad fall-back scenario: Create the fucker and ask it, and then destroy it again
		#if flash9
			var tempMovie = new MovieClip();
			parent.addChild(tempMovie);
			var mc = build(c, tempMovie, availableWidth, availableHeight, true, 0);
			var m = { width : mc.width, height : mc.height, growWidth: false, growHeight: false };
			parent.removeChild(tempMovie);
		#else flash
			var d = parent.getNextHighestDepth();
			var tempMovie = parent.createEmptyMovieClip("c" + d, d);
			var mc = build(c, tempMovie, availableWidth, availableHeight, true, 0);
			var m = { width : mc.width, height : mc.height, growWidth: false, growHeight: false };
			tempMovie.removeMovieClip();
//			mc.removeMovieClip();
		#end
		if (text != null) {
			metricsCache.set(text, { width: m.width, height : m.height });
		}
		return m;
	}
	
	/// For text elements, we cache the sizes
	static private var metricsCache : Hash< { width: Float, height : Float } >;

	/**
	 * Creates a clip (if construct is true) as childNo, otherwise gets existing movieclip at that point.
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

	/// Get to the book keeping details of the given clip
	private function getBlockInfo(clip : MovieClip) : BlockInfo {
		return Reflect.field(clip, "arcticInfo");
	}
	
	/// Set the book keeping details for this clip
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
	 * Notice also that it clears out any graphics that might exist in the clip.
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
			return { width: cast(clip.stage.stageWidth, Float), height: cast(clip.stage.stageHeight, Float) };
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
	
	/// Returns true when the clip is visible and enabled
	static function isActive(clip: MovieClip): Bool {
		if (clip == null) return false;
		
		var active = true;
		#if flash9
			active = clip.visible && clip.enabled;
			var parent = clip.parent;
			while (null != parent && active) {
				active = active && parent.visible && parent.mouseEnabled;
				parent = parent.parent;
			}	
		#else flash
			var parent = clip;
			while (null != parent && active) {
				active = active && parent._visible && parent.enabled;
				parent = parent._parent;
			}
		#end
		
		return active;
	}
}
