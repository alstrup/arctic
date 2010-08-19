package arctic;
import arctic.ArcticMC;

// We introduce an alias for MovieClip which works in both Flash 8 & 9. See also ArcticMC.hx
#if flash9
	typedef ArcticMovieClip = flash.display.Sprite;
#elseif flash
	typedef ArcticMovieClip = flash.MovieClip
#elseif neko
	typedef ArcticMovieClip = neash.display.MovieClip
#end

/**
 * Arctic is an embedded Domain Specific Language for making user interfaces.
 * A user interface is built from ArcticBlocks. Read this file to learn which
 * blocks are available.
 */
enum ArcticBlock {
	/**
	 * Draw a solid background behind the given block. 
	 * Alpha is an optional transparency from 0.0 to 100.0.
	 * roundRadius > 0 makes the background rounded at the corners.
	 */
	Background(color : Null<Int>, block : ArcticBlock, ?alpha : Null<Float>, ?roundRadius : Null<Float>);

	/**
	 * Draw a gradient background behind the given block.
	 * colors is an array of colors in the gradient.
	 * xOffset & yOffset are percentage offsets from the center of the block, so an offset of 0.5, -0.5 means
	 * to put the center of the gradient in the top, right corner.
	 * Alpha is an array of optional transparencies from 0 to 100.0. It has to have as many entries as the color array.
	 * roundRadius > 0 makes the gradient rounded at the corners.
	 * rotation - the amount to rotate, in radians (the default value is 0).
	 * ratios - an array with numbers from 0 to 255 defining how to "distribute" the gradient colors.
	 */ 
	GradientBackground(type : String, colors : Array<Int>, xOffset : Float, yOffset : Float, block : ArcticBlock, ?alpha : Array<Float>, ?roundRadius : Null<Float>, ?rotation: Null<Float>, ?ratios: Array<Int>);

	/// Add some space around the block
	Border(x : Float, y : Float, block : ArcticBlock);

	/**
	 * A text (in the subset of HTML which Flash understands).
	 * If wordWrap is true, the text will grow in the width and height as much as possible,
	 * and the text inside word wrap according to how much width is available. Notice that
	 * layout of word-wrapping text can be unreliable when combined with Align or other 
	 * layout elements because of limitations of the layout algorithm used. In this cases, 
	 * the result will become much more predictable when you wrap the Text block with a
	 * ConstrainWidth block: 
	 * 
	 *   ConstrainWidth(0, width, Text(text, null, true))
	 * 
	 * If wordWrap is false, the text will always have the same size, and only break lines
	 * if <br/> tags exist in the text.
	 * selectable defines whether user can select & copy contents.
	 */
	Text(html : String, ?embeddedFont : Null<Bool>, ?wordWrap : Null<Bool>, ?selectable: Null<Bool>, ?format : ArcticTextFormat);

	/**
	 * An input text.  Text Font/Size/Color can be specified along with initial text content in the subset of HTML which Flash understands.
	 * The validator callback is called on each change. You can use this callback to extract the contents of the text input.
	 * Width and height, being set to null, cause text field to resize dynamically in the relevant direction (and call refresh(false) upon it)
	 * All fields of the style parameter is copied verbatim to the textinput object. This allows you to customize the text input in
	 * all detail, but it's up to you to make sure this works in both Flash 8 & 9. ( { wordWrap: true, multiline: true } as style is portable.)
	 * The onInit parameter is called on construction and returns a function textFn( TextInputModel ) : TextInputModel which
	 * can be used to change the contents of the TextInput (html and text), force it to have focus, change selection and cursor position, 
	 * and will return current TextInput status in each of these dimensions. 
	 * When changing, pass the values you don't want to change as null. If you only want to get status, you can pass null for the entire structure 
	 */
	TextInput(html : String, width : Null<Float>, height : Null<Float>, ?validator : String -> Bool, ?style : Dynamic, ?maxChars : Null<Int>, ?numeric : Null<Bool>, ?bgColor : Null<Int>, ?focus : Null<Bool>, ?embeddedFont : Null<Bool>, ?onInit : (TextInputModel -> TextInputModel) -> Void, ?onInitEvents: (TextInputEvents -> Void) -> Void);

