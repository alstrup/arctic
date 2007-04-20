package arctic;

import arctic.ArcticMC;
import arctic.ArcticBlock;

#if flash8
import flash.Mouse;
#else flash7
import flash.Mouse;
#end

typedef ScrollMetrics = { 
	startX : Float, 
	startY : Float, 
    endY : Float, 
	scrollHeight : Float, 
	toScroll : Float, 
	clipHeight : Float, 
	dragHeight : Float
}

class Scrollbar {

    // This method draws a scrollbar given a movie clip. 
    // This movieclips should have a parent, which will also be the parent of the scroll bar 
    // rendered.
    // This can be seperated out and written as a seperate class - ideally it should use ArcticBlocks to construct itself
    public static function drawScrollBar(parent : ArcticMovieClip, clip : ArcticMovieClip, availableWidth : Float,
                                                         availableHeight : Float, realHeight : Float, ensureYVisible : Float) {
		var scrollBar : ArcticMovieClip;
		var upperChild : ArcticMovieClip;
		var scrollOutline : ArcticMovieClip;
		var scrollHand : ArcticMovieClip;
		var lowerChild : ArcticMovieClip;
		var construct : Bool;
		if (Reflect.hasField(parent, "scrollbar")) {
			construct = false;
			#if flash9
				scrollBar = Reflect.field(parent, "scrollbar");
				upperChild = getChild(scrollBar, 0);
				scrollOutline = getChild(scrollBar, 1);
				scrollHand = getChild(scrollBar, 2);
				lowerChild = getChild(scrollBar, 3);
			#else flash
				scrollBar = Reflect.field(parent, "scrollbar");
				upperChild = Reflect.field(scrollBar, "upperChild");
				scrollOutline = Reflect.field(scrollBar, "outline");
				scrollHand = Reflect.field(scrollBar, "hand");
				lowerChild = Reflect.field(scrollBar, "lowerChild");
			#end
		} else {
			construct = true;
			#if flash9
				scrollBar = new ArcticMovieClip();
				Reflect.setField(parent, "scrollbar", scrollBar);
				parent.addChild(scrollBar);

				upperChild = new ArcticMovieClip();
				scrollBar.addChild(upperChild);

				scrollOutline = new ArcticMovieClip();
				scrollBar.addChild(scrollOutline);

				scrollHand = new ArcticMovieClip();
				scrollBar.addChild(scrollHand);

				lowerChild = new ArcticMovieClip();
				scrollBar.addChild(lowerChild);
			#else flash
				var d = parent.getNextHighestDepth();
				scrollBar = parent.createEmptyMovieClip("c" + d, d);
				Reflect.setField(parent, "scrollbar", scrollBar);
	
				var d = scrollBar.getNextHighestDepth();
				upperChild = scrollBar.createEmptyMovieClip("scrollBarUpperChild" + d, d);
				Reflect.setField(scrollBar, "upperChild", upperChild);

				d = scrollBar.getNextHighestDepth();
				scrollOutline = scrollBar.createEmptyMovieClip("scrollBarOutline" + d, d);
				Reflect.setField(scrollBar, "outline", scrollOutline);
				
				d = scrollBar.getNextHighestDepth();
				scrollHand = scrollBar.createEmptyMovieClip("scrollHand" + d, d);
				Reflect.setField(scrollBar, "hand", scrollHand);

				d = scrollBar.getNextHighestDepth();
				lowerChild = scrollBar.createEmptyMovieClip("scrollBarLowerChild" + d, d);
				Reflect.setField(scrollBar, "lowerChild", lowerChild);
			#end
		}


		var clipRectangle = new ArcticRectangle(0.0, 0.0, availableWidth, availableHeight);
		ArcticMC.setScrollRect(clip, clipRectangle);
		ArcticMC.setScrollRect(parent, clipRectangle);
		var squareHeight = 10;

		var height =  7;

		// Upper scroll bar handle
		if (construct) {
			//Drawing upper white squate    
			DrawUtils.drawRectangle(upperChild, 0, 0, 12, squareHeight, 0, 
									0x000000, 0x000000 );
			var g = ArcticMC.getGraphics(upperChild);
			//Drawing upper scrollbar triangle
			g.lineStyle(0.2, 0xFFFFFF);
			g.beginFill(0xFFFFFF);
			g.moveTo(2 , height );
			g.lineTo(2 , height );
			g.lineTo(2 + 7 , height );
			g.lineTo(2 + 3.5 , height - 4 );
			g.endFill();
		}

		// The slider background part
		var scrollHeight = availableHeight - (squareHeight * 2);

		DrawUtils.drawRectangle(scrollOutline, 0, 0, 10, scrollHeight, 0, 0x000000, 0x000000,0);

		ArcticMC.getGraphics(scrollOutline).clear();

		DrawUtils.drawRectangle(scrollOutline, 0, 0, 10, scrollHeight, 0, 0x000000, 0x000000, 0);

		ArcticMC.setXY(scrollOutline, null, ArcticMC.getSize(upperChild).height);
		
		// The slider hand
		var scrollHandHeight = 10.0;
		if ((realHeight - availableHeight) < scrollHeight) {
			scrollHandHeight = scrollHeight - (realHeight - availableHeight);
		}
		
		ArcticMC.getGraphics(scrollHand).clear();
		DrawUtils.drawRectangle(scrollHand, 0, 0, 6, scrollHandHeight - 0.5, 0, 0x000000, 0x000000);

		var scrollMetrics = { 
				startX : 2.0, 
				startY : ArcticMC.getSize(upperChild).height + 0.5,
				endY : 0.0, 
				scrollHeight : scrollHeight - scrollHandHeight - 1, 
				toScroll : 0.0,
				clipHeight : realHeight, 
				dragHeight : scrollHeight - scrollHandHeight + 10 
		};
		scrollMetrics.toScroll = ( (realHeight - availableHeight) / scrollMetrics.scrollHeight);
		scrollMetrics.endY = scrollMetrics.startY + scrollMetrics.scrollHeight - 0.5;
		
		Reflect.setField(clip, "scrollmet", scrollMetrics);

		ArcticMC.setXY(scrollHand, scrollMetrics.startX, scrollMetrics.startY);

		// The lower button
		if (construct) {
			DrawUtils.drawRectangle(lowerChild, 0, 0, 12, squareHeight, 0, 0x000000, 0x000000 );
			
			height = 3;
			var g = ArcticMC.getGraphics(lowerChild);
			//Drawing lower scrollbar triangle
			g.lineStyle(0.2, 0xFFFFFF);
			g.beginFill(0xFFFFFF);
			g.moveTo(2 , height );
			g.lineTo(2, height );
			g.lineTo(2 + 7, height );
			g.lineTo(2 + 3.5, height + 4 );
			g.endFill();
		}
		ArcticMC.setXY(lowerChild, null, availableHeight - 10);

		// Behaviour
		#if flash9
			if (construct) {
				scrollHand.addEventListener(
					flash.events.MouseEvent.MOUSE_DOWN, 
					function (s) {
						var scrollMet = Reflect.field(clip, "scrollmet");
						scrollHand.startDrag(false, new ArcticRectangle( scrollMet.startX, scrollMet.startY, 0, scrollMet.dragHeight) );
						Reflect.setField(Bool, "dragging", true);
						scrollTimer(clip, scrollHand);
					 } ); 

					var mouseUp = function (s) {
						var dragged = Reflect.field(Bool, "dragging");
						if (dragged) {
							scrollHand.stopDrag();                
							Reflect.setField(Bool, "dragging", false);
						}
					 }
				scrollHand.addEventListener(flash.events.MouseEvent.MOUSE_UP, mouseUp); 

				scrollHand.stage.addEventListener(flash.events.MouseEvent.MOUSE_UP, mouseUp );

				scrollOutline.addEventListener(
					flash.events.MouseEvent.MOUSE_DOWN, 
					function (s) {
						var scrollMet : ScrollMetrics = Reflect.field(clip, "scrollmet");
						var scrollToY = s.localY;
						var startY = scrollMet.startY;
						if (scrollToY < startY ) {
							scrollToY = scrollMet.startY;
						} else if (scrollToY >= scrollMet.endY) {
							scrollToY = scrollMet.endY;
						}
						scrollHand.y = scrollToY;
						scroll(clip, scrollHand, scrollMet);
					 } ); 

				lowerChild.addEventListener(
					flash.events.MouseEvent.MOUSE_DOWN, 
					function (s) {
						var scrollMet = Reflect.field(clip, "scrollmet");
						Reflect.setField(Bool, "scrollPressed", true);
						scrollByOne(clip, scrollHand, scrollMet, true);
					} ); 

				lowerChild.addEventListener(
					flash.events.MouseEvent.MOUSE_UP, 
					function (s) {
						var scrollPressed = Reflect.field(Bool, "scrollPressed");
						if (scrollPressed) {
							Reflect.setField(Bool, "scrollPressed", false);
						}            
					 } ); 

				upperChild.addEventListener(
					flash.events.MouseEvent.MOUSE_DOWN, 
					function (s) {
						var scrollMet = Reflect.field(clip, "scrollmet");
						Reflect.setField(Bool, "scrollPressed", true);
						scrollByOne(clip, scrollHand, scrollMet, false);
					} ); 

				upperChild.addEventListener(
					flash.events.MouseEvent.MOUSE_UP, 
					function (s) {
						var scrollPressed = Reflect.field(Bool, "scrollPressed");
						if (scrollPressed) {
							Reflect.setField(Bool, "scrollPressed", false);
						}            
					 } );

				clip.stage.addEventListener( flash.events.MouseEvent.MOUSE_WHEEL,
					function (s) {
						if (parent.hitTestPoint(flash.Lib.current.mouseX, 
												  flash.Lib.current.mouseY, false)) {
							var delta = s.delta;
							var scrollDown = false;

							if (delta > 0) {
								scrollDown = false;
							}

							if (delta < 0) {
								scrollDown = true;
								delta *= -1;
							}
							var intDelta : Int = cast(delta, Int);
							var scrollMet = Reflect.field(clip, "scrollmet");
							moveBy(clip, scrollHand, scrollMet, scrollDown, intDelta);
						}
					}
				);
			}

			scrollBar.x = availableWidth - 11;
			scrollBar.y = clip.y;

		#else flash
		
			var dragged = false;
			scrollBar.onMouseDown = function () {
				var mouseInside = scrollHand.hitTest(flash.Lib.current._xmouse, 
												  flash.Lib.current._ymouse, false);
				
				var inScrollOutline = scrollOutline.hitTest(flash.Lib.current._xmouse, 
												  flash.Lib.current._ymouse, false);
				var inLowerChild = lowerChild.hitTest(flash.Lib.current._xmouse, 
												  flash.Lib.current._ymouse, false);
				var inUpperChild = upperChild.hitTest(flash.Lib.current._xmouse, 
												  flash.Lib.current._ymouse, false);

				var scrollMet : ScrollMetrics = Reflect.field(clip, "scrollmet");
												  
				if (mouseInside) {
					scrollHand.startDrag(false, scrollMet.startX , 
													scrollMet.startY ,
													scrollMet.startX , 
													scrollMet.dragHeight );
					dragged = true;
					Reflect.setField(Bool, "dragging", true);
					scrollTimer(clip, scrollHand);
				} else if (inScrollOutline) {
					var scrollToY = flash.Lib.current._ymouse;
					scrollToY = scrollBar._ymouse;
					var startY = scrollMet.startY;
					if (scrollToY < startY ) {
						scrollToY = scrollMet.startY;
					} else if (scrollToY >= scrollMet.endY) {
						scrollToY = scrollMet.endY;
					}
					scrollHand._y = scrollToY;
					scroll(clip, scrollHand, scrollMet);
				} else if ( inLowerChild) {
					Reflect.setField(Bool, "scrollPressed", true);
					scrollByOne(clip, scrollHand, scrollMet, true);
				} else if (inUpperChild) {
					Reflect.setField(Bool, "scrollPressed", true);
					scrollByOne(clip, scrollHand, scrollMet, false);
				}
			}

			scrollBar.onMouseUp = function() {
				var dragged = Reflect.field(Bool, "dragging");
				if (dragged) {
					scrollHand.stopDrag();                
					Reflect.setField(Bool, "dragging", false);
				}
				var scrollPressed = Reflect.field(Bool, "scrollPressed");
				if (scrollPressed) {
					Reflect.setField(Bool, "scrollPressed", false);
				}            

				var mouseWheelListener = { 
						onMouseDown : function() {},
						onMouseMove : function() {},
						onMouseUp : function() {},
						onMouseWheel : function ( delta : Float, target ) {
							if (clip.hitTest(flash.Lib.current._xmouse, flash.Lib.current._ymouse)) {
								var scrollDown = false;

								if (delta > 0) {
									scrollDown = false;
								}

								if (delta < 0) {
									scrollDown = true;
									delta*= -1;
								}
								var intDelta : Int = cast(delta, Int);
								var scrollMet = Reflect.field(clip, "scrollmet");
								moveBy(clip, scrollHand, scrollMet, scrollDown, intDelta);
							}
						}
					};
				flash.Mouse.addListener(mouseWheelListener);
			}

			scrollBar._x = availableWidth - 11;
			scrollBar._y = clip._y;
		#end
	
		moveToY(clip, scrollHand, ensureYVisible);
    }

