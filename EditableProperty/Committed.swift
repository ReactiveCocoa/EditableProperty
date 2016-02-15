import ReactiveCocoa

/// Represents a committed change to the value of an EditableProperty.
public enum Committed<Value, ValidationError: ErrorType> {
	/// The change is an automatic update to a new default value.
	case DefaultValue(Value)

	/// The change is a new value that has been explicitly set _without_ an
	/// editor.
	/// 
	/// This might occur from setting `value` directly, or by explicitly binding
	/// signals, producers, or other properties to the EditableProperty.
	case ExplicitUpdate(Value)

	/// The value was validated and committed by the given editor.
	case ValidatedEdit(Value, Editor<Value, ValidationError>)

	/// The value that was committed.
	public var value: Value {
		switch self {
		case let .DefaultValue(value):
			return value

		case let .ExplicitUpdate(value):
			return value

		case let .ValidatedEdit(value, _):
			return value
		}
	}

	/// Whether this change represents a user-initiated edit.
	public var isEdit: Bool {
		switch self {
		case .ValidatedEdit:
			return true

		case .DefaultValue, .ExplicitUpdate:
			return false
		}
	}
}

public func == <Value: Equatable, ValidationError> (lhs: Committed<Value, ValidationError>, rhs: Committed<Value, ValidationError>) -> Bool {
	switch (lhs, rhs) {
	case (.DefaultValue, .DefaultValue), (.ExplicitUpdate, .ExplicitUpdate):
		return lhs.value == rhs.value
	
	case let (.ValidatedEdit(_, left), .ValidatedEdit(_, right)):
		return left === right && lhs.value == rhs.value
	
	default:
		return false
	}
}

extension Committed: CustomStringConvertible {
	public var description: String {
		let value = self.value

		switch self {
		case .DefaultValue:
			return "DefaultValue(\(value))"

		case .ExplicitUpdate:
			return "ExplicitUpdate(\(value))"

		case .ValidatedEdit:
			return "ValidatedEdit(\(value))"
		}
	}
}
