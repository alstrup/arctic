package arctic;

#if flash9
import flash.display.MovieClip;
#else true
import flash.MovieClip;
#end

import flash.geom.Rectangle;
import flash.geom.Point;


/**
 * Namespace for MovieClip utils
 */
class DrawUtils {

	/// Contributed by Zjnue Brzavi <zjnue.brzavi@googlemail.com>
	static public function drawRect(mc : MovieClip, x : Float, y : Float, w : Float, h : Float, ?cornerRadius : Float) {
		var angle, sideSign, cnrSign, strtX, strtY, nextX, nextY, cnrX, cnrY, endX, endY;
		if (cornerRadius != null && cornerRadius > 0) {
			strtX = x + cornerRadius;
			strtY = y;
			#if flash9
				mc.graphics.moveTo(strtX,strtY);
			#else flash
				mc.moveTo(strtX,strtY);
			#end
			for (i in 0...4) {
				angle = (Math.PI/4) - (i*Math.PI/2);
				sideSign = if (Math.cos(angle) >= 0) 1 else -1;
				cnrSign = if (Math.sin(angle) >= 0) 1 else -1;
				if ((i%2)== 0) {
					nextX = strtX + sideSign * (w-2*cornerRadius);
					nextY = strtY;
					cnrX = nextX + sideSign * cornerRadius;
					cnrY = strtY;
					endX = cnrX;
					endY = cnrY + cnrSign * cornerRadius;
				} else {
					nextY = strtY + sideSign * (h-2*cornerRadius);
					nextX = strtX;
					cnrY = nextY + sideSign * cornerRadius;
					cnrX = strtX;
					endY = cnrY;
					endX = cnrX + cnrSign * cornerRadius;
				}
				#if flash9
					mc.graphics.lineTo(nextX,nextY);
					mc.graphics.curveTo(cnrX,cnrY,endX,endY);
				#else flash
					mc.lineTo(nextX,nextY);
					mc.curveTo(cnrX,cnrY,endX,endY);
				#end
				strtX = endX;
				strtY = endY;
			}
		} else {
			#if flash9
				mc.graphics.moveTo(x, y);
				mc.graphics.lineTo(x+w, y);
				mc.graphics.lineTo(x+w, y+h);
				mc.graphics.lineTo(x, y+h);
				mc.graphics.lineTo(x, y);
			#else flash
				mc.moveTo(x, y);
				mc.lineTo(x+w, y);
				mc.lineTo(x+w, y+h);
				mc.lineTo(x, y+h);
				mc.lineTo(x, y);
			#end
		}
	}

#if flash9
#else flash

// draws an arrow at the end of the line specified using current fill settings - i.e.
// mc.beginFill() and mc.endFill() has to be invoked by the caller
// original AS2 code taken from http://www.experts-exchange.com/Web/WebDevSoftware/Flash/Q_21655556.html#15442997
static public function drawArrowHead(mc: MovieClip, startX: Float, startY: Float, endX: Float, endY: Float, arrowW: Float, arrowH: Float) {
    // calc position of arrow
    // first find the angle of the line
    var angle_real = Math.atan2(endY - startY, endX - startX);
    // calc the hypotenuse component
    var r2 = Math.abs(if (0 != endY - startY) (endY - startY) / Math.sin(angle_real) else (endX - startX));
    // find the normalized angle of difference in the arrow w and h
    var angle_s = Math.abs((Math.PI/2) - Math.atan2(r2 - arrowH, arrowW / 2));
    // apply the x / y components to the new angle difference
    var pt2 = new Point<Float>(startX + (r2-arrowH)*Math.cos(angle_real-angle_s), startY + (r2-arrowH)*Math.sin(angle_real-angle_s));
    var pt3 = new Point<Float>(startX + (r2-arrowH)*Math.cos(angle_real+angle_s), startY + (r2-arrowH)*Math.sin(angle_real+angle_s));
    var pt1 = new Point<Float>(endX, endY);

    // basically, the arrow is a filled in triangle
    mc.moveTo(pt1.x, pt1.y);
    mc.lineTo(pt2.x, pt2.y);
    mc.lineTo(pt3.x, pt3.y);
    mc.lineTo(pt1.x, pt1.y);
}

static public function drawArrow(mc: MovieClip, startX, startY, endX, endY, arrowW, arrowH, color) {
	mc.beginFill(color);
	drawArrowHead(mc, startX, startY, endX, endY, arrowW, arrowH);
	mc.endFill();
	mc.moveTo(startX, startY);
	mc.lineTo(endX, endY);
}

#end

// Draws a circle with optional filling
static public function drawCircle(mc : MovieClip, x : Float, y : Float, radius : Float, color : Int, ?fillColor : Int, ?fillAlpha : Float)
{
	#if flash9
		mc.graphics.lineStyle(1, color);
		if (null != fillColor) {
			mc.graphics.beginFill(fillColor, if (fillAlpha == null) 100.0 else fillAlpha);
		}
		mc.graphics.drawCircle(x, y, radius);
		if (null != fillColor) {
			mc.graphics.endFill();
		}
	#else flash
		mc.lineStyle(1, color);
		if (null != fillColor) {
			mc.beginFill(fillColor, if (fillAlpha == null) 100.0 else fillAlpha);
		}
		DrawUtils.drawRect(mc, x-radius, y-radius, radius*2.0, radius*2.0, radius);
		if (null != fillColor) {
			mc.endFill();
		}
	#end
}

static public function drawRectangle(mc : MovieClip, x : Float, y : Float, w : Float, h : Float, cornerRadius : Float, color : Int, ?fillColor : Int, ?fillAlpha : Float) {
	#if flash9
		mc.graphics.lineStyle(1, color);
		if (null != fillColor) {
			mc.graphics.beginFill(fillColor, if (fillAlpha == null) 100.0 else fillAlpha);
		}
		drawRect(mc, x, y, w, h, cornerRadius);
		if (null != fillColor) {
			mc.graphics.endFill();
		}
	#else flash
		mc.lineStyle(1, color);
		if (null != fillColor) {
			mc.beginFill(fillColor, if (fillAlpha == null) 100.0 else fillAlpha);
		}
		drawRect(mc, x, y, w, h, cornerRadius);
		if (null != fillColor) {
			mc.endFill();
		}
	#end
}

}