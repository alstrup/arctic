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

/*-------------------------------------------------------------
	mc.drawRect is a method for drawing rectangles and
	rounded rectangles. Regular rectangles are
	sufficiently easy that I often just rebuilt the
	method in any file I needed it in, but the rounded
	rectangle was something I was needing more often,
	hence the method. The rounding is very much like
	that of the rectangle tool in Flash where if the
	rectangle is smaller in either dimension than the
	rounding would permit, the rounding scales down to
	fit.
-------------------------------------------------------------*/
static public function drawRect(mc : MovieClip, x : Float, y : Float, w : Float, h : Float, cornerRadius : Float) {

	// ==============
	// mc.drawRect() - by Ric Ewing (ric@formequalsfunction.com) - version 1.1 - 4.7.2002
	// 
	// x, y = top left corner of rect
	// w = width of rect
	// h = height of rect
	// cornerRadius = [optional] radius of rounding for corners (defaults to 0)
	// ==============
	
	// if the user has defined cornerRadius our task is a bit more complex. :)
	if (null != cornerRadius && cornerRadius > 0) {
		// init vars
		var theta, angle, cx, cy, px, py;
		// make sure that w + h are larger than 2*cornerRadius
		if (cornerRadius>Math.min(w, h)/2) {
			cornerRadius = Math.min(w, h)/2;
		}
		// theta = 45 degrees in radians
		theta = Math.PI/4;
		// draw top line
		#if flash9
			mc.graphics.moveTo(x+cornerRadius, y);
			mc.graphics.lineTo(x+w-cornerRadius, y);
		#else flash
			mc.moveTo(x+cornerRadius, y);
			mc.lineTo(x+w-cornerRadius, y);
		#end
		//angle is currently 90 degrees
		angle = -Math.PI/2;
		// draw tr corner in two parts
		cx = x+w-cornerRadius+(Math.cos(angle+(theta/2))*cornerRadius/Math.cos(theta/2));
		cy = y+cornerRadius+(Math.sin(angle+(theta/2))*cornerRadius/Math.cos(theta/2));
		px = x+w-cornerRadius+(Math.cos(angle+theta)*cornerRadius);
		py = y+cornerRadius+(Math.sin(angle+theta)*cornerRadius);
		#if flash9
			mc.graphics.curveTo(cx, cy, px, py);
		#else flash
			mc.curveTo(cx, cy, px, py);
		#end
		angle += theta;
		cx = x+w-cornerRadius+(Math.cos(angle+(theta/2))*cornerRadius/Math.cos(theta/2));
		cy = y+cornerRadius+(Math.sin(angle+(theta/2))*cornerRadius/Math.cos(theta/2));
		px = x+w-cornerRadius+(Math.cos(angle+theta)*cornerRadius);
		py = y+cornerRadius+(Math.sin(angle+theta)*cornerRadius);
		#if flash9
			mc.graphics.curveTo(cx, cy, px, py);
			// draw right line
			mc.graphics.lineTo(x+w, y+h-cornerRadius);
		#else flash
			mc.curveTo(cx, cy, px, py);
			// draw right line
			mc.lineTo(x+w, y+h-cornerRadius);
		#end
		// draw br corner
		angle += theta;
		cx = x+w-cornerRadius+(Math.cos(angle+(theta/2))*cornerRadius/Math.cos(theta/2));
		cy = y+h-cornerRadius+(Math.sin(angle+(theta/2))*cornerRadius/Math.cos(theta/2));
		px = x+w-cornerRadius+(Math.cos(angle+theta)*cornerRadius);
		py = y+h-cornerRadius+(Math.sin(angle+theta)*cornerRadius);
		#if flash9
			mc.graphics.curveTo(cx, cy, px, py);
		#else flash
			mc.curveTo(cx, cy, px, py);
		#end
		angle += theta;
		cx = x+w-cornerRadius+(Math.cos(angle+(theta/2))*cornerRadius/Math.cos(theta/2));
		cy = y+h-cornerRadius+(Math.sin(angle+(theta/2))*cornerRadius/Math.cos(theta/2));
		px = x+w-cornerRadius+(Math.cos(angle+theta)*cornerRadius);
		py = y+h-cornerRadius+(Math.sin(angle+theta)*cornerRadius);
		#if flash9
			mc.graphics.curveTo(cx, cy, px, py);
			// draw bottom line
			mc.graphics.lineTo(x+cornerRadius, y+h);
		#else flash
			mc.curveTo(cx, cy, px, py);
			// draw bottom line
			mc.lineTo(x+cornerRadius, y+h);
		#end
		// draw bl corner
		angle += theta;
		cx = x+cornerRadius+(Math.cos(angle+(theta/2))*cornerRadius/Math.cos(theta/2));
		cy = y+h-cornerRadius+(Math.sin(angle+(theta/2))*cornerRadius/Math.cos(theta/2));
		px = x+cornerRadius+(Math.cos(angle+theta)*cornerRadius);
		py = y+h-cornerRadius+(Math.sin(angle+theta)*cornerRadius);
		#if flash9
			mc.graphics.curveTo(cx, cy, px, py);
		#else flash
			mc.curveTo(cx, cy, px, py);
		#end
		angle += theta;
		cx = x+cornerRadius+(Math.cos(angle+(theta/2))*cornerRadius/Math.cos(theta/2));
		cy = y+h-cornerRadius+(Math.sin(angle+(theta/2))*cornerRadius/Math.cos(theta/2));
		px = x+cornerRadius+(Math.cos(angle+theta)*cornerRadius);
		py = y+h-cornerRadius+(Math.sin(angle+theta)*cornerRadius);
		#if flash9
			mc.graphics.curveTo(cx, cy, px, py);
			// draw left line
			mc.graphics.lineTo(x, y+cornerRadius);
		#else flash
			mc.curveTo(cx, cy, px, py);
			// draw left line
			mc.lineTo(x, y+cornerRadius);
		#end
		// draw tl corner
		angle += theta;
		cx = x+cornerRadius+(Math.cos(angle+(theta/2))*cornerRadius/Math.cos(theta/2));
		cy = y+cornerRadius+(Math.sin(angle+(theta/2))*cornerRadius/Math.cos(theta/2));
		px = x+cornerRadius+(Math.cos(angle+theta)*cornerRadius);
		py = y+cornerRadius+(Math.sin(angle+theta)*cornerRadius);
		#if flash9
			mc.graphics.curveTo(cx, cy, px, py);
		#else flash
			mc.curveTo(cx, cy, px, py);
		#end
		angle += theta;
		cx = x+cornerRadius+(Math.cos(angle+(theta/2))*cornerRadius/Math.cos(theta/2));
		cy = y+cornerRadius+(Math.sin(angle+(theta/2))*cornerRadius/Math.cos(theta/2));
		px = x+cornerRadius+(Math.cos(angle+theta)*cornerRadius);
		py = y+cornerRadius+(Math.sin(angle+theta)*cornerRadius);
		#if flash9
			mc.graphics.curveTo(cx, cy, px, py);
		#else flash
			mc.curveTo(cx, cy, px, py);
		#end
	} else {
		// cornerRadius was not defined or = 0. This makes it easy.
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

}