	static public function removeScrollbar(parent : ArcticMovieClip, clip : ArcticMovieClip) {
		if (Reflect.hasField(parent, "scrollbar")) {
			#if flash9
				// TODO: Remove all event listeners as well
				parent.removeChild(Reflect.field(parent, "scrollbar"));
			#else flash
				// TODO: Remove all event listeners as well
				Reflect.field(parent, "scrollbar").removeMovieClip();
			#end
			ArcticMC.setScrollRect(parent, null);
			ArcticMC.setScrollRect(clip, null);
			Reflect.deleteField(parent, "scrollbar");
		}
	}

   static public function scrollTimer(clip : ArcticMovieClip, scrollHand : ArcticMovieClip) {
		var scrollMet = Reflect.field(clip, "scrollmet");
		var interval = new haxe.Timer(100);                
		interval.run = function () {
			var dragged = Reflect.field(Bool, "dragging");
			scroll(clip, scrollHand, scrollMet);
			if ( !dragged ) {
				interval.stop();
			}
		}
	}

	static private function moveBy(clip : ArcticMovieClip, scrollHand : ArcticMovieClip, 
					 scrollMet : ScrollMetrics, scrollDown : Bool, unit : Int) {
		#if flash9
			if (scrollDown) {
				if ( (scrollHand.y + unit) <= scrollMet.endY ) {
					  scrollHand.y += unit;
				} else {
					scrollHand.y = scrollMet.endY;
				}
			} else {
				if ( (scrollHand.y - unit ) >= scrollMet.startY ) {
					  scrollHand.y -= unit;
				} else {
					scrollHand.y = scrollMet.startY;
				}
			}
		#else flash
			if (scrollDown) {
				if ( (scrollHand._y + unit) <= scrollMet.endY ) {
					scrollHand._y += unit;
				} else {
					scrollHand._y = scrollMet.endY;
				}
			} else {
				if ( (scrollHand._y - unit ) >= scrollMet.startY ) {
					scrollHand._y -= unit;
				} else {
					scrollHand._y = scrollMet.startY;
				}
			}
		#end
		scroll(clip, scrollHand, scrollMet);
	}

