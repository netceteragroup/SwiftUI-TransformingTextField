//
//  TransformingTextFieldDelegate.swift
//  TransformingTextField
//
//  Created by Vikram Kriplaney on 11.08.23.
//  https://github.com/markiv
//

import SwiftUI

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

    /// To track and work around multiple calls when the user accepts an autocomplete suggestion
    var lastReplacementString = ""
    var lastReplacementDate = Date.distantPast

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
    ///
    /// It replaces the text with the transformed text **only** if it's different from the original text.
    /// - Parameters:A range of text in a document.
    ///   - range: A range to replace in the input's text.
    ///   - string: The proposed text to replace the text in range.
    /// - Returns: `true` if the text was transformed and replaced.
    func replaceCharacters(in range: NSRange, with string: String) -> Bool {
        guard var text = textInput?.text, let indexRange = Range(range, in: text), let textInput else { return false }

        let replacement = transform(range: range, replacement: string)
        if replacement == string {
            return false // not changed, return early to let the default behavior happen
        }

        // Replace the text and update the text field and binding
        text.replaceSubrange(indexRange, with: replacement)
        textInput.text = text
        self.text?.wrappedValue = text

        // Update the cursor position
        if let cursorPosition = textInput.position(
            from: textInput.beginningOfDocument, offset: range.location + replacement.count
        ), let selection = textInput.textRange(from: cursorPosition, to: cursorPosition) {
            setSelection(selection, for: text)
        }
        return true
    }
}
