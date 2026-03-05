import Foundation

/// Represents a segment in a URL path pattern.
///
/// Path segments can either be literal strings that must match exactly,
/// or parameters that capture values from the URL.
public enum PathSegment: Sendable {
	/// A literal segment that must match the URL path exactly.
	/// - Parameter value: The expected string value.
	case literal(String)

	/// A parameter segment that captures a value from the URL path.
	/// - Parameters:
	///   - name: The name of the parameter (for debugging).
	///   - type: The type to parse the captured value as.
	case parameter(name: String, type: any DeeplinkParameter.Type)

	/// A wildcard segment that captures all remaining path components joined by "/".
	/// Must be the last segment in a route.
	/// - Parameters:
	///   - name: The name of the parameter (for debugging).
	///   - type: The type to parse the captured value as.
	case wildcard(name: String, type: any DeeplinkParameter.Type)

	var name: String? {
		switch self {
			case .literal: nil
			case let .parameter(name, _), let .wildcard(name, _): name
		}
	}

	var isWildcard: Bool {
		if case .wildcard = self { return true }
		return false
	}
}

extension PathSegment: ExpressibleByStringLiteral {
	public init(stringLiteral value: String) {
		self = .literal(value)
	}
}

extension PathSegment {
	/// Attempts to match this segment against a URL path component.
	/// - Parameter component: The URL path component to match.
	/// - Returns: The parsed value if the segment is a parameter, `true` if it's a matching literal, or `nil` if no match.
	func match(_ component: String) -> Any? {
		switch self {
			case .wildcard: nil // Handled at the Route level
			case let .literal(expected): component == expected ? true : nil
			case let .parameter(_, type): type.fromParameterString(component)
		}
	}
}
