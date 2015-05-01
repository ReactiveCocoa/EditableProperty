import ReactiveCocoa

/// Represents a value that has been validated and committed by an editor.
///
/// This structure cannot be instantiated directly. It can only result from
/// successful validation.
public struct Validated<T> {
	/// The value that has been validated.
	public let value: T

	private init(value: T) {
		self.value = value
	}
}

public func == <T: Equatable> (lhs: Validated<T>, rhs: Validated<T>) -> Bool {
	return lhs.value == rhs.value
}

public func hashValue<T: Hashable> (validated: Validated<T>) -> Int {
	return validated.value.hashValue
}

extension Validated: Printable {
	public var description: String {
		return "Validated\(value)"
	}
}
