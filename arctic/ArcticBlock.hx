package arctic;

// We introduce an alias for MovieClip which works in both Flash 8 & 9. See also ArcticMC.hx
#if flash9
	typedef ArcticMovieClip = flash.display.MovieClip
#else flash
	typedef ArcticMovieClip = flash.MovieClip
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
	 */ 
	GradientBackground(type : String, colors : Array<Int>, xOffset : Float, yOffset : Float, block : ArcticBlock, ?alpha : Array<Float>, ?roundRadius : Null<Float>, ?rotation: Null<Float>);

	/// Add some space around the block
	Border(x : Float, y : Float, block : ArcticBlock);

	/**
	 * A text (in the subset of HTML which Flash understands).
	 * If wordWrap is true, the text will grow in the width and height as much as possible,
	 * and the text inside word wrap according to how much width is available.
	 * If wordWrap is false, the text will always have the same size, and only break lines
	 * if <br/> tags exist in the text.
	 */
	Text(html : String, ?embeddedFont : Null<Bool>, ?wordWrap : Null<Bool>);

	/**
	 * An input text.  Text Font/Size/Color can be specified along with initial text content in the subset of HTML which Flash understands.
	 * The validator callback is called on each change. You can use this callback to extract the contents of the text input.
	 * All fields of the style parameter is copied verbatim to the textinput object. This allows you to customize the text input in
	 * all detail, but it's up to you to make sure this works in both Flash 8 & 9. ( { wordWrap: true, multiLine: true } as style is portable.)
	 */
	TextInput(html : String, width : Float, height : Float, ?validator : String -> Bool, ?style : Dynamic, ?maxChars : Null<Int>, ?numeric : Null<Bool>, ?bgColor : Null<Int>, ?focus : Null<Bool>, ?embeddedFont : Null<Bool>);

	/**
	* A static picture loaded from a URL. It is your responsibility to set the scaling such that the picture has the stated size.
	* Notice that the width & height should be the size of this block, not the original size of the picture.
	*/
	Picture(url : String, width : Float, height : Float, scaling : Float, ?resource : Null<Bool>);

	/**
	 * A button - when mouse is above, we change to hover look. Notice block and hover should have the exact same size.
	 * When the button is clicked, onClick is called.
	 */
	Button(block : ArcticBlock, hover : ArcticBlock, onClick : Void -> Void);

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
     * The ArcticBlock will be constrained to the dimensions given - by clipping or extending
     */
    ConstrainWidth(minimumWidth : Float, maximumWidth : Float, block : ArcticBlock); 

    /**
     * The ArcticBlock will be constrained to the dimensions given - by clipping or extending
     */
    ConstrainHeight(minimumHeight : Float, maximumHeight : Float, block : ArcticBlock);

	/**
	 * Filler is greedy empty space, that eats space when put in a LineStack or ColumnStack.
	 * This can be used to implement left alignment, centering, and similar layout strategies.
	 */
	Filler;
	
	/**
	 * An empty block of the given size
	 */
	Fixed(width : Null<Float>, height : Null<Float>);

	/**
	 * Columns are blocks put next to each other horizontally. The height is the maximum
	 * height of the blocks. If there is an unconstrained filler in the column stack (recursively)
	 * this block will use all available width.
	 */
	ColumnStack(columns : Array< ArcticBlock > );

	/**
	 * A bunch of blocks stacked on top of each other. The width is the maximum width
	 * of the blocks. If you want to make sure the very top of a specific block is visible, 
	 * pass the index number of the block in the array as second parameter. Notice there
	 * is no guarantee that all of the entry is visible.
	 */
	LineStack(blocks : Array<ArcticBlock>, ?ensureVisibleIndex : Null<Int>);
	
	/**
	 * A 2-d grid of block. For now, this does not support resizing or scrollbars.
	 */
	Grid(blocks: Array<Array<ArcticBlock>>);

	/// Wrap the block in a window of the given size, and add a scrollbar if necessary
    ScrollBar(block : ArcticBlock, fixedWidth : Float, fixedHeight : Float);

	/**
	 * Make a block dragable by the mouse in the given directions.
	 * If stayWithinSize is true, the movement is constrained to the available area
	 * of the block (and this block becomes size greedy in the directions we allow motion in).
	 * This block can be used to make many things, including dialogs. Use the wrapper 
	 * Arctic.makeDragable if you want to preserve the dragged distance across canvas resizes.
	 */
	Dragable(stayWithinBlock : Bool, sideMotionAllowed : Bool, upDownMotionAllowed : Bool, block : ArcticBlock, 
			onDrag : DragInfo -> Void, ?onInit : DragInfo -> (Float -> Float -> Void) -> Void, ?mouseWheel : Null<Bool>);

	/**
	 * Set the cursor shape to a block when the mouse is within the given block.
	 * If you want the cursor block to be in ADDITION to the normal cursor, set
	 * keepNormalCursor to true. This is useful for toolips, see Arctic.makeTooltip.
	 * Per default, the normal cursor is hidden when the custom cursor is visible.
	 */
	Cursor(block : ArcticBlock, cursor : ArcticBlock, ?keepNormalCursor : Null<Bool>);

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

	/// A state-full block which can be updated from the outside with a new block. See MutableBlock below for more info
	Mutable( state : MutableBlock );
	
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
	Frame(block: ArcticBlock, ?thickness: Null<Float>, ?color: Null<Int>, ?roundRadius: Null<Float>, ?alpha: Null<Float>, ?xspacing: Null<Float>, ?yspacing: Null<Float>);

	/**
	 * Drops a shadow for the given block. Notice that the shadow is not considered as part of
	 * the block in terms of size.
	 */
	Shadow(block: ArcticBlock, distance: Int, angle: Int, color: Int, alpha: Float);
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
}

/// Information returned about draggable blocks
typedef DragInfo = {
	// How much we have moved so far in pixels?
	x : Float,
	y : Float,
	// How much room is available for dragging in pixels?
	totalWidth : Float,
	totalHeight : Float
}

/**
 * A MutableBlock object encapsulates a block which can be updated later.
 * Just assign a new ArcticBlock to the block member variable, and the display will be updated
 * automatically. See the Mutable ArcticBlock above.
 * This has also been wrapped as an easy-to-use state block. See ArcticState for more info
 * on this.
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
		myBlock = block;
		update();
		return myBlock;
	}
	
	/// For safety, provide an explicit way to update the view (should never be necessary)
	public function update() : Metrics {
		if (arcticUpdater != null) {
			return arcticUpdater(block, availableWidth, availableHeight);
		} else {
			return null;
		}
	}

	/// Updated by ArcticView.build
	public var arcticUpdater(null, default) : ArcticBlock -> Float -> Float -> Metrics;
	public var availableWidth(null, default) : Float;
	public var availableHeight(null, default) : Float;
}	
