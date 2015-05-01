import LlamaKit
import ReactiveCocoa

/// A property that editors can propose and commit changes to.
///
/// This can be used to implement multi-way bindings, where each "side" of the
/// binding is a separate editor that ignores changes made by itself.
public final class EditableProperty<Value, ValidationError: ErrorType> {
	private let _committedValues: MutableProperty<Committed<Value, ValidationError>>
	public var committedValues: SignalProducer<Committed<Value, ValidationError>> {
		return _committedValues.producer
	}

	private let validationErrorsSink: Signal<ValidationError, NoError>.Observer
	public let validationErrors: Signal<ValidationError, NoError>
	
	public init<P: PropertyType where P.Value == T>(defaultValues: P, editsTakePriority: Bool = false) {
		// TODO: editsTakePriority

		(validationErrors, validationErrorsSink) = Signal<ValidationError, NoError>.pipe()

		_committedValues = MutableProperty(.DefaultValue(Box(defaultValues.value)))

		_committedValues <~ defaultValues.producer
			|> map { Committed<Value, ValidationError>.DefaultValue(Box($0)) }
	}

	public convenience init(_ defaultValue: T) {
		self.init(defaultValues: ConstantProperty(defaultValue))
	}
}

extension EditableProperty: MutablePropertyType {
	public var value: Value {
		get {
			return _committedValues.value.value
		}

		set(value) {
			_committedValues.value = .ExplicitUpdate(Box(value))
		}
	}

	public var producer: SignalProducer<Value, NoError> {
		return committedValues
			|> map { $0.value }
	}
}

public func <~ <Value, ValidationError: ErrorType>(property: EditableProperty<Value, ValidationError>, editor: Editor<Value, ValidationError>) -> Disposable {
	let committedValues = property.committedValues
	let validationErrorsSink = property.validationErrorsSink

	let validatedEdits = editor.edits
		|> joinMap(.Latest) { session in
			let sessionProducer = SignalProducer { observer, disposable in
				disposable.addDisposable(session.observe(observer))
			}

			let sessionCompleted = sessionProducer
				|> then(.empty)
				|> catch { _ in .empty }

			let validatedValues = committedValues
				|> promoteErrors(ValidationError.self)
				|> takeUntil(sessionCompleted)
				|> combineLatestWith(sessionProducer)
				|> joinMap(.Latest) { committed, proposed in
					return editor.mergeCommittedValue(committed, intoProposedValue: proposed)
				}
				|> takeLast(1)

			return SignalProducer { observer, disposable in
				validatedValues.startWithSignal { signal, signalDisposable in
					disposable.addDisposable(signalDisposable)

					signal.observe(SinkOf { event in
						switch event {
						case let .Next(value):
							sendNext(observer, value.unbox)

						case let .Error(error):
							sendNext(property.validationErrorsSink, error.unbox)

						case .Interrupted, .Completed:
							sendCompleted(observer)
						}
					})
				}
			}
		}
		|> map { .ValidatedEdit(Box($0), editor) }
	
	return property._committedValues <~ validatedEdits
}
