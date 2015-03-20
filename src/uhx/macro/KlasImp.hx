package uhx.macro;

import haxe.Json;
import Type in StdType;
import haxe.ds.StringMap;

#if macro
import sys.io.File;
import sys.FileSystem;
import sys.io.Process;
import msignal.Signal;
import haxe.macro.Type;
import haxe.macro.Expr;
import haxe.macro.Context;
import haxe.macro.Printer;
import haxe.macro.Compiler;
import uhx.macro.klas.Signal;
import uhx.macro.klas.RVSlot;
import uhx.macro.klas.RVSignal;

using Lambda;
using StringTools;
using sys.FileSystem;
using haxe.macro.TypeTools;
using haxe.macro.ComplexTypeTools;
using haxe.macro.MacroStringTools;

typedef TypeInfo = {
	var type:Type;
	var fields:Array<Field>;
	var current:TypePath;
	var original:TypePath;
}

#end

/**
 * ...
 * @author Skial Bainn
 */

@:KLAS_SKIP class KlasImp {
	
	#if macro
	private static var isSetup:Bool = false;
	
	public static function initialize() {
		if (isSetup == null || isSetup == false) {
			// Initialize public hooks first.
			info = new StringMap();
			rebuild = new StringMap();
			inlineMetadata = new Map();
			allMetadata = new RVSignal();
			classMetadata = new StringMap();
			fieldMetadata = new StringMap();
			
			// Initialize internal variables
			history = new StringMap();
			pendingInfo = new StringMap();
			
			dependencyCache = new StringMap();
			
			onRebuild = new Signal1();
			
			Context.onGenerate( KlasImp.onGenerate );
			
			isSetup = true;
		}
	}
	
	public static function addGlobalMetadata(pathFilter:String, meta:String, ?recursive:Bool = true, ?toTypes:Bool = true, ?toFields:Bool = false) {
		Compiler.addGlobalMetadata( pathFilter, meta, recursive, toTypes, toFields );
	}
	
	/**
	 * A callback which will be run on every class encountered.
	 */
	public static var allMetadata:RVSignal<ClassType, Array<Field>>;
	
	/**
	 * A callback which will be run only when the specified metadata
	 * has been found on a class.
	 */
	public static var classMetadata:Signal<String, ClassType, Array<Field>>;
	
	/**
	 * A callback which will be run only when the specified metadata
	 * has been found on a field.
	 */
	public static var fieldMetadata:Signal<String, ClassType, Field>;
	
	/**
	 * A callback which will be run only when a field has inline
	 * metadata matching the regular expression.
	 */
	public static var inlineMetadata:Signal<EReg, ClassType, Field>;
	
	/**
	 * A simple counter used in the naming of new `TypeDefinition`.
	 */
	private static var counter:Int = 0;
	
	/**
	 * A list of metadata paired with a handler method returning a 
	 * rebuilt class.
	 */
	public static var rebuild:StringMap<ClassType->Array<Field>->Null<TypeDefinition>>;
	
	/**
	 * A signal you can register with to get notified when types are rebuilt.
	 */
	public static var onRebuild:Signal1<TypeInfo>;
	
	/**
	 * A map of callbacks that are interested in information for a
	 * perticular type.
	 */
	public static var info:StringMap<Array<Type->Array<Field>->Void>>;
	
	/**
	 * Holds paths, which are the key, with an array of callbacks
	 * wanting to inspect `Type` and `Array<Field>`. You should not
	 * modify any of the `Field`.
	 */
	private static var pendingInfo:StringMap<Array<Type->Array<Field>->Void>>;
	
	/**
	 * Used to turn `Expr` and `TypeDefinition` into readable Haxe code.
	 */
	private static var printer:Printer = new Printer();
	
	/**
	 * Holds a list of types and their fields internally if global build has 
	 * been forced on all types.
	 */
	private static var history:StringMap<TypeInfo>;
	
	private static var dependencyCache:StringMap<Array<Expr>>;
	
	/**
	 * Called by KlasImp's `extraParams.hxml` file for globally applied
	 * metadata.
	 */
	@:noCompletion
	public static function inspection():Array<Field> {
		initialize();
		populateHistory( Context.getLocalType(), Context.getBuildFields() );
		processHistory();
		
		return Context.getBuildFields();
	}
	
	/**
	 * Collect information on the current type.
	 */
	private static function populateHistory(type:Type, fields:Array<Field>):Void {
		if (type != null && !history.exists( type.toString() )) {
			var parts = type.toString().split('.');
			var typePath = { name: parts.pop(), pack: parts };
			history.set( type.toString(), { type:type, fields:fields, original:typePath, current:typePath } );
			
		}
	}
	
	/**
	 * Processes any methods interested in a specific `Type`.
	 */
	private static function processHistory():Void {
		var _history = null;
		
		for (key in info.keys()) if (history.exists( key )) {
			_history = history.get( key );
			
			// Process any pending calls.
			if (pendingInfo.exists( key )) {
				for (cb in pendingInfo.get( key )) {
					cb( _history.type, _history.fields );
				}
				
				pendingInfo.remove( key );
				
			}
			
			for (cb in info.get( key )) cb( _history.type, _history.fields );
			
			// All callbacks have been called, clear from the map.
			info.remove( key );
		}
	}
	
	@:noCompletion
	public static function dependency():Array<Field> {
		var type = Context.getLocalType();
		var fields = Context.getBuildFields();
		var key = type.toString();
		var cls = null;
		
		initialize();
		populateHistory( type, fields );
		processHistory();
		
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
	@:noCompletion 
	@:access(haxe.macro.TypeTools)
	public static function build(?isGlobal:Bool = false):Array<Field> {
		var type = Context.getLocalType();
		var fields = Context.getBuildFields();
		
		if (Context.getLocalClass() == null) return fields;
		
		var cls = Context.getLocalClass().get();
		
		// This detects classes which have `implements Klas` and `@:build(uhx.macro.KlasImp.build(true))`.
		for (face in cls.interfaces) if (face.t.toString() == 'Klas' && isGlobal) return fields;
		
		initialize();
		
		populateHistory( type, fields );
		processHistory();
		
		log( cls.pack.toDotPath( cls.name ) + ' :: ' + [for (meta in cls.meta.get()) meta.name ] );
		
		if (cls.meta.has(':KLAS_SKIP')) return fields;
		
		/**
		 * Loop through any class metadata and pass along 
		 * the class and its fields to the matching handler.
		 * -----
		 * Each handler should decide if its needed to be run
		 * while in IDE display mode, `-D display`.
		 */
		
		log( 'CLASS_META :: ' + [for (key in classMetadata.keys()) key] );
		
		for (key in classMetadata.keys()) if (cls.meta.has( key )) {
			fields = classMetadata.dispatch( key, cls, fields );
			
		}
		
		log( 'FIELD_META :: ' + [for (key in fieldMetadata.keys()) key] );
		
		for (i in 0...fields.length) {
			
			var field = fields[i];
			
			// First check the field's metadata for matches. 
			// Passing along the class and matched field.
			for (key in fieldMetadata.keys()) if (field.meta != null && field.meta.exists( function(m) return m.name == key )) {
				//field = fieldMetadata.get( key )( cls, field );
				field = fieldMetadata.dispatch( key, cls, field );
				
			}
			
			var printed = printer.printField( field );
			//trace( printed );
			// Now check the stringified field for matching inline metadata.
			// Passing along the class and matched field.
			for (key in inlineMetadata.keys()) if (key.match( printed )) {
				//field = inlineMetadata.get( key )( cls, field );
				field = inlineMetadata.dispatch( key, cls, field );
			}
			
			fields[i] = field;
			
		}
		
		fields = allMetadata.dispatch(cls, fields);
		
		log( 'REBUILD :: ' + [for (key in rebuild.keys()) key] );
		
		return fields;
	}
	
	/**
	 * Starts the process of rebuilding a Class and its fields. Returns information
	 * if the rebuilt type was successfull, `null` otherwise.
	 */
	@:access(haxe.macro.TypeTools)
	public static function triggerRebuild(path:String, metadata:String):Null<TypeInfo> {
		var result = null;
		
		if (rebuild.exists( metadata ) && history.exists( path )) {
			// Fetch the previous class and fields.
			var cache = history.get( path );
			var clsName = cache.original.pack.toDotPath( cache.original.name );
			
			if (cache.type.match(TInst(_, _)) && cache.fields != null) {
				var cls = cache.type.getClass();
				
				// Check that the selected class has the required `metadata`.
				if (!cls.meta.has( metadata )) return result;
				
				// Pass `cls` and `fields` to the retype handler to get a `typedefinition` back.
				var td = rebuild.get( metadata )( cls, cache.fields );
				
				if (td == null) return result;
				
				var tdName = td.pack.toDotPath( td.name );
				var nativeF = metadataFilter.bind(_, ':native', clsName);
				
				// Check if `@:native('path.to.Class')` exists. Remove any found.
				if (td.meta != null && td.meta.exists( nativeF )) for (m in td.meta.filter( nativeF )) td.meta.remove( m );
				
				// Add `@:native` and use the original package and type name.
				td.meta.push( { name:':native', params:[macro $v { clsName } ], pos:cls.pos } );
				
				// If the TypeDefinition::name is the same as `cls.name`, modify it.
				if (tdName == clsName) {
					tdName = td.name += ('' + Date.now().getTime() + '' + (counter++)).replace('+', '_').replace('.', '_');
					
				}
				
				// Remove the previous class for the the current compile.
				Compiler.exclude( cache.current.pack.toDotPath( cache.current.name ) );
				// Add the "retyped" class into the current compile.
				Context.defineType( td );
				
				// Cache the "rebuilt" fields in case of another "rebuild".
				cache.fields = td.fields;
				// Update the current name
				cache.current = { name: td.name, pack: td.pack };
				
				history.set( path, cache );
				
				result = cache;
				
				onRebuild.dispatch( cache );
				
			}
			
		}
		
		processHistory();
		
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
			if (pendingInfo.exists( path )) {
				for (cb in pendingInfo.get( path )) {
					cb( _history.type, _history.fields );
				}
				
				pendingInfo.remove( path );
				
			}
			
			callback( _history.type, _history.fields );
			result = true;
			
		} else {
			var callbacks = pendingInfo.exists( path ) ? pendingInfo.get( path ) : [];
			callbacks.push( callback );
			
			pendingInfo.set( path, callbacks );
			
		}
		
		processHistory();
		
		return result;
	}
	
	/**
	 * Generate `a` before `b`.
	 */
	public static function generateBefore(a:TypePath, b:TypePath):Void {
		var aname = a.pack.toDotPath( a.name );
		var bname = b.pack.toDotPath( b.name );
		
		var values = dependencyCache.exists( bname ) ? dependencyCache.get( bname ) : [];
		values.push( macro $p { a.pack.concat( [a.name] ) } );
		
		dependencyCache.set( bname, values );

	}
	
	/**
	 * Generate `a` after `b`.
	 */
	public static function generateAfter(a:TypePath, b:TypePath):Void {
		var aname = a.pack.toDotPath( a.name );
		var bname = b.pack.toDotPath( b.name );
		
		var values = dependencyCache.exists( aname ) ? dependencyCache.get( aname ) : [];
		values.push( macro $p { b.pack.concat( [b.name] ) } );
		
		dependencyCache.set( aname, values );
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
						#if !klas_verbose
						field.meta.add( ':extern', [], field.pos );
						#end
						
					}
					
				case _:
					
			}
		}
	}
	#end
	
	/**
	 * Used internally by KlasImp.
	 */
	@:noCompletion
	public static macro function getDependencies(key:String):Expr {
		var values = dependencyCache.get( key );
		return values == null ? macro null : macro [$a { values }];
	}
	
}