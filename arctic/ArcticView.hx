package arctic;

import arctic.ArcticBlock;
import arctic.ArcticMC;

#if flash9
import flash.display.MovieClip;
import flash.text.TextField;
import flash.text.TextFieldType;
import flash.events.FocusEvent;
#else flash
import flash.MovieClip;
import flash.MovieClipLoader;
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
 * their children to make layout themselves, which build can find out.
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
	public function adjustToFit(extraWidth : Float, extraHeight : Float) : { width: Float, height : Float} {
		var w = build(gui, parent, 0, 0, Metrics, 0);
		ArcticMC.setSize(parent, w.width + extraWidth, w.height + extraHeight);
		return { width: w.width + extraWidth, height: w.height + extraHeight };
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
			ArcticMC.stageSize(parent);
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
		ArcticMC.showMouse();
		
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
			var stage = ArcticMC.getStageSize(parent);
			var result = build(gui, parent, stage.width, stage.height, Reuse, firstChild);
			base = result.clip;
		} else {
			/// This is dumb refresh, where we rebuilt everything from scratch
			if (base != null) {
				remove();
			}
			ArcticMC.stageSize(parent);
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
			ArcticMC.showMouse();
			#if flash9
			firstChild = parent.numChildren;
			#else flash
			firstChild = ArcticMC.getNextHighestDepth(parent);
			mouseWheelListeners = new Array<{ clip: ArcticMovieClip, listener: Dynamic } >();
			#end
		}
		var size;
		if (useStageSize) {
			size = ArcticMC.getStageSize(parent);
		} else {
			size = ArcticMC.getSize(parent);
		}
		
		var result = build(gui, parent, size.width, size.height, if (rebuild) Create else Reuse, firstChild);
		base = result.clip;
	}
	/// What child number is the root block on the parent clip?
	private var firstChild : Int;

	/**
	 * Use this to change the named block to the new block. You have to
	 * call refresh yourself afterwards to update the screen. See the
	 * dynamic example to see how this is done.
	 */
	public function update(id : String, block : ArcticBlock) {
		if (block == null) {
			updates.remove(id);
		} else {
			updates.set(id, block);
		}
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
		#if flash9
		#else flash
			// Clean up mouse wheel listeners
			for (s in mouseWheelListeners) {
				flash.Mouse.removeListener(s.listener);
			}
			mouseWheelListeners = [];
		#end
		for (m in movieClips) {
			ArcticMC.remove(m);
		}
		movieClips = [];
		activeClips = [];
		idMovieClip = new Hash<ArcticMovieClip>();
		base = null;
	}
	
	private function removeClip(c : ArcticMovieClip) {
		movieClips.remove(c);
		activeClips.remove(c);
		#if flash9
		#else flash
		// Clean up mouse wheel listeners
		for (s in mouseWheelListeners) {
			if (s.clip == c) {
				flash.Mouse.removeListener(s.listener);
				mouseWheelListeners.remove(s);
				return;
			}
		}
		#end
	}
	
	// We collect all generated movieclips here, so we can be sure to remove all when done
	private var movieClips : Array<ArcticMovieClip>;
	
	// Here we record active movieclips which are interested in events to implement nesting
	private var activeClips : Array<ArcticMovieClip>;

	/// We record updates of blocks here.
	private var updates : Hash<ArcticBlock>;
	
	/// And the movieclips for named ids here
	private var idMovieClip : Hash<ArcticMovieClip>;
	
	#if flash9
	#else flash
	private var mouseWheelListeners : Array< { clip: ArcticMovieClip, listener : Dynamic } >;
	#end

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
                    availableWidth : Float, availableHeight : Float, mode : BuildMode, childNo : Int) : Metrics {
#if false
		if (debug) {
			if (nesting == null) {
				nesting = "";
			} else {
				nesting = nesting + "  ";
			}
			trace(nesting + "Calling build ( " + availableWidth + "," + availableHeight + ", " + mode + ") on "+ gui);
		}
		var clip = doBuild(gui, p, availableWidth, availableHeight, mode, childNo);
		if (debug) {
			trace(nesting + "built (" + availableWidth + "," + availableHeight + ", " + mode + "): (" 
				+ clip.width + "," + clip.height + " " + clip.growWidth + "," + clip.growHeight + ") on " + gui );
			if (nesting != null) {
				nesting = nesting.substr(0, nesting.length - 2);
			}
		}

		return clip;
	}
	
	public var debug : Bool;
	private var nesting : String;
	
	private function doBuild(gui : ArcticBlock, p : MovieClip, 
                    availableWidth : Float, availableHeight : Float, mode : BuildMode, childNo : Int) : Metrics {
#end
		#if debug
			if (this == null) {
				// This should not happen, but just to be safe
				return { clip: null, width: 0.0, height: 0.0, growWidth: false, growHeight: false };
			}
		#end
		switch (gui) {
		case Border(x, y, block):
			if (mode != Metrics) {
				if (availableWidth < 2 * x) {
					x = availableWidth / 2;
				}
				if (availableHeight < 2 * y) {
					y = availableHeight / 2;
				}
			}
			var clip : MovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(block, clip, Math.max(0.0, availableWidth - 2 * x), Math.max(availableHeight - 2 * y, 0.0), mode, 0);
			child.width += 2 * x;
			child.height += 2 * y;
			if (mode != Metrics && child.clip != null) {
				ArcticMC.setXY(child.clip, x, y);
				ArcticMC.setSize(clip, child.width, child.height);
			}
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
		
		case Frame(block, thickness, color, roundRadius, alpha, xspacing, yspacing):
			var clip : MovieClip = getOrMakeClip(p, mode, childNo);			
			if (xspacing == null) xspacing = 0;
			if (yspacing == null) yspacing = 0;
			if (thickness == null) thickness = 0;
			var x = xspacing + thickness;
			var y = yspacing + thickness;
			if (x != 0 || y != 0) {
				block = Border(x, y, block);
			}	
			var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			if (mode != Metrics && thickness != 0) {
				var delta = thickness / 2;
				var g = ArcticMC.getGraphics(clip);
				g.clear();
				g.lineStyle(thickness, color, ArcticMC.convertAlpha(alpha));
				DrawUtils.drawRect(clip, delta, delta, child.width - thickness, child.height - thickness, roundRadius);
			}
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };

		case Filter(filter, block):
			var clip : MovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			#if flash6
			#else flash7
			#else flash // 8 & 9
			if (mode == Create) {
				/// We have to fix parameters that are "undefined"
				/// Since null == undefined, the following functions will change undefined to null
				/// Due to strong typing, we have a fix-up function for each parameter type. c is color, which can be Float or UInt depending on target
				var f = function (a) { return if (a == null) null else a; };
				var c = function (a) { return if (a == null) null else a; };
				var i = function (a) { return if (a == null) null else a; };
				var b = function (a) { return if (a == null) null else a; };
				var s = function (a) { return if (a == null) null else a; };

				var myFilter : Dynamic;
				switch(filter) {
				case Bevel(distance, angle, highlightColor, highlightAlpha, shadowColor, shadowAlpha, blurX, blurY, strength, quality, type, knockout):
					myFilter = new flash.filters.BevelFilter(f(distance ), f(angle), c(highlightColor), f(highlightAlpha), c(shadowColor), f(shadowAlpha), f(blurX), f(blurY), f(strength), i(quality), s(type), b(knockout));
				case Blur(blurX, blurY, quality):
					myFilter = new flash.filters.BlurFilter(f(blurX), f(blurY), i(quality));
				case ColorMatrix(matrix):
					myFilter = new flash.filters.ColorMatrixFilter(matrix);
				case Convolution(matrixX, matrixY, matrix, divisor, bias, preserveAlpha, clamp, color, alpha):
					myFilter = new flash.filters.ConvolutionFilter(f(matrixX), f(matrixY), matrix, f(divisor), f(bias), b(preserveAlpha), b(clamp), c(color), f(alpha));
				case DropShadow(distance, angle, color, alpha, blurX, blurY, strength, quality, inner, knockout, hideObject):
					myFilter = new flash.filters.DropShadowFilter(f(distance), f(angle), c(color), f(alpha), f(blurX), f(blurY), f(strength), i(quality), b(inner), b(knockout), b(hideObject));
				case Glow(color, alpha, blurX, blurY, strength, quality, inner, knockout):
					myFilter = new flash.filters.GlowFilter(c(color), f(alpha), f(blurX), f(blurY), f(strength), i(quality), b(inner), b(knockout));
				case GradientBevel(distance, angle, colors, alphas, ratios, blurX, blurY, strength, quality, type, knockout):
					myFilter = new flash.filters.GradientBevelFilter(f(distance), f(angle), colors, alphas, ratios, f(blurX), f(blurY), f(strength), i(quality), s(type), b(knockout));
				case GradientGlow(distance, angle, colors, alphas, ratios, blurX, blurY, strength, quality, type, knockout):
					myFilter = new flash.filters.GradientGlowFilter(f(distance), f(angle), colors, alphas, ratios, f(blurX), f(blurY), f(strength), i(quality), s(type), b(knockout));
				};
				// TODO: We do not support changing of Filter parameters in an update
				// We must use a temporary array (see documentation)
				var _filters = clip.filters;
				_filters.push(myFilter);
				clip.filters = _filters;
			}
			#end
			// Notice: We do not let the filter affect the size
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
		
		case Background(color, block, alpha, roundRadius):
			if (mode == Metrics) {
				return build(block, null, availableWidth, availableHeight, Metrics, 0);
			}
			var clip : MovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			// a fill will not be created if the color is equal to null
			var g = ArcticMC.getGraphics(clip);
			g.clear();
			if (color != null) {
				g.beginFill(color, ArcticMC.convertAlpha(alpha));
				DrawUtils.drawRect(clip, 0, 0, child.width, child.height, roundRadius);
				g.endFill();
			}
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };

		case GradientBackground(type, colors, xOffset, yOffset, block, alpha, roundRadius, rotation):
			var clip : MovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			if (mode == Metrics || colors == null || colors.length == 0) {
				return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
			}
			var ratios = [];
			var alphas = [];
			var dt = 255 / (colors.length - 1);
			var r = 0.0;
			for (i in 0...colors.length) {
				ratios.push(r);
				r += dt;
				if (alpha == null) {
					alphas.push(ArcticMC.convertAlpha(100.0));
				} else {
					alphas.push(ArcticMC.convertAlpha(alpha[i]));
				}
			}
			if (rotation == null) rotation = 0;
			#if flash6
			var matrix = {matrixType:"box", x:child.width * xOffset, y:child.height * yOffset, w:child.width , h: child.height , r: rotation};
			#else flash7
			var matrix = {matrixType:"box", x:child.width * xOffset, y:child.height * yOffset, w:child.width , h: child.height , r: rotation};
			#else flash
			var matrix = new flash.geom.Matrix();
			matrix.createGradientBox(child.width, child.height, rotation, child.width * xOffset, child.height * yOffset);
			#end
			var g = ArcticMC.getGraphics(clip);
			g.clear();
			#if flash9
				var t = if (type == "linear") { flash.display.GradientType.LINEAR; } else flash.display.GradientType.RADIAL;
				g.beginGradientFill(t, colors, alphas, ratios, matrix);
			#else flash
				g.beginGradientFill(type, colors, alphas, ratios, matrix);
			#end
			DrawUtils.drawRect(clip, 0, 0, child.width, child.height, roundRadius);
			g.endFill();
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };

		case Text(html, embeddedFont, wordWrap):
			if (mode == Metrics && !wordWrap && metricsCache.exists(html)) {
				var m = metricsCache.get(html);
				return { clip: null, width : m.width, height : m.height, growWidth : false, growHeight : false };
			}
			var clip : MovieClip = getOrMakeClip(p, mode, childNo);
			#if flash9
				var tf : flash.text.TextField;
				if (mode == Create || mode == Metrics) {
					tf = new flash.text.TextField();
				} else if (mode == Reuse) {
					tf = cast(clip.getChildAt(0), flash.text.TextField);
				}
				if (embeddedFont) {
					tf.embedFonts = true;
				}
				if (wordWrap) {
					tf.wordWrap = true;
					tf.width = availableWidth;
				}
				tf.autoSize = flash.text.TextFieldAutoSize.LEFT;
				tf.selectable = false;
				tf.multiline = true;
				tf.htmlText = html;
				if (mode == Create) {
					clip.addChild(tf);
				}
			#else flash
				if (mode == Metrics) {
					clip = ArcticMC.create(parent);
				}
				var tf : flash.TextField;
				if (mode == Create || mode == Metrics) {
					tf = ArcticMC.createTextField(clip, 0, 0, if (wordWrap) availableWidth else 0, 100);
					Reflect.setField(clip, "tf", tf);
				} else {
					tf = Reflect.field(clip, "tf");
					if (wordWrap) {
						tf._width = availableWidth;
					}
				}
				if (embeddedFont) {
					tf.embedFonts = true;
				}
				tf.autoSize = true;
				tf.html = true;
				tf.selectable = false;
				tf.multiline = true;
				tf.htmlText = html;
				tf.wordWrap = wordWrap;
			#end
			var s = ArcticMC.getSize(clip);
			if (mode == Metrics) {
				#if flash9
					s.width = tf.width;
					s.height = tf.height;
				#else flash
					clip.removeMovieClip();
				#end
				clip = null;
				// Cache the result
				if (!wordWrap) {
					metricsCache.set(html, s);
				}
			}
			return { clip: clip, width: s.width, height: s.height, growWidth: if (wordWrap) true else false, growHeight: false };

		case TextInput(html, width, height, validator, style, maxChars, numeric, bgColor, focus, embeddedFont) :
			if (mode == Metrics) {
				return { clip: null, width : width, height : height, growWidth : false, growHeight : false };
			}
			var clip : MovieClip = getOrMakeClip(p, mode, childNo);
			if (mode == Create) {
				activeClips.push(clip);
			}
			#if flash9
				var txtInput : flash.text.TextField;
				if (mode == Create) {
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
				if (mode == Create) {
					txtInput = ArcticMC.createTextField(clip, 0, 0, width, height);
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
			ArcticMC.setSize(clip, width, height);
			if (null != maxChars) {
				txtInput.maxChars = maxChars;
			}
			if (null != bgColor) {
				txtInput.background = true;
				txtInput.backgroundColor = bgColor;
			}
			if (mode == Create) {
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
				// Setting additional txtInput properties from the style object
				var fields = Reflect.fields(style);
				for (i in 0...fields.length){
					Reflect.setField(txtInput, fields[i], Reflect.field(style,fields[i]));
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
					var listener = function (e) { validate(); };
					txtInput.addEventListener(flash.events.Event.CHANGE, listener);
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
			}
			if (mode != Metrics) {
				// Setting focus on txtInput 
				#if flash9
					if (focus != null && focus) clip.stage.focus = txtInput;
				#else flash
					if (focus != null && focus) {
						flash.Selection.setFocus(txtInput);
					}
				#end
			}

			var s = ArcticMC.getSize(clip);
			return { clip: clip, width: s.width, height: s.height, growWidth: false, growHeight: false };

		case Picture(url, w, h, scaling, resource):
			if (mode == Metrics) {
				return { clip: null, width : w, height : h, growWidth : false, growHeight : false };
			}
			var clip : MovieClip = getOrMakeClip(p, mode, childNo);
			#if flash9
				// TODO: Resource version probably does not work
				if (mode == Create) {
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
					if (mode == Create) {
						var d = ArcticMC.getNextHighestDepth(clip);
						child = clip.attachMovie(url, "picture", d);
						Reflect.setField(clip, "picture", child);
					} else {
						child = Reflect.field(clip, "picture");
					}
					child._xscale = s;
					child._yscale = s;
				} else {
					if (mode == Create) {
						var loader = new flash.MovieClipLoader();
						var r = loader.loadClip(url, clip);
					}
					clip._xscale = s;
					clip._yscale = s;
				}
			#end
			ArcticMC.setSize(clip, w, h);
			return { clip: clip, width: w, height: h, growWidth: false, growHeight: false };

		case Button(block, hover, action):
			if (mode == Metrics) {
				var child = build(block, null, availableWidth, availableHeight, Metrics, 0);
				var hover = build(hover, null, availableWidth, availableHeight, Metrics, 1);
				return { clip: null, width: Math.max(child.width, hover.width), height: Math.max(child.height, hover.height), growWidth: child.growWidth, growHeight: child.growHeight };
			}
			var clip : MovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			var hover = build(hover, clip, availableWidth, availableHeight, mode, 1);
			if (child.clip == null || hover.clip == null) {
				#if debug
				trace("Can not make button of empty clip");
				#end
				return { clip: clip, width: Math.max(child.width, hover.width), height: Math.max(child.height, hover.height), growWidth: child.growWidth, growHeight: child.growHeight };
			}
			// TODO: It would be nice if this hovered if the cursor was on this button, but we are not in the correct
			// position yet, so we can't do this yet! The parent would have to position us first, which is a change
			// for another day.
			ArcticMC.setVisible(child.clip, true);
			ArcticMC.setVisible(hover.clip, false);
			#if flash9
				child.clip.buttonMode = true;
				child.clip.mouseChildren = false;
				hover.clip.buttonMode = true;
				hover.clip.mouseChildren = false;
				if (mode == Create) {
					if (action != null) {
						clip.addEventListener(flash.events.MouseEvent.MOUSE_UP, function(s) { 
								// TODO: To get pictures with alpha-channels to work correctly, we have to use some BitmapData magic
								// http://dougmccune.com/blog/2007/02/03/using-hittestpoint-or-hittest-on-transparent-png-images/
								if (clip.hitTestPoint(flash.Lib.current.mouseX, flash.Lib.current.mouseY, true) && ArcticMC.isActive(clip)) {
									action(); 
								}
							} ); 
					}
					addStageEventListener( clip.stage, flash.events.MouseEvent.MOUSE_MOVE, function (s) {
							// TODO: To get pictures with alpha-channels to work correctly, we have to use some BitmapData magic
							if (clip.hitTestPoint(flash.Lib.current.mouseX, flash.Lib.current.mouseY, true) && ArcticMC.isActive(clip)) {
								child.clip.visible = false;
								hover.clip.visible = true;
							} else {
								child.clip.visible = true;
								hover.clip.visible = false;
							}
						} );
					addStageEventListener( clip.stage, flash.events.Event.MOUSE_LEAVE, function() {
						child.clip.visible = true;
						hover.clip.visible = false;
					});
				}
			#else flash
				if (mode == Create) {
					clip.onMouseUp = function () {
						// TODO: To get pictures with alpha-channels to work correctly, we have to use some BitmapData magic
						if (clip.hitTest(flash.Lib.current._xmouse, flash.Lib.current._ymouse, true) && ArcticMC.isActive(clip)) {
							action();
						}
					}
					clip.onMouseMove = function() {
						// TODO: To get pictures with alpha-channels to work correctly, we have to use some BitmapData magic
						var mouseInside = child.clip.hitTest(flash.Lib.current._xmouse, flash.Lib.current._ymouse, true) && ArcticMC.isActive(clip);
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
			return { clip: clip, width: Math.max(child.width, hover.width), height: Math.max(child.height, hover.height), growWidth: child.growWidth, growHeight: child.growHeight };

		case ToggleButton(selected, unselected, initialState, onChange, onInit):
			var clip : MovieClip = getOrMakeClip(p, mode, childNo);
			var sel = build(selected, clip, availableWidth, availableHeight, mode, 0);
			var unsel = build(unselected, clip, availableWidth, availableHeight, mode, 1);
			if (mode != Metrics) {
				if (sel.clip == null || unsel.clip == null) {
					#if debug
					trace("Can not make ToggleButton of empty blocks");
					#end
				} else {
					#if flash9
						unsel.clip.buttonMode = true;
						unsel.clip.mouseChildren = false;
						sel.clip.buttonMode = true;
						sel.clip.mouseChildren = false;
						if (mode == Create) {
							sel.clip.visible = initialState;
							unsel.clip.visible = !initialState;
							var setState = function (newState : Bool) { sel.clip.visible = newState; unsel.clip.visible = !newState; }; 
							if (null != onInit) {
								onInit(setState);
							}
							clip.addEventListener(flash.events.MouseEvent.MOUSE_UP, function(s) {
									// TODO: In fact, we should check that the position at MOUSE_DOWN is on top of us as well
									if (null != onChange && clip.hitTestPoint(flash.Lib.current.mouseX, flash.Lib.current.mouseY, true) && ArcticMC.isActive(clip)) {
										setState(!sel.clip.visible);
										onChange(sel.clip.visible);
									}
								});
						}
					#else flash
						if (mode == Create) {
							sel.clip._visible = initialState;
							unsel.clip._visible = !initialState;
							var setState = function (newState : Bool) { sel.clip._visible = newState; unsel.clip._visible = !newState; }; 
							if (null != onInit) {
								onInit(setState);
							}
							clip.onMouseUp = function() {
								if (null != onChange && clip.hitTest(flash.Lib.current._xmouse, flash.Lib.current._ymouse, true) && ArcticMC.isActive(clip)) {
									setState(!sel.clip._visible);
									onChange(sel.clip._visible);
								}
							};
						}
					#end
				}
			}
			return { clip: clip, width: Math.max(sel.width, unsel.width), height: Math.max(sel.height, unsel.height), growWidth: sel.growWidth, growHeight: sel.growHeight};

		case Mutable(mutableBlock):
			var clip : MovieClip = getOrMakeClip(p, mode, childNo);
			if (mode != Metrics) {
				mutableBlock.availableWidth = availableWidth;
				mutableBlock.availableHeight = availableHeight;
			}
			if (mode == Create) {
				var me = this;
				mutableBlock.arcticUpdater = function(block : ArcticBlock, w, h) : Metrics {
					var oldClip = me.getOrMakeClip(clip, Reuse, 0);
					if (oldClip != null) {
						ArcticMC.remove(oldClip);
						me.removeClip(oldClip);
					}
					var childClip : MovieClip = me.getOrMakeClip(clip, Create, 0);
					return me.build(mutableBlock.block, childClip, w, h, mode, 0);
				};
			}
			var childClip : MovieClip = getOrMakeClip(clip, mode, 0);
			var result = build(mutableBlock.block, childClip, availableWidth, availableHeight, mode, 0);
			return { clip: clip, width : result.width, height: result.height, growWidth: result.growWidth, growHeight: result.growHeight };

		case Filler:
			return { clip: null, width: availableWidth, height: availableHeight, growWidth: true, growHeight: true };
		
		case Fixed(width, height):
			#if debug
				if (width == null || height == null || Math.isNaN(width) || Math.isNaN(height)) {
					trace("Broken Fixed(" + width + "," + height + ") block");
				}
			#end
			return { clip: null, width: width, height: height, growWidth: false, growHeight: false };

        case ConstrainWidth(minimumWidth, maximumWidth, block) :
			var clip : MovieClip = getOrMakeClip(p, mode, childNo);
            var child = build(block, clip, Math.max( minimumWidth, Math.min(availableWidth, maximumWidth) ), availableHeight, mode, 0);
			if (child.width < minimumWidth) {
				if (mode != Metrics) {
					ArcticMC.setSize(clip, minimumWidth, child.height);
				}
				child.width = minimumWidth;
			}
			if (child.width > maximumWidth) {
				if (mode != Metrics) {
					ArcticMC.clipSize(clip, maximumWidth, child.height);
				}
				child.width = maximumWidth;
			}
			return { clip: clip, width: child.width, height: child.height, growWidth: false, growHeight: child.growHeight };

        case ConstrainHeight(minimumHeight, maximumHeight, block) :
			var clip : MovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(block, clip, availableWidth, Math.max( minimumHeight, Math.min(availableHeight, maximumHeight) ), mode, 0);
			if (child.height < minimumHeight) {
				if (mode != Metrics) {
					ArcticMC.setSize(clip, child.width, minimumHeight);
				}
				child.height = minimumHeight;
			}
			if (child.height > maximumHeight) {
				if (mode != Metrics) {
					ArcticMC.clipSize(clip, child.width, maximumHeight);
				}
				child.height = maximumHeight;
			}
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: false };

		case ColumnStack(blocks):
			var clip : MovieClip = getOrMakeClip(p, mode, childNo);
			var m = { clip: clip, width : 0.0, height : 0.0, growWidth : false, growHeight : false };
			// The number of children which wants to grow (including our own fillers)
			var numberOfWideChildren = 0;
			var childMetrics = [];
			var width = 0.0;
			var maxHeight = 0.0;
			for (r in blocks) {
				// We want the minimum size, so do not give any extra width to this
				var cm = build(r, clip, 0, availableHeight, Metrics, 0);
				childMetrics.push(cm);
				if (cm.growWidth) {
					numberOfWideChildren++;
				}
				// A filler here should in itself not impact height growth in this situation
				if (r != Filler) {
					m.growHeight = m.growHeight || cm.growHeight;
					maxHeight = Math.max(maxHeight, cm.height);
				}
				width += cm.width;
			}
			if (m.growHeight) {
				maxHeight = Math.max(maxHeight, availableHeight);
			}

			// Next, determine how much space children get
            var freeSpace = availableWidth - width;
			if (freeSpace < 0) {
				// Hmm, we should do a scrollbar instead
				freeSpace = 0;
			}
			if (numberOfWideChildren > 0) {
				freeSpace = freeSpace / numberOfWideChildren;
				m.growWidth = true;
			} else {
				freeSpace = 0;
			}

			var h = 0.0;
			var x = 0.0;
			var i = 0;
			for (l in blocks) {
				var w = childMetrics[i].width + if (childMetrics[i].growWidth) freeSpace else 0;
				var child = build(l, clip, w, maxHeight, mode, i);
                // var child = build(l, clip, w, availableHeight, mode, i);
				if (mode != Metrics && child.clip != null) {
					ArcticMC.setXY(child.clip, x, null);
				}
				x += child.width;
				if (l != Filler) {
					h = Math.max(h, child.height);
				}
   				++i;
			}
			m.width = x;
			m.height = h;
			return m;

		case LineStack(blocks, ensureVisibleIndex):
			var clip : MovieClip = getOrMakeClip(p, mode, childNo);
			var m = { clip: clip, width : 0.0, height : 0.0, growWidth : false, growHeight : false };
			// Get child 0
			var child = getOrMakeClip(clip, mode, 0);

			// The number of children which wants to grow (including our own fillers)
			var numberOfTallChildren = 0;
			var childMetrics = [];
			var minimumHeight = 0.0;
			var maxWidth = 0.0;
			for (r in blocks) {
				// We want the minimum size, so do not give any extra height to this
				var rm = build(r, clip, availableWidth, 0, Metrics, 0);
				childMetrics.push(rm);
				if (rm.growHeight) {
					numberOfTallChildren++;
				}
				minimumHeight += rm.height;
				// A filler here should in itself not impact width growth in this situation
				if (r != Filler) {
					m.growWidth = m.growWidth || rm.growWidth;
					maxWidth = Math.max(maxWidth, rm.width);
				}
			}

			if (m.growWidth) {
				maxWidth = Math.max(maxWidth, availableWidth);
			}
			// Next, determine how much space children get
            var freeSpace = availableHeight - minimumHeight;
			var freeSpacePerChild = 0.0;
			
			// This is logic to try to make it such that innermost children get scrollbars, rather than outermost
			if (freeSpace < 0) {
				// See if we can free space up by shrinking children enough
				var gh = 0.0;
				var shrinkable = 0;
				var cutoffHeight = 40;
				for (cm in childMetrics) {
					if (cm.growHeight && cm.height > cutoffHeight) {
						gh += (cm.height - cutoffHeight);
						shrinkable++;
					}
				}
				if (gh >= -freeSpace) {
					// We could use knapsack to reduce children instead
					var reductionPerGrowingChild = freeSpace / shrinkable;
					for (cm in childMetrics) {
						if (cm.growHeight && cm.height > cutoffHeight) {
							cm.height += reductionPerGrowingChild;
						}
					}
					freeSpace = 0;
				}
			}
			
			if (numberOfTallChildren > 0 && freeSpace > 0) {
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
                var line = build(l, child, maxWidth, h, mode, i);
                // var line = build(l, child, availableWidth, h, mode, i);
				if (mode != Metrics && line.clip != null) {
					ArcticMC.setXY(line.clip, null, y);
				}
				if (i == ensureVisibleIndex) {
					ensureY = y;
				}
                children.push(line);
				y += line.height;
				w = Math.max(w, line.width);
				// A filler here should in itself not impact width growth in this situation
				if (l != Filler) {
					m.growWidth = m.growWidth || line.growWidth;
				}
				m.growHeight = m.growHeight || line.growHeight;
   				++i;
			}
			if (i == ensureVisibleIndex) {
				ensureY = y;
			}
			
			if (y - availableHeight >= 1 && availableHeight >= 34) {
				// Scrollbar
				if (mode != Metrics) {
					Scrollbar.drawScrollBar(clip, child, w, availableHeight, y, ensureY);
				}
				w += 17;
				y = availableHeight;
			} else {
				if (mode == Reuse) {
					Scrollbar.removeScrollbar(clip, child);
				}
			}
			m.width = w;
			m.height = y;
			return m;
		
		case Grid(cells):
			var clip : MovieClip = getOrMakeClip(p, mode, childNo);
			var child = getOrMakeClip(clip, mode, 0);

			var gridMetrics = { width : 0.0, height : 0.0, growWidth : false, growHeight : false };
			var columnWidths = [];
			var lineHeights = [];
			var y = 0;
			for (line in cells) {
				var x = 0;
				var lineHeight = 0.0;
				for (block in line) {
					// We want the minimum size, so do not give any extra space to this
					var m = build(block, clip, 0, 0, Metrics, 0);
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
					var b = build(block, child, columnWidths[x], lineHeights[y], mode, i);
					if (mode != Metrics && b.clip != null) {
						ArcticMC.setXY(b.clip, xc, yc);
					}
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
		
			return { clip: clip, width: width, height: height, growWidth: false, growHeight: false };

		case ScrollBar(block, availableWidth, availableHeight):
			var clip : MovieClip = getOrMakeClip(p, mode, childNo);
            var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			if (mode != Metrics) {
				Scrollbar.drawScrollBar(clip, child.clip, availableWidth, availableHeight, child.height, 0);
			}
			return { clip: clip, width: availableWidth, height: availableHeight, growWidth: child.growWidth, growHeight: child.growHeight };

		case Dragable(stayWithin, sideMotion, upDownMotion, block, onDrag, onInit, mouseWheel):
			var clip : MovieClip = getOrMakeClip(p, mode, childNo);
			
            var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			
			if (mode != Metrics) {
				if (child.clip == null) {
					#if debug
					trace("Can not make dragable with empty block");
					#end
					return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
				}
			}
			
			if (mode == Create) {
				activeClips.push(child.clip);
			}

			var width = child.width;
			var height = child.height;
			if (stayWithin) {
				if (sideMotion) {
					child.growWidth = true;
					child.width = Math.max(child.width, availableWidth);
				}
				if (upDownMotion) {
					child.growHeight = true;
					child.height = Math.max(child.height, availableHeight);
				}
			}
			
			if (mode == Metrics) {
				return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
			}

			var info : BlockInfo;
			if (mode == Create) {
				info = {
					available: { width: availableWidth, height: availableHeight },
					totalDx: 0.0,
					totalDy: 0.0,
					childWidth: width,
					childHeight: height
				};
				setBlockInfo(child.clip, info);
			} else if (mode == Reuse) {
				info = getBlockInfo(child.clip);
				info.available = { width: availableWidth, height: availableHeight };
				info.childWidth = width;
				info.childHeight = height;
			}
			
			if (stayWithin) {
				ArcticMC.setSize(clip, availableWidth, availableHeight);
			}
			
			var me = this;
			var dragClip = child.clip;
			var setOffset = function (dx : Float, dy : Float) {
				var info = me.getBlockInfo(dragClip);
				if (stayWithin) {
					dx = Math.min(info.available.width - info.childWidth, dx);
					dy = Math.min(info.available.height - info.childHeight, dy);
				}
				ArcticMC.moveClip(dragClip, dx, dy);
				info.totalDx = dx;
				info.totalDy = dy;
			}; 
			
			if (mode != Create) {
				if (mode == Reuse && null != onInit) {
					// Reverse movement so it's back in a second
					ArcticMC.moveClip(dragClip, -info.totalDx, -info.totalDy);
					var dragInfo = { 
						x : info.totalDx, 
						y : info.totalDy, 
						totalWidth : info.available.width - info.childWidth, 
						totalHeight : info.available.height - info.childHeight 
					};
					onInit(dragInfo, setOffset);
				}
				return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
			}
			
			var dragX = -1.0;
			var dragY = -1.0;
			
			var doDrag = function (dx : Float, dy : Float) {
				var info = me.getBlockInfo(dragClip);
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
							ArcticMC.moveClip(dragClip, dx, 0);
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
							ArcticMC.moveClip(dragClip, 0, dy);
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
						var dragInfo = { 
							x : info.totalDx, 
							y : info.totalDy, 
							totalWidth : info.available.width - info.childWidth, 
							totalHeight : info.available.height - info.childHeight 
						};
						onDrag(dragInfo);
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
						if (me.getActiveClip() == dragClip) {
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
				if (mouseWheel == true) {
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
				}
			#else flash
				clip.onMouseDown = function() {
					if (me.getActiveClip() == dragClip) {
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
				if (mouseWheel != false) {
					var mouseWheelListener = { 
						onMouseDown : function() {},
						onMouseMove : function() {},
						onMouseUp : function() {},
						onMouseWheel : function ( delta : Float, target ) {
							if (dragClip.hitTest(flash.Lib.current._xmouse, flash.Lib.current._ymouse)) {
								if (upDownMotion) {
									doDrag(0, -10 * delta);
								} else if (sideMotion) {
									doDrag(-10 * delta, 0);
								}
							}
						}
					};
					flash.Mouse.addListener(mouseWheelListener);
					// We record this one so we can remove it again later
					mouseWheelListeners.push({ clip: clip, listener: mouseWheelListener } );
				}
			#end

			if (null != onInit) {
				var dragInfo = { 
					x : info.totalDx, 
					y : info.totalDy, 
					totalWidth : info.available.width - info.childWidth, 
					totalHeight : info.available.height - info.childHeight 
				};
				onInit(dragInfo, setOffset);
			}
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
		
		case Cursor(block, cursor, keepNormalCursor) :
			var clip : MovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			if (mode == Metrics) {
				return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
			}
			if (child.clip == null) {
				#if debug
				trace("Can not make cursor of empty block");
				#end
				return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
			}
			var me = this;
			var cursorMc = null;
			// We need to construct the cursor lazily because we want it to come on top of everything
			var cursorMcFn = function() { return me.build(cursor, me.parent, 0, 0, mode, 1);};
			var keep = if (keepNormalCursor == null) true else keepNormalCursor;
			#if flash9
				var onMove = function (s) {
					if (child.clip.hitTestPoint(flash.Lib.current.mouseX, flash.Lib.current.mouseY, true)) {
						ArcticMC.showMouse(keep);
						if (cursorMc == null) {
							cursorMc = cursorMcFn();
							cursorMcFn = null;
						}
						if (cursorMc.clip == null) {
							return;
						}
						cursorMc.clip.visible = true;
						cursorMc.clip.x = me.parent.mouseX;
						cursorMc.clip.y = me.parent.mouseY;
						return;
					} else {
						if (cursorMc != null && cursorMc.clip != null) {
							cursorMc.clip.visible = false;
						}
						ArcticMC.showMouse();
					}
				};
				if (mode == Create) {
					addStageEventListener( clip.stage, flash.events.MouseEvent.MOUSE_MOVE, onMove);
					addStageEventListener( clip.stage, flash.events.Event.MOUSE_LEAVE, function() {
							if (cursorMc != null && cursorMc.clip != null) {
								cursorMc.clip.visible = false;
							}
							ArcticMC.showMouse();
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
								ArcticMC.showMouse(keep);
								return;
							} else {
								if (cursorMc != null) {
									cursorMc.clip._visible = false;
								}
								ArcticMC.showMouse();
							}
						};
				if (mode == Create) {
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
							ArcticMC.showMouse();
						};
					}
				}
				onMove();
			#end
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };

		case Offset(dx, dy, block) :
			var clip : MovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			if (mode == Create && child.clip != null) {
				ArcticMC.moveClip(child.clip, dx, dy);
			}
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
			
		case OnTop(base, overlay) :
			var clip : MovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(base, clip, availableWidth, availableHeight, mode, 0);
			var over = build(overlay, clip, availableWidth, availableHeight, mode, 1);
			return { clip: clip, width: Math.max(child.width, over.width), height: Math.max(child.height, over.height),
					growWidth: child.growWidth || over.growWidth, growHeight: child.growHeight || over.growHeight};
		 
		case Id(id, block) :
			var clip : MovieClip = getOrMakeClip(p, mode, childNo);
			if (updates.exists(id)) {
				// Refine this to send build in rebuilt if it's a new update
				var child = build(updates.get(id), clip, availableWidth, availableHeight, mode, 0);
				if (mode != Metrics) {
					idMovieClip.set(id, child.clip);
				}
				return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
			}
			var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			if (mode != Metrics) {
				idMovieClip.set(id, child.clip);
			}
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };

		case CustomBlock(data, buildFun):
			var clip : MovieClip = getOrMakeClip(p, mode, childNo);
			if (mode == Create) {
				var result = buildFun(data, mode, clip, availableWidth, availableHeight, null);
				Reflect.setField(clip, "customClip", result.clip);
				return result;
			} else if (mode == Reuse) {
				var dclip = Reflect.field(clip, "customClip");
				return buildFun(data, mode, clip, availableWidth, availableHeight, dclip);
			} else {
				return buildFun(data, mode, null, availableWidth, availableHeight, null);
			}
		}
		return null;
	}

	/// For text elements, we cache the sizes
	static private var metricsCache : Hash< { width: Float, height : Float } >;

	/**
	 * Creates a clip (if construct is true) as childNo, otherwise gets existing movieclip at that point.
	 */ 
	private function getOrMakeClip(p : MovieClip, buildMode : BuildMode, childNo : Int) : MovieClip {
		if (buildMode == Metrics) {
			return null;
		}
		if (buildMode == Create) {
			#if flash6
				var d = ArcticMC.getNextHighestDepth(p);
				p.createEmptyMovieClip("c" + childNo, d);
				var clip = Reflect.field(p, "c" + childNo);
				Reflect.setField(p, "c" + childNo, clip);
			#else flash7
				var d = p.getNextHighestDepth();
				var clip = p.createEmptyMovieClip("c" + childNo, d);
				Reflect.setField(p, "c" + childNo, clip);
			#else flash8
				var d = p.getNextHighestDepth();
				var clip = p.createEmptyMovieClip("c" + childNo, d);
				Reflect.setField(p, "c" + childNo, clip);
			#else flash9
				var clip = new MovieClip();
				p.addChild(clip);
				if (p != parent) {
					Reflect.setField(p, "c" + childNo, clip);
				} else {
					// For the parent, we use movieclip child numbers, 
					// because we can not add properties to things
					// like flash.Lib.current in Flash 9
				}
			#end
			movieClips.push(clip);
			clip.tabEnabled = false;
			return clip;
		}
		// Reuse case
		#if flash9
			if (p != parent) {
				if (Reflect.hasField(p, "c" + childNo)) {
					return Reflect.field(p, "c" + childNo);
				}
				// Fallback - should never happen
				return getOrMakeClip(p, Create, childNo);
			}
			if (p.numChildren < childNo) {
				// Fallback - should never happen
				return getOrMakeClip(p, Create, childNo);
			} else {
				var d : Dynamic= p.getChildAt(childNo);
				return d;
			}
		#else flash
			if (Reflect.hasField(p, "c" + childNo)) {
				return Reflect.field(p, "c" + childNo);
			}
			// Fallback - should never happen
			return getOrMakeClip(p, Create, childNo);
		#end
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
				if (clip.hitTest(x, y, true)) {
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

}
