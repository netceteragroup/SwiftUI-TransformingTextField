//
//  TransformingTextFieldDelegate+UITextViewDelegate.swift
//  TransformingTextField
//
//  Created by Vikram Kriplaney on 11.08.23.
//  https://github.com/markiv
//

import UIKit

extension TransformingTextFieldDelegate: UITextViewDelegate {
    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        replaceCharacters(in: range, with: text)
        // We already updated the text, binding and cursor position. Stop the default SwiftUI behavior.
        return false
    }

    /// Since we don't really know what delegates SwiftUI is handling, we're intercepting ALL known
    /// `UITextViewDelegate` methods and passing them to the original, SwiftUI delegates.

    func textViewDidChange(_ textView: UITextView) {
        originalDelegate?.textViewDidChange?(textView)
    }

    func textViewDidChangeSelection(_ textView: UITextView) {
        originalDelegate?.textViewDidChangeSelection?(textView)
    }

    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        originalDelegate?.textViewShouldBeginEditing?(textView) ?? true
    }

    func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
        originalDelegate?.textViewShouldEndEditing?(textView) ?? true
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        originalDelegate?.textViewDidBeginEditing?(textView)
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        originalDelegate?.textViewDidEndEditing?(textView)
    }
}

// MARK: - UITextViewDelegate (iOS 16)
#if compiler(>=5.7) // iOS 16 SDK
@available(iOS 16, *)
extension TransformingTextFieldDelegate {
    func textView(_ textView: UITextView, willDismissEditMenuWith animator: UIEditMenuInteractionAnimating) {
        originalDelegate?.textView?(textView, willDismissEditMenuWith: animator)
    }

    func textView(_ textView: UITextView, willPresentEditMenuWith animator: UIEditMenuInteractionAnimating) {
        originalDelegate?.textView?(textView, willPresentEditMenuWith: animator)
    }

    func textView(
        _ textView: UITextView, editMenuForTextIn range: NSRange, suggestedActions: [UIMenuElement]
    ) -> UIMenu? {
        originalDelegate?.textView?(textView, editMenuForTextIn: range, suggestedActions: suggestedActions)
    }
}
#endif

// MARK: - UITextViewDelegate (iOS 17)
#if compiler(>=5.9) // iOS 17 SDK
@available(iOS 17, *)
extension TransformingTextFieldDelegate {
    func textView(_ textView: UITextView, primaryActionFor textItem: UITextItem, defaultAction: UIAction) -> UIAction? {
        originalDelegate?.textView?(textView, primaryActionFor: textItem, defaultAction: defaultAction)
    }

    func textView(
        _ textView: UITextView, menuConfigurationFor textItem: UITextItem, defaultMenu: UIMenu
    ) -> UITextItem.MenuConfiguration? {
        originalDelegate?.textView?(textView, menuConfigurationFor: textItem, defaultMenu: defaultMenu)
    }

    func textView(
        _ textView: UITextView, textItemMenuWillEndFor textItem: UITextItem, animator: UIContextMenuInteractionAnimating
    ) {
        originalDelegate?.textView?(textView, textItemMenuWillEndFor: textItem, animator: animator)
    }

    func textView(
        _ textView: UITextView, textItemMenuWillDisplayFor textItem: UITextItem,
        animator: UIContextMenuInteractionAnimating
    ) {
        originalDelegate?.textView?(textView, textItemMenuWillDisplayFor: textItem, animator: animator)
    }
}
#endif
