# BSManagedDocument

  A document class that mimics `UIManagedDocument` to support Core Data in all its modern glory:

  *   Saves to a file package

  *   On 10.7+, asynchronous saving is supported. We set up a parent/child pair of contexts; the parent saves on its own thread

  *   Full support for concurrent document opening too

  *   Subclasses can hook in to manage additional content inside the package

  *   A hook is also provided at the best time to set metadata for the store

  *   New docs have the bundle bit set on them. It means that if the doc gets transferred to a Mac without your app installed, with the bundle bit still intact, it will still appear in the Finder as a file package rather than a folder

  *   If the document moves on disk, Core Data is kept informed of the new location

  *   If multiple validation errors occur during saving, the presented error is adjusted to make debugging a little easier

  *   And of course, full support for Autosave-In-Place and Versions

## License (BSD)

Standard BSD licence.

Please see the header file for the full text.

## Documentation

Documentation is automatically generated from `BSManagedDocument.h` and published at http://cocoadocs.org/docsets/BSManagedDocument/

## Usage

Add `BSManagedDocument` `.m` and `.h` to your Xcode project and carry on your merry way. Or if it's more your style of thing, we're on CocoaPods too. 
