package arctic;

#if flash9
typedef ArcticMovieClip = flash.display.MovieClip
#else flash
typedef ArcticMovieClip = flash.MovieClip
#end

/**
 * Arctic is an embedded Domain Specific Language for making user interfaces.
 * A user interface is built from ArcticBlocks.
 */
enum ArcticBlock {
	/**
	 * Draw a solid background behind the given block. 
	 * Alpha is an optional transparency from 0.0 to 100.0.
	 * roundRadius > 0 makes the background rounded at the corners.
	 */
	Background(color : Int, block : ArcticBlock, ?alpha : Float, ?roundRadius : Float);

	/**
	 * Draw a gradient background behind the given block.
	 * colors is an array of colors in the gradient.
	 * xOffset & yOffset are percentage offsets from the center of the block, so an offset of 0.5, -0.5 means
	 * to put the center of the gradient in the top, right corner.
	 * Alpha is an array of optional transparencies from 0 to 100.0. It has to have as many entries as the color array.
	 * roundRadius > 0 makes the gradient rounded at the corners.
	 * rotation - the amount to rotate, in radians (the default value is 0).
	 */ 
	GradientBackground(type : String, colors : Array<Int>, xOffset : Float, yOffset : Float, block : ArcticBlock, ?alpha : Array<Float>, ?roundRadius : Float, ?rotation: Float);

	/// Add some space around the block
	Border(x : Float, y : Float, block : ArcticBlock);

	/**
	 * A text (in the subset of HTML which Flash understands).
	 * If wordWrap is true, the text will grow in the width and height as much as possible,
	 * and the text inside word wrap according to how much width is available.
	 * If wordWrap is false, the text will always have the same size, and only break lines
	 * if <br/> tags exist in the text.
	 */
	Text(html : String, ?embeddedFont : Bool, ?wordWrap : Bool);

	/**
	 * An input text.  Text Font/Size/Color can be specified along with initial text content in the subset of HTML which Flash understands.
	 * The validator callback is called on each change in Flash 8, but only on loss of focus in Flash 9. You can use this callback to
	 * extract the contents of the text input.
	 * All fields of the style parameter is copied verbatim to the textinput object. This allows you to customize the text input in
	 * all detail, but it's up to you to make sure this works in both Flash 8 & 9.
	 */
	TextInput(html : String, width : Float, height : Float, ?validator : String -> Bool, ?style : Dynamic, ?maxChars : Int, ?numeric : Bool, ?bgColor : Int, ?focus : Bool, ?embeddedFont : Bool);

	/// A static picture loaded from a URL. It is your responsibility to set the scaling such that the picture has the stated size
	Picture(url : String, width : Float, height : Float, scaling : Float, ?resource : Bool);

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
	 * with the state we have. This can be used to implement connected radio button groups - like the factory
	 * Arctic.makeRadioButtonGroup does.
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
	Fixed(width : Float, height : Float);

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
	LineStack(blocks : Array<ArcticBlock>, ?ensureVisibleIndex : Int);
	
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
			onDrag : Float -> Float -> Void, ?onInit : (Float -> Float -> Void) -> Void);

	/**
	 * Set the cursor shape to a block when the mouse is within the given block.
	 * If you want the cursor block to be in ADDITION to the normal cursor, set
	 * keepNormalCursor to true. This is useful for toolips, see Arctic.makeTooltip.
	 * Per default, the normal cursor is hidden when the custom cursor is visible.
	 */
	Cursor(block : ArcticBlock, cursor : ArcticBlock, ?keepNormalCursor : Bool);

	/**
	 * Translate a block in some direction - notice layout does not take this into account.
	 */
	Offset(xOffset : Float, yOffset : Float, block : ArcticBlock);

	/**
	 * Place a block on top of another block (overlay).
	 */
	OnTop(base : ArcticBlock, overlay : ArcticBlock);

	/**
	 * Name this block so that we can get to it, and update it using ArcticView.update
	 * and ArcticView.getRawMovieClip.
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
	 *       element.
	 *       If this is null, the intent is that this function should construct a new view from
	 *       stratch. If this is not null, the code should update the given MovieClip.
	 *       The function should return the metrics for the block. The different build modes
	 *       should be consistent in the metrics - otherwise, layout bugs can occur.
	 * 
	 * Notice that you have to build the custom blocks such that their work with
	 * both Flash 8 and 9.
	 */
	CustomBlock( data : Dynamic, buildFunc : Dynamic -> BuildMode -> ArcticMovieClip -> Float -> Float -> ArcticMovieClip -> Metrics );

	/**
	 * Draws a frame around the given block
	 */
	Frame(block: ArcticBlock, ?thickness: Float, ?color: Int, ?roundRadius: Float, ?alpha: Float, ?xspacing: Float, ?yspacing: Float);

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
