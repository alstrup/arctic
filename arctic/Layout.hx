package arctic;

import arctic.ArcticBlock;
import arctic.ArcticMC;

class Layout {
	// This gives the size of a block when displayed in the given area
	static public function getSize(block : ArcticBlock, ?size : { width : Float, height : Float }) : { width : Float, height : Float } {
		if (size == null) {
			size = arctic.ArcticMC.getStageSize(ArcticMC.getCurrentClip());
		}
		var view = new ArcticView(block, null);
		var result = view.build(block, null, size.width, size.height, Metrics, 0);
		return {width: result.width, height: result.height};
	}
	
	/**
	 * Resizes and word wraps a text to make it fit in the given dimensions.
	 * Does a binary search to find the wrapping point that gives the total least area
	 * usage.
	 */
	static public function makeTextFit(html : String, maxWidth : Float, maxHeight : Float, embeddedFont : Bool, selectable : Bool, ?minWidth : Float) : ArcticBlock {
		#if flash9
		var tf : flash.text.TextField = new flash.text.TextField();
		// Determine singleline or word-wrap based on text size
		tf.wordWrap = false;
		if (embeddedFont) {
			tf.embedFonts = true;
		}
		tf.selectable = (true == selectable);
		//tf.multiline = true;
		tf.htmlText = html;
		tf.autoSize = flash.text.TextFieldAutoSize.LEFT;

		if (Arctic.textSharpness != null || Arctic.textThickness != null) {
			ArcticMC.setTextRenderingQuality(tf, Arctic.textSharpness, Arctic.textGridFit, Arctic.textThickness);
		}
		
		var widthFits = tf.width < maxWidth;
		var heightFits = tf.height < maxHeight;
		
		if (widthFits && heightFits) {
			// It fits
			return Text(html, embeddedFont, false, selectable);
		}
		
		if (widthFits) {
			// OK, it fits in the width, but not in the height. There is no other solution but to scale it down
			var scale = maxHeight / tf.height;
			return Transform(Text(html, embeddedFont, false, selectable), scale, scale);
		}
		
		// We do not fit in the width, so we need to word wrap and maybe scale down.
		
		// First we do word wrapping and aim for the best aspect ratio that fits the requested aspect ratio
		
		var lower = minWidth == null ? 0 : minWidth;
		var upper = 10 * maxWidth;
		
		var width = (upper + lower) / 2;
		tf.wordWrap = true;
		tf.width = width;
		
		var scale = getScaling(tf, maxWidth, maxHeight);
		
		var bestWidth = width;
		var bestScale = scale;
		var lowestArea = tf.width * tf.height;
		
		var desiredAspect = maxWidth / maxHeight;
		
		var count = 0;
		while ((upper - lower > 0.1) && count < 20) {
			var scale = getScaling(tf, maxWidth, maxHeight);
			var area = tf.width * tf.height;
			// trace(count + " Width " + width + " gives " + scale * tf.width + "," + scale * tf.height + " with " + scale + " with area " + area + " " + lower + "-" + upper);
			
			if (scale >= bestScale && (area < lowestArea || scale > bestScale)) {
				bestScale = scale;
				lowestArea = area;
				bestWidth = width;
			}
			
			// OK, decide whether to shrink or grow by approximating towards the correct aspect ratio
			var aspectDiff = desiredAspect - tf.width / tf.height;
			if (aspectDiff <= 0.0) {
				// Too wide
				upper = width;
				width = (upper + lower) / 2;
			} else {
				// Too high
				lower = width;
				width = (upper + lower) / 2;
			}
			
			tf.width = width;
			++count;
		}

		tf.width = bestWidth;

		scale = getScaling(tf, maxWidth, maxHeight);
		// trace("Winner: " + bestWidth + " with scale " + scale + " and area " + tf.height * tf.width);
		return Transform(ConstrainWidth(0, bestWidth, Text(html, embeddedFont, true, selectable)), scale, scale);
		#else
		throw "Not implemented!";
		return null;
		#end
	}
	
	static function getScaling(tf : ArcticTextField, width : Float, height : Float) : Float {
		var scale = 1.0;
		var tfheight = ArcticMC.getTextFieldHeight(tf);
		var tfwidth = ArcticMC.getTextFieldWidth(tf);
		if (tfheight > height) {
			scale = height / tfheight;
		}
		if (tfwidth > width) {
			scale = Math.min(scale, width / tfwidth);
		}
		return scale;
	}
	
