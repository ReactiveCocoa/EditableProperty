import ReactiveCocoa

/// Represents a value of type T that has been validated for use in an
/// EditableProperty.
public struct Validated<T, ValidationError: ErrorType> {
	/// The value that has been validated.
	public let value: T
	
	/// The editor that validated the value, or nil if the value was a default
	/// value (and thus no validation is necessary).
	public let editor: Editor<T, ValidationError>?

	private init(value: T, editor: Editor<T, ValidationError>)
}

public func == <T: Equatable, ErrorA, ErrorB>(lhs: Validated<T, ErrorA>, rhs: Validated<T, ErrorB>) -> Bool

public final class Editor<T, ValidationError: ErrorType> {
	public let edits: SignalProducer<Signal<T, NoError>, NoError>

	public init(edits: SignalProducer<Signal<T, NoError>, NoError>, commit: (Fact<T>, T) -> SignalProducer<T, ValidationError>)
	
	public func commit(current: Fact<T>, proposed: T) -> SignalProducer<T, ValidationError>
}

public final class EditableProperty<T, ValidationError: ErrorType>: PropertyType {
	public typealias Value = Fact<T, ValidationError>

	public let validationErrors: Signal<ValidationError, NoError>

	private let defaultValues: PropertyOf<T>
	private var editors: [Editor<T, ValidationError>]
	
	public init<P: PropertyType where P.Value == T>(defaultValues: P, editsTakePriority: Bool = false)
	public init(defaultValue: T)
}

public func <~ <T, ValidationError: ErrorType>(property: EditableProperty<T, ValidationError>, editor: Editor<T, ValidationError>) -> Disposable

extension EditableProperty: MutablePropertyType {
}
