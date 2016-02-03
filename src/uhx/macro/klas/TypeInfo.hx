package uhx.macro.klas;

import haxe.ds.Vector;
import haxe.macro.Type;
import haxe.macro.Expr;

/**
 * @author Skial Bainn
 */

class TypeInfo {
	public var type:Type;
	public var fields:Array<Field>;
	public var current:TypePath;
	public var original:TypePath;
	
	public function new(type:Type, fields:Array<Field>, current:TypePath, original:TypePath) {
		this.type = type;
		this.fields = fields;
		this.current = current;
		this.original = original;
	}
	
}