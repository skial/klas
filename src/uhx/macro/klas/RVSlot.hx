package uhx.macro.klas;

import msignal.Slot;

/**
 * ...
 * @author Skial Bainn
 */
class RVSlot<T1, T2> extends Slot<RVSignal<T1, T2>, T1->T2->T2> {
	
	public var param1:T1;
	public var param2:T2;

	public function new(signal:RVSignal<T1, T2>, listener:T1->T2->T2, once:Bool = false, priority:Int = 0) {
		super(signal, listener, once, priority);
	}
	
	public function execute(value1:T1, value2:T2):Null<T2> {
		if (!enabled) return null;
		if (once) remove();
		
		if (param1 != null) value1 = param1;
		if (param2 != null) value2 = param2;
		
		return listener(value1, value2);
	}
}