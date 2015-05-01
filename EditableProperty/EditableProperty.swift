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
	/// `defaultValue`. Otherwise, new default values may replace
	/// user-initiated edits.
	public init<P: PropertyType where P.Value == Value>(defaultValue: P, editsTakePriority: Bool) {
		(validationErrors, validationErrorsSink) = Signal<ValidationError, NoError>.pipe()

		_committedValue = MutableProperty(.DefaultValue(Box(defaultValue.value)))

		var defaults = defaultValue.producer
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
		self.init(defaultValue: ConstantProperty(defaultValue), editsTakePriority: true)
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

extension EditableProperty: SinkType {
	public func put(value: Value) {
		self.value = value
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
	let validatedEdits = editor.edits
		|> map(liftSignal)
		// We only care about the latest edit.
		|> flatMap(FlattenStrategy.Latest) { [weak property] editSession -> SignalProducer<Value, NoError> in
			let sessionCompleted: SignalProducer<(), NoError> = editSession
				|> then(.empty)
				|> catch { _ in .empty }

			let committedValues = (property?._committedValue.producer ?? .empty)
				|> promoteErrors(ValidationError.self)
				|> takeUntil(sessionCompleted)

			return combineLatest(committedValues, editSession)
				// We only care about the result of merging the latest values.
				|> flatMap(.Latest) { committed, proposed in
					return editor.mergeCommittedValue(committed, intoProposedValue: proposed)
				}
				// Wait until validation completes, then use the final value for
				// the property's value. If the signal never sends anything,
				// don't update the property.
				|> takeLast(1)
				// If interrupted or errored, just complete (to cancel the edit).
				|> ignoreInterruption
				|> catch { error in
					if let property = property {
						sendNext(property.validationErrorsSink, error)
					}

					return .empty
				}
		}
		|> map { Committed<Value, ValidationError>.ValidatedEdit(Box($0), editor) }
	
	return property._committedValue <~ validatedEdits
}

/// Lifts a Signal to a SignalProducer.
///
/// This is a fundamentally unsafe operation, as no buffering is performed, and
/// events may be missed. Use only in contexts where this is acceptable or
/// impossible!
private func liftSignal<T, Error>(signal: Signal<T, Error>) -> SignalProducer<T, Error> {
	return SignalProducer { observer, disposable in
		disposable.addDisposable(signal.observe(observer))
	}
}

/// Ignores any Interrupted event on the input signal, translating it to
/// Completed instead.
private func ignoreInterruption<T, Error>(signal: Signal<T, Error>) -> Signal<T, Error> {
	return Signal { observer in
		return signal.observe(Signal.Observer { event in
			switch event {
			case .Interrupted:
				sendCompleted(observer)

			default:
				observer.put(event)
			}
		})
	}
}