	/**
	* A static picture loaded from a URL. It is your responsibility to set the scaling such that the picture has the stated size.
	* Notice that the width & height should be the size of this block, not the original size of the picture. If crop is true,
	* the picture will be cropped the number of pixels in all edges.
	*/
	Picture(url : String, width : Float, height : Float, scaling : Float, ?resource : Null<Bool>, ?crop : Int, ?cache : Bool, ?cbSizeDiff : Float -> Float -> Void);

	/**
	 * A button - when mouse is above, we change to hover look. Notice block and hover should have the exact same size.
	 * When the button is clicked, onClick is called. If onClickExtended is supplied, it is called with the x and y
	 * coordinates, plus a bool signifying whether the mouse button is pressed (true) or released (false). 
	 * onClickExtended is called even if the click or released is outside the button, and the final bool tells 
	 * whether the click is inside the button or not.
	 * On button release, onClick is called before onClickExtended.
	 * hover can be null, in which case the button does not change look when hovered.
	 */
	Button(block : ArcticBlock, hover : ArcticBlock, onClick : Void -> Void, ?onClickExtended : Float -> Float -> Bool -> Bool-> Void);

	/**
	 * Toggle button (selected/unselected).
	 * Though technically the ArcticBlock can be of any type, the most appropriate ones are Text & Picture.
	 * Notice that the selected and unselected blocks should have the exact same size, because we do not
	 * do a relayout when the state is changed. The onInit method is called when the view is constructed
	 * with the state we have. This can be used to implement connected radio button groups - like Arctic.makeTextChoice
	 * and Arctic.makeRadioButtonGroup do. This can also be used to implement check boxes - see Arctic.makeCheckbox.
	 */ 
	ToggleButton(selected : ArcticBlock, unselected : ArcticBlock, initialState : Bool, onChange : Bool -> Void, ?onInit : (Bool -> Void) -> Void);

    /**
     * The ArcticBlock will be constrained to the dimensions given - in terms of layout only.
	 * To crop a clip, use the Crop block. 
	 * If the minimumWidth is negative, the absolute value is reserved for layout purposes 
	 * even if there is not extra space from the environment. However, the block is not 
	 * artificially grown in case there was enough space to begin with.
     */
    ConstrainWidth(minimumWidth : Float, maximumWidth : Float, block : ArcticBlock); 

    /**
     * The ArcticBlock will be constrained to the dimensions given - in terms of layout only.
	 * To crop a clip, use the Crop block.
	 * If the minimumHeight is negative, the absolute value is reserved for layout purposes 
	 * even if there is not extra space from the environment. However, the block is not 
	 * artificially grown in case there was enough space to begin with.
     */
    ConstrainHeight(minimumHeight : Float, maximumHeight : Float, block : ArcticBlock);

	/**
	 * Clip the block to a certain size
	 */
	Crop(x : Float, y : Float, width : Null<Float>, height : Null<Float>, block : ArcticBlock);
	
	/**
	 * Filler is greedy empty space, that eats space when put in a LineStack or ColumnStack.
	 * This can be used to implement left alignment, centering, and similar layout strategies.
	 */
	Filler;
	
	/**
	 * A block of the given size - can be empty
	 */
	Fixed(width : Null<Float>, height : Null<Float>);

	/**
	 * Align a block. 
	 * xpos: 0=left align, 0.5 = center horizontally, 1=right align, -1 = width to fit, -2 = use width of child
	 * ypos: 0=top align, 0.5 = center vertically, 1=bottom align, -1 = height to fit, -2 = use height of child
	 */
	Align(xpos : Float, ypos : Float, block : ArcticBlock);
	
