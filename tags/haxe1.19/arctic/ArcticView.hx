package arctic;
import arctic.ArcticBlock;
import arctic.ArcticMC;
import haxe.Timer;

#if flash9
import flash.geom.Matrix;
import flash.geom.Point;
import flash.display.DisplayObjectContainer;
import flash.events.Event;
import flash.events.EventDispatcher;
import flash.events.FocusEvent;
import flash.events.MouseEvent;
import flash.text.TextField;
import flash.text.TextFieldType;
import flash.display.DisplayObject;
import flash.display.Bitmap;
import flash.display.Loader;
import flash.display.BitmapData;
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
	public function new(gui0 : ArcticBlock, parent0 : ArcticMovieClip) {
		gui = gui0;
		parent = parent0;
		base = null;
		useStageSize = false;
		if (metricsCache == null) {
			metricsCache = new Hash<{ width: Float, height : Float } >();
		}
		size = null;
		pendingPictureRequests = 0;

		#if (flash9||neko)
			stageEventHandlers = [];
		#end

		#if flash9
		if (pictureCache == null) {
			pictureCache = new Hash();
		}
		#end
		#if debug
		trackMemory = false;
		#end
	}

	/// This is the block this view presents
	public var gui : ArcticBlock;
	/// The parent MovieClip which we put the view on
	public var parent : ArcticMovieClip;
	/// The root ArcticMovieClip we built for the view
	private var base : ArcticMovieClip;
	/// Whether or not we should track resizing of the Flash window
	private var useStageSize : Bool;
	/// If not using stage size, what size should we use when building?
	private var size : { width : Float, height : Float };
	
	/// This resizes the hosting movieclip to make room for our GUI block minimumsize, plus some extra space
	public function adjustToFit(extraWidth : Float, extraHeight : Float) : { width: Float, height : Float} {
		#if debug
		currentPath = "";
		currentBlockKind = "";
		#end
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
	public function display(useStageSize0 : Bool) : ArcticMovieClip {
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
				addStageEventListener(parent, parent.stage, flash.events.Event.RESIZE, function( event : flash.events.Event ) { t.onResize();} ); 
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
	private var stageEventHandlers : Array<{ obj: EventDispatcher, event : String, handler : Dynamic, ref : Dynamic } >;
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
			#if debug
			currentPath = "";
			currentBlockKind = "";
			#end
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
	public function refresh(rebuild : Bool): {width: Float, height: Float, base: ArcticMovieClip} {
		if (rebuild && base != null) {
			remove();
		}
		if (rebuild) {
			idMovieClip = new Hash<ArcticMovieClip>();
			ArcticMC.showMouse();
			#if flash9
			firstChild = parent.numChildren;
			// remove stage listeners
			for (e in stageEventHandlers) {
				e.obj.removeEventListener(e.event, e.handler);
			}
			stageEventHandlers = [];
			#else flash
			firstChild = ArcticMC.getNextHighestDepth(parent);
			mouseWheelListeners = new Array<{ clip: ArcticMovieClip, listener: Dynamic } >();
			#end
		}
		#if debug
		currentPath = "";
		currentBlockKind = "";
		#end
		var result = build(gui, parent, size.width, size.height, if (rebuild) Create else Reuse, firstChild);
		base = result.clip;
		return {width: result.width, height: result.height, base: base};
	}
	/// What child number is the root block on the parent clip?
	private var firstChild : Int;

	/**
	* Get access to the raw movieclip for the named block.
	* Notice! This movieclip is destroyed on refresh, and thus you have to
	* do call this method again to do the special stuff you do again
	* on the new clip for the named block.
	*/
	public function getRawMovieClip(id : String) : ArcticMovieClip {
		if (idMovieClip != null) return idMovieClip.get(id);
		else return null;
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
		#if debug
		currentPath = "";
		currentBlockKind = "";
		#end
		var result = build(gui, parent, size.width, size.height, Destroy, firstChild);
		ArcticMC.remove(base);
		#if flash9
		#else flash
		ArcticMC.delete(parent, "c" + firstChild);
		#end
		idMovieClip = new Hash<ArcticMovieClip>();
		base = null;
	}

	/// And the movieclips for named ids here
	private var idMovieClip : Hash<ArcticMovieClip>;
	
	#if flash9
	#else flash
	private var mouseWheelListeners : Array< { clip: ArcticMovieClip, listener : Dynamic } >;
	#end

	/**
	 * This constructs or updates all the movieclips used to display the given block on the
	 * given movieclip. It will potentially fill out the available space passed. The
	 * childNo parameter is bookkeeping to who which sibling ArcticMovieClip corresponds to the
	 * root movieclip.
	 * We return the resulting root clip, along with the size of it. (We can not rely
	 * on Flash to tell the size, especially when scrollbars using Flash scrollRect
	 * feature are involved).
	 * The algorithm is a simple recursive depth first traversal of the blocks.
	 */
    private function build(gui : ArcticBlock, p : ArcticMovieClip, 
                    availableWidth : Float, availableHeight : Float, mode : BuildMode, childNo : Int) : Metrics {
#if false
		if (mode == Destroy) {
			if (nesting == null) {
				nesting = "";
			} else {
				nesting = nesting + "  ";
			}
			trace(nesting + currentPath + "Calling build ( " + availableWidth + "," + availableHeight + ", " + mode + ") on "+ gui);
		}
		var clip = doBuild(gui, p, availableWidth, availableHeight, mode, childNo);
		if (mode == Destroy) {
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
	
	private function doBuild(gui : ArcticBlock, p : ArcticMovieClip, 
                    availableWidth : Float, availableHeight : Float, mode : BuildMode, childNo : Int) : Metrics {
#end
		#if debug
			if (gui == null) {
				currentBlockKind = "empty";
			} else {
				currentBlockKind = Type.enumConstructor(gui);
			}
			currentPath += "/" + currentBlockKind;
		#end

		if (gui == null) {
			/* This can happen (at least) because of the call
			   
						var result = build(mutableBlock.block, childClip, availableWidth, availableHeight, mode, 0);

			   in the case for Mutable.
			*/
			return { clip: null, width: 0.0, height: 0.0, growWidth: false, growHeight: false };
		}
		switch (gui) {
		case Border(x, y, block):
			if (mode != Metrics && mode != Destroy) {
				if (availableWidth < 2 * x) {
					x = availableWidth / 2;
				}
				if (availableHeight < 2 * y) {
					y = availableHeight / 2;
				}
			}
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(block, clip, Math.max(0.0, availableWidth - 2 * x), Math.max(availableHeight - 2 * y, 0.0), mode, 0);
			child.width += 2 * x;
			child.height += 2 * y;
			if ((mode == Create || mode == Reuse) && child.clip != null) {
				ArcticMC.setXY(child.clip, x, y);
			}
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
		
		case Frame(thickness, color, block, roundRadius, alpha, xspacing, yspacing):
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);			
			if (xspacing == null) xspacing = 0;
			if (yspacing == null) yspacing = 0;
			var x = xspacing + thickness;
			var y = yspacing + thickness;
			if (x != 0 || y != 0) {
				block = Border(x, y, block);
			}
			var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			if ((mode == Create || mode == Reuse) && thickness != 0) {
				var delta = thickness / 2;
				var g = ArcticMC.getGraphics(clip);
				g.clear();
				g.lineStyle(thickness, color, ArcticMC.convertAlpha(alpha));
				DrawUtils.drawRect(clip, delta, delta, child.width - thickness, child.height - thickness, roundRadius);
			}
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };

		case Filter(filter, block):
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
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
				return build(block, null, availableWidth, availableHeight, mode, 0);
			}
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			if (mode != Destroy) {
				// a fill will not be created if the color is equal to null
				var g = ArcticMC.getGraphics(clip);
				g.clear();
				if (color != null) {
					g.beginFill(color, ArcticMC.convertAlpha(alpha));
					DrawUtils.drawRect(clip, 0, 0, child.width, child.height, roundRadius);
					g.endFill();
				}
			}
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };

		case GradientBackground(type, colors, xOffset, yOffset, block, alpha, roundRadius, rotation, ratios):
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			if (mode == Metrics || mode == Destroy || colors == null || colors.length == 0) {
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
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			if (mode == Destroy) {
				return { clip: clip, width: 0.0, height: 0.0, growWidth: wordWrap, growHeight: wordWrap };
			}
			#if flash9
				var tf : flash.text.TextField;
				if (mode == Create || mode == Metrics) {
					tf = new flash.text.TextField();
					if (mode == Create) {
						ArcticMC.set(clip, "tf", tf);
					}
				} else if (mode == Reuse) {
					tf = ArcticMC.get(clip, "tf");
					if (tf == null) {
						return { clip: clip, width: 0.0, height: 0.0, growWidth: wordWrap, growHeight: wordWrap };						
					}
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
					ArcticMC.set(clip, "tf", tf);
				} else {
					tf = ArcticMC.get(clip, "tf");
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
			/* This stuff is useful, but breaks lots of layouts so we have to disable it and find some way to introduce it without breaking stuff:
			#if flash9
				if (wordWrap) {
					// If we are word wrapped and there is plenty of room in the width, we shrink ourselves accordingly
					if (s.width - tf.textWidth > 5) {
						tf.width = tf.textWidth + 5;
					}
					s = ArcticMC.getSize(clip);
				}
			#end
			*/
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
		
		case Picture(url, w, h, scaling, resource, crop, cache):
			if (mode == Metrics) {
				return { clip: null, width : w, height : h, growWidth : false, growHeight : false };
			}
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			#if flash9
				if (mode == Create) {
					if (Type.resolveClass(url) != null) {
						var loader = flash.Lib.attach(url);
						clip.addChild(loader);
					} else {
						var cachedPicture:Dynamic = pictureCache.get(url);
						if (cachedPicture != null) {
							//trace("in cache:" + url, 0);
							var clone : BitmapData = cachedPicture.clone(); 
							var bmp:Bitmap = new Bitmap(clone);
							bmp.smoothing = true;
							
							clip.addChild(bmp);
						}
						else {
							// Count how many pictures we are loading
							pendingPictureRequests++;
							var loader = new flash.display.Loader();
							clip.addChild(loader);
							var dis = loader.contentLoaderInfo;
							var request = new flash.net.URLRequest(Arctic.baseurl + url);
						
							dis.addEventListener(flash.events.IOErrorEvent.IO_ERROR, function (event : flash.events.IOErrorEvent) {
								trace("[ERROR] IO Error with " + url + ": " + event.text);
							});
							dis.addEventListener(flash.events.SecurityErrorEvent.SECURITY_ERROR, function (event : flash.events.SecurityErrorEvent) {
								trace("[ERROR] Security Error with " + url + ": " + event.text);						
							});
							var me = this;
												
							dis.addEventListener(flash.events.Event.COMPLETE, function(event : flash.events.Event) {
								try {
									var loader : flash.display.Loader = event.target.loader;
									var content:Dynamic = loader.content;
									//trace(loader.content);
									if (Std.is(content, flash.display.Bitmap)) {
										//trace("isbmp", 0);
										// Bitmaps are not smoothed per default when loading. We take care of that here
										var image : flash.display.Bitmap = cast loader.content;
										image.smoothing = true;
										if (cache == true) {
											pictureCache.set(url, image.bitmapData);
										}
									} else {
										var className:String = untyped __global__["flash.utils.getQualifiedClassName"](content);
										if (className == "flash.display::AVM1Movie") {
											//trace("url:" + url + " is AVM1. Caching", 0);
											var width = content.width;
											var height = content.height;
											var transparent = true;
											var bmpData:BitmapData = new BitmapData(width, height, transparent, 0);
											bmpData.draw(content);
											if (cache == true){
												pictureCache.set(url, bmpData);
											}
										}
										//else {
											//trace("url:" + url + " is:" + className + " ignore", 0);
										//}
									}
									if (crop != null) {
										// Crop our clip in attempt to avoid spurious lines
										loader.scrollRect = new ArcticRectangle(crop, crop, loader.width - 2 * crop, loader.height - 2 * crop);
									}
									if (me.pictureLoadedFn != null) {
										me.pictureLoadedFn(--me.pendingPictureRequests);
									}
								} catch (e : Dynamic) {
									// When running locally, security errors can be called when we access the content
									// of loaded files, so in that case, we have lost, and can not use nice smoothing
								}
							}
							);
							loader.load(request);						
						}
					}
					var s = scaling;
					clip.scaleX = s;
					clip.scaleY = s;
				}
			#else flash
				var s = scaling * 100.0;
				if (resource) {
					var child;
					if (mode == Create) {
						var d = ArcticMC.getNextHighestDepth(clip);
						child = clip.attachMovie(Arctic.baseurl + url, "picture", d);
						ArcticMC.set(clip, "picture", child);
						child._xscale = s;
						child._yscale = s;
					}
				} else {
					if (mode == Create) {
						var loader = new flash.MovieClipLoader();
						var r = loader.loadClip(url, clip);
						clip._xscale = s;
						clip._yscale = s;
					}
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
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			if (child.clip == null && mode != Destroy) {
				#if debug
				trace("Can not make button of empty clip");
				#end
				return { clip: null, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
			}
			var hover = null;
			if (hoverb != null) {
				hover = build(hoverb, clip, availableWidth, availableHeight, mode, 1);
			}
			// TODO: It would be nice if this hovered if the cursor was on this button, but we are not in the correct
			// position yet, so we can't do this yet! The parent would have to position us first, which is a change
			// for another day.
			
			var hasHover = hover != null && hover.clip != null;
			if (mode == Destroy) {
				removeStageEventListeners(clip);
				if (!hasHover) {
					return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
				} else {
					return { clip: clip, width: Math.max(child.width, hover.width), height: Math.max(child.height, hover.height), growWidth: child.growWidth, growHeight: child.growHeight };
				}
			}

			ArcticMC.setVisible(child.clip, true);
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
					#if arcticevidence
					var aem = ArcticEvidenceManager.get();
					var abId = ArcticEvidenceManager.idFromArctic(block);
					#end
					if (action != null) {
						#if arcticevidence
						var eventName = "buttonclick";
						aem.registerReplayer(eventName, abId, action);
						#end
						clip.addEventListener(MouseEvent.MOUSE_UP, function(s) { 
								var m = ArcticMC.getMouseXY();
								// TODO: To get pictures with alpha-channels to work correctly, we have to use some BitmapData magic
								// http://dougmccune.com/blog/2007/02/03/using-hittestpoint-or-hittest-on-transparent-png-images/
								if (ArcticMC.isActive(clip) && clip.hitTestPoint(m.x, m.y, true)) {
									#if arcticevidence
									aem.recordEvent(eventName, abId, []);
									#end
									action(); 
								}
							} ); 
					}
					if (actionExt != null) {
						#if arcticevidence
						var eventName = "buttonclickxyup";
						aem.registerReplayer(eventName, abId, actionExt);
						#end
						addStageEventListener( clip, clip.stage, MouseEvent.MOUSE_UP, function(s) { 
								if (ArcticMC.isActive(clip)) {
									// TODO: To get pictures with alpha-channels to work correctly, we have to use some BitmapData magic
									// http://dougmccune.com/blog/2007/02/03/using-hittestpoint-or-hittest-on-transparent-png-images/
									var m = ArcticMC.getMouseXY();
									#if arcticevidence
									aem.recordEvent(eventName, abId, 
													[clip.mouseX, clip.mouseY, false,
													 clip.hitTestPoint(m.x, m.y, true)]);
									#end
									actionExt(clip.mouseX, clip.mouseY, false,
											  clip.hitTestPoint(m.x, m.y, true));
								}
							} );
						#if arcticevidence
						var eventName = "buttonclickxydown";
						aem.registerReplayer(eventName, abId, actionExt);
						#end
						addStageEventListener( clip, clip.stage, MouseEvent.MOUSE_DOWN, function(s) { 
								if (ArcticMC.isActive(clip)) {
									// TODO: To get pictures with alpha-channels to work correctly, we have to use some BitmapData magic
									// http://dougmccune.com/blog/2007/02/03/using-hittestpoint-or-hittest-on-transparent-png-images/
									var m = ArcticMC.getMouseXY();
									#if arcticevidence
									aem.recordEvent(eventName, abId, 
													[clip.mouseX, clip.mouseY, true,
													 clip.hitTestPoint(m.x, m.y, true)]);
									#end
									actionExt(clip.mouseX, clip.mouseY, true,
											  clip.hitTestPoint(m.x, m.y, true));
								}
							} );
					}
					if (hasHover) {
						addStageEventListener( clip, clip.stage, MouseEvent.MOUSE_MOVE, function (s) {
								var m = ArcticMC.getMouseXY();
								// TODO: To get pictures with alpha-channels to work correctly, we have to use some BitmapData magic
								if (clip.hitTestPoint(m.x, m.y, true) && ArcticMC.isActive(clip)) {
									child.clip.visible = false;
									hover.clip.visible = true;
								} else {
									child.clip.visible = true;
									hover.clip.visible = false;
								}
							} );
						addStageEventListener( clip, clip.stage, Event.MOUSE_LEAVE, function() {
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
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			var sel = build(selected, clip, availableWidth, availableHeight, mode, 0);
			var unsel = build(unselected, clip, availableWidth, availableHeight, mode, 1);
			if (mode != Metrics && mode != Destroy) {
				if (sel.clip == null || unsel.clip == null) {
					#if debug
					trace("Can not make ToggleButton of empty blocks");
					#end
				} else {
					#if flash9
						unsel.clip.buttonMode = true;
						sel.clip.buttonMode = true;
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
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			if (mode != Metrics) {
				mutableBlock.availableWidth = availableWidth;
				mutableBlock.availableHeight = availableHeight;
			}
			if (mode == Create) {
				var me = this;
				mutableBlock.arcticUpdater = function(oldBlock : ArcticBlock, block : ArcticBlock, w, h) : Void {
					if (me.gui == null) {
						return;
					}
					var oldClip = me.getOrMakeClip(clip, Destroy, 0);
 					if (oldBlock != null) {
						#if debug
						me.currentPath = "destroy Mutable/";
						me.currentBlockKind = "Mutable";
						#end
 						me.build(oldBlock, oldClip, w, h, Destroy, 0);
 					}
					if (oldClip != null) {
						ArcticMC.remove(oldClip);
					}
					// Hm, nothing to do
					if (block == null) {
						return;
					}
					#if debug
					me.currentPath = "update Mutable/";
					me.currentBlockKind = "Mutable";
					#end
					var childClip : ArcticMovieClip = me.getOrMakeClip(clip, Create, 0);
					me.build(mutableBlock.block, childClip, w, h, Create, 0);
				};
			} else if (mode == Destroy) {
				// Get rid of the old stuff
				mutableBlock.destroy();
				// And then we stop!
				return { clip: clip, width : 0.0, height: 0.0, growWidth: false, growHeight: false };
			}
			var childClip : ArcticMovieClip = getOrMakeClip(clip, mode, 0);
			var result = build(mutableBlock.block, childClip, availableWidth, availableHeight, mode, 0);
			return { clip: clip, width : result.width, height: result.height, growWidth: result.growWidth, growHeight: result.growHeight };

		case Switch(blocks, current, onInit):
			var cur;
			var children : Array<Metrics> = [];
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			if (mode == Create) {
				cur = current;
				ArcticMC.set(clip, "current", cur);
			} else if (mode == Reuse) {
				cur = ArcticMC.get(clip, "current");
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
				if (mode != Metrics && mode != Destroy) {
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
						ArcticMC.set(clip, "current", cur);
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
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			var width = availableWidth;
			var height = availableHeight;
            var child = build(block, clip, width, height, mode, 0);
			width = Math.max(width, child.width);
			height = Math.max(height, child.height);
			if (mode != Metrics && mode != Destroy && child.clip != null) {
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

            var child = build(block, p, Math.max( Math.abs(minimumWidth), Math.min(availableWidth, maximumWidth)), availableHeight, mode, childNo);
			if (minimumWidth >= 0 && child.width < minimumWidth) {
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
		
			var child = build(block, p, availableWidth, Math.max( Math.abs(minimumHeight), Math.min(availableHeight, maximumHeight)), mode, childNo);
			if (minimumHeight >= 0 && child.height < minimumHeight) {
				child.height = minimumHeight;
			}
			if (child.height > maximumHeight) {
				child.height = maximumHeight;
			}
			return { clip: child.clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: false };
			
		case Crop(width, height, block):
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(block, p, availableWidth, availableHeight, mode, childNo);
			var w = child.width;
			var h = child.height;
			if (width != null) w = width;
			if (height != null) h = height;
			if (mode != Metrics && mode != Destroy) {
				ArcticMC.clipSize(clip, w, h);
			}
			return { clip: clip, width: w, height: h, growWidth: false, growHeight: false };

		case ColumnStack(blocks, useIntegerFillings):
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
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
			var remainder = 0.0;
			
			if (freeSpace < 0) {
				// Hmm, we should do a scrollbar instead
				freeSpace = 0;
			}
			if (numberOfWideChildren > 0) {
				if (useIntegerFillings) {
					freeSpace = Math.round(freeSpace / numberOfWideChildren);
					remainder = availableWidth - width - (numberOfWideChildren * freeSpace);
				} else {
					freeSpace = freeSpace / numberOfWideChildren;
				}
				m.growWidth = true;
			} else {
				freeSpace = 0;
			}

			var h = 0.0;
			var x = 0.0;
			var i = 0;
			var firstGrowWidthChild = true;
			for (l in blocks) {
				var w = childMetrics[i].width + if (childMetrics[i].growWidth) freeSpace else 0;
				if (firstGrowWidthChild && childMetrics[i].growWidth) {
					firstGrowWidthChild = false;
					w += remainder;
				}
				var child = build(l, clip, w, maxHeight, mode, i);
                // var child = build(l, clip, w, availableHeight, mode, i);
				if (mode != Metrics && mode != Destroy && child.clip != null) {
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

		case LineStack(blocks, ensureVisibleIndex, disableScrollbar, useIntegerFillings):
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			var m = { clip: clip, width : 0.0, height : 0.0, growWidth : false, growHeight : false };
			// Get child 0
			var child = getOrMakeClip(clip, mode, 0);
			
			if (mode == Destroy) {
				Scrollbar.removeScrollbar(clip, child);
				var i = 0;
				for (l in blocks) {
					var line = build(l, child, 0, 0, mode, i);
					++i;
				}
				return m;
			}
			
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
					var remainder = 0.0;
					if (useIntegerFillings) {
						reductionPerGrowingChild = Math.round(reductionPerGrowingChild);
						remainder = freeSpace - (reductionPerGrowingChild * shrinkable);
					}
					var firstGrowHeightChild = true;
					for (cm in childMetrics) {
						if (cm.growHeight && cm.height > cutoffHeight) {
							cm.height += reductionPerGrowingChild;
							if (firstGrowHeightChild) {
								cm.height += remainder;
								firstGrowHeightChild = false;
							}
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
				if (mode != Metrics && mode != Destroy && line.clip != null) {
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
				if (y - availableHeight >= 1 && availableHeight >= 34 && mode != Destroy) {
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
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
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
					if (mode != Metrics && mode != Destroy && child.clip != null) {
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
				while (ArcticMC.has(clip, "c" + i)) {
					ArcticMC.setVisible(ArcticMC.get(clip, "c" + i), false);
					++i;
				}
			}

			m.width = width;
			m.height = y - yspacing;
			return m;
		
		case Grid(cells, disableScrollbar, oddRowColor, evenRowColor, borderSize, borderColor):
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
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
					if (mode != Metrics && mode != Destroy && b.clip != null) {
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
				if (mode != Metrics && mode != Destroy && color != null) {
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
			
			#if flash9
			if ((borderSize != null) && (borderColor!=null)) {
				if ((mode == Create) || (mode == Reuse)) {
					var g:flash.display.Graphics = child.graphics;
					g.clear();
					g.lineStyle(borderSize, borderColor, 1.0);
					var x = 0.0;
					var y = 0.0;
					for (w in columnWidths) {
						g.moveTo(x, 0);
						g.lineTo(x, height);
						x += w;
					}
					g.moveTo(x, 0);
					g.lineTo(x, height);
					
					for (h in lineHeights) {
						g.moveTo(0, y);
						g.lineTo(width, y);
						y += h;
					}
					g.moveTo(0, y);
					g.lineTo(width, y);
				}
			}
			#end
			
			if (disableScrollbar != true) {
				// TODO: draw horizontal scrollbar if (width > availableHeight) 
				// draw vertical scrollbar
				if (height - availableHeight >= 1 && availableHeight >= 34 && mode != Destroy) {
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
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
            var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			if (mode == Destroy) {
				Scrollbar.removeScrollbar(clip, child.clip);
			} else if (mode != Metrics) {
				Scrollbar.drawScrollBar(clip, child.clip, availableWidth, availableHeight, child.height, 0);
			}
			return { clip: clip, width: availableWidth, height: availableHeight, growWidth: child.growWidth, growHeight: child.growHeight };

		case Dragable(stayWithin, sideMotion, upDownMotion, block, onDrag, onInit, onStopDrag):
			return buildDragable(p, childNo, mode, availableWidth, availableHeight, stayWithin, sideMotion, upDownMotion, block, onDrag, onInit, onStopDrag);

		case Cursor(block, cursor, keepNormalCursor) :
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			if (mode == Metrics) {
				return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
			}
			if (child.clip == null && mode != Destroy) {
				#if debug
				trace("Can not make cursor of empty block");
				#end
				return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
			}
			var me = this;
			var cursorMc = ArcticMC.get(clip, "cursor");
			
			if (mode == Destroy) {
				removeStageEventListeners(clip);
				if (cursorMc != null) {
					#if flash9
					// Since cursors are constructed lazily, we have to search for our child 
					// because other Cursors might have gone before us changing the child numbering
					for (i in 0...parent.numChildren) {
						var c : Dynamic = parent.getChildAt(i);
						if (c == cursorMc.clip) {
							build(cursor, parent, 0, 0, mode, i);
							break;
						}
					}
					#end
					ArcticMC.remove(cursorMc.clip);
					ArcticMC.delete(clip, "cursor");
				}
				return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
			}
			// We need to construct the cursor lazily because we want it to come on top of everything
			var cursorMcFn = function(n) { return me.build(cursor, me.parent, 0, 0, Create, n);};
			var keep = if (keepNormalCursor == null) true else keepNormalCursor;
			#if flash9
				var onMove = function (s) {
					//trace("on move");
					if (!ArcticMC.isActive(child.clip)) {
						return;
					}
					
					var hit = child.clip.hitTestPoint(flash.Lib.current.mouseX, flash.Lib.current.mouseY, true);
					
					// If we are covered by a dialog, we disable the cursor.
					if (hit && !ArcticDialogManager.get().dialogCovers(child.clip)) {
						ArcticMC.showMouse(keep);
						cursorMc = ArcticMC.get(clip, "cursor");
						if (cursorMc == null) {
							// Since we are constructed lazily, we have to find out what child number we are
							var no = me.parent.numChildren;
							cursorMc = cursorMcFn(no);
							cursorMcFn = null;
							ArcticMC.set(clip, "cursor", cursorMc);
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
					addStageEventListener( clip, clip.stage, flash.events.MouseEvent.MOUSE_MOVE, onMove);
					addStageEventListener( clip, clip.stage, flash.events.Event.MOUSE_LEAVE, function() {
							if (cursorMc != null && cursorMc.clip != null) {
								cursorMc.clip.visible = false;
							}
							ArcticMC.showMouse();
						}
					);
				}
				//trace("explicit call");
				onMove(null);
			#else flash
				
				var onMove = function() {
							if (!ArcticMC.isActive(child.clip)) {
								return;
							}
							if (child.clip.hitTest(flash.Lib.current._xmouse, flash.Lib.current._ymouse)) {
								if (cursorMc == null) {
									cursorMc = cursorMcFn(childNo);
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
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			if (mode == Create && child.clip != null) {
				ArcticMC.moveClip(child.clip, dx, dy);
			}
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
			
		case OnTop(base, overlay) :
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(base, clip, availableWidth, availableHeight, mode, 0);
			var over = build(overlay, clip, availableWidth, availableHeight, mode, 1);
			return { clip: clip, width: Math.max(child.width, over.width), height: Math.max(child.height, over.height),
					growWidth: child.growWidth || over.growWidth, growHeight: child.growHeight || over.growHeight };
		#if flash9
		case OnTopView(base, overlay) :
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(base, clip, availableWidth, availableHeight, mode, 0);
			
			if (mode == Metrics) {
				return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
			}
			
			if (mode == Destroy) {
				var overlayMc = ArcticMC.get(clip, "overlay");
				if (overlayMc != null) {
					for (i in 0...parent.numChildren) {
						var c : Dynamic = this.parent.getChildAt(i);
						if (c == overlayMc.clip) {
							build(overlay, this.parent, 0, 0, mode, i);
							break;
						}
					}
					ArcticMC.remove(overlayMc.clip);
					ArcticMC.delete(clip, "overlay");
				}
				return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
			}
			var me = this;
			var register = function (e:Dynamic) {
				var overlayMc = me.build(overlay, me.parent, 0, 0, mode, 0);
				ArcticMC.set(clip, "overlay", overlayMc);
				var r = child.clip.getBounds(me.parent);
				overlayMc.clip.x = r.left;
				overlayMc.clip.y = r.top;
				clip.removeEventListener(Event.ENTER_FRAME, ArcticMC.get(clip, "onframe"));
			}
			ArcticMC.set(clip, "onframe", register);
						
			clip.addEventListener(Event.ENTER_FRAME, register);
			
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };

		#end
		
		case Id(id, block) :
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			if (mode == Destroy) {
				idMovieClip.remove(id);
			} else if (mode == Create) {
				idMovieClip.set(id, child.clip);
			}
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };

		case CustomBlock(data, buildFun):
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			if (mode == Create) {
				var result = buildFun(data, mode, clip, availableWidth, availableHeight, null);
				ArcticMC.set(clip, "customClip", result.clip);
				return result;
			} else if (mode == Reuse || mode == Destroy) {
				var dclip = ArcticMC.get(clip, "customClip");
				if (mode == Destroy) {
					ArcticMC.delete(clip, "customClip");
				}
				var r = buildFun(data, mode, clip, availableWidth, availableHeight, dclip);
				if (r == null) {
					return { clip: null, width: 0.0, height: 0.0, growWidth: false, growHeight: false };
				}
				return r;
			} else {
				return buildFun(data, mode, null, availableWidth, availableHeight, null);
			}
		
		case MouseWheel(block, onMouseWheel):
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			if (mode == Create) {
				// To support empty children, we ensure that we have the right size
				ArcticMC.setSize(clip, child.width, child.height);
				#if flash9
					addStageEventListener( clip, clip.stage, flash.events.MouseEvent.MOUSE_WHEEL,
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
			} else if (mode == Destroy) {
				removeStageEventListeners(clip);
			}
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };

		case Mask(block, mask) :
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
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

		case Scale(block, maxScale, alignX, alignY):
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			
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
			if (mode != Metrics && mode != Destroy) {
				ArcticMC.setScaleXY(child.clip, scale, scale);
				if ((alignX != null && alignX != -1.0) || (alignY != null && alignY != -1.0)) {
					var x = 0.0;
					var y = 0.0;
					if (alignX != null && alignX != -1.0 && availableWidth > child.width*scale) {
						x = (availableWidth - child.width*scale) * alignX;
					}
					if (alignY != null && alignY != -1.0 && availableHeight > child.height*scale) {
						y = (availableHeight - child.height*scale) * alignY;
					}
					ArcticMC.setXY(child.clip, x, y);
				}
			}
			return { clip: clip, width: scale * child.width, height: scale * child.height, growWidth: growWidth, growHeight: growHeight };
		#if flash9
		case Rotate(block, angle):
			var childW:Float = 0;
			var childH:Float = 0;
			var minx:Float = 0;
			var miny:Float = 0;
			var maxx:Float = 0;
			var maxy:Float = 0;
			var ca:Float = 0;
			var sa:Float = 0;
			
			if (mode != Destroy) {
				ca = Math.cos(angle*Math.PI/180.0);
				sa = Math.sin(angle*Math.PI/180.0);
				var d:Float = 1.0/(ca * ca - sa * sa); 
				childW = d * (Math.abs(ca * availableWidth) - Math.abs(sa * availableHeight));
				childH = d * (Math.abs(ca * availableHeight) - Math.abs(sa * availableWidth));
			}
			
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
			var child = build(block, clip, childW, childH, mode, 0);
		
			if (mode != Destroy) {
				var w:Float = child.width;
				var h:Float = child.height;
				if ((ca >= 0) && (sa >= 0)) {
					minx = -h * sa;
					miny = 0;
					maxx = w * ca;
					maxy = w * sa + h * ca;
				} else if ((ca <= 0) && (sa >= 0)) {
					minx = w * ca - h * sa;
					miny = h * ca;
					maxx = 0;
					maxy = w * sa;
				} else if ((ca <= 0) && (sa <= 0)) {
					minx = w * ca;
					miny = w * sa + h * ca;
					maxx = -h * sa;
					maxy = 0;
				} else if ((ca >= 0) && (sa <= 0)) {
					minx = 0;
					miny = w * sa;
					maxx = w * ca - h * sa;
					maxy = h * ca;
				}
				if (child.clip != null) {
					child.clip.rotation = angle;
					child.clip.x = -minx;
					child.clip.y = -miny;
				}
			}
		return { clip: clip, width: maxx - minx, height: maxy-miny, growWidth: child.growWidth, growHeight: child.growHeight};
		#end
		
		case Animate(animator):
			var clip = getOrMakeClip(p, mode, childNo);
			var child = build(animator.block, clip, availableWidth, availableHeight, mode, 0);
			if (mode == Create) {
				animator.registerClip(clip);
			} else if (mode == Destroy) {
				animator.destroy();
			}
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };

		case Cached(block):
			var clip = getOrMakeClip(p, mode, childNo);
			var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			#if flash9
			if (mode == Create) {
				var visitor:Array<ArcticMovieClip->Void> = [];
				var visit = function (mc:Dynamic) { mc.cacheAsBitmap = true; if (Reflect.hasField(mc, "numChildren") && (ArcticMC.get(mc, "nocache") == null))for (i in 0...mc.numChildren) visitor[0](mc.getChildAt(i)); }
				visitor.push(visit);
				visit(clip);
			} 
			#end
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };

		case UnCached(block):
			//trace("uncached met", 0);
			var clip = getOrMakeClip(p, mode, childNo);
			var child = build(block, clip, availableWidth, availableHeight, mode, 0);
			if (mode == Create) {
				ArcticMC.set(clip, "nocache", true);
			} 
			return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
		
		case DebugBlock(id, block):
			var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
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
		var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
		if (mode == Create) {
			ActiveClips.get().add(clip);
		} else if (mode == Destroy) {
			ActiveClips.get().remove(clip);
			// Should we clear out event handlers as well?
			return { clip: clip, width: 0.0, height: 0.0, growWidth: false, growHeight: false };
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
				ArcticMC.set(clip, "ti", txtInput);
			} else {
				txtInput = ArcticMC.get(clip, "ti");
			}
			txtInput.html = true;
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
				var isValid: Null<Bool> = validator(txtInput.text);
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
			var txtFormat;
			if (txtInput.text.length > 0) {
				txtFormat = txtInput.getTextFormat(0,1);
			}
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
				if (txtFormat != null) {
					txtInput.defaultTextFormat = txtFormat;
				}
				if (txtInput.text == " ") {
					txtInput.text = "";
				} else {
					// Set the text again to enforce the formatting
					txtInput.htmlText = html;
				}
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
		if (mode == Create) {
			// Setting focus on txtInput 
			#if (flash9 || neko)
				if (focus != null && focus) {
					clip.stage.focus = txtInput;
					if (txtInput.text != " ") {
						txtInput.setSelection(0, txtInput.length);
					} else {
						txtInput.setSelection(1, 1);
					}
				}
			#else flash
				if (focus != null && focus) {
					flash.Selection.setFocus(txtInput);
				}
			#end

			if (onInit != null) {
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
						
						var cursorX:Null<Float> = 0;
						var bounds = txtInput.getCharBoundaries(txtInput.caretIndex);
						if (bounds != null)
							cursorX = bounds.left;
						else { 
							bounds = txtInput.getCharBoundaries(txtInput.caretIndex - 1);
							if (bounds != null)
								cursorX = bounds.left;
						}
						return { html: txtInput.htmlText, text: txtInput.text, focus: focus, selStart: focus ? selStart : null, selEnd: focus ? selEnd : null, 
								 cursorPos: focus ? cursorPos : null, disabled: txtInput.type != TextFieldType.INPUT, cursorX: cursorX }
					#else flash
						var hasFocus = flash.Selection.getFocus() == txtInput._target;
						return { html: txtInput.htmlText, text: txtInput.text, focus: hasFocus, selStart: hasFocus ? flash.Selection.getBeginIndex() : null,
								 selEnd: hasFocus ? flash.Selection.getEndIndex() : null, cursorPos: hasFocus ? flash.Selection.getCaretIndex() : null, 
								 disabled: txtInput.type != "input", cursorX: null }
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
					addOptionalEventListener(txtInput, flash.events.KeyboardEvent.KEY_DOWN, events.onKeyDown, function (e) {
						events.onKeyDown(e.charCode);
					});
					addOptionalEventListener(txtInput, flash.events.KeyboardEvent.KEY_UP, events.onKeyUp, function (e) {
						events.onKeyUp(e.charCode);
					});
					var prevCaretPos = [txtInput.caretIndex];
					addOptionalEventListener(txtInput, Event.ENTER_FRAME, events.onCaretPosChanged, function (e) {
						if (prevCaretPos[0] != txtInput.caretIndex) {
							prevCaretPos[0] = txtInput.caretIndex;
							events.onCaretPosChanged();
						}
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
		}

		var s = ArcticMC.getSize(clip);
		return { clip: clip, width: s.width, height: s.height, growWidth: null == width, growHeight: null == height };
	}

	private function buildDragable(p, childNo, mode, availableWidth, availableHeight, stayWithin, sideMotion, upDownMotion, block, onDrag, onInit, onStopDrag) {
		
		var clip : ArcticMovieClip = getOrMakeClip(p, mode, childNo);
		
		var child = build(block, clip, availableWidth, availableHeight, mode, 0);
		
		if (mode != Metrics && mode != Destroy) {
			if (child.clip == null) {
				#if debug
				trace("Can not make dragable with empty block");
				#end
				return { clip: clip, width: child.width, height: child.height, growWidth: child.growWidth, growHeight: child.growHeight };
			}
		}

		var dragClip = clip; 
		if (mode == Create) {
			ActiveClips.get().add(dragClip);
		} else if (mode == Destroy) {
			ActiveClips.get().remove(dragClip);
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
			if (mode == Destroy) {
				removeStageEventListeners(clip);
			} else if (mode == Reuse && null != onInit) {
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
				if (clip == null || !clip.visible || clip.stage == null) {
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
					if (clip != null && clip.stage != null) {
						me.removeStageEventListener( clip, clip.stage, flash.events.MouseEvent.MOUSE_MOVE, mouseMove );
					}
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
						me.addStageEventListener( clip, clip.stage, flash.events.MouseEvent.MOUSE_MOVE, mouseMove );
						if (firstTime) {
							me.addStageEventListener( clip, clip.stage, flash.events.MouseEvent.MOUSE_UP, mouseUp );
							firstTime = false;
						}
					}
				}
			);
		#else flash
			clip.onMouseDown = function() {
				if (ActiveClips.get().getActiveClip() == dragClip) {
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

	/// Count of how many pictures are loaded
	public var pendingPictureRequests : Int;
	/// Callback for when picture is loaded
	public var pictureLoadedFn : Int -> Void;

	
	#if debug
	var currentBlockKind : String;
	var currentPath : String;
	public var trackMemory : Bool;
	#end
	
	/**
	 * Creates a clip (if construct is true) as childNo, otherwise gets existing movieclip at that point.
	 */ 
	private function getOrMakeClip(p : ArcticMovieClip, buildMode : BuildMode, childNo : Int) : ArcticMovieClip {
		if (buildMode == Metrics || p == null) {
			return null;
		}
		if (buildMode == Create) {
			#if flash6
				var d = ArcticMC.getNextHighestDepth(p);
				p.createEmptyMovieClip("c" + childNo, d);
				var clip = Reflect.field(p, "c" + childNo);
				ArcticMC.set(p, "c" + childNo, clip);
			#else flash7
				var d = p.getNextHighestDepth();
				var clip = p.createEmptyMovieClip("c" + childNo, d);
				ArcticMC.set(p, "c" + childNo, clip);
			#else flash8
				var d = p.getNextHighestDepth();
				var clip = p.createEmptyMovieClip("c" + childNo, d);
				ArcticMC.set(p, "c" + childNo, clip);
			#else (flash9 || neko)
				var clip = new ArcticMovieClip();
				#if debug
				if (p.numChildren > childNo) {
					trace("p already has " + p.numChildren + " children, so adding as " + childNo + " makes no sense");
				}
				if (trackMemory) {
					// MemoryProfiling.track(clip, currentBlockKind);
				}
				#end
				p.addChild(clip);
				if (p != parent) {
					ArcticMC.set(p, "c" + childNo, clip);
				}
			#end
			clip.tabEnabled = false;
			return clip;
		}
		// Reuse/Destroy case
		#if (flash9 || neko)
			if (p != parent) {
				if (ArcticMC.has(p, "c" + childNo)) {
					return ArcticMC.get(p, "c" + childNo);
				}
				if (buildMode == Destroy) {
					trace("Crap! Can leak active clips");
					return null;
				}
#if debug
				trace("getOrMakeClip() unexpected fallback 1." + buildMode);
#end
				return getOrMakeClip(p, Create, childNo);
			}
			if (childNo >= p.numChildren) {
				if (buildMode == Destroy) {
					return null;
				}
				// Fallback - should never happen
#if debug
				trace("getOrMakeClip() unexpected fallback 2.");
#end
				return getOrMakeClip(p, Create, childNo);
			} else {
				var d : Dynamic = p.getChildAt(childNo);
				return d;
			}
		#else flash
			if (ArcticMC.has(p, "c" + childNo)) {
				return ArcticMC.get(p, "c" + childNo);
			}
			// Fallback - should never happen
			return getOrMakeClip(p, Create, childNo);
		#end
	}
	
	#if flash9
	/// A nice helper function to initialize optional event handlers
	private static function addOptionalEventListener<Handler>(target: EventDispatcher, type: String, handler: Handler, 
		flashHandler: /*flash.events.Event*/Dynamic -> Void) {
		if (null != handler) {
			target.addEventListener(type, flashHandler);
		}
	}
	#end

	/// Get to the book keeping details of the given clip
	private function getBlockInfo(clip : ArcticMovieClip) : BlockInfo {
		return ArcticMC.get(clip, "arcticInfo");
	}
	
	/// Set the book keeping details for this clip
	private function setBlockInfo(clip : ArcticMovieClip, info : BlockInfo) {
		ArcticMC.set(clip, "arcticInfo", info);
	}
	
	#if (flash9||neko)
	private function addStageEventListener(refObj : Dynamic, d : EventDispatcher, event : String, handler : Dynamic) {
		d.addEventListener(event, handler);
		stageEventHandlers.push( { obj: d, event: event, handler: handler, ref: refObj });
	}
	private function removeStageEventListeners(refObj : Dynamic) {
		var i : Int = stageEventHandlers.length;
		while (i > 0) {
			i--;
			if (stageEventHandlers[i].ref == refObj) {
				stageEventHandlers[i].obj.removeEventListener(stageEventHandlers[i].event, stageEventHandlers[i].handler);
				stageEventHandlers.splice(i, 1);
			}
		}
	}
	private function removeStageEventListener(refObj : Dynamic, d : EventDispatcher, event : String, handler : Dynamic) {
		d.removeEventListener(event, handler);
		var i : Int = stageEventHandlers.length;
		while (i > 0) {
			i--;
			if (stageEventHandlers[i].ref == refObj && stageEventHandlers[i].obj == d &&
				stageEventHandlers[i].event == event && stageEventHandlers[i].handler == handler) {
				stageEventHandlers.splice(i, 1);
			}
		}
	}
	#else true
	private function removeStageEventListeners(refObj : Dynamic) {
	}
	private function removeStageEventListener(refObj : Dynamic, d : Dynamic, event : String, handler : Dynamic) {
	}
	#end

	#if flash9
	// Hash of all pictures
	private static var pictureCache: Hash<BitmapData>;
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
	public function getActiveClip() : ArcticMovieClip {
		#if flash9
			var x = flash.Lib.current.mouseX;
			var y = flash.Lib.current.mouseY;
		#else flash
			var x = flash.Lib.current._xmouse;
			var y = flash.Lib.current._ymouse;
		#end
		// bottom-up traverse: from children to parent
		var i = activeClips.length - 1;
		while (i >= 0) {
			var clip = activeClips[i];
			#if flash9
				if (clip.hitTestPoint(x, y, false)) {
					return clip;
				}
			#else flash
				if (clip.hitTest(x, y, false) && ArcticMC.isActive(clip)) {
					return clip;
				}
			#end
			i--;
		}
		return null;
	}
	
	// remove clip and all its children from the activeClips	
	public function remove(mc: ArcticMovieClip): Bool {
		if (mc == null) {
			return false;
		}
		
		var contains = function (clip: ArcticMovieClip) {
			#if (flash9||neko)
				return mc == clip || mc.contains(clip);
			#else flash	
				return mc == clip || StringTools.startsWith(clip._target, mc._target + "/");
			#end
		}
		
		var i = 0;
		var del = false;
		while (i < activeClips.length) {
			if (contains(activeClips[i])) {
				activeClips.splice(i, 1);
				del = true;
			} else {
				i++;
			}
		}
		return del;
	}
	
	// add movie clip in smart way - according to its z-order
	public function add(mc: ArcticMovieClip) {
		if (mc == null) {
			return;
		}
		
		var i = findInsertIndex(mc);
		if (i != null) {
			activeClips.insert(i, mc);	
		}
	}
	
	private function findInsertIndex(mc: ArcticMovieClip): Null<Int> {
		#if flash9
		if (mc.stage == null) {
			// the display object is not added to the display list
			return null;
		}
		#end
		
		var start = 0;
		var end = activeClips.length - 1;
		while (start <= end) {
			var i = Math.floor((end + start) / 2);
			var res = compare(mc, activeClips[i]);
			if (res == 0) {
				// return i;
				// the array contains this clip already
				// should not happen
				return null;
			} 
			if (res > 0) {
				// this clip is higher
				start = i + 1;
			} else {
				end = i - 1;
			}
		}
		return start;
	}
	
	#if (flash9||neko)
	static private function buildPath(mc: ArcticMovieClip): Array<DisplayObjectContainer> {
		var path = new Array<DisplayObjectContainer>();
		var parent: DisplayObjectContainer = mc;
		while (parent != null) {
			path.unshift(parent);
			parent = parent.parent;
		}
		return path;
	}
	#end
	
	public static function compare(mc1: ArcticMovieClip, mc2: ArcticMovieClip): Int {
		if (mc1 == mc2) {
			return 0;
		}
	#if (flash9||neko)
		var path1 = buildPath(mc1);
		var path2 = buildPath(mc2);
	#else flash	
		var path1 = mc1._target.split("/");
		var path2 = mc2._target.split("/");
	#end
		// find the Least Common Ancestor (it can be root)
		var length = Std.int(Math.min(path1.length, path2.length));
		var diffIndex = 0;
		while (diffIndex < length && path1[diffIndex] == path2[diffIndex]) {
			diffIndex++;
		}
		if (diffIndex == length || diffIndex == 0) {
			// one clip is a parent of another
			return path1.length < path2.length ? -1 : 1;
		}
	#if (flash9||neko)
		var lca = path1[diffIndex - 1];
		var childNo1 = lca.getChildIndex(path1[diffIndex]);
		var childNo2 = lca.getChildIndex(path2[diffIndex]);
	#else flash
		// we use ["c" + childNo] notation
		// (should be faster than evaluating depth of the 'fork')
		var childNo1 = Std.parseInt(path1[diffIndex].substr(1));
		var childNo2 = Std.parseInt(path2[diffIndex].substr(1));
	#end
		return childNo1 < childNo2 ? -1 : 1;
	}

	// Here, we record all MovieClips that compete for mouse drags
	public var activeClips : Array<ArcticMovieClip>;
}