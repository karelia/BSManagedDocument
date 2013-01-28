# BSManagedDocument

  A document class that mimics UIManagedDocument to support Core Data in all its modern glory:

  *   Saves to a file package

  *   On 10.7+, asynchronous saving is supported. We set up a parent/child pair of contexts; the parent saves on its own thread

  *   Full support for concurrent document opening too

  *   Subclasses can hook in to manage additional content inside the package

  *   A hook is also provided at the best time to set metadata for the store

  *   New docs have the bundle bit set on them. It means that if the doc gets transferred to a Mac without your app installed, with the bundle bit still intact, it will still appear in the Finder as a file package rather than a folder

  *   If the document moves on disk, Core Data is kept informed of the new location

  *   If multiple validation errors occur during saving, the presented error is adjusted to make debugging a little easier

  *   And of course, full support for Autosave-In-Place and Versions

## Branch structure for submodules

There are two branches to this repository, *ksmanageddocument* and *tests*, these
make it easier to use the same repository for developing as well as for sharing
the code as a Git submodule.

### The ksmanageddocument branch

The ksmanageddocument branch just contains the class files and this README file. It is
the one to use if you want to add it as a submodule to your project. This should
be treated as a readonly branch. *do not perform any development on this
branch*.

### The tests branch

The tests branch contains the class files as well as Xcode projects for
development and demonstration. This is the branch where development should be
performed, the changes push back to the master branch cleanly through the magic
of careful merging and cherry-picking.

There are Unit Tests for the class in each of the ARC and MRC projects. These
are not shared files, so be sure to write tests in both projects while developing.

### Artefacts

Sometimes, there may be artefacts left over when switching from ksmanageddocument to
tests. These are files that are ignored by Git and are easily cleaned up
by running

    git clean -dxf

## License (BSD)

Standard BSD licence.

Please see the header file for the full text.