	/**
	 * Columns are blocks put next to each other horizontally. The height is the maximum
	 * height of the blocks. If there is an unconstrained filler in the column stack (recursively)
	 * this block will use all available width.
	 */
	ColumnStack(columns: Array<ArcticBlock>, ?useIntegerFillings: Bool, ?rowAlign : Float);

	/**
	 * A bunch of blocks stacked on top of each other. The width is the maximum width
	 * of the blocks. If you want to make sure the very top of a specific block is visible, 
	 * pass the index number of the block in the array as second parameter. Notice there
	 * is no guarantee that all of the entry is visible. If you do not need a scrollbar,
	 * no matter how high the LineStack is, then pass false as the last parameter. The default
	 * is to automatically add a scrollbar if needed.
	 */
	LineStack(blocks: Array<ArcticBlock>, ?ensureVisibleIndex: Null<Int>, ?useScrollbar : Bool, ?useIntegerFillings: Bool, ?lineAlign : Float);
	
	/**
	 * A 2-d grid of block. For now, this does not support resizing or horizontal scrollbar.
	 * Vertical scrollbar will be added automatically if the opposite is not specified
	 */
	Grid(blocks: Array<Array<ArcticBlock>>, ?disableScrollbar: Bool, ?oddRowColor: Int, ?evenRowColor: Int, ?borderSize : Float, ?borderColor : Float);

	//TODO: may be it should be removed from ArcticBlock enum? 
	TableCell(block : ArcticBlock, ?rowSpan : Int, ?colSpan : Int, ?topBorder : Int, ?rightBorder : Int, ?bottomBorder : Int, ?leftBorder : Int);
	Table(cells : Array<ArcticBlock>, nRows : Int, nCols : Int, borderColor : Null<Int>);
	
	/**
	* Places the first block at the top-left corner, then the next block will be placed to the right. 
	* The layout continues placing blocks along the x axis until a block reaches the bestWidth, then 
	* the layout will begin placing blocks at the next row.
	* Best width is choosen from [lowerWidth * maxWidth ... maxWidth] by minimizing of block area.
	* 	eolFiller: optional block, which will be placed into the end of each row if there is some 
	* 			free space
	* If maxWidth is null, the block will grow and use all available width.
	* lowerWidth should be in [0 ... 1] range. By default its value is 0.45
	* lineAlign defines blocks alignment in the row. [Top ... Bottom] corresponds to [0 ... 1] range.
	* rowAlign defines left-to-right justification of each row. Should be in [0 ... 1] range.
	* rowIndent defines first line indentation. Negative value indents subsequent lines.
	*/
	Wrap(blocks: Array<ArcticBlock>, ?maxWidth: Float, ?xspacing: Null<Float>, ?yspacing: Null<Float>, ?eolFiller: ArcticBlock, ?lowerWidth : Float, ?lineAlign : Float, ?rowAlign : Float, ?rowIndent : Float );

	/// Add a scrollbar if necessary
    ScrollBar(block : ArcticBlock);

	/**
	 * Make a block dragable by the mouse in the given directions.
	 * If stayWithinSize is true, the movement is constrained to the available area
	 * of the block (and this block becomes size greedy in the directions we allow motion in).
	 * This block can be used to make many things, including dialogs. Use the wrapper 
	 * Arctic.makeDragable if you want to preserve the dragged distance across canvas resizes.
	 */
	Dragable(stayWithinBlock : Bool, sideMotionAllowed : Bool, upDownMotionAllowed : Bool, block : ArcticBlock, 
			onDrag : DragInfo -> Void, ?onInit : DragInfo -> (Float -> Float -> Void) -> Void, ?onStopDrag: Void -> Void);

