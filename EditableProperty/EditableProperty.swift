import ReactiveCocoa

/// Represents a value of type T that has been validated for use in an
/// EditableProperty.
public struct Validated<T, ValidationError: ErrorType> {
	/// The value that has been validated.
	public let value: T
	
	/// The editor that validated the value, or nil if the value was a default
	/// value (and thus no validation is necessary).
	public let editor: Editor<T, ValidationError>?

	private init(value: T, editor: Editor<T, ValidationError>?) {
		self.value = value
		self.editor = editor
	}
}

public func == <T: Equatable, ErrorA, ErrorB>(lhs: Validated<T, ErrorA>, rhs: Validated<T, ErrorB>) -> Bool {
	return lhs.value == rhs.value && lhs.editor === rhs.editor
}

public final class Editor<T, ValidationError: ErrorType> {
	public typealias CommitFunction = (Validated<T, ValidationError>, T) -> SignalProducer<T, ValidationError>

	public let edits: SignalProducer<Signal<T, NoError>, NoError>
	private let _commit: CommitFunction

	public init(edits: SignalProducer<Signal<T, NoError>, NoError>, commit: CommitFunction) {
		self.edits = edits
		self._commit = commit
	}
	
	public func commit(current: Validated<T, ValidationError>, proposed: T) -> SignalProducer<T, ValidationError> {
		return _commit(current, proposed)
	}
}

public final class EditableProperty<T, ValidationError: ErrorType>: MutablePropertyType {
	public typealias Value = Validated<T, ValidationError>

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
