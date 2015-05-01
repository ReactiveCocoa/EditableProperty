import LlamaKit

/// Represents a committed change to the value of an EditableProperty.
public enum Committed<Value, ValidationError: ErrorType> {
	/// The change is an automatic update to a new default value.
	case DefaultValue(Box<Value>)

	/// The change is a new value that has been explicitly set _without_ an
	/// editor.
	/// 
	/// This might occur from setting `value` directly, or by explicitly binding
	/// signals, producers, or other properties to the EditableProperty.
	case ExplicitUpdate(Box<Value>)

	/// The value was validated and committed by the given editor.
	case ValidatedEdit(Box<Value>, Editor<Value, ValidationError>)

	/// The value that was committed.
	public var value: Value {
		switch self {
		case let .DefaultValue(value):
			return value.unbox

		case let .ExplicitUpdate(value):
			return value.unbox

		case let .ValidatedEdit(value, _):
			return value.unbox
		}
	}
}

public func == <Value: Equatable, ValidationError> (lhs: Committed<Value, ValidationError>, rhs: Committed<Value, ValidationError>) {
	switch (lhs, rhs) {
	case let (.DefaultValue(left), .DefaultValue(right)):
		return left == right
	
	case let (.ExplicitUpdate(left), .ExplicitUpdate(right)):
		return left == right
	
	case let (.ValidatedEdit(leftValue, leftEditor), .ValidatedEdit(rightValue, rightEditor)):
		return leftEditor === rightEditor && leftValue == rightValue
	}
}

extension Committed: Printable {
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