	/**
	 * Set the cursor shape to a block when the mouse is within the given block.
	 * If you want the cursor block to be in ADDITION to the normal cursor, set
	 * keepNormalCursor to true. This is useful for tooltips, see Arctic.makeTooltip.
	 * Per default, the normal cursor is hidden when the custom cursor is visible.
	 * If showFullCursor is true and cursor block juts out base clip on the right side,
	 * cursor block will be placed a bit left to mouse cursor (but its left-upper corner
	 * will be still visible). Same for bottom side.
	 */
	Cursor(block : ArcticBlock, cursor : ArcticBlock, ?keepNormalCursor : Null<Bool>, ?showFullCursor : Null<Bool> );

	/**
	 * Translate a block in some direction - notice layout does not take this offset
	 * into account.
	 */
	Offset(xOffset : Float, yOffset : Float, block : ArcticBlock);

	/**
	 * Place a block on top of another block (overlay). The size is the maximum of the
	 * two blocks in each dimension.
	 */
	OnTop(base : ArcticBlock, overlay : ArcticBlock);
	
	#if flash9
	OnTopView(base : ArcticBlock, overlay : ArcticBlock);
	#end

	/// A state-full block which can be updated from the outside with a new block. See MutableBlock below for more info
	Mutable( state : MutableBlock );
	
	/**
	 * A choice block that allows you to choose one of an array of blocks. At any time, 
	 * just one of these blocks is visible (the initial one is selected by 'current'). The 
	 * block will cache the views of the other, invisible blocks, so that switching to another 
	 * block is fast. The onInit function is a function that is called on construction with a 
	 * function which allows you to switch between the different blocks.
	 * 
	 * Example:
	 * 
	 *   var switchFn : Int -> Void; 
	 *   var getSwitchFn = function (fn) { switchFn = fn; };
	 *   var gui = Switch( [ block0, block1, block2 ], 0, getSwitchFn);
	 *   ...
	 *   // Switch to block 1
	 *   switchFn(1);
	 * 
	 * See Arctic.makeSwitch for an simple wrapper that helps do this.
	 */ 
	Switch(blocks : Array<ArcticBlock>, current : Int, onInit : (Int -> Void) -> Void);
	
	/**
	 * Name this block so that we can get to it, and update it using ArcticView.update
	 * and ArcticView.getRawMovieClip. Has no visual effect besides this.
	 */
	Id(name : String, block : ArcticBlock);

	/**
	 * A custom block. This is an escape mechanism which allows you to extend Arctic
	 * with your own basic blocks. Parameters:
	 * 
	 *  data: an optional payload.
	 *  buildFunc: This is called with the optional data payload as first parameter,
	 *       the build mode requested (see enum below), the parent MovieClip where the 
	 *       block should be put or drawn, and the available height and width for the 
	 *       element. The final parameter is any existing MovieClip. This is useful in
	 *       Reuse mode, where the code should update the looks of this MovieClip.
	 * 
	 *       The buildFunc should return parentMc as clip in Create mode, existingMC in
	 *       Reuse mode, and null in Metrics mode. (Therefore, this could be omitted
	 *       from the API, but for now, I'll let it be like be like this to avoid
	 *       introducing new types.)
	 * 
	 *       The function should return the metrics for the block. The different build modes
	 *       should be consistent in the metrics - otherwise, layout bugs can occur.
	 * 
	 * Notice that you have to build the custom blocks such that their work with
	 * both Flash 8 and 9. See ArcticMC for helper functions that makes this simpler.
	 */
	CustomBlock( data : Dynamic, buildFunc : Dynamic -> BuildMode -> ArcticMovieClip -> Float -> Float -> ArcticMovieClip -> Metrics );

	/**
	 * Draws a frame around the given block. Alpha is optional between 0 and 100.
	 */
	Frame(thickness: Float, color: Int, block: ArcticBlock, ?roundRadius: Null<Float>, ?alpha: Null<Float>, ?xspacing: Null<Float>, ?yspacing: Null<Float>);

	/**
	 * Apply a filter on the block. Notice that the filter effect is not considered as part of the block
	 * in terms of size.
	 */
	Filter(filter : Filter, block : ArcticBlock);

