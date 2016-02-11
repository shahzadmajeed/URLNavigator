// The MIT License (MIT)
//
// Copyright (c) 2016 Suyeol Jeon (xoul.kr)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in all
// copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
// SOFTWARE.

import UIKit

/// URLNavigator provides an elegant way to navigate through view controllers by URLs. URLs should be mapped by using
/// `URLNavigator.map(_:_:)` function.
///
/// URLNavigator can be used to map URLs with 2 kind of types: `URLNavigable` and `URLOpenHandler`. `URLNavigable` is
/// a type which defines an custom initializer and `URLOpenHandler` is a closure. Both an initializer and a closure
/// have URL and values for its parameters.
///
/// Here's an example of mapping URLNaviable-conforming class `UserViewController` to URL:
///
///     Navigator.map("myapp://user/<id>", UserViewController.self)
///
/// This URL can be used to push or present the `UserViewController` by providing URLs:
///
///     Navigator.pushURL("myapp://user/123")
///     Navigator.presentURL("myapp://user/123")
///
/// This is another example of mapping `URLOpenHandler` to URL:
///
///     Navigator.map("myapp://say-hello") { URL, values in
///         print("Hello, world!")
///         return true
///     }
///
/// Use `URLNavigator.openURL()` to execute closures.
///
///     Navigator.openURL("myapp://say-hello") // prints "Hello, world!"
///
/// - Note: Use `UIApplication.openURL()` method to launch other applications or to open URLs in application level.
///
/// - SeeAlso: `URLNavigable`
public class URLNavigator {

    /// A closure type which has URL and values for parameters.
    public typealias URLOpenHandler = (URL: URLStringConvertible, values: [String: AnyObject]) -> Bool

    /// A dictionary to store URLNaviables by URL patterns.
    private(set) var URLMap = [String: URLNavigable.Type]()

    /// A dictionary to store URLOpenHandlers by URL patterns.
    private(set) var URLOpenHandlers = [String: URLOpenHandler]()


    // MARK: Initializing

    public init() {
        // ⛵ I'm an URLNavigator!
    }


    // MARK: Singleton

    /// Returns a default navigator. A global constant `Navigator` is a shortcut of `URLNavigator.defaultNavigator()`.
    ///
    /// - SeeAlso: `Navigator`
    public static func defaultNavigator() -> URLNavigator {
        struct Shared {
            static let defaultNavigator = URLNavigator()
        }
        return Shared.defaultNavigator
    }


    // MARK: URL Mapping

    /// Map an `URLNavigable` to an URL pattern.
    public func map(URLPattern: URLStringConvertible, _ navigable: URLNavigable.Type) {
        let URLString = URLNavigator.normalizedURL(URLPattern).URLString
        self.URLMap[URLString] = navigable
        NSLog("URLNavigator: Map '\(navigable)' to '\(URLPattern)'")
    }

    /// Map an `URLOpenHandler` to an URL pattern.
    public func map(URLPattern: URLStringConvertible, _ handler: URLOpenHandler) {
        let URLString = URLNavigator.normalizedURL(URLPattern).URLString
        self.URLOpenHandlers[URLString] = handler
        NSLog("URLNavigator: Map URL open handler to '\(URLPattern)'")
    }


    // MARK: Matching URLs

    /// Returns a matching URL pattern and placeholder values from specified URL and URL patterns. Returns `nil` if the
    /// URL is not contained in URL patterns.
    ///
    /// For example:
    ///
    ///     let (URLPattern, values) = URLNavigator.matchURL("myapp://user/123", from: ["myapp://user/<id>"])
    ///
    /// The value of the `URLPattern` from an example above is `"myapp://user/<id>"` and the value of the `values` is
    /// `["id": "123"]`.
    ///
    /// - Parameter URL: The placeholder-filled URL.
    /// - Parameter from: The array of URL patterns.
    ///
    /// - Returns: A tuple of URL pattern string and a dictionary of URL placeholder values.
    static func matchURL(URL: URLStringConvertible, from URLPatterns: [String]) -> (String, [String: AnyObject])? {
        // e.g. ["myapp:", "user", "123"]
        let URLPathComponents = URLNavigator.normalizedURL(URL).URLString.componentsSeparatedByString("/")

        outer: for URLPattern in URLPatterns {
            // e.g. ["myapp:", "user", "<id>"]
            let URLPatternPathComponents = URLPattern.componentsSeparatedByString("/")
            if URLPatternPathComponents.count != URLPathComponents.count {
                continue
            }

            var values = [String: AnyObject]()

            // e.g. ["user", "<id>"]
            for (i, component) in URLPatternPathComponents.enumerate() {
                if component.hasPrefix("<") && component.hasSuffix(">") { // e.g. "<id>"
                    let start = component.startIndex.advancedBy(1)
                    let end = component.endIndex.advancedBy(-1)
                    let placeholder = component[start..<end] // e.g. "id"
                    values[placeholder] = URLPathComponents[i] // e.g. ["id": "123"]
                } else if component != URLPathComponents[i] {
                    continue outer
                }
            }

            return (URLPattern, values)
        }
        return nil
    }

    /// Returns a matched view controller from a specified URL.
    ///
    /// - Parameter URL: The URL to find view controllers.
    /// - Returns: A match view controller or `nil` if not matched.
    public func viewControllerForURL(URL: URLStringConvertible) -> UIViewController? {
        if let (URLPattern, values) = URLNavigator.matchURL(URL, from: Array(self.URLMap.keys)) {
            let navigable = self.URLMap[URLPattern]
            return navigable?.init(URL: URL, values: values) as? UIViewController
        }
        return nil
    }


