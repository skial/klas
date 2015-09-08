package uhx.macro.klas;

/**
 * ...
 * @author Skial Bainn
 */
@:forward(keys, exists, iterator) 
abstract Signal<T0, T1, T2>(Map<T0, RVSignal<T1, T2>>) from Map<T0, RVSignal<T1, T2>> to Map<T0, RVSignal<T1, T2>> {
	
	public var numListeners(get, never):Int;
	
	public inline function new(u:Map<T0, RVSignal<T1, T2>>) this = u;
	
	private inline function get_numListeners():Int {
		var total = 0;
		
		for (key in this.keys()) total += this.get( key ).numListeners;
		
		return total;
	}
	
	public inline function add(metadata:T0, callback:T1->T2->T2):RVSlot<T1, T2> {
		var signal = null;
		
		if (this.exists( metadata )) {
			signal = this.get( metadata );
		} else {
			signal = new RVSignal();
			this.set( metadata, signal );
			
		}
		
		return signal.add( callback );
	}
	
	public inline function addOnce(metadata:T0, callback:T1->T2->T2):RVSlot<T1, T2> {
		var signal = null;
		
		if (this.exists( metadata )) {
			signal = this.get( metadata );
		} else {
			signal = new RVSignal();
			this.set( metadata, signal );
			
		}
		
		return signal.addOnce( callback );
	}
	
	public inline function addWithPriority(metadata:T0, callback:T1->T2->T2, ?priority:Int = 0):RVSlot<T1, T2> {
		var signal = null;
		
		if (this.exists( metadata )) {
			signal = this.get( metadata );
		} else {
			signal = new RVSignal();
			this.set( metadata, signal );
			
		}
		
		return signal.addWithPriority( callback, priority );
	}
	
	public inline function addOnceWithPriority(metadata:T0, callback:T1->T2->T2, ?priority:Int = 0):RVSlot<T1, T2> {
		var signal = null;
		
		if (this.exists( metadata )) {
			signal = this.get( metadata );
		} else {
			signal = new RVSignal();
			this.set( metadata, signal );
			
		}
		
		return signal.addOnceWithPriority( callback, priority );
	}
	
	public inline function remove(metadata:T0, callback:T1->T2->T2):RVSlot<T1, T2> {
		var signal = null;
		
		if (this.exists( metadata )) {
			signal = this.get( metadata );
		} else {
			signal = new RVSignal();
			this.set( metadata, signal );
			
		}
		
		return signal.remove( callback );
	}
	
	public inline function removeAll(metadata:T0):Void {
		if (this.exists( metadata )) this.get( metadata ).removeAll();
	}
	
	public inline function dispatch(metadata:T0, value1:T1, value2:T2):T2 {
		if (this.exists( metadata )) value2 = this.get( metadata ).dispatch( value1, value2 );
		return value2;
	}
	
}