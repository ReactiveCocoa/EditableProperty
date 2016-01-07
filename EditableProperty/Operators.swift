//
//  Operators.swift
//  EditableProperty
//
//  Created by Christopher Liscio on 1/7/16.
//  Copyright © 2016 ReactiveCocoa. All rights reserved.
//

import Foundation
import ReactiveCocoa

/// Attaches a SignalProducer to a MutableProperty of edit sessions (as defined 
/// by Editor.EditSession). This allows for far simpler "sessions" that crop up 
/// in practice when binding changes from UI elements that require validation from 
/// an associated editor.
public func <~<Producer: SignalProducerType, ValidationError : ErrorType>(session: MutableProperty<Signal<Producer.Value, ValidationError>>, producer: Producer) {
    producer.startWithNext { value in
        let (editSignal, editSink) = Signal<Producer.Value, ValidationError>.pipe()
        session.value = editSignal
        
        editSink.sendNext(value)
        editSink.sendCompleted()
    }
}

/// Attaches a Signal to a MutableProperty of edit sessions (as defined
/// by Editor.EditSession). This allows for far simpler "sessions" that crop up
/// in practice when binding changes from UI elements that require validation from
/// an associated editor.
public func <~<Producer: SignalType, ValidationError: ErrorType>(session: MutableProperty<Signal<Producer.Value, ValidationError>>, producer: Producer) {
    producer.observeNext { value in
        let (editSignal, editSink) = Signal<Producer.Value, ValidationError>.pipe()
        session.value = editSignal
        
        editSink.sendNext(value)
        editSink.sendCompleted()
    }
}
