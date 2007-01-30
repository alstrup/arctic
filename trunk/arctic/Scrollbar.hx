package arctic;

#if flash9
import flash.display.MovieClip;
import flash.geom.Rectangle;
#else true
import flash.MovieClip;
import flash.geom.Rectangle;
import flash.Mouse;
#end

typedef ScrollMetrics = { startX : Float, startY : Float, 
                         endY : Float, scrollHeight : Float, toScroll : Float, 
                         clipHeight : Float, dragHeight : Float }

class Scrollbar {


    /// Increasing this value will reduce the speed of the scroll bar and vice versa
    static private var SCROLL_DELAY : Int = 100;


    // This method draws a scrollbar given a movie clip. 
    // This movieclips should have a parent, which will also be the parent of the scroll bar 
    // rendered.
    // This can be seperated out and written as a seperate class - ideally it should use ArcticBlocks to construct itself
    public static function drawScrollBar(parent : MovieClip, clip : MovieClip, availableWidth : Float,
                                                         availableHeight : Float, realHeight : Float, ensureYVisible : Float) {
        #if flash9 
            drawScrollBarForFlash9(parent, clip, availableWidth, availableHeight, realHeight, ensureYVisible);
        #else flash
			var scrollBar;
			
			if (Reflect.hasField(parent, "scrollbar")) {
				scrollBar = Reflect.field(parent, "scrollbar");
			} else {
				var d = parent.getNextHighestDepth();
				scrollBar = parent.createEmptyMovieClip("c" + d, d);
				Reflect.setField(parent, "scrollbar", scrollBar);
			}
            var clipRect = new Rectangle<Float>(0, 0, availableWidth, availableHeight);
            clip.scrollRect = clipRect;
			parent.scrollRect = clipRect;
            var squareHeight = 10;

            var d = scrollBar.getNextHighestDepth();
            var upperChild = scrollBar.createEmptyMovieClip("scrollBarUpperChild" + d, d);

            // Upper scroll bar handle
            //Drawing upper white squate    
            
            DrawUtils.drawRectangle(upperChild, 0, 0, 12, squareHeight, 0, 
                                        0x000000, 0x000000 );
            var height =  7;

            //Drawing upper scrollbar triangle
            upperChild.lineStyle(0.2, 0xFFFFFF);
            upperChild.beginFill(0xFFFFFF);
            upperChild.moveTo(2 , height );
            upperChild.lineTo(2 , height );
            upperChild.lineTo(2 + 7 , height );
            upperChild.lineTo(2 + 3.5 , height - 4 );
            upperChild.endFill();

			// The slider background part
            var scrollHeight = availableHeight - (squareHeight * 2);

            d = scrollBar.getNextHighestDepth();
            var scrollOutline = scrollBar.createEmptyMovieClip("scrollBarOutline" + d, d);
            
            DrawUtils.drawRectangle(scrollOutline, 0, 0, 10, scrollHeight, 0, 
                                                                      0x000000);
            scrollOutline._y = upperChild._height;
			
			// The slider hand
            d = scrollBar.getNextHighestDepth();
            var scrollHand = scrollBar.createEmptyMovieClip("scrollHand" + d, d);
            var scrollHandHeight = 10.0;
            if ((realHeight - availableHeight) < scrollHeight) {
                scrollHandHeight = scrollHeight - (realHeight - availableHeight);
            }
            DrawUtils.drawRectangle(scrollHand, 0, 0, 6, scrollHandHeight - 0.5,
                                                            0, 
                                                            0x000000, 0x000000);
            var scrollMet = { 
					startX : 2.0, 
					startY : upperChild._height + 0.5, 
					endY : 0.0, 
					scrollHeight : scrollHeight - scrollHandHeight - 1, 
					toScroll : 0.0, 
					clipHeight : realHeight, 
					dragHeight : scrollHeight - scrollHandHeight + 10
			};
			scrollMet.toScroll = ( (realHeight - availableHeight) / scrollMet.scrollHeight);
            scrollMet.endY = scrollMet.startY + scrollMet.scrollHeight - 0.5;
			Reflect.setField(clip, "scrollmet", scrollMet);
            scrollHand._y = scrollMet.startY;
            scrollHand._x = scrollMet.startX;

			// The lower button
            d = scrollBar.getNextHighestDepth();
            var lowerChild = scrollBar.createEmptyMovieClip("scrollBarLowerChild" + d, d);

            //Drawing lower white square 
            DrawUtils.drawRectangle(lowerChild, 0, 0, 12, squareHeight, 0, 
                                        0x000000, 0x000000 );
            height = 3;
            //Drawing lower scrollbar triangle
            lowerChild.lineStyle(0.2, 0xFFFFFF);
            lowerChild.beginFill(0xFFFFFF);
            lowerChild.moveTo(2 , height );
            lowerChild.lineTo(2, height );
            lowerChild.lineTo(2 + 7, height );
            lowerChild.lineTo(2 + 3.5, height + 4 );
            lowerChild.endFill();
            //lowerChild._x = 10;
            lowerChild._y = availableHeight - 10 ;

			// Behaviour
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
                    scrollTimer(clip, scrollHand, clipRect);
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
                    scroll(clip, scrollHand, clipRect, scrollMet);
                } else if ( inLowerChild) {
                    Reflect.setField(Bool, "scrollPressed", true);
                    scrollByOne(clip, scrollHand, clipRect, scrollMet, true);
                } else if (inUpperChild) {
                    Reflect.setField(Bool, "scrollPressed", true);
                    scrollByOne(clip, scrollHand, clipRect, scrollMet, false);
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
            }