	/// A general minimizer
	static public function minimize(minWidth : Float, maxWidth : Float, measureFn : Float -> Float) : Float {
		crashCase = 14;
		var lower = minWidth;
		var upper = maxWidth;
		var count = 0;
		var bestValue : Null<Float> = null;
		var bestWidth : Null<Float> = maxWidth;
		
		var measureCache = new IntHash<Float>();
		var measure = function(v) {
			var iv = Math.round(v);
			var cached = measureCache.get(iv);
			if (cached != null) {
				return cached;
			}
			var value = measureFn(iv);
			measureCache.set(iv, value);
			if (bestValue == null || value < bestValue) {
				bestValue = value;
				bestWidth = iv;
			}
			return value;
		}
		crashCase = 15;
		
		var n = 9;
		var dist = 1 / (n - 1);
		while (count < 5) {
			crashCase = 16;
			// Sample n points uniformly and record the minimum interval
			var d : Float = (upper - lower);
			if (d < 1) return bestWidth;
			d = d * dist;
			if (d < 1) d = 1;
			var vs = [];
			var min = null;
			var mini : Null<Int> = null;
			for (i in 0...n) {
				var x = lower + i * d;
				if (x <= maxWidth) {
					var value = measure(x);
					vs.push(value);
					if (min == null || value < min) {
						min = value;
						mini = i;
					}
				}
			}
			crashCase = 17;
			var down = if (mini > 0) mini - 1 else mini;
			var up = if (mini + 1 < n) mini + 1 else mini;
			upper = lower + up * d;
			lower = lower + down * d;
			++count;
		}
		return bestWidth;
	}
	
	// Finds the value that best fits in the given target area such that downscaling will be minized
	static public function aspectFit(targetWidth : Float, targetHeight : Float, minimum : Float, maximum : Float, valToSize : Float -> { width : Float, height : Float } ) : Float {
		crashCase = 10;
		if (targetWidth == 0 || targetHeight == 0) {
			// OK, we have to give up and choose some arbitrary value in between
			return (maximum + minimum) / 2.0;
		}
		crashCase = 11;
		return minimize(minimum, maximum, function(w) {
			crashCase = 12;
			var size = valToSize(w);
			var xscale = size.width / targetWidth;
			var yscale = size.height / targetHeight;
			var scale = Math.max(xscale, yscale);
			// trace(w + " -> " + size.width + "x" + size.height + " in " + targetWidth + "," + targetHeight + " -> " + xscale + "," + yscale + " -> " + scale);
			return scale;
		});
	}
	
	/**
	 * Optimise a parameter to give the best fit in the given target area, minimizing downscaling.
	 */ 
	static public function fit(targetWidth : Float, targetHeight : Float, minimum : Float, maximum : Float, getBlock : Float -> ArcticBlock) : ArcticBlock {
		crashCase = 1;
		var size2width = function(w) {
			return getSize(getBlock(w), { width: targetWidth, height: targetHeight});
		};

		crashCase = 2;
		// Find the best value
		var w = aspectFit(targetWidth, targetHeight, minimum, maximum, size2width);
		crashCase = 3;
		
		// Then find the corresponding scaling
		var size = size2width(w);
		if (size.width == 0 || size.height == 0) {
			crashCase = 4;
			return getBlock(w);
		} else {
			crashCase = 5;
			var scale = targetWidth / size.width;
			scale = Math.min(targetHeight / size.height, scale);
			scale = Math.min(1.0, scale);
			// And build the final result
			return Transform(getBlock(w), scale, scale);
		}
	}
	
	static public var crashCase : Int;

	/**
	 * Find the width of the largest single word.
	 */
	static public function maxWordWidth(text : String, size : Float, font : String, ?isEmbedded : Bool) : Float {
		var length = 0.0;
		for (word in ~/[^a-zA-Z0-9']+/g.split(text)) {
			if (word != "") {
				// Pad the word to provide a small safety area:
				var block = Arctic.makeText("X"+word, size, null, font, isEmbedded, false, false);
				var cur_width = getSize(block, { width: 0.0, height: 0.0 }).width;
				if (cur_width > length)
					length = cur_width;
			}
		}
		return length;
	}
	
	/**
	 * Trying to fit text in width/height block. 
	 * If it is impossible a text block with proportion of given width/height is made, which then is scaled to given sizes.
	 */ 
	static public function makeTextWithProportions( text : String, size : Float, color : String, font : String,
													width : Float, height : Float,
													?alignX : Float = 0.5, ?alignY : Float = 0.5,
													?textAlign : String = "center") : ArcticBlock {
		var block = Arctic.makeText('<p align="' + textAlign + '">' + text + '</p>', size, color, font, true, true, false );
		
		var min_width = maxWordWidth(text, size, font, true);
		var cur_width = (min_width < width ? width : min_width);
		var testblock = ConstrainWidth(cur_width, cur_width, block);
		var cur_height = getSize(testblock, { width: 0.0, height: 0.0 } ).height;
		
		if (cur_height > height) {
			var q = width / height;
			var step = width / 20;
			while (q > cur_width / cur_height ) {
				cur_width += step;
				testblock = ConstrainWidth(cur_width, cur_width, block);
				cur_height = getSize(testblock, { width: 0.0, height: 0.0 } ).height;
			}
		}
		
		var htmlText = '<p align="' + textAlign + '"><font face="' + font + '" size="' + size + '" color="' + color + '">' + text + '</font></p>';
		var fitText = ConstrainWidth(cur_width, cur_width, Align(alignX, alignY, makeTextFit(htmlText, cur_width, cur_height, true, false, min_width)));
		return Arctic.fixSize(width, height, Scale(fitText));
	}
}
