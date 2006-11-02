package arctic;

#if flash9
typedef ArcticMovieClip = flash.display.MovieClip
#else flash
typedef ArcticMovieClip = flash.MovieClip
#end

typedef Metrics = { width : Float, height : Float, growWidth : Bool, growHeight : Bool }

/**
 * Arctic is an embedded Domain Specific Language for making user interfaces.
 * A user interface is built from ArcticBlocks.
 */
enum ArcticBlock {
	/// A solid background
	Background(color : Int, block : ArcticBlock, ?alpha : Float, ?roundRadius : Float);

	/// A gradient background
	GradientBackground(type : String, colors : Array<Int>, xOffset : Float, yOffset : Float, block : ArcticBlock, ?alpha : Array<Float>, ?roundRadius : Float);

	/// Add some space around the block
	Border(x : Float, y : Float, block : ArcticBlock);

	/// A text (in the subset of HTML which Flash understands)
	Text(html : String);

	/**
	 * An input text.  Text Font/Size/Color can be specified along with initial text content in the subset of HTML which Flash understands.
	 */
	TextInput(html : String, width : Float, height : Float, validator : String -> Bool, ?maxChars : Int, ?numeric : Bool, ?bgColor : Int);

	/// A static picture
	Picture(url : String, width : Float, height : Float, scaling : Float);

	/**
	 * A button - when mouse is above, we change to hover look. Notice block and hover should have the exact same size.
	 */
	Button(block : ArcticBlock, hover : ArcticBlock, onClick : Void -> Void);

	/**
	 * Toggle button(selected/unselected)
	 * Though technically the ArcticBlock can be of any type, the most appropriate ones are Text & Picture.
	 * Notice that the selected and unselected blocks should have the exact same size, because we do not
	 * do a relayout when the state is changed.
	 */ 
	ToggleButton(selected : ArcticBlock, unselected : ArcticBlock, initialState : Bool, onChange : Bool -> Void, ?onInit : (Bool -> Void) -> Void);

    /**
     * The ArcticBlock will be constraint to the dimensions given
     */
    ConstrainWidth(minimumWidth : Float, maximumWidth : Float, block : ArcticBlock); 

    /**
     * The ArcticBlock will be constraint to the dimensions given
     */
    ConstrainHeight(minimumHeight : Float, maximumHeight : Float, block : ArcticBlock);

	/**
	 * Filler is empty space, that eats space when put in a stack or list of some kind
	 */
	Filler;

	/**
	 * Columns are blocks put next to each other horizontally
	 */
	ColumnStack(columns : Array< ArcticBlock > );

	/**
	 * A bunch of blocks stacked on top of each other.
	 */
	LineStack(blocks : Array<ArcticBlock>);

    ScrollBar(block : ArcticBlock, availableWidth : Float, availableHeight : Float);
	
	/**
	 * A custom block. This is an escape mechanism which allows you to extend Arctic
	 * with your own basic blocks. Parameters:
	 * 
	 *  data: an optional payload.
	 *  calcMetricsFunc: a function which has to calculate the metrics of the block.
	 *       This is the size of the block, and bools defining whether the block
	 *       wants to grow in width and/or height.
	 *  buildFunc: This is called with the optional data payload as first parameter,
	 *       the parent display object (i.e. MovieClip) and the available height
	 *       and width for the element. It should return the resulting display
	 *       object (movie clip). 
	 * 
	 * Notice that you have to build the custom blocks such that their work with
	 * both Flash 8 and 9.
	 */
	CustomBlock( data : Dynamic, 
				calcMetricsFunc : Dynamic -> Metrics, 
				buildFunc : Dynamic -> ArcticMovieClip -> Float -> Float -> ArcticMovieClip
				);
	
}