    // MARK: Pushing View Controllers with URL

    /// Pushes a view controller using `UINavigationController.pushViewController()`.
    ///
    /// This is an example of pushing a view controller to the top-most view contoller:
    ///
    ///     Navigator.pushURL("myapp://user/123")
    ///
    /// Use the return value to access a view controller.
    ///
    ///     let userViewController = Navigator.pushURL("myapp://user/123")
    ///     userViewController?.doSomething()
    ///
    /// - Parameter URL: The URL to find view controllers.
    /// - Parameter from: The navigation controller which is used to push a view controller. Use application's top-most
    ///     view controller if `nil` is specified. `nil` by default.
    /// - Parameter animated: Whether animates view controller transition or not. `true` by default.
    ///
    /// - Returns: The pushed view controller. Returns `nil` if there's no matching view controller or failed to push
    ///     a view controller.
    public func pushURL(URL: URLStringConvertible,
                        from: UINavigationController? = nil,
                        animated: Bool = true) -> UIViewController? {
        guard let viewController = self.viewControllerForURL(URL) else {
            return nil
        }
        guard let navigationController = from ?? UIViewController.topMostViewController()?.navigationController else {
            return nil
        }
        navigationController.pushViewController(viewController, animated: animated)
        return viewController
    }


    // MARK: Presenting View Controllers with URL

    /// Presents a view controller using `UIViewController.presentViewController()`.
    ///
    /// This is an example of presenting a view controller to the top-most view contoller:
    ///
    ///     Navigator.presentURL("myapp://user/123")
    ///
    /// Use the return value to access a view controller.
    ///
    ///     let userViewController = Navigator.presentURL("myapp://user/123")
    ///     userViewController?.doSomething()
    ///
    /// - Parameter URL: The URL to find view controllers.
    /// - Parameter wrap: Wraps the view controller with a `UINavigationController` if `true` is specified. `false` by 
    ///     default.
    /// - Parameter from: The view controller which is used to present a view controller. Use application's top-most
    ///     view controller if `nil` is specified. `nil` by default.
    /// - Parameter animated: Whether animates view controller transition or not. `true` by default.
    ///
    /// - Returns: The presented view controller. Returns `nil` if there's no matching view controller or failed to
    ///     present a view controller.
    public func presentURL(URL: URLStringConvertible,
                           wrap: Bool = false,
                           from: UIViewController? = nil,
                           animated: Bool = true) -> UIViewController? {
        guard let viewController = self.viewControllerForURL(URL) else {
            return nil
        }
        guard let fromViewController = from ?? UIViewController.topMostViewController() else {
            return nil
        }
        if wrap {
            let navigationController = UINavigationController(rootViewController: viewController)
            fromViewController.presentViewController(navigationController, animated: animated, completion: nil)
        } else {
            fromViewController.presentViewController(viewController, animated: animated, completion: nil)
        }
        return viewController
    }


    // MARK: Opening URL

    /// Executes the registered `URLOpenHandler`.
    ///
    /// - Parameter URL: The URL to find `URLOpenHandler`s.
    ///
    /// - Returns: The return value of the matching `URLOpenHandler`. Returns `false` if there's no match.
    public func openURL(URL: URLStringConvertible) -> Bool {
        if let (URLPattern, values) = URLNavigator.matchURL(URL, from: Array(self.URLOpenHandlers.keys)) {
            let handler = self.URLOpenHandlers[URLPattern]
            if handler?(URL: URL, values: values) == true {
                return true
            }
        }
        return false
    }


    // MARK: Utils

    /// Returns the URL by
    ///
    /// - Removing redundant trailing slash(/) on scheme
    /// - Removing redundant double-slashes(//)
    /// - Removing trailing slash(/)
    ///
    /// - Parameter URL: The dirty URL to be normalized.
    ///
    /// - Returns: The normalized URL. Returns `nil` if the pecified URL is invalid.
    static func normalizedURL(dirtyURL: URLStringConvertible) -> URLStringConvertible {
        let charSet = NSMutableCharacterSet()
        charSet.formUnionWithCharacterSet(.URLHostAllowedCharacterSet())
        charSet.formUnionWithCharacterSet(.URLPathAllowedCharacterSet())
        charSet.formUnionWithCharacterSet(.URLQueryAllowedCharacterSet())
        charSet.formUnionWithCharacterSet(.URLFragmentAllowedCharacterSet())
        guard let encodedURLString = dirtyURL.URLString.stringByAddingPercentEncodingWithAllowedCharacters(charSet),
              let URL = NSURL(string: encodedURLString) else {
            return dirtyURL
        }
        var URLString = URL.scheme + "://" + (URL.host ?? "") + (URL.path ?? "")
        URLString = self.replaceRegex(":/{3,}", "://", URLString)
        URLString = self.replaceRegex("(?<!:)/{2,}", "/", URLString)
        URLString = self.replaceRegex("/+$", "", URLString)
        return URLString
    }

    static func replaceRegex(pattern: String, _ repl: String, _ string: String) -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return string
        }
        let mutableString = NSMutableString(string: string)
        let range = NSMakeRange(0, string.characters.count)
        regex.replaceMatchesInString(mutableString, options: [], range: range, withTemplate: repl)
        return mutableString as String
    }

}


// MARK: - Default Navigator

public let Navigator = URLNavigator.defaultNavigator()