	/**
	 * Captures mouse wheel movements in the given block
	 */
	MouseWheel(block : ArcticBlock, onMouseWheel : Float -> Void);

	/**
	 * A masking block - a block is masked by another block
	 */
	Mask(block : ArcticBlock, mask : ArcticBlock);

	/**
	 * Scale a block - original size is 1.0. The scaling can be constrained to maxScale.
	 * If childGrowth is 1.0, the child gets all available space for layout. Default is 0.
	 */
	Scale(block : ArcticBlock, ? maxScale : Float, ? alignX : Float, ? alignY : Float, ?childGrowth : Float);
	
	/**
	 * Transform a block
	 */
	Transform(block : ArcticBlock, scaleX : Float, scaleY : Float);
	
	#if flash9
	/// Rotates a block. The angle is in degrees. If keepOrigin is true, we do not translate or enlarge the result accordingly
	Rotate(block : ArcticBlock, ?angle : Float, ?keepOrigin : Bool);
	#end

	/// An animation block
	Animate(animator : Animator);
	
	Cached(block : ArcticBlock);
	UnCached(block : ArcticBlock);
	
	/// Special block which is useful for debugging
	DebugBlock(id : String, block : ArcticBlock);
}

/// The structure used by CustomBlocks to tell arctic of dimensions and requested resizing behaviour
typedef Metrics = { clip: ArcticMovieClip, width : Float, height : Float, growWidth : Bool, growHeight : Bool }

/// What the build function should do
enum BuildMode {
	/// Create a new movieclip for the block
	Create;
	/// Reuse an existing movieclip, but update that to reflect the block
	Reuse;
	/// Do not create or change any movieclips - just calculate metrics
	Metrics;
	/// Destroy, removing movieClip and event listeners.
	Destroy;
}

/// Information returned about draggable blocks
typedef DragInfo = {
	// How much we have moved so far in pixels?
	x : Float,
	y : Float,
	// How wide/high is the drag handle?
	width : Float,
	height : Float,
	// How much room is available for dragging in pixels?
	totalWidth : Float,
	totalHeight : Float
}

/**
 * TextInputModel is an aux structure to manipulate get and set status of text inputs - see below
 * Note: when setting status, leave the parameters you don't want to change as null
 * Selection takes precedence over cursor position when setting
 */
typedef TextInputModel = {
	var html: Null<String>;
	var text: Null<String>;
	var focus: Null<Bool>;
	var selStart: Null<Int>;
	var selEnd: Null<Int>;
	var cursorPos: Null<Int>;
	var disabled: Null<Bool>;
	var cursorX: Null<Float>;
}

/**
 * TextInputEvents is an aux structure to manipulate manipulate input events
 */
typedef TextInputEvents = {
	var onChange: Void -> Void;
	var onSetFocus: Void -> Void;
	var onKillFocus: Void -> Void;
	var onPress: Void -> Void;
	var onRelease: Void -> Void;
	#if flash9
	var onKeyDown: UInt -> Void;
	var onKeyUp: UInt -> Void;
	#else
	var onKeyDown: Int -> Void;
	var onKeyUp: Int -> Void;
	#end
	var onCaretPosChanged: Void -> Void;
}