	static private function scrollByOne(clip : ArcticMovieClip, scrollHand : ArcticMovieClip, 
						scrollMet : ScrollMetrics, scrollDown : Bool) {
		var interval = new haxe.Timer(15);                
		interval.run = function () {
			var scrollPressed = false;
			if (Reflect.hasField(Bool, "scrollPressed")) {
			   scrollPressed = Reflect.field(Bool, "scrollPressed");
			}
			moveBy( clip, scrollHand, scrollMet, scrollDown, 1);
			if ( !scrollPressed ) {
				interval.stop();
			}
		}
	}

	static private function scroll(clip : ArcticMovieClip, scrollHand : ArcticMovieClip, scrollMet : ScrollMetrics ) {
		var rect = ArcticMC.getScrollRect(clip);
		
		#if flash9
			scrollHand.y = Math.min(scrollMet.endY, Math.max(scrollMet.startY, scrollHand.y));
			var diff = scrollHand.y - scrollMet.startY;
		#else flash
			scrollHand._y = Math.min(scrollMet.endY, Math.max(scrollMet.startY, scrollHand._y));
			var diff = scrollHand._y - scrollMet.startY;
		#end
		var increment = scrollMet.toScroll * diff;
		if (increment < (scrollMet.clipHeight - rect.height) ) {
			#if flash7
			rect.top = increment;
			#else true
			// Using .y does not change height of rectangle in Flash 8 & 9, while using .top *will* change height
			rect.y = increment;
			#end
			ArcticMC.setScrollRect(clip, rect);
		} else {
			#if flash7
			rect.top = scrollMet.clipHeight - rect.height;
			#else true
			// Using .y does not change height of rectangle in Flash 8 & 9, while using .top *will* change height
			rect.y = scrollMet.clipHeight - rect.height;
			#end
			ArcticMC.setScrollRect(clip, rect);
		}
	}

