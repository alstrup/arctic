package arctic;

import arctic.ArcticBlock;

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

		if (Arctic.textSharpness != null) {
			ArcticMC.setTextRenderingQuality(tf, Arctic.textSharpness, Arctic.textGridFit);
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
		#end
	}
	
	static function getScaling(tf : flash.text.TextField, width : Float, height : Float) : Float {
		var scale = 1.0;
		if (tf.height > height) {
			scale = height / tf.height;
		}
		if (tf.width > width) {
			scale = Math.min(scale, width / tf.width);
		}
		return scale;
	}
	
	/// A general minimizer
	static public function minimize(minWidth : Float, maxWidth : Float, measureFn : Float -> Float) : Float {
		var lower = minWidth;
		var upper = maxWidth;
		var count = 0;
		var bestValue : Null<Float> = null;
		var bestWidth : Null<Float> = null;
		
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
		
		while ((upper - lower > 0.9) && count < 20) {
			var mid = (upper + lower) / 2.0;
			var value = measure(mid);
			var down = (mid + lower) / 2.0;
			var downValue = measure(down);
			var up = (upper + mid) / 2.0;
			var upValue = measure(up);
			if (downValue < upValue) {
				upper = mid;
			} else {
				lower = mid;
			}
		}
		return bestWidth;
	}
}
