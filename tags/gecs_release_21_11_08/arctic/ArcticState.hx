package arctic;

import arctic.ArcticBlock;

/**
 * A stateful block. Use this to make blocks that can be updated from the outside.
 * Initialize with a given state and a function which returns a block given a certain state.
 * When you want to update the state, just assign to the state variable, and the
 * display will automatically be updated according to the function given. Notice 
 * that no re-layout of existing items is performed, which might be necessary if 
 * this stateful block changes size.  You can use arcticView.refresh(false) to do 
 * a relayout of the entire view.
 * Example of use:

 		var counter = new ArcticState(0, function(number : Int) : ArcticBlock {
				return Arctic.makeText("Number: " + number);
			});
		var stateFull = LineStack( [ 
				counter.block, 
				Arctic.makeSimpleButton( "Increase counter", function () { counter.state++; } )
			]);
		arcticView = new ArcticView( stateFull, flash.Lib.current );
		var root = arcticView.display(true);
		
 */
class ArcticState<T> {
	public function new(initialState : T, getBlock0 : T -> ArcticBlock) {
		myState = initialState;
		setFunction(getBlock0);
	}
	
	/// The function that defines the block for a given state can be set or changed using this method
	public function setFunction(getBlock0 : T -> ArcticBlock) {
		if (getBlock0 == null) {
			getBlock = null;
			mutableBlock = null;
			block = null;
			return;
		}
		getBlock = getBlock0;
		mutableBlock = new MutableBlock(getBlock(myState));
		block = Mutable(mutableBlock);
	}

	/// The state of this state block
	public var state(get, set) : T;
	/// The current ArcticBlock for this state
	public var block(default, null) : ArcticBlock;

	/**
	 * If the state is an object, changes to the state might not be detected.
	 * You can explicitly update the view using this method.
	 */
	public function update() : Void {
		mutableBlock.block = getBlock(myState);
	}
	
	private var getBlock : T -> ArcticBlock;
	private var myState : T;
	private function get() : T {
		return myState;
	}
	private function set(state : T) : T{
		myState = state;
		update();
		return myState;
	}
	private var mutableBlock : MutableBlock;
}

