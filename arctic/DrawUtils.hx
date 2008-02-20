package arctic;

import arctic.ArcticMC;
#if flash9
import flash.display.MovieClip;
#else flash
import flash.MovieClip;
#else neko
import neash.display.MovieClip;
#end

/**
 * Namespace for MovieClip utils
 */
class DrawUtils {

	/// Contributed by Zjnue Brzavi <zjnue.brzavi@googlemail.com>
	static public function drawRect(mc : MovieClip, x : Float, y : Float, w : Float, h : Float, ?cornerRadius : Float) {
		var g = ArcticMC.getGraphics(mc);
		#if flash9
		if (cornerRadius != null && cornerRadius > 0) {
			g.drawRoundRect(x, y, w, h, cornerRadius);
		} else {
			g.drawRect(x, y, w, h);
		}
		#else true
		var angle, sideSign, cnrSign, strtX, strtY, nextX, nextY, cnrX, cnrY, endX, endY;
		if (cornerRadius != null && cornerRadius > 0) {
			strtX = x + cornerRadius;
			strtY = y;
			g.moveTo(strtX,strtY);
			for (i in 0...4) {
				sideSign = if (i < 2) 1 else -1;
				cnrSign = if (i == 1 || i == 2) -1 else 1;
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
				g.lineTo(nextX,nextY);
				g.curveTo(cnrX,cnrY,endX,endY);
				strtX = endX;
				strtY = endY;
			}
		} else {
			g.moveTo(x, y);
			g.lineTo(x+w, y);
			g.lineTo(x+w, y+h);
			g.lineTo(x, y+h);
			g.lineTo(x, y);
		}
		#end
	}

// Draws a circle with optional filling
static public function drawCircle(mc : MovieClip, x : Float, y : Float, radius : Float, color : Int, ?fillColor : Int, ?fillAlpha : Float)
{
	var g = ArcticMC.getGraphics(mc);
	g.lineStyle(1, color);
	if (null != fillColor) {
		g.beginFill(fillColor, ArcticMC.convertAlpha(fillAlpha));
	}
	#if flash9
	g.drawCircle(x, y, radius);
	#else true
	DrawUtils.drawRect(mc, x-radius, y-radius, radius*2.0, radius*2.0, radius);
	#end
	if (null != fillColor) {
		g.endFill();
	}
}

static public function drawRectangle(mc : MovieClip, x : Float, y : Float, w : Float, h : Float, cornerRadius : Float, color : Int, ?fillColor : Int, ?fillAlpha : Float) {
	var g = ArcticMC.getGraphics(mc);
	g.lineStyle(1, color);
	if (null != fillColor) {
		g.beginFill(fillColor, ArcticMC.convertAlpha(fillAlpha));
	}
	drawRect(mc, x, y, w, h, cornerRadius);
	if (null != fillColor) {
		g.endFill();
	}
}

}
