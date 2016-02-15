//
//  EditablePropertySpec.swift
//  EditableProperty
//
//  Created by Justin Spahr-Summers on 2015-05-01.
//  Copyright (c) 2015 ReactiveCocoa. All rights reserved.
//

import Nimble
import Quick
import EditableProperty
import Result
import ReactiveCocoa

typealias TestEditor = Editor<Int, NoError>

class EditablePropertySpec: QuickSpec {
	override func spec() {
		it("should do some binding magic") {
			let defaultValue
            = MutableProperty(0)

			let property = EditableProperty<Int, NoError>(defaultValue: defaultValue, editsTakePriority: false)
			expect(property.value).to(equal(defaultValue.value))

			let (editsProducer, editsSink) = SignalProducer<TestEditor.EditSession, NoError>.buffer(0)
			let editor = Editor(edits: editsProducer) { committed, proposed in
				return SignalProducer(value: max(committed.value, proposed))
			}

			property <~ editor

			defaultValue.value = 1
			expect(property.value).to(equal(defaultValue.value))

			let tryEdit: Int -> () = { proposed in
				let (editSignal, editSink) = TestEditor.EditSession.pipe()
				editsSink.sendNext(editSignal)
				expect(property.value).to(equal(defaultValue.value))

				editSink.sendNext(proposed)
				expect(property.value).to(equal(defaultValue.value))

				editSink.sendCompleted()
			}

			tryEdit(2)
			expect(property.value).to(equal(2))

			defaultValue.value = 3
			expect(property.value).to(equal(defaultValue.value))

			tryEdit(2)
			expect(property.value).to(equal(defaultValue.value))

			tryEdit(4)
			expect(property.value).to(equal(4))
		}
	}
}
