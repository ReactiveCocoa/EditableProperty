import ReactiveCocoa
import Result

/// A property of type `Value` that Editors can propose and commit changes to.
///
/// This can be used to implement multi-way bindings, where each "side" of the
/// binding is a separate editor that ignores changes made by itself.
public final class EditableProperty<Value, ValidationError: ErrorType>: MutablePropertyType {
	/// The current value of the property, along with information about how that
	/// value was obtained.
	public var committedValue: AnyProperty<Committed<Value, ValidationError>> {
		return AnyProperty(_committedValue)
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

		_committedValue = MutableProperty(.DefaultValue(defaultValue.value))

		var defaults = defaultValue.producer
			.map { Committed<Value, ValidationError>.DefaultValue($0) }

		if editsTakePriority {
			let hasBeenEdited = _committedValue.producer
				.filter { $0.isEdit }
				.map { _ in () }

			defaults = defaults
				.takeUntil(hasBeenEdited)
		}

		_committedValue <~ defaults
	}

	/// Initializes an editable property with the given default value.
	public convenience init(_ defaultValue: Value) {
		self.init(defaultValue: ConstantProperty(defaultValue), editsTakePriority: true)
	}

	public var value: Value {
		get {
			return _committedValue.value.value
		}

		set(value) {
			_committedValue.value = .ExplicitUpdate(value)
		}
	}

	public var producer: SignalProducer<Value, NoError> {
		return _committedValue.producer
			.map { $0.value }
	}

	/// A signal that will send the property's changes over time,
	/// then complete when the property has deinitialized.
	public lazy var signal: Signal<Value, NoError> = { [unowned self] in
		var extractedSignal: Signal<Value, NoError>!
		self.producer.startWithSignal { signal, _ in
			extractedSignal = signal
		}
		return extractedSignal
	}()

	deinit {
		validationErrorsSink.sendCompleted()
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
		.map(liftSignal)
		// We only care about the latest edit.
		.flatMap(FlattenStrategy.Latest) { [weak property] editSession -> SignalProducer<Value, NoError> in
			let sessionCompleted: SignalProducer<(), NoError> = editSession
				.then(.empty)
				.flatMapError { _ in .empty }

			let committedValues = (property?._committedValue.producer ?? .empty)
				.promoteErrors(ValidationError.self)
				.takeUntil(sessionCompleted)

			return combineLatest(committedValues, editSession)
				// We only care about the result of merging the latest values.
				.flatMap(FlattenStrategy.Latest) { committed, proposed in
					return editor.mergeCommittedValue(committed, intoProposedValue: proposed)
				}
				// Wait until validation completes, then use the final value for
				// the property's value. If the signal never sends anything,
				// don't update the property.
				.takeLast(1)
				// If interrupted or errored, just complete (to cancel the edit).
				.ignoreInterruption()
				.flatMapError { error in
					if let property = property {
						property.validationErrorsSink.sendNext(error)
					}

					return .empty
				}
		}
		.map { Committed<Value, ValidationError>.ValidatedEdit($0, editor) }
	
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

private extension Signal {
	/// Ignores any Interrupted event on the input signal, translating it to
	/// Completed instead.
	func ignoreInterruption() -> Signal<Value, Error> {
		return Signal { observer in
			return self.observe { event in
				switch event {
				case .Interrupted:
					observer.sendCompleted()
					
				default:
					observer.action(event)
				}
			}
		}
	}
}

private extension SignalProducer {
	func ignoreInterruption() -> SignalProducer<Value, Error> {
		return lift { $0.ignoreInterruption() }
	}
}