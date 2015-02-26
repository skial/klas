package uhx.macro;

import haxe.Json;
import haxe.macro.Printer;
import sys.io.File;
import sys.FileSystem;
import sys.io.Process;
import Type in StdType;
import haxe.macro.Type;
import haxe.macro.Expr;
import haxe.ds.StringMap;
import haxe.macro.Context;
import haxe.macro.Compiler;

using Lambda;
using StringTools;
using sys.FileSystem;
using haxe.macro.TypeTools;
using haxe.macro.ComplexTypeTools;
using haxe.macro.MacroStringTools;

/**
 * ...
 * @author Skial Bainn
 */

class KlasImp {
	
	public static var isSetup:Bool = false;
	
	public static function initalize() {
		if (isSetup == null || isSetup == false) {
			history = new StringMap();
			DEFAULTS = new StringMap();
			CLASS_META = new StringMap();
			FIELD_META = new StringMap();
			INLINE_META = new Map();
			ONCE = [];
			
			RETYPE = new StringMap();
			RETYPE_PENDING = new StringMap();
			RETYPE_PREVIOUS = new StringMap();
			
			isSetup = true;
		}
	}
	
	public static var DEFAULTS:StringMap<ClassType->Array<Field>->Array<Field>>;
	public static var CLASS_META:StringMap<ClassType->Array<Field>->Array<Field>>;
	public static var FIELD_META:StringMap<ClassType->Field->Field>;	
	public static var INLINE_META:Map<EReg, ClassType->Field->Field>;
	public static var ONCE:Array<Void->Void>;
	
	/**
	 * Simply holds a class path with a boolean value. If true, run the
	 * handler in `RETYPE` if it has a matching metadata.
	 */
	public static var RETYPE_PENDING:StringMap<Bool>;
	
	/**
	 * A list of metadata paired with a handler method returning a 
	 * rebuilt class.
	 */
	public static var RETYPE:StringMap<ClassType->Array<Field>->Null<TypeDefinition>>;
	
	/**
	 * Holds a class path paired with its ClassType and Fields from the previous time
	 * it was encountered.
	 */
	public static var RETYPE_PREVIOUS:StringMap<{ cls:ClassType, fields:Array<Field> }>;
	
	public static var printer:Printer = new Printer();
	public static var history:StringMap<Array<String>>;
	
	public static function build():Array<Field> {
		var cls = Context.getLocalClass().get();
		var fields = Context.getBuildFields();
		
		// Populate history
		/*if (!history.exists( cls.pack.toDotPath( cls.name ) )) {
			history.set( cls.pack.toDotPath( cls.name ), [for (field in fields) field.name] );
		}*/
		
		initalize();
		if (cls.meta.has(':KLAS_SKIP')) return fields;
		
		// Call all callbacks.
		for (once in ONCE) once();
		ONCE = [];
		
		reTypes = [];
		
		/**
		 * Loop through any class metadata and pass along 
		 * the class and its fields to the matching handler.
		 * -----
		 * Each handler should decide if its needed to be run
		 * while in IDE display mode, `-D display`.
		 */
		
		for (key in CLASS_META.keys()) if (cls.meta.has( key )) {
			fields = CLASS_META.get( key )( cls, fields );
		}
		
		for (i in 0...fields.length) {
			
			var field = fields[i];
			
			// First check the field's metadata for matches. 
			// Passing along the class and matched field.
			for (key in FIELD_META.keys()) if (field.meta != null && field.meta.exists( function(m) return m.name == key )) {
				field = FIELD_META.get( key )( cls, field );
			}
			
			var printed = printer.printField( field );
			//trace( printed );
			// Now check the stringified field for matching inline metadata.
			// Passing along the class and matched field.
			for (key in INLINE_META.keys()) if (key.match( printed )) {
				field = INLINE_META.get( key )( cls, field );
			}
			
			fields[i] = field;
			
		}
		
		for (def in DEFAULTS) {
			fields = def( cls, fields );
		}
		
		for (key in RETYPE.keys()) if (cls.meta.has( key )) {
			// Build the cache.
			if (!RETYPE_PREVIOUS.exists( cls.pack.toDotPath( cls.name ) )) {
				RETYPE_PREVIOUS.set( cls.pack.toDotPath( cls.name ), { cls:cls, fields:fields } );
				
			}
			
			// Run any pending calls to `KlasImp.retype`.
			if (RETYPE_PENDING.exists( cls.pack.toDotPath( cls.name ) ) && RETYPE_PENDING.get( cls.pack.toDotPath( cls.name ) )) {
				retype( cls.pack.toDotPath( cls.name ), key, cls, fields );
				RETYPE_PENDING.set( cls.pack.toDotPath( cls.name ), false );
				
			}
			
		}
		
		return fields;
	}
	
	public static function retype(path:String, metadata:String, ?cls:ClassType, ?fields:Array<Field>):Bool {
		var result = false;
		
		if (RETYPE_PREVIOUS.exists( path )) {
			// Fetch the previous class and fields.
			var prev = RETYPE_PREVIOUS.get( path );
			
			// Set `cls` and `fields` only if the cache exists.
			if (cls == null && prev != null) cls = prev.cls;
			if (fields == null && prev != null) fields = prev.fields;
			
			if (cls != null && fields != null) {
				// Pass `cls` and `fields` to the retype handler to get a `typedefinition` back.
				var td = RETYPE.get( metadata )( cls, fields );
				
				if (td == null) return false;
				
				var nativeF = metadataFilter.bind(_, ':native');
				
				// Check if `@:native('path.to.Class')` exists. Add if it doesnt exist.
				if (!td.meta != null && td.meta.exists( nativeF ) {
					for (m in td.meta.filter( nativeF )) td.meta.remove( m );
					td.meta.push( { name:':native', params:[macro $v { cls.pack.toDotPath( cls.name ) } ], pos:cls.pos } );
					
				}
				
				// Remove the previous class for the the current compile.
				Compiler.exclude( cls.pack.toDotPath( cls.name ) );
				
				// Add the "retyped" class into the current compile.
				Context.defineType( td );
				
				// Cache the "retyped" fields in case of another "retype"
				prev.fields = td.fields;
				prev.cls = Context.getType( td.pack.toDotPath( td.name ) );
				
				RETYPE_PREVIOUS.set( path, prev );
				
				result = true;
				
			}
			
		} else {
			RETYPE_PENDING.set( path, true );
			if (cls != null && fields != null) RETYPE_PREVIOUS.set( path, { cls:cls, fields:fields } );
			
		}
		
		return result;
	}
	
	private static function metadataFilter(meta:Metadata, tag:String):Metadata {
		return meta.name == tag && printer.printExprs( meta.params, '.' ).indexOf( cls.pack.toDotPath( cls.name ) ) > -1;
	}
	
}