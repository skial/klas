package uhx.macro;

import haxe.Json;
import Type in StdType;
import haxe.ds.StringMap;

#if macro
import sys.io.File;
import sys.FileSystem;
import sys.io.Process;
import haxe.macro.Type;
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Printer;
import haxe.macro.Compiler;

using Lambda;
using StringTools;
using sys.FileSystem;
using haxe.macro.TypeTools;
using haxe.macro.ComplexTypeTools;
using haxe.macro.MacroStringTools;
#end

/**
 * ...
 * @author Skial Bainn
 */

@:KLAS_SKIP class KlasImp {
	
	#if macro
	public static var isSetup:Bool = false;
	
	public static function initialize() {
		if (isSetup == null || isSetup == false) {
			history = new StringMap();
			dependencyCache = new StringMap();
			DEFAULTS = new StringMap();
			CLASS_META = new StringMap();
			FIELD_META = new StringMap();
			INLINE_META = new Map();
			ONCE = [];
			
			RETYPE = new StringMap();
			RETYPE_PENDING = new StringMap();
			RETYPE_PREVIOUS = new StringMap();
			
			INFO = new StringMap();
			INFO_PENDING = new StringMap();
			
			isSetup = true;
			
			Context.onGenerate( KlasImp.onGenerate );
		}
	}
	
	public static function addGlobalMetadata(pathFilter:String, meta:String, ?recursive:Bool = true, ?toTypes:Bool = true, ?toFields:Bool = false) {
		Compiler.addGlobalMetadata( pathFilter, meta, recursive, toTypes, toFields );
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
	public static var RETYPE_PREVIOUS:StringMap<{ name:String, cls:ClassType, fields:Array<Field> }>;
	
	/**
	 * A simple counter used in the naming of new `TypeDefinition`.
	 */
	private static var RETYPE_COUNTER:Int = 0;
	
	/**
	 * A map of callbacks that are interested in information for a
	 * perticular type.
	 */
	public static var INFO:StringMap<Array<Type->Array<Field>->Void>>;
	
	/**
	 * Holds paths, which are the key, with an array of callbacks
	 * wanting to inspect `Type` and `Array<Field>`. You should not
	 * modify any of the `Field`.
	 */
	public static var INFO_PENDING:StringMap<Array<Type->Array<Field>->Void>>;
	
	/**
	 * Used to turn `Expr` and `TypeDefinition` into readable Haxe code.
	 */
	private static var printer:Printer = new Printer();
	
	/**
	 * Holds a list of types and their fields internally if global build has 
	 * been forced on all types.
	 */
	private static var history:StringMap<{ type:Type, fields:Array<Field> }>;
	
	private static var dependencyCache:StringMap<Array<Expr>>;
	
	/**
	 * Called by KlasImp's `extraParams.hxml` file for globally applied
	 * metadata.
	 */
	public static function inspection():Array<Field> {
		var type = Context.getLocalType();
		var fields = Context.getBuildFields();
		
		initialize();
		
		if (type != null && !history.exists( type.toString() )) {
			history.set( type.toString(), { type:type, fields:fields } );
			
		}
		
		processHistory();
		
		return fields;
	}
	
	/**
	 * Processes any methods interested in a specific `Type`.
	 */
	private static function processHistory():Void {
		var _history = null;
		
		for (key in INFO.keys()) if (history.exists( key )) {
			_history = history.get( key );
			
			// Process any pending calls.
			if (INFO_PENDING.exists( key )) {
				for (cb in INFO_PENDING.get( key )) {
					cb( _history.type, _history.fields );
				}
				
				INFO_PENDING.remove( key );
				
			}
			
			for (cb in INFO.get( key )) cb( _history.type, _history.fields );
			
			// All callbacks have been called, clear from the map.
			INFO.remove( key );
		}
	}
	
	public static function dependency():Array<Field> {
		var type = Context.getLocalType();
		var fields = Context.getBuildFields();
		var key = type.toString();
		var cls = null;
		initialize();
		
		switch (type) {
			case TInst(r, _) if (r != null):
				var cls = r.get();
				
				if (!cls.isInterface && !cls.isExtern && !cls.meta.has(':coreApi') && !cls.meta.has(':coreType') && !cls.meta.has(':KLAS_SKIP')) {
					if (!fields.exists( function(f) return f.name == '__klasDependencies__' )) {
						
						fields = fields.concat( (macro class Temp {
							@:skip @:ignore @:noCompletion @:noDebug @:noDoc 
							public static var __klasDependencies__:Array<Class<Dynamic>> = uhx.macro.KlasImp.getDependencies( $v { key } );
						}).fields );
						
					}
					
				}
				
			case _:
				
		}
		
		return fields;
	}
	
	/**
	 * The main build method which passes Classes and their fields
	 * to other build macros.
	 */
	public static function build(?isGlobal:Bool = false):Array<Field> {
		var type = Context.getLocalType();
		var fields = Context.getBuildFields();
		
		if (Context.getLocalClass() == null) return fields;
		
		var cls = Context.getLocalClass().get();
		
		// This detects classes which have `implements Klas` and `@:build(uhx.macro.KlasImp.build(true))`.
		for (face in cls.interfaces) if (face.t.toString() == 'Klas' && isGlobal) return fields;
		
		initialize();
		
		// Populate `history`.
		if (type != null && !history.exists( type.toString() )) {
			history.set( type.toString(), { type:type, fields:fields } );
			
		}
		
		processHistory();
		
		log( cls.pack.toDotPath( cls.name ) + ' :: ' + [for (meta in cls.meta.get()) meta.name ] );
		
		if (cls.meta.has(':KLAS_SKIP')) return fields;
		
		// Call all callbacks.
		for (once in ONCE) once();
		ONCE = [];
		
		/**
		 * Loop through any class metadata and pass along 
		 * the class and its fields to the matching handler.
		 * -----
		 * Each handler should decide if its needed to be run
		 * while in IDE display mode, `-D display`.
		 */
		
		log( 'CLASS_META :: ' + [for (key in CLASS_META.keys()) key] );
		
		for (key in CLASS_META.keys()) if (cls.meta.has( key )) {
			fields = CLASS_META.get( key )( cls, fields );
		}
		
		log( 'FIELD_META :: ' + [for (key in FIELD_META.keys()) key] );
		
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
		
		log( 'DEFAULTS :: ' + [for (key in DEFAULTS.keys()) key] );
		
		for (def in DEFAULTS) {
			fields = def( cls, fields );
		}
		
		log( 'RETYPE :: ' + [for (key in RETYPE.keys()) key] );
		
		for (key in RETYPE.keys()) if (cls.meta.has( key )) {
			// Build the cache.
			if (!RETYPE_PREVIOUS.exists( cls.pack.toDotPath( cls.name ) )) {
				RETYPE_PREVIOUS.set( cls.pack.toDotPath( cls.name ), { cls:cls, name:cls.pack.toDotPath( cls.name ), fields:fields } );
				
			}
			
			// Run any pending calls to `KlasImp.retype`.
			if (RETYPE_PENDING.exists( cls.pack.toDotPath( cls.name ) ) && RETYPE_PENDING.get( cls.pack.toDotPath( cls.name ) )) {
				retype( cls.pack.toDotPath( cls.name ), key, cls, fields );
				RETYPE_PENDING.set( cls.pack.toDotPath( cls.name ), false );
				
			}
			
		}
		
		return fields;
	}
	
	/**
	 * Starts the process of rebuilding a Class and its fields. Returns `true`
	 * is the rebuilt was a success, `false` otherwise.
	 */
	public static function retype(path:String, metadata:String, ?cls:ClassType, ?fields:Array<Field>):Null<String> {
		var result = null;
		
		if (RETYPE.exists( metadata ) && RETYPE_PREVIOUS.exists( path )) {
			// Fetch the previous class and fields.
			var prev = RETYPE_PREVIOUS.get( path );
			
			// Set `cls` and `fields` only if the cache exists.
			if (cls == null && prev != null) cls = prev.cls;
			if (fields == null && prev != null) fields = prev.fields;
			if (prev.name == null || prev.name == '') prev.name = cls.pack.toDotPath( cls.name );
			
			if (cls != null && fields != null) {
				// Pass `cls` and `fields` to the retype handler to get a `typedefinition` back.
				var td = RETYPE.get( metadata )( cls, fields );
				
				if (td == null) return result;
				
				var nativeF = metadataFilter.bind(_, ':native', cls.pack.toDotPath( cls.name ));
				
				// Check if `@:native('path.to.Class')` exists. Remove any found.
				if (td.meta != null && td.meta.exists( nativeF )) for (m in td.meta.filter( nativeF )) td.meta.remove( m );
				
				// Add `@:native` and use the original package and type name.
				td.meta.push( { name:':native', params:[macro $v { cls.pack.toDotPath( cls.name ) } ], pos:cls.pos } );
				
				// If the TypeDefinition::name is the same as `cls.name`, modify it.
				if (td.pack.toDotPath( td.name ) == cls.pack.toDotPath( cls.name ) || td.pack.toDotPath( td.name ) == prev.name) {
					td.name += ('' + Date.now().getTime() + '' + (RETYPE_COUNTER++)).replace('+', '_').replace('.', '_');
					
				}
				
				result = td.pack.toDotPath( td.name );
				
				// Remove the previous class for the the current compile.
				Compiler.exclude( prev.name );
				// Add the "retyped" class into the current compile.
				Context.defineType( td );
				
				// Cache the "retyped" fields in case of another "retype".
				prev.fields = td.fields;
				prev.name = td.pack.toDotPath( td.name );
				
				RETYPE_PREVIOUS.set( path, prev );
				
			}
			
		} else {
			RETYPE_PENDING.set( path, true );
			if (cls != null && fields != null) RETYPE_PREVIOUS.set( path, { cls:cls, name:cls.pack.toDotPath( cls.name ), fields:fields } );
			
		}
		
		return result;
	}
	
	/**
	 * Calls the `callback` for the specific `path` allowing you to
	 * look at a Type and its fields. Returns `true` if it ran your
	 * `callback` now or `false` if it cached your `callback`.
	 */
	public static function inspect(path:String, callback:Type->Array<Field>->Void):Bool {
		var result = false;
		var _history = null;
		
		if (history.exists( path )) {
			_history = history.get( path );
			
			// Process any pending calls.
			if (INFO_PENDING.exists( path )) {
				for (cb in INFO_PENDING.get( path )) {
					cb( _history.type, _history.fields );
				}
				
				INFO_PENDING.remove( path );
				
			}
			
			callback( _history.type, _history.fields );
			result = true;
			
		} else {
			var callbacks = INFO_PENDING.exists( path ) ? INFO_PENDING.get( path ) : [];
			callbacks.push( callback );
			
			INFO_PENDING.set( path, callbacks );
			
		}
		
		return result;
	}
	
	/**
	 * Generate `a` before `b`.
	 */
	public static function generateBefore(a:ComplexType, b:ComplexType):Void {
		switch ([a, b]) {
			case [TPath(_a), TPath(_b)]:
				var aname = _a.pack.toDotPath( _a.name );
				var bname = _b.pack.toDotPath( _b.name );
				
				var values = dependencyCache.exists( bname ) ? dependencyCache.get( bname ) : [];
				values.push( macro $p { _a.pack.concat( [_a.name] ) } );
				
				dependencyCache.set( bname, values );
				
			case _:
				
		}
	}
	
	/**
	 * Generate `a` after `b`.
	 */
	public static function generateAfter(a:ComplexType, b:ComplexType):Void {
		switch ([a, b]) {
			case [TPath(_a), TPath(_b)]:
				var aname = _a.pack.toDotPath( _a.name );
				var bname = _b.pack.toDotPath( _b.name );
				
				var values = dependencyCache.exists( aname ) ? dependencyCache.get( aname ) : [];
				values.push( macro $p { _b.pack.concat( [_b.name] ) } );
				
				dependencyCache.set( aname, values );
				
			case _:
				
		}
	}
	
	private static function metadataFilter(meta:MetadataEntry, tag:String, pack:String):Bool {
		return meta.name == tag && printer.printExprs( meta.params, '.' ).indexOf( pack ) > -1;
	}
	
	private static inline function log(value:String):Void {
		#if klas_verbose
		Sys.println( value );
		#end
	}
	
	private static function onGenerate(types:Array<Type>):Void {
		for (type in types) {
			// Prevent `__klasDependencies__` being included in the output.
			switch (type) {
				case TInst(r, p) if (r != null):
					for (field in r.get().statics.get()) if (field.name == '__klasDependencies__') {
						//field.meta.add( ':extern', [], field.pos );
						
					}
					
				case _:
					
			}
		}
	}
	#end
	
	public static macro function getDependencies(key:String):Expr {
		var values = dependencyCache.get( key );
		return values == null ? macro null : macro [$a { values }];
	}
	
}