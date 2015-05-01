import LlamaKit
import ReactiveCocoa

/// A property of type `Value` that Editors can propose and commit changes to.
///
/// This can be used to implement multi-way bindings, where each "side" of the
/// binding is a separate editor that ignores changes made by itself.
public final class EditableProperty<Value, ValidationError: ErrorType> {
	/// The current value of the property, along with information about how that
	/// value was obtained.
	public var committedValue: PropertyOf<Committed<Value, ValidationError>> {
		return PropertyOf(_committedValue)
	}

	private let _committedValue: MutableProperty<Committed<Value, ValidationError>>

	/// Sends any errors that occur during edit validation, from any editor.
	public let validationErrors: Signal<ValidationError, NoError>
	private let validationErrorsSink: Signal<ValidationError, NoError>.Observer
	
	/// Initializes an editable property that will have the given default
	/// values while no edits have yet occurred.
	///
	/// If `editsTakePriority` is true, any edits will permanently override
	/// `defaultValues`. Otherwise, new default values may replace
	/// user-initiated edits.
	public init<P: PropertyType where P.Value == Value>(defaultValues: P, editsTakePriority: Bool) {
		(validationErrors, validationErrorsSink) = Signal<ValidationError, NoError>.pipe()

		_committedValue = MutableProperty(.DefaultValue(Box(defaultValues.value)))

		var defaults = defaultValues.producer
			|> map { Committed<Value, ValidationError>.DefaultValue(Box($0)) }

		if editsTakePriority {
			let hasBeenEdited = _committedValue.producer
				|> filter { $0.isEdit }
				|> map { _ in () }

			defaults = defaults
				|> takeUntil(hasBeenEdited)
		}

		_committedValue <~ defaults
	}

	/// Initializes an editable property with the given default value.
	public convenience init(_ defaultValue: Value) {
		self.init(defaultValues: ConstantProperty(defaultValue), editsTakePriority: true)
	}

	deinit {
		sendCompleted(validationErrorsSink)
	}
}

extension EditableProperty: MutablePropertyType {
	public var value: Value {
		get {
			return _committedValue.value.value
		}

		set(value) {
			_committedValue.value = .ExplicitUpdate(Box(value))
		}
	}

	public var producer: SignalProducer<Value, NoError> {
		return _committedValue.producer
			|> map { $0.value }
	}
}

/// Attaches an Editor to an EditableProperty, so that any edits will be
/// reflected in the property's value once editing has finished and validation
/// has succeeded.
///
/// If any error occurs during editing or validation, it will be sent along the
/// property's `validationErrors` signal.
///
/// The binding will automatically terminate when the property is deinitialized.
///
/// Returns a disposable which can be used to manually remove the editor from the
/// property.
public func <~ <Value, ValidationError: ErrorType>(property: EditableProperty<Value, ValidationError>, editor: Editor<Value, ValidationError>) -> Disposable {
	let committedValues = property._committedValue.producer
	let validationErrorsSink = property.validationErrorsSink

	let validatedEdits = editor.edits
		|> flatMap(FlattenStrategy.Latest) { (session: Editor<Value, ValidationError>.EditSession) -> SignalProducer<Value, NoError> in
			let sessionProducer = SignalProducer { observer, disposable in
				disposable.addDisposable(session.observe(observer))
			}

			let sessionCompleted: SignalProducer<(), NoError> = sessionProducer
				|> then(.empty)
				|> catch { _ in .empty }

			let validatedValues = committedValues
				|> promoteErrors(ValidationError.self)
				|> takeUntil(sessionCompleted)
				|> combineLatestWith(sessionProducer)
				|> flatMap(.Latest) { committed, proposed in
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
		|> map { Committed<Value, ValidationError>.ValidatedEdit(Box($0), editor) }
	
	return property._committedValue <~ validatedEdits
}
