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

/// Takes over the updating the text field's text, applying the given transformation to any text changes, and
/// preserving the cursor's logical position. This works around SwiftUI's current undesirable behavior of throwing
/// the cursor to the end of the field whenever the text buffer is modified programmatically.
class TransformingTextFieldDelegate: NSObject {
    init(transformer: @escaping TextFieldChangeTransformer) {
        self.transformer = transformer
    }

    let transformer: TextFieldChangeTransformer
    var text: Binding<String>?
    var originalDelegate: AnyObject? // UITextFieldDelegate or UITextViewDelegate
    var textInput: UITextInput? {
        didSet {
            if !isDelegating {
                originalDelegate = textInput?.anyDelegate
                textInput?.anyDelegate = self
            }
        }
    }

    /// Sets the cursor position. Prior to iOS 16.x, SwiftUI moves the cursor to the end after a delay.
    /// Here we check recursively and reset it if necessary.
    func setSelection(_ selection: UITextRange, for text: String, tries: Int = 20) {
        guard tries > 0, textInput?.selectedTextRange != selection, textInput?.text == text else { return }

        textInput?.selectedTextRange = selection
        // Check again after a short interval
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.setSelection(selection, for: text, tries: tries - 1)
        }
    }

    /// Checks if this delegate is already in the chain, to avoid circular references.
    var isDelegating: Bool {
        var delegate = textInput?.anyDelegate
        while delegate != nil {
            if delegate === self {
                return true
            }
            delegate = (delegate as? Self)?.originalDelegate
        }
        return false
    }

    /// Applies all transformations, including any chained modifiers.
    func transform(range: NSRange, replacement: String) -> String {
        guard let text = textInput?.text else { return replacement }

        var replacement = replacement
        // Allow chaining of transformation modifiers, invoking any other previously applied modifiers
        var delegate: TransformingTextFieldDelegate? = self
        while delegate != nil {
            // Apply the transformation
            replacement = delegate?.transformer(text, range, replacement) ?? replacement
            delegate = delegate?.originalDelegate as? TransformingTextFieldDelegate
        }
        return replacement
    }

    /// Takes over the updating of the text field's text, applying the given transformation to any text changes, and
    /// preserving the cursor's logical position. This works around SwiftUI's current undesirable behavior of throwing
    /// the cursor to the end of the field whenever the text buffer is modified programmatically.
    func replaceCharacters(in range: NSRange, with string: String) {
        guard let textInput else { return }
        var text = textInput.text

        let replacement = transform(range: range, replacement: string)
        // Replace the text and update the text field and binding
        let indexRange = String.Index(utf16Offset: range.lowerBound, in: text)
            ..< String.Index(utf16Offset: range.upperBound, in: text)
        text.replaceSubrange(indexRange, with: replacement)
        textInput.text = text
        self.text?.wrappedValue = text

        // Update the cursor position
        if let cursorPosition = textInput.position(
            from: textInput.beginningOfDocument, offset: range.location + replacement.count
        ), let selection = textInput.textRange(from: cursorPosition, to: cursorPosition) {
            setSelection(selection, for: text)
        }
    }
}

extension TransformingTextFieldDelegate: UITextFieldDelegate {
    func textField(
        _ textField: UITextField,
        shouldChangeCharactersIn range: NSRange,
        replacementString string: String
    ) -> Bool {
        replaceCharacters(in: range, with: string)
        // We already updated the text, binding and cursor position. Stop the default SwiftUI behavior.
        return false
    }
}

extension TransformingTextFieldDelegate: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        replaceCharacters(in: range, with: text)
        // We already updated the text, binding and cursor position. Stop the default SwiftUI behavior.
        return false
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

        @State private var text = ""

        public var body: some View {
            NavigationView {
                List {
                    Section {
                        Text(text).foregroundColor(.secondary)
                    } header: {
                        Text("Binding Value")
                    }

                    Section {
                        TextField("Strip Diacritics and Uppercase", text: $text)
                            .strippingDiacritics(in: $text)
                            .uppercased(text: $text)

                        TextField("Allow Only Characters in a Set", text: $text)
                            .allowingCharacters(in: .letters.union(.whitespaces), in: $text)

                        TextField("Allow Only Four Digits", text: $text)
                            .characterLimit(4, in: $text)
                            .allowingCharacters(in: .decimalDigits, in: $text)

                        TextField("Custom Closure (5 Emojis Only) 😉", text: $text)
                            .transformingChanges(in: $text) { text, range, replacement in
                                replacement.filter { character in
                                    guard let scalar = character.unicodeScalars.first else { return false }
                                    return scalar.properties.isEmoji
                                        && (scalar.value >= 0x203C || character.unicodeScalars.count > 1)
                                }
                            }
                            .characterLimit(5, in: $text)
                    } header: {
                        Text("SwiftUI TextField Examples")
                    }

                    if #available(iOS 16, *) {
                        Section {
                            TextField("Allow Only Ten Characters and Uppercase", text: $text, axis: .vertical)
                                .characterLimit(10, in: $text)
                                .uppercased(text: $text)
                        } header: {
                            Text("TextField with Vertical Axis (UITextView)")
                        }
                    }

                    Section {
                        TextEditor(text: $text)
                            .characterLimit(10, in: $text)
                            .uppercased(text: $text)
                    } header: {
                        Text("TextEditor (UITextView)")
                    }

                    Section {
                        CustomTextField(title: "Allow Only Six Letters and Uppercase", text: $text)
                            .uppercased(text: $text)
                            .transformingChanges(in: $text) { text, range, replacement in
                                replacement.filter(\.isLetter)
                            }
                            .characterLimit(6, in: $text)
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
