//
//  TransformingTextField.swift
//  TransformingTextField
//
//  Created by Vikram Kriplaney on 11.07.23.
//  https://github.com/markiv
//

import SwiftUI
import SwiftUIIntrospect

/// A closure that receives the original text, the range to replace, and the replacement string.
/// It returns a modified replacement.
public typealias TextFieldChangeTransformer = (_ text: String, _ range: NSRange, _ replacement: String) -> String

/// Applies a transformation to characters as they're typed into a `TextField`.
/// It uses view introspection to find the underlying `UITextField`, so it can also be applied to custom
/// `UIViewRepresentable`s that wrap a `UITextField`.
public struct TransformingTextFieldModifier: ViewModifier {
    /// Creates a text field input transformation modifier.
    /// - Parameters:
    ///   - text: a binding to the text view's text.
    ///   - transformer: a closure that transforms the replacement characters.
    init(text: Binding<String>, transformer: @escaping TextFieldChangeTransformer) {
        self.delegate = TransformingTextFieldDelegate(transformer: transformer)
        self.text = text
    }

    @State private var delegate: TransformingTextFieldDelegate
    private var text: Binding<String>?

    public func body(content: Content) -> some View {
        content
            .introspect(.textField(axis: .vertical), on: .iOS(.v16, .v17)) { textField in
                delegate.textInput = textField
                delegate.text = text
            }
            .introspect(.textField, on: .iOS(.v14, .v15, .v16, .v17)) { textField in
                delegate.textInput = textField
                delegate.text = text
            }
    }
}

public extension View {
    /// Applies a transformation to characters as they're typed into a `TextField`.
    ///
    /// Multiple transformations can be composed together. For example:
    ///
    ///     TextField("Text", text: $text)
    ///         .strippingDiacritics(in: $text)
    ///         .uppercased(text: $text)
    ///         .characterLimit(6, in: $text)
    ///
    /// - Parameters:
    ///   - text: a binding to the text view's text.
    ///   - transformer: a closure that transforms the replacement characters.
    /// - Returns: A modified view.
    func transformingChanges(
        in text: Binding<String>,
        with transformer: @escaping TextFieldChangeTransformer
    ) -> some View {
        modifier(TransformingTextFieldModifier(text: text, transformer: transformer))
    }

    /// Uppercases alphabetical characters as they're typed.
    func uppercased(text: Binding<String>) -> some View {
        transformingChanges(in: text) { text, range, replacement in
            replacement.uppercased()
        }
    }

    /// Limits the number of characters that can be typed into this text field.
    func characterLimit(_ length: Int, in text: Binding<String>) -> some View {
        transformingChanges(in: text) { text, range, replacement in
            (text.count - range.length + replacement.count) <= length ? replacement : ""
        }
    }

    /// Replaces characters that have diacritics with their unmarked equivalents (e.g. "ü" becomes "u").
    func strippingDiacritics(in text: Binding<String>) -> some View {
        transformingChanges(in: text) { text, range, replacement in
            replacement.applyingTransform(.stripDiacritics, reverse: false) ?? replacement
        }
    }

    /// Allows only characters in the given character set to be entered, discarding all other input.
    func allowingCharacters(in set: CharacterSet, in text: Binding<String>) -> some View {
        transformingChanges(in: text) { text, range, replacement in
            replacement.filter { CharacterSet(charactersIn: String($0)).isSubset(of: set) }
        }
    }
}

extension UITextInput {
    /// Abstracts the text
    var text: String {
        get {
            guard let range = textRange(from: beginningOfDocument, to: endOfDocument) else { return "" }
            return text(in: range) ?? ""
        }
        set {
            guard let range = textRange(from: beginningOfDocument, to: endOfDocument) else { return }
            replace(range, withText: newValue)
        }
    }

    /// Abstracts the delegate (either a UITextFieldDelegate or a UITextViewDelegate)
    var anyDelegate: AnyObject? {
        get {
            (self as? UITextField)?.delegate ?? (self as? UITextView)?.delegate
        }
        set {
            (self as? UITextField)?.delegate = newValue as? UITextFieldDelegate
            (self as? UITextView)?.delegate = newValue as? UITextViewDelegate
        }
    }
}

#if DEBUG
/// Preview and example code.
/// You can also run this by dropping `TransformingTextField_Previews.Example()` into your `ContentView` while in DEBUG
/// mode.
///
///     var body: some View {
///         TransformingTextField_Previews.Example()
///     }
public struct TransformingTextField_Previews: PreviewProvider {
    public struct Example: View {
        public init() {}

        @State private var text = Array(repeating: "", count: 7)

        public var body: some View {
            NavigationView {
                List {
                    Section {
                        TextField("Strip Diacritics and Uppercase", text: $text[0])
                            .strippingDiacritics(in: $text[0])
                            .uppercased(text: $text[0])

                        TextField("Allow Only Characters in a Set", text: $text[1])
                            .allowingCharacters(in: .letters.union(.whitespaces), in: $text[1])

                        TextField("Allow Only Four Digits", text: $text[2])
                            .characterLimit(4, in: $text[2])
                            .allowingCharacters(in: .decimalDigits, in: $text[2])

                        TextField("Custom Closure (5 Emojis Only) 😉", text: $text[3])
                            .transformingChanges(in: $text[3]) { text, range, replacement in
                                replacement.filter { character in
                                    guard let scalar = character.unicodeScalars.first else { return false }
                                    return scalar.properties.isEmoji
                                        && (scalar.value >= 0x203C || character.unicodeScalars.count > 1)
                                }
                            }
                            .characterLimit(5, in: $text[3])
                    } header: {
                        Text("SwiftUI TextField Examples")
                    }

                    if #available(iOS 16, *) {
                        Section {
                            TextField("Allow Only Ten Characters and Uppercase", text: $text[4], axis: .vertical)
                                .characterLimit(10, in: $text[4])
                                .uppercased(text: $text[4])
                        } header: {
                            Text("TextField with Vertical Axis (UITextView)")
                        }
                    }

                    Section {
                        TextEditor(text: $text[5])
                            .characterLimit(10, in: $text[5])
                            .uppercased(text: $text[5])
                    } header: {
                        Text("TextEditor (UITextView)")
                    }

                    Section {
                        CustomTextField(title: "Allow Only Six Letters and Uppercase", text: $text[6])
                            .uppercased(text: $text[6])
                            .transformingChanges(in: $text[6]) { text, range, replacement in
                                replacement.filter(\.isLetter)
                            }
                            .characterLimit(6, in: $text[6])
                    } header: {
                        Text("UITextField UIViewRepresentable Example")
                    }
                }
                .navigationTitle("Examples")
            }
        }
    }

    /// An example `UITextField` wrapper.
    struct CustomTextField: UIViewRepresentable {
        let title: String
        @Binding var text: String

        func makeUIView(context: Context) -> UITextField {
            let textField = UITextField(frame: .zero)
            textField.placeholder = title
            textField.text = text
            return textField
        }

        func updateUIView(_ textField: UITextField, context: Context) {
            textField.text = text
        }
    }

    public static var previews: some View {
        Example()
    }
}
#endif