enum Filter {
	#if flash9
	Bevel(?distance : Float, ?angle : Float, ?highlightColor : UInt, ?highlightAlpha : Float, ?shadowColor : UInt, ?shadowAlpha : Float, ?blurX : Float, ?blurY : Float, ?strength : Float, ?quality : Int, ?type : String, ?knockout : Bool);
	Blur(?blurX : Float, ?blurY : Float, ?quality : Int);
	ColorMatrix(?matrix : Array<Float>);
	Convolution(?matrixX : Float, ?matrixY : Float, ?matrix : Array<Dynamic>, ?divisor : Float, ?bias : Float, ?preserveAlpha : Bool, ?clamp : Bool, ?color : UInt, ?alpha : Float);
	DropShadow(?distance : Float, ?angle : Float, ?color : UInt, ?alpha : Float, ?blurX : Float, ?blurY : Float/*, ?strength : Float, ?quality : Int, ?inner : Bool, ?knockout : Bool, ?hideObject : Bool*/);
//	DropShadow(?distance : Float, ?angle : Float, ?color : UInt, ?alpha : Float);
	Glow(?color : UInt, ?alpha : Float, ?blurX : Float, ?blurY : Float, ?strength : Float, ?quality : Int, ?inner : Bool, ?knockout : Bool);
	GradientBevel(?distance : Float, ?angle : Float, ?colors : Array<Dynamic>, ?alphas : Array<Dynamic>, ?ratios : Array<Dynamic>, ?blurX : Float, ?blurY : Float, ?strength : Float, ?quality : Int, ?type : String, ?knockout : Bool);
	GradientGlow(?distance : Float, ?angle : Float, ?colors : Array<Dynamic>, ?alphas : Array<Dynamic>, ?ratios : Array<Dynamic>, ?blurX : Float, ?blurY : Float, ?strength : Float, ?quality : Int, ?type : String, ?knockout : Bool);
	#else
	Bevel(?distance : Float, ?angle : Float, ?highlightColor : Float, ?highlightAlpha : Float, ?shadowColor : Float, ?shadowAlpha : Float, ?blurX : Float, ?blurY : Float, ?strength : Float, ?quality : Float, ?type : String, ?knockout : Bool);
	Blur(?blurX : Float, ?blurY : Float, ?quality : Int);
	ColorMatrix(?matrix : Array<Float>);
	Convolution(?matrixX : Float, ?matrixY : Float, ?matrix : Array<Dynamic>, ?divisor : Float, ?bias : Float, ?preserveAlpha : Bool, ?clamp : Bool, ?color : Int, ?alpha : Float);
//	DropShadow(?distance : Float, ?angle : Float, ?color : Float, ?alpha : Float, ?blurX : Float, ?blurY : Float, ?strength : Float, ?quality : Float, ?inner : Bool, ?knockout : Bool, ?hideObject : Bool);
	DropShadow(?distance : Float, ?angle : Float, ?color : Float, ?alpha : Float);
	Glow(?color : Int, ?alpha : Float, ?blurX : Float, ?blurY : Float, ?strength : Float, ?quality : Int, ?inner : Bool, ?knockout : Bool);
	GradientBevel(?distance : Float, ?angle : Float, ?colors : Array<Dynamic>, ?alphas : Array<Dynamic>, ?ratios : Array<Dynamic>, ?blurX : Float, ?blurY : Float, ?strength : Float, ?quality : Int, ?type : String, ?knockout : Bool);
	GradientGlow(?distance : Float, ?angle : Float, ?colors : Array<Dynamic>, ?alphas : Array<Dynamic>, ?ratios : Array<Dynamic>, ?blurX : Float, ?blurY : Float, ?strength : Float, ?quality : Int, ?type : String, ?knockout : Bool);
	#end
}

/**
 * A MutableBlock object encapsulates a block which can be updated later.
 * Just assign a new ArcticBlock to the block member variable, and the display will be updated
 * automatically. See the Mutable ArcticBlock above.
 * This has also been wrapped as an easy-to-use state block. See ArcticState for more info
 * on this.
 * Example:
 *   var mutable = new MutableBlock(Text("My block"));
 *   var gui = Mutable(mutable);
 *   var dialog = new ArcticDialogUi(gui).open();
 *   ...
 *   // Automatically update the block
 *   mutable.block = Text("New text");
 */
class MutableBlock {
	public function new(initialBlock : ArcticBlock) {
		myBlock = initialBlock;
		arcticUpdater = null;
	}
	public var block(get, set) : ArcticBlock;
	private var myBlock : ArcticBlock;
	private function get() : ArcticBlock {
		return myBlock;
	}
	private function set(block : ArcticBlock) : ArcticBlock {
		var oldBlock = myBlock;
		/* Hm, this is not possible, since enums can not be compared
		if (block == oldBlock) {
			return block;
		}
		*/
		myBlock = block;
		update(oldBlock);
		return myBlock;
	}
	
