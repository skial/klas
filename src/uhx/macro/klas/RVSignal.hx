package uhx.macro.klas;

import msignal.Signal;

/**
 * ...
 * @author Skial Bainn
 */
class RVSignal<T1, T2> extends Signal<RVSlot<T1, T2>, T1->T2->T2> {
	
	public function new(?type1:Dynamic = null, ?type2:Dynamic = null) {
		super([type1, type2]);
	}
	
	public function dispatch(value1:T1, value2:T2):T2 {
		var slotsToProcess = slots;
		
		while (slotsToProcess.nonEmpty) {
			value2 = slotsToProcess.head.execute(value1, value2);
			slotsToProcess = slotsToProcess.tail;
			
		}
		
		return value2;
	}
	
	override function createSlot(listener:T1->T2->T2, once:Null<Bool> = false, priority:Null<Int> = 0) {
		return new RVSlot<T1, T2>(this, listener, once, priority);
	}
}
