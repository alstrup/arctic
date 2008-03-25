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
#else neko
import neash.display.MovieClip;
import neash.text.TextField;
import neash.text.TextFieldType;
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
		size = null;

		#if (flash9||neko)
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
	/// If not using stage size, what size should we use when building?
	private var size : { width : Float, height : Float };
	
	/// This resizes the hosting movieclip to make room for our GUI block minimumsize, plus some extra space
	public function adjustToFit(extraWidth : Float, extraHeight : Float) : { width: Float, height : Float} {
		var w = build(gui, parent, 0, 0, Metrics, 0);
		ArcticMC.setSize(parent, w.width + extraWidth, w.height + extraHeight);
		size = { width: w.width + extraWidth, height: w.height + extraHeight };
		return size;
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
			size = ArcticMC.getStageSize(parent);
		} else {
			if (size == null) {
				size = ArcticMC.getSize(parent);
			}
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
	
	#if (flash9||neko)
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
		
		#if (flash9||neko)
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
			size = ArcticMC.getStageSize(parent);
			var result = build(gui, parent, size.width, size.height, Reuse, firstChild);
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
	public function refresh(rebuild : Bool): {width: Float, height: Float, base: MovieClip} {
		if (rebuild && base != null) {
			remove();
		}
		if (rebuild) {
			movieClips = [];
			idMovieClip = new Hash<ArcticMovieClip>();
			ArcticMC.showMouse();
			#if flash9
			firstChild = parent.numChildren;
			#else flash
			firstChild = ArcticMC.getNextHighestDepth(parent);
			mouseWheelListeners = new Array<{ clip: ArcticMovieClip, listener: Dynamic } >();
			#end
		}
		var result = build(gui, parent, size.width, size.height, if (rebuild) Create else Reuse, firstChild);
		base = result.clip;
		return {width: result.width, height: result.height, base: base};
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
		var activeClips = ActiveClips.get().activeClips;
		for (m in movieClips) {
			ArcticMC.remove(m);
			activeClips.remove(m);
		}
		movieClips = [];
		idMovieClip = new Hash<ArcticMovieClip>();
		base = null;
	}
	
	private function removeClip(c : ArcticMovieClip) {
		var p = ArcticMC.getParent(c);
		ArcticMC.remove(c);
		movieClips.remove(c);
		ActiveClips.get().activeClips.remove(c);

		Reflect.setField(p, "c0", null);
		
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
			}
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
		
		case Frame(thickness, color, block, roundRadius, alpha, xspacing, yspacing):
			var clip : MovieClip = getOrMakeClip(p, mode, childNo);			
			if (xspacing == null) xspacing = 0;
			if (yspacing == null) yspacing = 0;
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
				case DropShadow(distance, angle, color, alpha /*, blurX, blurY, strength, quality, inner, knockout, hideObject*/):
//					myFilter = new flash.filters.DropShadowFilter(f(distance), f(angle), c(color), f(alpha), f(blurX), f(blurY), f(strength), i(quality), b(inner), b(knockout), b(hideObject));
					myFilter = new flash.filters.DropShadowFilter(f(distance), f(angle), c(color), f(alpha));
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

		case GradientBackground(type, colors, xOffset, yOffset, block, alpha, roundRadius, rotation, ratios):
			var clip : MovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			if (mode == Metrics || colors == null || colors.length == 0) {
				return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
			}
			if (ratios == null) {
				ratios = [];
				var dt = 255 / (colors.length - 1);
				var r = 0.0;
				for (i in 0...colors.length) {
					ratios.push(Math.floor(r));
					r += dt;
				}
			}
			var alphas = [];
			for (i in 0...colors.length) {
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

		case Text(html, embeddedFont, wordWrap, selectable):
			if (wordWrap == null) {
				wordWrap = false;
			}
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
				tf.selectable = (true == selectable);
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
				tf.selectable = (true == selectable);
				tf.multiline = true;
				tf.htmlText = html;
				tf.wordWrap = wordWrap;
			#else neko
				var tf : neash.text.TextField;
				if (mode == Create || mode == Metrics) {
					tf = new neash.text.TextField();
				} else if (mode == Reuse) {
					tf = cast(clip.getChildAt(0), neash.text.TextField);
				}
				if (embeddedFont) {
					tf.embedFonts = true;
				}
				if (wordWrap) {
					tf.wordWrap = true;
					tf.width = availableWidth;
				}
				tf.autoSize = neash.text.TextFieldAutoSize.LEFT;
				tf.selectable = (true == selectable);
				tf.multiline = true;
				tf.htmlText = html;
				if (mode == Create) {
					clip.addChild(tf);
				}
			#end
			if (Arctic.textSharpness != null && mode == Create) {
				ArcticMC.setTextRenderingQuality(tf, Arctic.textSharpness, Arctic.textGridFit);
			}
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
			return { clip: clip, width: s.width, height: s.height, growWidth: wordWrap, growHeight: wordWrap };

		case TextInput(html, width, height, validator, style, maxChars, numeric, bgColor, focus, embeddedFont, onInit, onInitEvents) :
			return buildTextInput(p, childNo, mode, availableWidth, availableHeight, html, width, height, validator, style, maxChars, numeric, bgColor, focus, embeddedFont, onInit, onInitEvents);
		
		case Picture(url, w, h, scaling, resource, crop):
			if (mode == Metrics) {
				return { clip: null, width : w, height : h, growWidth : false, growHeight : false };
			}
			var clip : MovieClip = getOrMakeClip(p, mode, childNo);
			#if flash9
				// Resource version does not work
				if (mode == Create) {
					var loader = new flash.display.Loader();
					var dis = loader.contentLoaderInfo;
					var request = new flash.net.URLRequest(Arctic.baseurl + url);
					dis.addEventListener(flash.events.IOErrorEvent.IO_ERROR, function (event : flash.events.IOErrorEvent) {
						trace("[ERROR] IO Error with " + url + ": " + event.text);
					});
					dis.addEventListener(flash.events.SecurityErrorEvent.SECURITY_ERROR, function (event : flash.events.SecurityErrorEvent) {
						trace("[ERROR] Security Error with " + url + ": " + event.text);						
					});
					dis.addEventListener(flash.events.Event.COMPLETE, function(event : flash.events.Event) {
						try {
							var loader : flash.display.Loader = event.target.loader;
							if (Std.is(loader.content, flash.display.Bitmap)) {
								// Bitmaps are not smoothed per default when loading. We take care of that here
								var image : flash.display.Bitmap = cast loader.content;
								image.smoothing = true;
							}
							if (crop != null) {
								// Crop our clip in attempt to avoid spurious lines
								loader.scrollRect = new ArcticRectangle(crop, crop, loader.width - 2 * crop, loader.height - 2 * crop);
							}
						} catch (e : Dynamic) {
							// When running locally, security errors can be called when we access the content
							// of loaded files, so in that case, we have lost, and can not use nice smoothing
						}
					}
					);
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
						child = clip.attachMovie(Arctic.baseurl + url, "picture", d);
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
			return { clip: clip, width: w, height: h, growWidth: false, growHeight: false };

		case Button(block, hoverb, action, actionExt):
			if (mode == Metrics) {
				var child = build(block, null, availableWidth, availableHeight, Metrics, 0);
				if (hoverb == null) {
					return { clip: null, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
				}
				var hover = build(hoverb, null, availableWidth, availableHeight, Metrics, 1);
				return { clip: null, width: Math.max(child.width, hover.width), height: Math.max(child.height, hover.height), growWidth: child.growWidth, growHeight: child.growHeight };
			}
			var clip : MovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			if (child.clip == null) {
				#if debug
				trace("Can not make button of empty clip");
				#end
				return { clip: null, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
			}
			ArcticMC.setVisible(child.clip, true);

			var hover = null;
			if (hoverb != null) {
				hover = build(hoverb, clip, availableWidth, availableHeight, mode, 1);
			}
			// TODO: It would be nice if this hovered if the cursor was on this button, but we are not in the correct
			// position yet, so we can't do this yet! The parent would have to position us first, which is a change
			// for another day.
			
			var hasHover = hover != null && hover.clip != null;
			
			if (hasHover) {
				ArcticMC.setVisible(hover.clip, false);
			}
			#if (flash9||neko)
				child.clip.buttonMode = true;
				child.clip.mouseChildren = false;
				if (hasHover) {
					hover.clip.buttonMode = true;
					hover.clip.mouseChildren = false;
				}
				if (mode == Create) {
					if (action != null) {
						clip.addEventListener(flash.events.MouseEvent.MOUSE_UP, function(s) { 
								// TODO: To get pictures with alpha-channels to work correctly, we have to use some BitmapData magic
								// http://dougmccune.com/blog/2007/02/03/using-hittestpoint-or-hittest-on-transparent-png-images/
								if (ArcticMC.isActive(clip) && clip.hitTestPoint(flash.Lib.current.mouseX, flash.Lib.current.mouseY, true)) {
									action(); 
								}
							} ); 
					}
					if (actionExt != null) {
						addStageEventListener( clip.stage, flash.events.MouseEvent.MOUSE_UP, function(s) { 
								if (ArcticMC.isActive(clip)) {
									// TODO: To get pictures with alpha-channels to work correctly, we have to use some BitmapData magic
									// http://dougmccune.com/blog/2007/02/03/using-hittestpoint-or-hittest-on-transparent-png-images/
									actionExt(clip.mouseX, clip.mouseY, false, clip.hitTestPoint(flash.Lib.current.mouseX, flash.Lib.current.mouseY, true));
								}
							} ); 
						addStageEventListener( clip.stage, flash.events.MouseEvent.MOUSE_DOWN, function(s) { 
								if (ArcticMC.isActive(clip)) {
									// TODO: To get pictures with alpha-channels to work correctly, we have to use some BitmapData magic
									// http://dougmccune.com/blog/2007/02/03/using-hittestpoint-or-hittest-on-transparent-png-images/
									actionExt(clip.mouseX, clip.mouseY, true, clip.hitTestPoint(flash.Lib.current.mouseX, flash.Lib.current.mouseY, true));
								}
							} ); 
					}
					if (hasHover) {
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
				}
			#else flash
				if (mode == Create) {
					if (action != null || actionExt != null) {
						clip.onMouseUp = function () {
							// TODO: To get pictures with alpha-channels to work correctly, we have to use some BitmapData magic
							if (ArcticMC.isActive(clip)) {
								var hit = clip.hitTest(flash.Lib.current._xmouse, flash.Lib.current._ymouse, true);
								if (action != null && hit) {
									action();
								}
								if (actionExt != null) {
									actionExt(clip._xmouse, clip._ymouse, false, hit);
								}
							}
						}
					}
					if (actionExt != null) {
						clip.onMouseDown = function () {
							if (ArcticMC.isActive(clip)) {
								// TODO: To get pictures with alpha-channels to work correctly, we have to use some BitmapData magic
								actionExt(clip._xmouse, clip._ymouse, true, clip.hitTest(flash.Lib.current._xmouse, flash.Lib.current._ymouse, true));
							}
						}
					}
					if (hasHover) {
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
				}
			#end
			if (!hasHover) {
				return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
			}
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
					if (me.gui == null) return null;
					var oldClip = me.getOrMakeClip(clip, Reuse, 0);
					if (oldClip != null) { // remove the clip even if it's invisible
						me.removeClip(oldClip);
					}
					var childClip : MovieClip = me.getOrMakeClip(clip, Create, 0);
					return me.build(mutableBlock.block, childClip, w, h, Create, 0);
				};
			}
			var childClip : MovieClip = getOrMakeClip(clip, mode, 0);
			var result = build(mutableBlock.block, childClip, availableWidth, availableHeight, mode, 0);
			return { clip: clip, width : result.width, height: result.height, growWidth: result.growWidth, growHeight: result.growHeight };

		case Switch(blocks, current, onInit):
			var cur;
			var children : Array<Metrics> = [];
			var clip : MovieClip = getOrMakeClip(p, mode, childNo);
			if (mode == Create) {
				cur = current;
				Reflect.setField(clip, "current", cur);
			} else if (mode == Reuse) {
				cur = Reflect.field(clip, "current");
			}
			var width = 0.0;
			var height = 0.0;
			var growWidth = false;
			var growHeight = false;
			for (i in 0...blocks.length) {
				var b = blocks[i];
				var child = build(b, clip, availableWidth, availableHeight, mode, i);
				if (mode == Create) {
					children.push(child);
				}
				if (mode != Metrics) {
					ArcticMC.setVisible(child.clip, i == cur);
				}
				width = Math.max(child.width, width);
				height = Math.max(child.height, height);
				growWidth = growWidth || child.growWidth;
				growHeight = growHeight || child.growHeight;
			}
			if (mode == Create) {
				var switchFn = function (current : Int) {
					if (current != cur) {
						ArcticMC.setVisible(children[cur].clip, false);
						ArcticMC.setVisible(children[current].clip, true);
						cur = current;
						Reflect.setField(clip, "current", cur);
					}
				}
				onInit(switchFn);
			}

			return { clip: clip, width: width, height: height, growWidth: growWidth, growHeight: growHeight };

		case Filler:
			return { clip: null, width: availableWidth, height: availableHeight, growWidth: true, growHeight: true };
		
		case Fixed(width, height):
			#if debug
				if (width == null || height == null || Math.isNaN(width) || Math.isNaN(height)) {
					trace("Broken Fixed(" + width + "," + height + ") block");
				}
			#end
			return { clip: null, width: width, height: height, growWidth: false, growHeight: false };

		case Align(xpos, ypos, block):
			var clip : MovieClip = getOrMakeClip(p, mode, childNo);
			var width = availableWidth;
			var height = availableHeight;
            var child = build(block, clip, width, height, mode, 0);
			width = Math.max(width, child.width);
			height = Math.max(height, child.height);
			if (mode != Metrics && child.clip != null) {
				var x = 0.0;
				if (xpos != -1.0 && availableWidth > child.width) {
					x = (availableWidth - child.width) * xpos;
				}
				var y = 0.0;
				if (ypos != -1.0 && availableHeight > child.height) {
					y = (availableHeight - child.height) * ypos;
				}
				ArcticMC.setXY(child.clip, x, y);
			}
			return { clip: clip, width: width, height: height, growWidth: xpos != -1.0, growHeight: ypos != -1.0 };

		case ConstrainWidth(minimumWidth, maximumWidth, block) :
			// Special case: Nested constraints can be optimised a lot!
			if (mode == Metrics && minimumWidth == maximumWidth) {
				switch (block) {
					case ConstrainHeight(minHeight, maxHeight, b):
						if (minHeight == maxHeight) {
							return { clip: null, width: minimumWidth, height: minHeight, growWidth: false, growHeight: false };
						}
					default:
				}
			}
		
            var child = build(block, p, Math.max( minimumWidth, Math.min(availableWidth, maximumWidth) ), availableHeight, mode, childNo);
			if (child.width < minimumWidth) {
				child.width = minimumWidth;
			}
			if (child.width > maximumWidth) {
				child.width = maximumWidth;
			}
			return { clip: child.clip, width: child.width, height: child.height, growWidth: false, growHeight: child.growHeight };

        case ConstrainHeight(minimumHeight, maximumHeight, block) :
			// Special case: Nested constraints can be optimised a lot!
			if (mode == Metrics && minimumHeight == maximumHeight) {
				switch (block) {
					case ConstrainWidth(minWidth, maxWidth, b):
						if (minWidth == maxWidth) {
							return { clip: null, width: minWidth, height: minimumHeight, growWidth: false, growHeight: false };
						}
					default:
				}
			}
		
			var child = build(block, p, availableWidth, Math.max( minimumHeight, Math.min(availableHeight, maximumHeight) ), mode, childNo);
			if (child.height < minimumHeight) {
				child.height = minimumHeight;
			}
			if (child.height > maximumHeight) {
				child.height = maximumHeight;
			}
			return { clip: child.clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: false };
			
		case Crop(width, height, block):
			var clip : MovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(block, p, availableWidth, availableHeight, mode, childNo);
			var w = child.width;
			var h = child.height;
			if (width != null) w = width;
			if (height != null) h = height;
			if (mode != Metrics) {
				ArcticMC.clipSize(clip, w, h);
			}
			return { clip: clip, width: w, height: h, growWidth: false, growHeight: false };

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

		case LineStack(blocks, ensureVisibleIndex, disableScrollbar):
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
			
			if (disableScrollbar != false) {
				if (y - availableHeight >= 1 && availableHeight >= 34) {
					// Scrollbar
					if (mode != Metrics) {
						Scrollbar.drawScrollBar(clip, child, w, availableHeight, y, ensureY);
					}
					w += 17;
					y = availableHeight;
				} else {
					if (mode != Metrics) {
						Scrollbar.removeScrollbar(clip, child);
					}
				}
			}
			m.width = w;
			m.height = y;
			return m;
		
		case Wrap(blocks, maxWidth, xspacing, yspacing, eolFiller):
			var clip : MovieClip = getOrMakeClip(p, mode, childNo);
			var m = { clip: clip, width : 0.0, height : 0.0, growWidth : false, growHeight : false };
			
			if (maxWidth == null) {
				maxWidth = availableWidth;
				m.growWidth = true;
			}
			
			if (blocks.length == 0) {
				return m;
			}
		
			if (xspacing == null) {
				xspacing = 0;
			}
			if (yspacing == null) {
				yspacing = 0;
			}
			
			var children: Array<{block: ArcticBlock, m: Metrics}> = [];
			for (block in blocks) {
				// We want the minimum size, so do not give any extra width and height to this	
				var cm = build(block, clip, 0, 0, Metrics, 0);
				if (block != Filler) {
					m.growHeight = m.growHeight || cm.growHeight;
				}
				children.push({block: block, m: cm});
			}
			
			var newRow = function (): {blocks: Array<{block: ArcticBlock, m: Metrics}>, maxHeight: Float, width: Float, numberOfWideChildren: Int, numberOfTallChildren: Int} { 
					return {  blocks: [], maxHeight: 0.0, width: 0.0, numberOfWideChildren: 0, numberOfTallChildren: 0 };
			}
			
			var rows = [newRow()];
			for (i in 0...children.length) {
				var cm = children[i].m;
				var block = children[i].block;
				
				var row = rows[rows.length - 1];
				row.blocks.push(children[i]);
				if (cm.growWidth) {
					row.numberOfWideChildren++;
				}
				if (cm.growHeight) {
					row.numberOfTallChildren++;
				}
				// ignore Fillers
				if (block != Filler) {
					row.width += ( row.blocks.length > 1 ? xspacing : 0 ) + cm.width;
					row.maxHeight = Math.max(row.maxHeight, cm.height);
				}
				
				var next = i + 1;
				while (next < children.length && children[next].block == Filler) {
					next++;
				}
				if ( next < children.length && (row.width + xspacing + children[next].m.width) > maxWidth ) {           
					rows.push(newRow());
				}
			}
			
			// Next, determine how much space children get		
			var numOfTallRows = 0;
			var rowsHeight = yspacing * (rows.length - 1);
			for (row in rows) {
				rowsHeight += row.maxHeight;
				if (row.numberOfTallChildren > 0) {
					numOfTallRows++;
				}
			}
			var freeHeight = availableHeight - rowsHeight;
			// TODO: handle (freeHeight < 0) case
			if (numOfTallRows > 0 && freeHeight > 0) {
				freeHeight = freeHeight / numOfTallRows;
				m.growHeight = true;
			} else {
				freeHeight = 0;
			}
			
			var y = 0.0;
			var i = 0;
			var width = 0.0;
			availableWidth = Math.min(availableWidth, maxWidth);
			for (row in rows) {
				var freeWidth = availableWidth - row.width;
				if (freeWidth < 0) {
					//TODO
					freeWidth = 0;
				} else if (row.numberOfWideChildren > 0) {
					freeWidth = freeWidth / row.numberOfWideChildren;
					m.growWidth = true;
				} else if (eolFiller != null) {
					freeWidth = Math.max(0, freeWidth - xspacing);
					var cm = { clip: null, width : 0.0, height : 0.0, growWidth : true, growHeight : false };
					row.blocks.push({block: eolFiller, m: cm});
				}
			
				var h = row.maxHeight + (row.numberOfTallChildren > 0 ? freeHeight : 0); 
				var x = 0.0;
				for (entry in row.blocks) {
					var w = entry.m.width + (entry.m.growWidth ? freeWidth : 0);
					var child = build(entry.block, clip, w, h, mode, i);
					if (mode != Metrics && child.clip != null) {
						ArcticMC.setXY(child.clip, x, y);
						if (mode == Reuse) {
							ArcticMC.setVisible(child.clip, true);
						}
					}
					if (entry.block != Filler) {
						x += child.width + (entry != row.blocks[row.blocks.length - 1] ? xspacing : 0);
					}
					++i;
				}
				y += h + yspacing;
				width = Math.max(width, x);
			}
			
			if (mode == Reuse) {
				// Find and hide any left over fillers from earlier
				while (Reflect.hasField(clip, "c" + i)) {
					ArcticMC.setVisible(Reflect.field(clip, "c" + i), false);
					++i;
				}
			}

			m.width = width;
			m.height = y - yspacing;
			return m;
		
		case Grid(cells, disableScrollbar, oddRowColor, evenRowColor):
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
					// extra height check (important for text fields with wordWrap=true)
					if (b.height > lineHeights[y]) {
						lineHeights[y] = b.height;
					}
					++x;
					++i;
				}
				var color = (y + 1) % 2 == 0 ? evenRowColor : oddRowColor;
				// a fill will not be created if the color is equal to null
				if (mode != Metrics && color != null) {
					var g = ArcticMC.getGraphics(child);
					g.beginFill(color);
					DrawUtils.drawRect(child, 0, yc, xc, lineHeights[y]);
					g.endFill();
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
			
			if (disableScrollbar != true) {
				// TODO: draw horizontal scrollbar if (width > availableHeight) 
				// draw vertical scrollbar
				if (height - availableHeight >= 1 && availableHeight >= 34) {
					if (mode != Metrics) {
						Scrollbar.drawScrollBar(clip, child, width, availableHeight, height, 0);
					}
					width += 17;
					height = availableHeight;
				} else {
					if (mode != Metrics) {
						Scrollbar.removeScrollbar(clip, child);
					}
				}	
			}
		
			return { clip: clip, width: width, height: height, growWidth: false, growHeight: false };

		case ScrollBar(block, availableWidth, availableHeight):
			var clip : MovieClip = getOrMakeClip(p, mode, childNo);
            var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			if (mode != Metrics) {
				Scrollbar.drawScrollBar(clip, child.clip, availableWidth, availableHeight, child.height, 0);
			}
			return { clip: clip, width: availableWidth, height: availableHeight, growWidth: child.growWidth, growHeight: child.growHeight };

		case Dragable(stayWithin, sideMotion, upDownMotion, block, onDrag, onInit, onStopDrag):
			return buildDragable(p, childNo, mode, availableWidth, availableHeight, stayWithin, sideMotion, upDownMotion, block, onDrag, onInit, onStopDrag);

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
					if (!ArcticMC.isActive(child.clip)) {
						return;
					}
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
							if (!ArcticMC.isActive(child.clip)) {
								return;
							}
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
		
		case MouseWheel(block, onMouseWheel):
			var clip : MovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			if (mode == Create) {
				// To support empty children, we ensure that we have the right size
				ArcticMC.setSize(clip, child.width, child.height);
				#if flash9
					addStageEventListener( clip.stage, flash.events.MouseEvent.MOUSE_WHEEL,
						function (s) {
							// We do not respect alpha for mouse wheel detection
							if (ArcticMC.isActive(clip) && clip.hitTestPoint(flash.Lib.current.mouseX, flash.Lib.current.mouseY, false)) {
								onMouseWheel(s.delta);
							}
						}
					);
				#else flash
					var mouseWheelListener = { 
						onMouseDown : function() {},
						onMouseMove : function() {},
						onMouseUp : function() {},
						onMouseWheel : function ( delta : Float, target ) {
							// We do not respect alpha for mouse wheel detection
							if (ArcticMC.isActive(clip) && clip.hitTest(flash.Lib.current._xmouse, flash.Lib.current._ymouse, false)) {
								onMouseWheel(delta);
							}
						}
					};
					flash.Mouse.addListener(mouseWheelListener);
					// We record this one so we can remove it again later
					mouseWheelListeners.push({ clip: clip, listener: mouseWheelListener } );
				#end
			}
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };

		case Mask(block, mask) :
			var clip : MovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			var mask = build(mask, clip, availableWidth, availableHeight, mode, 1);
			if (mode == Create) {
				#if flash9
					child.clip.mask = mask.clip;
				#else flash
					child.clip.setMask(mask.clip);
				#end
			}
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };

		case Scale(block, maxScale):
			var clip : MovieClip = getOrMakeClip(p, mode, childNo);
			
			var metricsChild = build(block, clip, 0, 0, Metrics, 0);
			var growWidth = true;
			var growHeight = true;
			
			if (metricsChild.growHeight != metricsChild.growWidth) {
				growWidth = metricsChild.growWidth;
				growHeight = metricsChild.growHeight;
			}
			
			var scale : Null<Float> = null;
			if (metricsChild.width != 0) {
				if (availableWidth != 0) {
					var scaleX = availableWidth / metricsChild.width;
					scale = scaleX;
				}
			}
			if (metricsChild.height != 0) {
				if (availableHeight != 0) {
					var scaleY = availableHeight / metricsChild.height;
					if (scale != null) {
						scale = Math.min(scale, scaleY);
					} else {
						scale = scaleY;
					}
				}
			}
			if (scale == null) {
				scale = 1.0;
			}
			
			if (maxScale != null && scale > maxScale) {
				scale = maxScale;
				growWidth = false;
				growHeight = false;
			}
			
			var excessWidth = 0.0;
			var excessHeight = 0.0;
			if (scale >= 1.0 && metricsChild.growWidth) {
				excessWidth = availableWidth / scale;
			}
			if (scale >= 1.0 && metricsChild.growHeight) {
				excessHeight = availableHeight / scale;
			}
			//trace(availableWidth + "," + availableHeight + " " + metricsChild.width + "," + metricsChild.height + " " + scale + " " + excessWidth + "," + excessHeight);
			var child = build(block, clip, excessWidth, excessHeight, mode, 0);
			if (mode != Metrics) {
				ArcticMC.setScaleXY(child.clip, scale, scale);
			}
			return { clip: clip, width: scale * child.width, height: scale * child.height, growWidth: growWidth, growHeight: growHeight };
		
		case DebugBlock(id, block):
			var clip : MovieClip = getOrMakeClip(p, mode, childNo);
			trace("Calling build ( " + availableWidth + "," + availableHeight + ", " + mode + ") on "+ id);
			var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			trace("built (" + availableWidth + "," + availableHeight + ", " + mode + "): (" 
				+ child.width + "," + child.height + " " + child.growWidth + "," + child.growHeight + ") on " + id );
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
		}
	}
	
	private function buildTextInput(p, childNo, mode, availableWidth : Null<Float>, availableHeight : Null<Float>, html, width : Null<Float>, height : Null<Float>, validator, style, maxChars : Null<Int>, numeric : Null<Bool>, bgColor : Null<Int>, focus : Null<Bool>, embeddedFont, onInit, onInitEvents) {
		if (mode == Metrics) {
			return { clip: null, width : null != width ? width : availableWidth, height : null != height ? height : availableHeight, 
				growWidth : null == width, growHeight : null == height };
		}
		var clip : MovieClip = getOrMakeClip(p, mode, childNo);
		if (mode == Create) {
			ActiveClips.get().activeClips.push(clip);
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
			if (null != width) {
				txtInput.width = width;
			}
			if (null != height) {
				txtInput.height = height;
			}
		#else flash
			var txtInput : flash.TextField;
			if (mode == Create) {
				txtInput = ArcticMC.createTextField(clip, 0, 0, width, height);
				Reflect.setField(clip, "ti", txtInput);
			} else {
				txtInput = Reflect.field(clip, "ti");
			}
			txtInput.html = true;
		#else neko
			var txtInput : neash.text.TextField;
			if (mode == Create) {
				txtInput = new neash.text.TextField();
			} else {
				var t : Dynamic = clip.getChildAt(0);
				txtInput = t;
			}
			if (embeddedFont) {
				txtInput.embedFonts = true;
			}
			if (null != width) {
				txtInput.width = width;
			}
			if (null != height) {
				txtInput.height = height;
			}
		#end
		if (embeddedFont) {
			txtInput.embedFonts = true;
		}
		txtInput.tabEnabled = true;
		if (null != width && null != height) {
		} else {
			txtInput.autoSize = "left";	
			txtInput.wordWrap = (null != width); // wordWrap is the same as fixed width
			txtInput.multiline = (null == height); // multiline allows growing in height
		}
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
				if (isValid == true) {
					txtInput.background = (null != bgColor);
					if (txtInput.background) {
						txtInput.backgroundColor = bgColor;
					}
				} else if (isValid == false) {
					txtInput.background = true;
					txtInput.backgroundColor = 0xff0000;
				} // don't change background if isValid == null
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
				txtInput.restrict = "0-9\\-\\.";
				txtFormat.align = "right";
			}
			var lastWidth = ArcticMC.getTextFieldWidth(txtInput);
			var lastHeight = ArcticMC.getTextFieldHeight(txtInput);
			var sizeChanged = function () {
				if (null == width && lastWidth != ArcticMC.getTextFieldWidth(txtInput)) {
					lastWidth = ArcticMC.getTextFieldWidth(txtInput);
					return true;
				}
				if (null == height && lastHeight != ArcticMC.getTextFieldHeight(txtInput)) {
					lastHeight = ArcticMC.getTextFieldHeight(txtInput);
					return true;
				}
				return false;
			}
			#if flash9
				txtInput.defaultTextFormat = txtFormat;
				// Set the text again to enforce the formatting
				txtInput.htmlText = html;
				var me = this;
				var listener = (null != width && null != height) ? function (e) { validate(); }
					: function (e) { if (sizeChanged()) me.refresh(false); validate(); };
				txtInput.addEventListener(flash.events.Event.CHANGE, listener);
				clip.addChild(txtInput);
				txtInput.type = TextFieldType.INPUT;
			#else flash
				txtInput.setNewTextFormat(txtFormat);
				// Set the text again to enforce the formatting
				txtInput.htmlText = html;
				var me = this;
				var listener = {
					// TODO : Don't know why 'onKillFocus' event is not working.  'onChanged' will be annoying.
					onChanged : (null != width && null != height) ? function (txtFld : TextField) {	validate();	}
						: function (txtFld: TextField) { if (sizeChanged()) me.refresh(false); validate(); }
				};
				txtInput.addListener(listener);
				txtInput.type = "input";
			#end
		}
		if (mode != Metrics) {
			// Setting focus on txtInput 
			#if (flash9 || neko)
				if (focus != null && focus) {
					clip.stage.focus = txtInput;
					txtInput.setSelection(0, txtInput.length);
				}
			#else flash
				if (focus != null && focus) {
					flash.Selection.setFocus(txtInput);
				}
			#end
		}

		if (onInit != null) {
			#if flash9
			#else flash
			var hasFocus = focus;
			txtInput.onSetFocus = function(obj) {
				hasFocus = true;
			};
			txtInput.onKillFocus = function(obj) {
				hasFocus = false;
			};
			#end
			
			var textFn = function(status: TextInputModel) : TextInputModel {
				if (null != status) {
					if (status.html != null) {
						txtInput.htmlText = status.html;
					} else if (status.text != null) {
						txtInput.text = status.text;
					}
					if (status.focus == true) {
						#if (flash9 || neko)
							clip.stage.focus = txtInput;
							if (null == status.selStart || null == status.selEnd) {
								txtInput.setSelection(0, txtInput.length);
							}
						#else flash
							flash.Selection.setFocus(txtInput);
							hasFocus = status.focus;
						#end
					}
					if (null != status.selStart && null != status.selEnd) {
						#if (flash9 || neko)
						txtInput.setSelection(status.selStart, status.selEnd);
						#else flash
						flash.Selection.setSelection(status.selStart, status.selEnd);
						#end
					} else if (null != status.cursorPos) {
						#if (flash9 || neko)
						txtInput.setSelection(status.cursorPos, status.cursorPos);
						#else flash
						flash.Selection.setSelection(status.cursorPos, status.cursorPos);
						#end
					}
					if (status.disabled == true) {
						#if (flash9 || neko)
						txtInput.type = TextFieldType.DYNAMIC;
						#else flash
						txtInput.type = "dynamic";
						#end
					} else {
						#if (flash9 || neko)
						txtInput.type = TextFieldType.INPUT;
						#else flash
						txtInput.type = "input";
						#end
					}
				}
				
				#if (flash9 || neko)
					var focus = clip.stage.focus == txtInput;
					// temp variables to work around bugs in Null<Int> -> Int conversion
					var selStart: Null<Int> = txtInput.selectionBeginIndex;
					var selEnd: Null<Int> = txtInput.selectionEndIndex;
					var cursorPos: Null<Int> = txtInput.caretIndex;
					return { html: txtInput.htmlText, text: txtInput.text, focus: focus, selStart: focus ? selStart : null, selEnd: focus ? selEnd : null, 
							 cursorPos: focus ? cursorPos : null, disabled: txtInput.type != TextFieldType.INPUT }
				#else flash
					return { html: txtInput.htmlText, text: txtInput.text, focus: hasFocus, selStart: hasFocus ? flash.Selection.getBeginIndex() : null,
							 selEnd: hasFocus ? flash.Selection.getEndIndex() : null, cursorPos: hasFocus ? flash.Selection.getCaretIndex() : null, 
							 disabled: txtInput.type != "input" }
				#end

			}
			onInit(textFn);
		}
		
		if (onInitEvents != null) {
			var eventsFn = function (events: TextInputEvents): Void {					
				#if flash9
				addOptionalEventListener(txtInput, flash.events.Event.CHANGE, events.onChange, function (e) { events.onChange(); });
				addOptionalEventListener(txtInput, flash.events.FocusEvent.FOCUS_IN, events.onSetFocus, function (e) {
					if (e.target == txtInput) events.onSetFocus();
				});
				addOptionalEventListener(txtInput, flash.events.FocusEvent.FOCUS_OUT, events.onKillFocus, function (e) {
					if (e.target == txtInput) events.onKillFocus();
				});
				addOptionalEventListener(txtInput, flash.events.MouseEvent.MOUSE_DOWN, events.onPress, function (e) {
					events.onPress();
				});
				addOptionalEventListener(txtInput, flash.events.MouseEvent.MOUSE_UP, events.onRelease, function (e) {
					events.onRelease();
				});
				#else neko
				addOptionalEventListener(txtInput, neash.events.Event.CHANGE, events.onChange, function (e) { events.onChange(); });
				addOptionalEventListener(txtInput, neash.events.FocusEvent.FOCUS_IN, events.onSetFocus, function (e) {
					if (e.target == txtInput) events.onSetFocus();
				});
				addOptionalEventListener(txtInput, neash.events.FocusEvent.FOCUS_OUT, events.onKillFocus, function (e) {
					if (e.target == txtInput) events.onKillFocus();
				});
				addOptionalEventListener(txtInput, neash.events.MouseEvent.MOUSE_DOWN, events.onPress, function (e) {
					events.onPress();
				});
				addOptionalEventListener(txtInput, neash.events.MouseEvent.MOUSE_UP, events.onRelease, function (e) {
					events.onRelease();
				});
				#else flash
				var buildhandler = function (handler: Void -> Void) { 
					return function () {
						if (clip._xmouse >= txtInput._x && clip._xmouse < txtInput._x + txtInput._width && clip._ymouse >= txtInput._y && clip._ymouse < txtInput._y + txtInput._height) {
							handler();
						}
					}
				}
				
				txtInput.onChanged = null != events.onChange ? function (tf) { events.onChange(); } : txtInput.onChanged;
				txtInput.onSetFocus = null != events.onSetFocus ? function (tf) { events.onSetFocus(); } : txtInput.onSetFocus;
				txtInput.onKillFocus = null != events.onKillFocus ? function (tf) { events.onKillFocus(); } : txtInput.onKillFocus;
				
				clip.onMouseDown = null != events.onPress ? buildhandler(events.onPress) : clip.onMouseDown;
				clip.onMouseUp = null != events.onRelease ? buildhandler(events.onRelease) : clip.onMouseUp;
				#end
			}
			
			onInitEvents(eventsFn);
		}

		var s = ArcticMC.getSize(clip);
		return { clip: clip, width: s.width, height: s.height, growWidth: null == width, growHeight: null == height };
	}

	private function buildDragable(p, childNo, mode, availableWidth, availableHeight, stayWithin, sideMotion, upDownMotion, block, onDrag, onInit, onStopDrag) {
		
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

		var dragClip = clip; 
		if (mode == Create) {
			ActiveClips.get().activeClips.push(dragClip);
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
			setBlockInfo(dragClip, info);
		} else if (mode == Reuse) {
			info = getBlockInfo(dragClip);
			info.available = { width: availableWidth, height: availableHeight };
			info.childWidth = width;
			info.childHeight = height;
		}
		var me = this;
		var setPosition = function (x : Float, y : Float) {
			var info = me.getBlockInfo(dragClip);
			if (stayWithin) {
				x = Math.min(info.available.width - info.childWidth, x);
				y = Math.min(info.available.height - info.childHeight, y);
			}
			ArcticMC.setXY(dragClip, x, y);
			info.totalDx = x;
			info.totalDy = y;
		}; 
		
		if (mode != Create) {
			if (mode == Reuse && null != onInit) {
				var dragInfo = { 
					x : info.totalDx, 
					y : info.totalDy,
					width : info.childWidth,
					height : info.childHeight,
					totalWidth : info.available.width - info.childWidth, 
					totalHeight : info.available.height - info.childHeight 
				};
				onInit(dragInfo, setPosition);
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
						width : info.childWidth,
						height : info.childHeight,
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
					if (onStopDrag != null) {
						onStopDrag();
					}
				};
			clip.addEventListener(flash.events.MouseEvent.MOUSE_DOWN, 
				function (s) { 
					if (ActiveClips.get().getActiveClip() == dragClip) {
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
		#else flash
			clip.onMouseDown = function() {
				if (ActiveClips.get().getActiveClip() == dragClip) {
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
							if (onStopDrag != null) {
								onStopDrag();
							}
							clip.onMouseMove = null;
							clip.onMouseUp = null;
						};
					}
				}
			};
		#end

		if (null != onInit) {
			var dragInfo = { 
				x : info.totalDx, 
				y : info.totalDy, 
				width : info.childWidth,
				height : info.childHeight,
				totalWidth : info.available.width - info.childWidth, 
				totalHeight : info.available.height - info.childHeight 
			};
			onInit(dragInfo, setPosition);
		}
		return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
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
			#else (flash9 || neko)
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
		#if (flash9 || neko)
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
	
	#if flash9
	/// A nice helper function to initialize optional event handlers
	private static function addOptionalEventListener<Handler>(target: flash.events.EventDispatcher, type: String, handler: Handler, 
		flashHandler: flash.events.Event -> Void) {
		if (null != handler) {
			target.addEventListener(type, flashHandler);
		}
	}
	#end
	#if neko
	/// A nice helper function to initialize optional event handlers
	private static function addOptionalEventListener<Handler>(target: neash.events.EventDispatcher, type: String, handler: Handler, 
		flashHandler: neash.events.Event -> Void) {
		if (null != handler) {
			target.addEventListener(type, flashHandler);
		}
	}
	#end

	/// Get to the book keeping details of the given clip
	private function getBlockInfo(clip : MovieClip) : BlockInfo {
		return Reflect.field(clip, "arcticInfo");
	}
	
	/// Set the book keeping details for this clip
	private function setBlockInfo(clip : MovieClip, info : BlockInfo) {
		Reflect.setField(clip, "arcticInfo", info);
	}
	
	#if (flash9||neko)
	private function addStageEventListener(d : flash.events.EventDispatcher, event : String, handler : Dynamic) {
		d.addEventListener(event, handler);
		stageEventHandlers.push( { obj: d, event: event, handler: handler });
	}
	#end

}

class ActiveClips {
	// We are a singleton
	static private var instance : ActiveClips;
	static public function get() : ActiveClips {
		if (null == instance) {
			instance = new ActiveClips();
		}
		return instance;
	}
	private function new() {
		activeClips = [];
	}
	
	/// Get the topmost active clip under the mouse
	public function getActiveClip() : MovieClip {
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
				if (clip.hitTest(x, y, true) && ArcticMC.isActive(clip)) {
					return clip;
				}
			#end
			++i;
		}
		return null;
	}
	
	/*
	public function trace() {
		for (m in activeClips) {
			#if flash9
			trace(m.name);
			#end
		}
	}
*/	
	/// Here, we record all MovieClips that compete for mouse drags
	public var activeClips : Array<ArcticMovieClip>;
}
