import Foundation

/// A route definition that matches URL paths and produces deeplink values.
///
/// Routes consist of path segments (literals and parameters) and a factory
/// closure that creates the deeplink value from captured parameters.
public struct Route<Deeplink: DeeplinkRepresentable>: Sendable {
	/// The path segments that define this route's pattern.
	let segments: [PathSegment]

	/// A closure that creates a deeplink from captured parameter values.
	let factory: @Sendable ([String: Any]) -> Deeplink?

	/// Creates a route with the given segments and factory.
	public init(segments: [PathSegment], factory: @escaping @Sendable ([String: Any]) -> Deeplink?) {
		precondition(
			segments.dropLast().allSatisfy { !$0.isWildcard },
			"Wildcard segment must be the last segment in a route"
		)

		let names = paramNames(from: segments)
		precondition(
			names.count == Set(names).count,
			"Parameter names must be unique within a route"
		)

		self.segments = segments
		self.factory = factory
	}

	/// Creates a route with no parameters.
	/// - Parameters:
	///   - segments: The path segments to match.
	///   - factory: A closure that returns the deeplink.
	public init(_ segments: PathSegment..., factory: @escaping @Sendable () -> Deeplink) {
		self.init(segments: segments, factory: { _ in factory() })
	}

	/// Creates a route with one parameter.
	/// - Parameters:
	///   - s1: First path segment.
	///   - s2: Second path segment (parameter).
	///   - factory: A closure that takes the captured parameter and returns the deeplink.
	public init<P1: DeeplinkParameter>(
		_ s1: PathSegment,
		_ s2: PathSegment,
		factory: @escaping @Sendable (P1) -> Deeplink
	) {
		let names = paramNames(from: [s1, s2])
		precondition(names.count >= 1, "Route with 1 type parameter requires at least 1 parameter/wildcard segment")
		self.init(segments: [s1, s2], factory: { params in
			guard let p1 = params[names[0]] as? P1 else { return nil }
			return factory(p1)
		})
	}

	/// Creates a route with one parameter (single segment).
	/// - Parameters:
	///   - s1: Path segment (parameter).
	///   - factory: A closure that takes the captured parameter and returns the deeplink.
	public init<P1: DeeplinkParameter>(
		_ s1: PathSegment,
		factory: @escaping @Sendable (P1) -> Deeplink
	) {
		let names = paramNames(from: [s1])
		precondition(names.count >= 1, "Route with 1 type parameter requires at least 1 parameter/wildcard segment")
		self.init(segments: [s1], factory: { params in
			guard let p1 = params[names[0]] as? P1 else { return nil }
			return factory(p1)
		})
	}

	/// Creates a route with two parameters.
	/// - Parameters:
	///   - s1: First path segment.
	///   - s2: Second path segment.
	///   - s3: Third path segment.
	///   - factory: A closure that takes the captured parameters and returns the deeplink.
	public init<P1: DeeplinkParameter, P2: DeeplinkParameter>(
		_ s1: PathSegment,
		_ s2: PathSegment,
		_ s3: PathSegment,
		factory: @escaping @Sendable (P1, P2) -> Deeplink
	) {
		let names = paramNames(from: [s1, s2, s3])
		precondition(names.count >= 2, "Route with 2 type parameters requires at least 2 parameter/wildcard segments")
		self.init(segments: [s1, s2, s3], factory: { params in
			guard let p1 = params[names[0]] as? P1,
			      let p2 = params[names[1]] as? P2
			else { return nil }
			return factory(p1, p2)
		})
	}

	/// Creates a route with three parameters.
	/// - Parameters:
	///   - s1: First path segment.
	///   - s2: Second path segment.
	///   - s3: Third path segment.
	///   - s4: Fourth path segment.
	///   - factory: A closure that takes the captured parameters and returns the deeplink.
	public init<P1: DeeplinkParameter, P2: DeeplinkParameter, P3: DeeplinkParameter>(
		_ s1: PathSegment,
		_ s2: PathSegment,
		_ s3: PathSegment,
		_ s4: PathSegment,
		factory: @escaping @Sendable (P1, P2, P3) -> Deeplink
	) {
		let names = paramNames(from: [s1, s2, s3, s4])
		precondition(names.count >= 3, "Route with 3 type parameters requires at least 3 parameter/wildcard segments")
		self.init(segments: [s1, s2, s3, s4], factory: { params in
			guard let p1 = params[names[0]] as? P1,
			      let p2 = params[names[1]] as? P2,
			      let p3 = params[names[2]] as? P3
			else { return nil }
			return factory(p1, p2, p3)
		})
	}

	/// Attempts to match a URL against this route's pattern.
	/// - Parameter url: The URL to match.
	/// - Returns: The deeplink value if the URL matches, or `nil` otherwise.
	func match(_ url: URL) -> Deeplink? {
		var components = url.pathComponents.filter { $0 != "/" }
		if let host = url.host() { components.insert(host, at: 0) }

		if segments.last?.isWildcard == true {
			guard components.count >= segments.count - 1 else { return nil }
		} else {
			guard components.count == segments.count else { return nil }
		}

		var capturedParams: [String: Any] = [:]

		for (index, segment) in segments.enumerated() {
			switch segment {
				case let .wildcard(name, type):
					let remaining = components[index...].joined(separator: "/")
					guard let value = type.fromParameterString(remaining) else { return nil }
					capturedParams[name] = value

				case .literal, .parameter:
					guard let result = segment.match(components[index]) else { return nil }
					if case let .parameter(name, _) = segment {
						capturedParams[name] = result
					}
			}
		}

		return factory(capturedParams)
	}
}

private func paramNames(from segments: [PathSegment]) -> [String] {
	segments.compactMap(\.name)
}

/// A collection of routes that can be used to match URLs.
public protocol RouteCollection: Sendable {
	associatedtype Deeplink: DeeplinkRepresentable

	/// The routes in this collection.
	var routes: [Route<Deeplink>] { get }
}

/// A concrete implementation of `RouteCollection`.
public struct _Routes<Deeplink: DeeplinkRepresentable>: RouteCollection, Sendable {
	public let routes: [Route<Deeplink>]

	public init(routes: [Route<Deeplink>]) {
		self.routes = routes
	}
}
