package arctic;

class EscapingMap {
	public var unescaped_values(default, null): Array<String>;
	public var escaped_values(default, null): Array<String>;
	
	var escapingMap: Hash<String>;
	var unescapingMap: Hash<String>;
	
	public function getEscaped(s) { return escapingMap.get(s); }
	public function getUnescaped(s) { return unescapingMap.get(s); }

	public function new() {
		escapingMap = new Hash();
		unescapingMap = new Hash();
		escaped_values = [];
		unescaped_values = [];
		
		var replacements = [ { from: "&", to: "&amp;"}, { from: "<", to: "&lt;" }, { from: ">", to: "&gt;" },
			{ from: "'", to: "&apos;" }, { from: "\"", to: "&quot;" } ];
		
		for (item in replacements) {
			escapingMap.set(item.from, item.to);
			unescapingMap.set(item.to, item.from);
			escaped_values.push(item.to);
			unescaped_values.push(item.from);
		}
	}
}

class StringUtils {
	public static function getRandomChar(alphabet: String) {
		return alphabet.charAt(Math.round(Math.random() * (alphabet.length - 1)));
	}
	
	public static function getRandomString(alphabet: String, length: Int) {
		var buf = new StringBuf();
		while (length-- > 0) {
			buf.add(getRandomChar(alphabet));
		}
		
		return buf.toString();
	}
	
	public static var numeric = "0123456789";
    public static var alphaNumeric = numeric + "ABCDEFGHIKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz";
	
	public static function multiReplace(source: String, what: Array<String>, by: String) {
		return genericMultiReplace(source, what, function (s) { return by; });
	}
	
	public static function genericMultiReplace(source: String, what: Iterable<String>, replacer: String -> String) {
		return Lambda.fold(what, function (w, s) { return StringTools.replace(s, w, replacer(w)); }, source);		
	}
	
	static function getRange(min: Int, max: Int): Iterable<Int> {
		return { iterator: function (): Iterator<Int> { return new IntIter(min, max); } }
	}
	
	// replaces values in the template, supports values like %1...%9
	// not so nice but fast algorithm
	public static function replaceTemplate(template: String, values: Array<String>) {
		var positions = Lambda.map(getRange(1, values.length + 1), function (i) { 
			return { pos: template.indexOf("%" + Std.string(i)), val: values[i - 1] } });
		var buf = new StringBuf();
		var lastpos = 0;
		for (data in positions) {
			buf.add(template.substr(lastpos, data.pos - lastpos));
			buf.add(data.val);
			// 2: length of "%1"
			lastpos = data.pos + 2;
		}
		buf.add(template.substr(lastpos));
		
		return buf.toString();
		//return genericMultiReplace(template, Lambda.map({ iterator: function (): Iterator<Int> { return 1...values.length + 1; } }, function (i) { return "%" + Std.string(i); }), 
		//	function (item) { return values[Std.parseInt(item.substr(1)) - 1]; });
	}
	
	public static function filterEmpty(strings: Array<String>): Array<String> {
		return Lambda.fold(strings, function (s, res: Array<String>) {
			s = StringTools.trim(s);
			return if (!emptyString(s)) res.concat([s]) else res;
		}, []);
	}
	
	public static function genericFilterEmpty<T>(items: Iterable<T>, getString: T -> String) {
		return Lambda.filter(items, function (item) { 
			var s = getString(item);
			return !emptyString(StringTools.trim(s));
		});
	}
	
	public static inline function emptyString(s: String) {
		return null == s || "" == s;
	}
	
	public static function textFieldEncode(s) {
		return StringTools.replace(StringTools.replace(s, "<", "&lt;"), ">", "&gt;");
	}
	
	public static function identity(s: String): String {
		return s;
	}
	
	public static function xmlEscape(s) {
		return genericMultiReplace(s, escapingMap.unescaped_values, escapingMap.getEscaped);
	}
	
	public static function xmlUnescape(s) {
		return genericMultiReplace(s, escapingMap.escaped_values, escapingMap.getUnescaped);
	}
	
	static var escapingMap = new EscapingMap();
	
	static public function stripHtml(s : String) : String {
		var result = "";
		var i = 0;
		// invariant at entry to loop: i points at next char that must be
		// copied to result (or skipped if it is the beginning of a tag).
		// i never points inside a tag & is never negative.
		while (i < s.length) {
			var bad = s.indexOf("<", i);
			if (bad != -1) {
				// tag found, copy to result from last uncopied until badness starts
				result += s.substr(i, bad - i);
				// skip badness
				i = s.indexOf(">", bad);
				if (i == -1) {
					// '<' without '>', hm? not a tag, then, and there can
					// be no more tags in s, so copy rest of s to result &
					// quit the loop
					result += s.substr(bad);
					i = s.length;
					break;
				}
				i++;
			} else {
				// no more tags in s, so copy rest of s to result & quit
				// the loop
				result += s.substr(i);
				i = s.length;
				break;
			}
		}
		return StringUtils.xmlUnescape(result);
	}
}
