package arctic;

typedef ArcticInput = Array<{eventName: String, abId: String, args: Array<Dynamic>}>; 

class ArcticEvidenceManager {
	static public function get() : ArcticEvidenceManager {
		if (instance == null) {
			instance = new ArcticEvidenceManager();
		}
		return instance;
	}
	static private var instance : ArcticEvidenceManager;
	public function new() {
			replaying = false;
			input = [];
			time = null;
	}
	private var replaying : Bool;
	private var input : ArcticInput;
	private var time : String;

	public function setupRecordingOrReplay(eventName : String, abId : String, f : Void -> Void) : Void {
		if (replaying) {
			// set up event handler that handles recorded events & matches the same event
			// name that is sent if we are recording

			// an event is uniquely identified by combining two things: the line number in
			// ArcticView that set up the event (or some similar identifier of the place),
			// and the arctic instance where it happened...
		} else {
			// recording

			// set up event listener or whatever & do the action specified, but also
			// record the event name that will match the event handler set up in the other
			// branch of this if
		}
	}

	public function replayEvent(eventName : String, abId : String) : Void {
		if (replaying) {
			
			// look up the event in the hash set up in the first branch of the if in
			// setupRecordingOrReplay
		} else {
			// will never happen as replayEvent() is only called when replaying
		}
	}

	public function registerReplayer(eventName : String, abId : String, f : Dynamic) : Void {
		
	}
	
	public function recordEvent(eventName : String, abId : String, args : Array<Dynamic>) : Void {
		input.push({eventName: eventName, abId: abId, args: args});
		saveInput();
/*KILL 01/04/2008 16:14. to:
		
		if (abId.indexOf("Finish") != -1) {
			trace('');
			for (i in input) {
				trace('event: ' + i.eventName + ' ' + i.abId + ':');
				for (a in i.args) {
					trace('          ' + a);
				}
			}
		}
*/
	}

	public function saveInput() {
		for (i in input) {
			trace('event: ' + i.eventName + ' ' + i.abId + ':');
			for (a in i.args) {
				trace('          ' + a);
			}
		}
		#if conceiveclient
			if (time == null) {
				time = DateTools.format(Date.now(), "%Y%m%d-%H.%M.%S");
			}
			var filename = "evidence/input" + time + ".json";
			var json = Json.encode(input);
			json = StringTools.replace(json, "},{", "},\n {");
			trace('json=' + json);
			Main.get().save(filename, json);
		#end
	}

	public function runArcticInput(contents : String) {
		trace('contents=' + contents);
	}
	
	static public function idFromArctic(a : ArcticBlock) : String {
		return id(a);
	}

	static private function id(a : ArcticBlock) : String {
		return switch (a) {
		case Border(x, y, block): id(block);
		case Frame(thickness, color, block, roundRadius, alpha, xspacing, yspacing): id(block);
		case Filter(filter, block): "filter(" + id(block) + ")";
		case Background(color, block, alpha, roundRadius): "bg(" + id(block) + ")";
		case GradientBackground(type, colors, xOffset, yOffset, block, alpha, roundRadius, rotation, ratios): "grad(" + id(block) + ")";
		case Text(html, embeddedFont, wordWrap, selectable): StringUtils.stripHtml(html);
		case TextInput(html, width, height, validator, style, maxChars,
					   numeric, bgColor, focus, embeddedFont, onInit, onEventInit): "input";
		case Picture(url, w, h, scaling, resource, crop, cbSizeDiff): url;
		case Button(block, hover, action, actionExt): "button(" + id(block) + ")";
		case ToggleButton(selected, unselected, initialState, onChange, onInit): "toggle(" + id(selected) + ")";
		case Mutable(mutableBlock): "mutator(" + id(mutableBlock.block) + ")";
		case Switch(blocks, current, onInit): "switch(" + Util.map(id, blocks).join(",") + ")";
		case Filler: "   ";
		case Fixed(width, height): " ";
        case Align(xpos, ypos, block): "align(" + id(block) + ")";
        case ConstrainWidth(minimumWidth, maximumWidth, block): "constrainwidth(" + id(block) + ")";
        case ConstrainHeight(minimumHeight, maximumHeight, block): "constrainheight(" + id(block) + ")";
		case Crop(width, height, block): "crop(" + id(block) + ")";
		case ColumnStack(blocks): "cols(" + Util.map(id, blocks).join(",") + ")";
		case LineStack(blocks, ensureVisibleIndex, disableScrollbar): "lines(" + Util.map(id, blocks).join(",") + ")";
		case Grid(cells, disableScrollbar, oddRowColor, evenRowColor): "grid";
		case TableCell(block, rowSpan, colSpan, topBorder, rightBorder, bottomBorder, leftBorder) : "cell";
		case Table(cells, nRows, nCols, borderColor): "table";
		case Wrap(blocks, maxWidth, xspacing, yspacing, endOfLineFiller, lowerWidth, alignment): "wrap";
		case ScrollBar(block, availableWidth, availableHeight): "scrollbar(" + id(block) + ")";
		case Dragable(stayWithin, sideMotion, upDownMotion, block, onDrag, onInit, onStopDrag): "drag(" + id(block) + ")";
		case Cursor(block, cursor, keepNormalCursor, showFullCursor): "cursor(" + id(block) + ")";
		case Offset(dx, dy, block): "offset(" + id(block) + ")";
		case OnTop(base, overlay) : "ontop(" + id(base) + "," + id(overlay) + ")";
		case Id(i, block): "id" + i + "(" + id(block) + ")";
		case CustomBlock(data, buildFun): "customblock";
		case MouseWheel(block, onMouseWheel): "mousewheel(" + id(block) + ")";
		case Mask(block, mask): "mask(" + id(block) + ")";
		case Scale(block, maxScale): "scale(" + id(block) + ")";
		case DebugBlock(i, block): "debug(" + id(block) + ")";
		};
	}
}
