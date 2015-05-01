import LlamaKit
import ReactiveCocoa

/// A property that editors can propose and commit changes to.
///
/// This can be used to implement multi-way bindings, where each "side" of the
/// binding is a separate editor that ignores changes made by itself.
public final class EditableProperty<Value, ValidationError: ErrorType> {
	private let _committedValues: MutableProperty<Committed<Value, ValidationError>>
	public var committedValues: SignalProducer<Committed<Value, ValidationError>> {
		return _committedValues.producer
	}

	public let validationErrors: Signal<ValidationError, NoError>
	
	public init<P: PropertyType where P.Value == T>(defaultValues: P, editsTakePriority: Bool = false) {
		// TODO: editsTakePriority

		// TODO
		self.validationErrors = .never

		_committedValues = MutableProperty(.DefaultValue(Box(defaultValues.value)))

		_committedValues <~ defaultValues.producer
			|> map { Committed<Value, ValidationError>.DefaultValue(Box($0)) }
	}

	public convenience init(_ defaultValue: T) {
		self.init(defaultValues: ConstantProperty(defaultValue))
	}
}

extension EditableProperty: MutablePropertyType {
	public var value: Value {
		get {
			return _committedValues.value.value
		}

		set(value) {
			_committedValues.value = .ExplicitUpdate(Box(value))
		}
	}

	public var producer: SignalProducer<Value, NoError> {
		return committedValues
			|> map { $0.value }
	}
}

public func <~ <T, ValidationError: ErrorType>(property: EditableProperty<T, ValidationError>, editor: Editor<T, ValidationError>) -> Disposable {
	return SimpleDisposable()
}