	static private function moveToY(clip : ArcticMovieClip, scrollHand : ArcticMovieClip, ensureYVisible : Float ) {
		var rect = ArcticMC.getScrollRect(clip);
		var scrollMet = Reflect.field(clip, "scrollmet");
		var visibleY = rect.top + rect.height;
		var moveToY : Float = rect.top;
		if ( (ensureYVisible >= rect.top) && (ensureYVisible <= visibleY) ) {
			return;
		}

		if (ensureYVisible < rect.top) {
			moveToY = ensureYVisible;
		}
		if (ensureYVisible > visibleY) {
			moveToY = ensureYVisible - rect.height;
		}           
		var diff = moveToY / scrollMet.toScroll;
		#if flash7
		rect.top = moveToY;
		#else true
		// Using .y does not change height of rectangle in Flash 8 & 9, while using top *will* change height
		rect.y = moveToY;
		#end
		ArcticMC.setScrollRect(clip, rect);
		#if flash9
            scrollHand.y = scrollMet.startY + diff;
		#else flash 
            scrollHand._y = scrollMet.startY + diff;
		#end
    }

    #if flash9 
		private static function getChild(m : ArcticMovieClip, n : Int)  : ArcticMovieClip {
			var d : Dynamic = m.getChildAt(n);
			return d;
		}
	#end
}
