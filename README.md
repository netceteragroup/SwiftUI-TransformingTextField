
# SwiftUI-TransformingTextField

I love SwiftUI! ❤️

While it simplifies the way we build apps, it (currently) has some limitations and even some strange quirks. For example, manipulating a `TextField`'s text during editing causes the cursor to jump uncontrollably, and you really don't want to expose your users to that kind of madness. 🤪

Enter...

## TransformingTextFieldModifier

`TransformingTextFieldModifier` applies a transformation to characters as they're typed into a `TextField`.
It uses view introspection (thanks to [SwiftUI-Introspect](https://github.com/siteline/SwiftUI-Introspect)) to find the underlying `UITextField` (so it can even be applied to custom `UIViewRepresentable`s that wrap a `UITextField`). 🎁

It can be used via convenient `View` extensions, which **can be combined**:

```swift
TextField(...)
    .transformingChanges(in: $text) { text, range, replacement in
        replacement.filter(\.isLetter)
    }
    .uppercased(text: $text)
    .characterLimit(6, in: $text)

```


## TransformingTextFieldDelegate

`TransformingTextFieldDelegate` is a `UITextFieldDelegate` that takes over the task of updating the text field's text, applying the given transformation to any text changes, and preserving the cursor's logical position.

More importantly, this works around SwiftUI's current undesirable behavior of throwing the cursor to the end of the field whenever the text buffer is modified programmatically.

# Installation

Add https://github.com/netceteragroup/SwiftUI-TransformingTextField.git to your Swift package dependencies and `import TransformingTextField`.

For a quick demo, try the SwiftUI preview in `TransformingTextField.swift`. You can also run it by dropping `TransformingTextField_Previews.Example()` into your `ContentView` while in DEBUG mode.

```swift
var body: some View {
    TransformingTextField_Previews.Example()
}
```

> SwiftUI-TransformingTextField was created by [Vikram Kriplaney](https://github.com/markiv) in July 2023.
