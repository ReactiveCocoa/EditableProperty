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

final class Editor<T, ValidationError: ErrorType> {
	let edits: SignalProducer<Signal<T, NoError>, NoError>
	
	func commit(current: Fact<T>, proposed: T) -> SignalProducer<T, ValidationError>
}

final class EditableProperty<T, ValidationError: ErrorType> {
	typealias Value = Fact<T, ValidationError>

	let defaultValues: PropertyOf<T>
	let validationErrors: Signal<ValidationError, NoError>
	var editors: [Editor<T, ValidationError>]
}