	/// For safety, provide an explicit way to update the view (should never be necessary)
	public function update(?oldBlock : ArcticBlock) {
		if (arcticUpdater != null) {
			arcticUpdater(oldBlock, block, availableWidth, availableHeight);
		}
	}
	public function destroy() {
		if (arcticUpdater != null) {
			arcticUpdater(myBlock, null, availableWidth, availableHeight);
		}
	}

	/// Updated by ArcticView.build
	public var arcticUpdater(null, default) : ArcticBlock -> ArcticBlock -> Float -> Float -> Void;
	public var availableWidth(null, default) : Float;
	public var availableHeight(null, default) : Float;
}	

/**
 * Example of creating an animation in Arctic:
 *   var animator = new Animator( arctic.Text("Test") );
 *   var gui = LineStack( Animate(animator) );
 *   ...
 *   // To start an animation that takes 5 seconds:
 *   animator.animate(5.0, [ Alpha(Animators.line( 0.0, 1.0 )), ScaleX(Animators.line(10.0, 0.0)) ] );
 */
class Animator {
	public function new(block0 : ArcticBlock, ?doneFn0 : Void -> Void) {
		block = block0;
		doneFn = doneFn0;
		startTime = 0.0;
	}
	
	/// External interface used to start an animation
	public function animate(duration0 : Float, animations0 : Array<AnimateComponent>) {
	#if flash9
		if (startTime != 0.0) {
			clearHandler();
		}
		reciprocDuration = 0.001 / duration0;
		animations = animations0;
		startTime = flash.Lib.getTimer();
		endTime = startTime + duration0;
		clip.addEventListener(flash.events.Event.ENTER_FRAME, enterFrame);
	#end
	}

	private function enterFrame( e ) : Void {
		#if flash9
		var t = flash.Lib.getTimer() - startTime;
		t = t * reciprocDuration;
		if (t >= 1.0) {
			clearHandler();
			t = 1.0;
		}
		for (a in animations) {
			switch (a) {
				/// Hm, this should be recursive
				case Alpha( f ): var a = f(t); if (a != clip.alpha) clip.alpha = a;
				case X( f ): var x = f(t); if (x != clip.x) clip.x = x;
				case Y( f ): var y = f(t); if (y != clip.y) clip.y = y;
				case ScaleX( f ): var sx = f(t); if (sx != clip.scaleX) clip.scaleX = sx;
				case ScaleY( f ): var sy = f(t); if (sy != clip.scaleY) clip.scaleY = sy;
				case Rotation( f ): var r = f(t); if (r != clip.rotation) clip.rotation = r;
			}
		}
		if (t >= 1.0 && doneFn != null) {
			doneFn();
		}
		#end
	}
	
	/// Called by ArcticView.build
	public function registerClip(clip0 : ArcticMovieClip) {
		clip = clip0;
	}
	
	private function clearHandler() {
		if (clip != null) {
			#if flash9
				clip.removeEventListener(flash.events.Event.ENTER_FRAME, enterFrame);
			#end
		}
	}
	
	/// Called by ArcticView.build on destroy phase
	public function destroy() {
		clearHandler();
		clip = null;
	}
	
	public var block : ArcticBlock;
	private var doneFn : Void -> Void;
	private var clip : ArcticMovieClip;
	private var startTime : Float;
	private var endTime : Float;
	private var reciprocDuration : Float;
	private var animations : Array<AnimateComponent>;
}

enum AnimateComponent {
	Alpha( f : Float -> Float);
	X( f : Float -> Float);
	Y( f : Float -> Float);
	ScaleX( f : Float -> Float);
	ScaleY( f : Float -> Float);
	Rotation( f : Float -> Float);
}
