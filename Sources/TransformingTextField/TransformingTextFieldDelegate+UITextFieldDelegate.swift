//
//  TransformingTextFieldDelegate+UITextFieldDelegate.swift
//  TransformingTextField
//
//  Created by Vikram Kriplaney on 11.08.23.
//  https://github.com/markiv
//

import UIKit

extension TransformingTextFieldDelegate: UITextFieldDelegate {
    func textField(
        _ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String
    ) -> Bool {
        replaceCharacters(in: range, with: string)
        // We already updated the text, binding and cursor position. Stop the default SwiftUI behavior.
        return false
    }

    /// Since we don't really know what delegates SwiftUI is handling, we're intercepting ALL known
    /// `UITextFieldDelegate` methods and passing them to the original, SwiftUI delegates.

    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        originalDelegate?.textFieldShouldBeginEditing?(textField) ?? true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        originalDelegate?.textFieldDidBeginEditing?(textField)
    }

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        originalDelegate?.textFieldShouldEndEditing?(textField) ?? true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        originalDelegate?.textFieldDidEndEditing?(textField)
    }

    func textFieldDidEndEditing(_ textField: UITextField, reason: UITextField.DidEndEditingReason) {
        originalDelegate?.textFieldDidEndEditing?(textField, reason: reason)
    }

    func textFieldShouldClear(_ textField: UITextField) -> Bool {
        originalDelegate?.textFieldShouldClear?(textField) ?? true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        originalDelegate?.textFieldShouldReturn?(textField) ?? true
    }

    func textFieldDidChangeSelection(_ textField: UITextField) {
        originalDelegate?.textFieldDidChangeSelection?(textField)
    }
}

// MARK: - UITextFieldDelegate (iOS 16)
#if compiler(>=5.7) // iOS 16 SDK
@available(iOS 16.0, *)
extension TransformingTextFieldDelegate {
    func textField(
        _ textField: UITextField, editMenuForCharactersIn range: NSRange, suggestedActions: [UIMenuElement]
    ) -> UIMenu? {
        originalDelegate?.textField?(textField, editMenuForCharactersIn: range, suggestedActions: suggestedActions)
    }

    func textField(_ textField: UITextField, willPresentEditMenuWith animator: UIEditMenuInteractionAnimating) {
        originalDelegate?.textField?(textField, willPresentEditMenuWith: animator)
    }

    func textField(_ textField: UITextField, willDismissEditMenuWith animator: UIEditMenuInteractionAnimating) {
        originalDelegate?.textField?(textField, willDismissEditMenuWith: animator)
    }
}
#endif
