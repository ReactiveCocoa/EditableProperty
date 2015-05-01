import ReactiveCocoa

/// Represents an editor that can propose changes to properties, and then commit
/// those changes when editing has completed.
///
/// Editors have identity, which is useful for ignoring an editor's own changes
/// during property observation.
public final class Editor<Value, ValidationError: ErrorType> {
	/// Represents a single editing session. A signal of this type should send:
	///
	/// - .Next events as edits are proposed
	/// - .Error if an error occurs during editing
	/// - .Completed if editing finishes successfully, and the result should
	///   be committed
	/// - .Interrupted if editing is cancelled, and the result should be
	///   discarded
	public typealias EditSession = Signal<Value, ValidationError>

	/// Produces signals that represent distinct editing sessions.
	///
	/// Events should not be sent upon each inner signal until the signal
	/// instance itself has been sent along the `edits` producer.
	public let edits: SignalProducer<EditSession, NoError>

	private let _mergeCommittedValue: (Committed<Value, ValidationError>, Value) -> SignalProducer<Value, ValidationError>

	/// Asks the editor to merge its proposed value with the most recent
	/// validated value that was actually committed to the property.
	///
	/// The property will take the values of the returned producer, unless
	/// another value is proposed by this editor first, or another editor
	/// commits a validated value.
	public func mergeCommittedValue(committedValue: Committed<Value, ValidationError>, intoProposedValue proposedValue: Value) -> SignalProducer<Value, ValidationError> {
		return _mergeCommittedValue(committedValue, proposedValue)
	}

	/// Instantiates an editor with the given behaviors.
	public init(edits: SignalProducer<EditSession, NoError>, mergeCommittedValue: (Committed<Value, ValidationError>, Value) -> SignalProducer<Value, ValidationError>) {
		self.edits = edits
		self._mergeCommittedValue = mergeCommittedValue
	}
}