            scrollBar._x = availableWidth - 11;
            scrollBar._y = clip._y;
            moveToY(clip, scrollHand, clipRect, ensureYVisible);
            
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
                            moveBy(clip, scrollHand, clipRect, scrollMet, 
                                                          scrollDown, intDelta);
						}
					}
				};
			flash.Mouse.addListener(mouseWheelListener);
        #end
       }

	static public function removeScrollbar(parent : MovieClip, clip : MovieClip) {
		if (Reflect.hasField(parent, "scrollbar")) {
			#if flash9
				parent.removeChild(Reflect.field(parent, "scrollbar"));
				parent.scrollRect = null;
				clip.scrollRect = null;
			#else flash
				Reflect.field(parent, "scrollbar").removeMovieClip();
				parent.scrollRect = null;
				clip.scrollRect = null;
			#end
			Reflect.deleteField(parent, "scrollbar");
		}
	}

    #if flash9
       static public function scrollTimer(clip : MovieClip, scrollHand : MovieClip, 
                            rect : Rectangle) {          
    #else flash
       static public function scrollTimer(clip : MovieClip, scrollHand : MovieClip, 
                        rect : Rectangle<Float>) {
    #end
			var scrollMet = Reflect.field(clip, "scrollmet");
            var interval = new haxe.Timer(100);                
            interval.run = function () {
                var dragged = Reflect.field(Bool, "dragging");
                scroll(clip, scrollHand, rect, scrollMet);
                if ( !dragged ) {
                    interval.stop();
                }
            }
        }


    #if flash9
        static private function moveBy(clip : MovieClip, 
                             scrollHand : MovieClip, rect : Rectangle, 
                         scrollMet : ScrollMetrics, scrollDown : Bool, unit : Int) {
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
        static private function moveBy(clip : MovieClip, scrollHand : MovieClip, 
                      rect : Rectangle < Float >, scrollMet : ScrollMetrics,
                                              scrollDown : Bool, unit : Int) {
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
                scroll(clip, scrollHand, rect, scrollMet);
        }



    #if flash9
        static private function scrollByOne(clip : MovieClip, 
                             scrollHand : MovieClip, rect : Rectangle, 
                             scrollMet : ScrollMetrics, scrollDown : Bool) {
   #else flash
        static private function scrollByOne(clip : MovieClip, scrollHand : MovieClip, 
              rect : Rectangle < Float >, scrollMet : ScrollMetrics,
                                                            scrollDown : Bool) {
        
   #end
            var interval = new haxe.Timer(15);                
            interval.run = function () {
                var scrollPressed = false;
                if (Reflect.hasField(Bool, "scrollPressed")) {
                   scrollPressed = Reflect.field(Bool, "scrollPressed");
                }
                moveBy ( clip, scrollHand, rect, scrollMet, scrollDown, 1);
                if ( !scrollPressed ) {
                    interval.stop();
                }
            }
        }



    #if flash9
        static private function scroll(clip : MovieClip, scrollHand : MovieClip, 
                rect : Rectangle, scrollMet : ScrollMetrics ) {   
            if ( scrollHand.y < scrollMet.startY ) {
				scrollHand.y = scrollMet.startY;
            }
             
			if ( scrollHand.y > scrollMet.endY ) {
				scrollHand.y = scrollMet.endY;
            }
             
            if ( (scrollHand.y >= scrollMet.startY )  && (scrollHand.y <= scrollMet.endY)) {
                var diff = scrollHand.y - scrollMet.startY;

    #else flash
        static private function scroll(clip : MovieClip, scrollHand : MovieClip, 
                    rect : Rectangle < Float >, scrollMet : ScrollMetrics) {
             if ( scrollHand._y < scrollMet.startY ) {
             	scrollHand._y = scrollMet.startY;
             }
             
	     if ( scrollHand._y > scrollMet.endY ) {
             	scrollHand._y = scrollMet.endY;
             }
             
             if ( (scrollHand._y >= scrollMet.startY )  && (scrollHand._y <= scrollMet.endY)) {
                var diff = scrollHand._y - scrollMet.startY;
    #end
                var increment = scrollMet.toScroll * diff;
                if (increment < (scrollMet.clipHeight - rect.height) ) {
                    rect.y = increment;
                    clip.scrollRect = rect;
                } else {
                    rect.y = scrollMet.clipHeight - rect.height;
                    clip.scrollRect = rect;
                }
            }
        }

    #if flash9
        static private function moveToY(clip : MovieClip, scrollHand : MovieClip, 
                          rect : Rectangle, ensureYVisible : Float ) {
    #else flash
        static private function moveToY(clip : MovieClip, scrollHand : MovieClip, 
                          rect : Rectangle < Float >, ensureYVisible : Float ) {
    #end
			var scrollMet = Reflect.field(clip, "scrollmet");
            var visibleY = rect.y + rect.height;
            var moveToY = rect.y;
            if ( (ensureYVisible >= rect.y) && (ensureYVisible <= visibleY) ) {
                return;
            }

            if (ensureYVisible < rect.y) {
                moveToY = ensureYVisible;
            }
            if (ensureYVisible > visibleY) {
                moveToY = ensureYVisible - rect.height;
            }           
            var diff = moveToY / scrollMet.toScroll;
            rect.y = moveToY;
            clip.scrollRect = rect;
    #if flash9
            scrollHand.y = scrollMet.startY + diff ;
    #else flash 
            scrollHand._y = scrollMet.startY + diff ;
    #end
            }

    #if flash9 
	
		private static function getChild(m : MovieClip, n : Int)  : MovieClip {
			var d : Dynamic = m.getChildAt(n);
			return d;
		}
	
        private static function drawScrollBarForFlash9(parent : MovieClip, clip : MovieClip, availableWidth : Float,
                                                         availableHeight : Float, realHeight : Float, ensureYVisible : Float) {
			var scrollBar : MovieClip;
			var upperChild : MovieClip;
			var scrollOutline : MovieClip;
			var scrollHand : MovieClip;
			var lowerChild : MovieClip;
			var construct : Bool;
			if (Reflect.hasField(parent, "scrollbar")) {
				scrollBar = Reflect.field(parent, "scrollbar");
				upperChild = getChild(scrollBar, 0);
				scrollOutline = getChild(scrollBar, 1);
				scrollHand = getChild(scrollBar, 2);
				lowerChild = getChild(scrollBar, 3);
				construct = false;
			} else {
				scrollBar = new MovieClip();
				Reflect.setField(parent, "scrollbar", scrollBar);
				parent.addChild(scrollBar);

				upperChild = new MovieClip();
				scrollBar.addChild(upperChild);

				scrollOutline = new MovieClip();
				scrollBar.addChild(scrollOutline);

				scrollHand = new MovieClip();
				scrollBar.addChild(scrollHand);

				lowerChild = new MovieClip();
				scrollBar.addChild(lowerChild);
				construct = true;
			}
            var clipRectangle = new Rectangle(0, 0 , availableWidth, availableHeight);
            clip.scrollRect = clipRectangle;
            parent.scrollRect = clipRectangle;
            var squareHeight = 10;

			var height =  7;

            // Upper scroll bar handle
			if (construct) {
				//Drawing upper white squate    
				DrawUtils.drawRectangle(upperChild, 0, 0, 12, squareHeight, 0, 
															   0x000000, 0x000000 );
				
				//Drawing upper scrollbar triangle
				upperChild.graphics.beginFill(0xFFFFFF);
				upperChild.graphics.moveTo(2 , height );
				upperChild.graphics.lineTo(2 , height );
				upperChild.graphics.lineTo(2 + 8 , height );
				upperChild.graphics.lineTo(2 + 4 , height - 4 );
				upperChild.graphics.endFill();
			}

            var scrollHeight = availableHeight - (squareHeight * 2);

			scrollOutline.graphics.clear();
            DrawUtils.drawRectangle(scrollOutline, 0, 0, 10, scrollHeight, 0, 
                                                          0x000000, 0x000000,0);

            scrollOutline.y = upperChild.height;

            var scrollHandHeight = 10.0;

            if ((realHeight - availableHeight) < scrollHeight) {
                scrollHandHeight = scrollHeight - (realHeight - availableHeight);
            }

			scrollHand.graphics.clear();
            DrawUtils.drawRectangle(scrollHand, 0, 0, 6, scrollHandHeight - 0.5,
                                                            0, 
                                                            0x000000, 0x000000);
            var scrollMetrics = { 
					startX : 2.0, 
					startY : upperChild.height + 0.5, 
					endY : 0.0, 
					scrollHeight : scrollHeight - scrollHandHeight - 1, 
					toScroll : 0.0,
					clipHeight : realHeight, 
					dragHeight : scrollHeight - scrollHandHeight + 10 
			};
			scrollMetrics.toScroll = ( (realHeight - availableHeight) / scrollMetrics.scrollHeight);
            scrollMetrics.endY = scrollMetrics.startY + scrollMetrics.scrollHeight - 0.5;
			
			Reflect.setField(clip, "scrollmet", scrollMetrics);
			
            scrollHand.y = scrollMetrics.startY;
            scrollHand.x = scrollMetrics.startX;

            // Drawing lower white square 
			lowerChild.graphics.clear();
            DrawUtils.drawRectangle(lowerChild, 0, 0, 12, squareHeight, 0, 
                                                           0x000000, 0x000000 );
            
            height = 3;
            // Drawing lower scrollbar triangle
            lowerChild.graphics.beginFill(0xFFFFFF);
            lowerChild.graphics.moveTo(2 , height );
            lowerChild.graphics.lineTo(2, height );
            lowerChild.graphics.lineTo(2 + 8, height );
            lowerChild.graphics.lineTo(2 + 4, height + 4 );
            lowerChild.graphics.endFill();
            //lowerChild._x = 10;
            lowerChild.y = availableHeight - 10 ;

			if (construct) {
				scrollHand.addEventListener(
					flash.events.MouseEvent.MOUSE_DOWN, 
					function (s) {
						var scrollMet = Reflect.field(clip, "scrollmet");
						scrollHand.startDrag(false, new Rectangle(
														scrollMet.startX , 
														scrollMet.startY ,
																	   0 , 
														scrollMet.dragHeight) );
						Reflect.setField(Bool, "dragging", true);
						scrollTimer(clip, scrollHand, clip.scrollRect);
					 } ); 

					var mouseUp = function (s) {
						var dragged = Reflect.field(Bool, "dragging");
						if (dragged) {
							scrollHand.stopDrag();                
							Reflect.setField(Bool, "dragging", false);
						}
					 }
				scrollHand.addEventListener(flash.events.MouseEvent.MOUSE_UP, 
																		   mouseUp); 

				scrollHand.stage.addEventListener(flash.events.MouseEvent.MOUSE_UP,
																		  mouseUp );

				scrollOutline.addEventListener(
					flash.events.MouseEvent.MOUSE_DOWN, 
					function (s) {
						var scrollMet : ScrollMetrics = Reflect.field(clip, "scrollmet");
						//var scrollToY = scrollBar._ymouse;
						var scrollToY = s.localY;
						var startY = scrollMet.startY;
						if (scrollToY < startY ) {
							scrollToY = scrollMet.startY;
						} else if (scrollToY >= scrollMet.endY) {
							scrollToY = scrollMet.endY;
						}
						scrollHand.y = scrollToY;
						scroll(clip, scrollHand, clip.scrollRect, scrollMet);
					 } ); 



				lowerChild.addEventListener(
					flash.events.MouseEvent.MOUSE_DOWN, 
					function (s) {
						var scrollMet = Reflect.field(clip, "scrollmet");
						Reflect.setField(Bool, "scrollPressed", true);
						scrollByOne(clip, scrollHand, clip.scrollRect, scrollMet, true);
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
						scrollByOne(clip, scrollHand, clip.scrollRect, scrollMet, false);
					} ); 


				upperChild.addEventListener(
					flash.events.MouseEvent.MOUSE_UP, 
					function (s) {
						var scrollPressed = Reflect.field(Bool, "scrollPressed");
						if (scrollPressed) {
							Reflect.setField(Bool, "scrollPressed", false);
						}            
					 } ); 
			}

            scrollBar.x = availableWidth - 11;
            scrollBar.y = clip.y;
            moveToY(clip, scrollHand, clip.scrollRect, ensureYVisible);

			if (construct) {
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
							moveBy(clip, scrollHand, clip.scrollRect, scrollMet, 
															  scrollDown, intDelta);
						}
					}
				);
			}
		}
		#end
}
