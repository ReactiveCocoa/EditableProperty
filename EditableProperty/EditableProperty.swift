import ReactiveCocoa

/// A property that editors can propose and commit changes to.
///
/// This can be used to implement multi-way bindings, where each "side" of the
/// binding is a separate editor that ignores changes made by itself.
public final class EditableProperty<Value, ValidationError: ErrorType>: MutablePropertyType {
	public struct Edit {
		public let value: Validated<Value>
	}

	public let edits: SignalProducer<(Validated<Value>, Editor<Value, ValidationError>)

	public let validationErrors: Signal<ValidationError, NoError>

	private let defaultValues: PropertyOf<T>
	private var editors: [Editor<T, ValidationError>] = []

	public var value: Value
	public let producer: SignalProducer<Value, NoError> = .empty
	
	public init<P: PropertyType where P.Value == T>(defaultValues: P, editsTakePriority: Bool = false) {
		self.defaultValues = PropertyOf(defaultValues)
		self.validationErrors = .never

		self.value = Validated(value: self.defaultValues.value, editor: nil)
	}

	public convenience init(defaultValue: T) {
		self.init(defaultValues: ConstantProperty(defaultValue))
	}
}

public func <~ <T, ValidationError: ErrorType>(property: EditableProperty<T, ValidationError>, editor: Editor<T, ValidationError>) -> Disposable {
	return SimpleDisposable()
}
