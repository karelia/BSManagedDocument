//
//  BSManagedDocument.h
//
//  Created by Sasmito Adibowo on 29-08-12.
//  Rewritten by Mike Abdullah on 02-11-12.
//  Copyright (c) 2012-2013 Karelia Software, Basil Salad Software. All rights reserved.
//  http://basilsalad.com
//
//  Licensed under the BSD License <http://www.opensource.org/licenses/bsd-license>
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY
//  EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
//  OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT
//  SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT,
//  INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED
//  TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR
//  BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
//  STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF
//  THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
//
//  A document class that mimics UIManagedDocument to support Core Data in all its modern glory:
//
//  *   Saves to a file package
//
//  *   On 10.7+, asynchronous saving is supported. We set up a parent/child pair of contexts; the parent saves on its own thread
//
//  *   Full support for concurrent document opening too
//
//  *   Subclasses can hook in to manage additional content inside the package
//
//  *   A hook is also provided at the best time to set metadata for the store
//
//  *   New docs have the bundle bit set on them. It means that if the doc gets transferred to a Mac without your app installed, with the bundle bit still intact, it will still appear in the Finder as a file package rather than a folder
//
//  *   If the document moves on disk, Core Data is kept informed of the new location
//
//  *   If multiple validation errors occur during saving, the presented error is adjusted to make debugging a little easier
//
//  *   And of course, full support for Autosave-In-Place and Versions
//
//  NOTE: Prior to OS X 10.9, there was a major flaw in Core Data's handling of Externally Stored
//  Data Attributes. The subsystem that handles with them was unable to deal with the persistent
//  store being moved/renamed. It would attempt to work with external data at the OLD store location,
//  instead of the new, and throw an exception when that failed. The described scenario happens
//  whenever a user moves or renames the document (this is supposed to be supported behaviour on OS X).
//  But just as importantly, when a new document gets explicitly saved by the user for the first
//  time, it transitions from being stored in a temporary folder, to the real location, also
//  triggering the bug. Only happens when there is data added to the document large enough for Core
//  Data to try and store it externally, so make sure you take that into account if trying to repro!
//  Reported as rdar://problem/13023874
//


#import <Cocoa/Cocoa.h>


@interface BSManagedDocument : NSDocument
{
  @private  // still targeting legacy runtime, so YES, I need to declare the ivars
    NSManagedObjectContext	*_managedObjectContext;
    NSManagedObjectModel    *_managedObjectModel;
	NSPersistentStore       *_store;
    
    id  _contents;
    
    NSURL   *_autosavedContentsTempDirectoryURL;
    
    BOOL    _closing;
}

/**
 @return The name of the folder directly inside the document which the persistent store will be saved to.
 
 The default name is `StoreContent` to match `UIManagedDocument`. You can
 override to customize, including returning `nil` which means the persistent
 store will be saved directly inside the document package with no intermediate
 folder.
 */
+ (NSString *)storeContentName;

/**
 @return The name for the persistent store file inside the document’s file package.
 
 The default name is `persistentStore` to match `UIManagedDocument`. The store
 is nested inside the document within the `+storeContentName` folder.
 */
+ (NSString *)persistentStoreName;

/**
 The receiver's managed object context
 
 Persistent documents always have a managed object context and a persistent
 store coordinator through that context.
 
 A default context is created on-demand. You can call `-setManagedObjectContext:`
 to substitute your own context instead. This will automatically supply a
 persistence stack for the context and uses its undo manager.
 */
@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;

/**
 The document's managed object model. (read-only)
 
 Persistent documents always have a managed object model. The default model is
 the union of all models in the main bundle. You can specify a configuration to
 use with modelConfiguration. You can subclass `BSManagedDocument` to override
 this method if you need custom behavior.
 */
@property (nonatomic, strong, readonly) NSManagedObjectModel* managedObjectModel;

/**
 Creates or loads the document’s persistent store. Called whenever a document is opened *and* when a
 new document is first saved.
 
 @param storeURL The URL for the persistent store.
 @param fileType The document’s file type.
 @param configuration The managed object model configuration to use.
 @param storeOptions The options used to configure the persistent store coordinator.
 @param error Upon return, if a problem occurs, contains an error object that describes the problem.
 @return `YES` if configuration is successful, otherwise `NO`.
 
 You can override this method if you want customize the creation or loading of
 the document’s persistent store. For example, you can perform post-migration
 clean-up—if your application needs to migrate store data to use a new version
 of the managed object model, you can override this method to make additional
 modifications to the store after migration.
 */
- (BOOL)configurePersistentStoreCoordinatorForURL:(NSURL *)storeURL ofType:(NSString *)fileType modelConfiguration:(NSString *)configuration storeOptions:(NSDictionary *)storeOptions error:(NSError **)error;

/**
 Returns the Core Data store type for a given document file type.
 
 @param fileType The document file type.
 @return The persistent store type for fileType.
 
 Override this method to specify a persistent store type for a given document
 type. The default returns `NSSQLiteStoreType`. See
 `NSPersistentStoreCoordinator.h` for store type information.
 */
- (NSString *)persistentStoreTypeForFileType:(NSString *)fileType;

/* Overridden to save the document's managed objects referenced by the managed object context, and additional content too.
 */
- (BOOL)writeToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation originalContentsURL:(NSURL *)absoluteOriginalContentsURL error:(NSError **)error; 

/* Overridden to load the document's managed objects through the managed object context.
 */
- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)error;

/* Overridden to clean up the managedObjectContext and window controllers during a revert.
 */
- (BOOL)revertToContentsOfURL:(NSURL *)inAbsoluteURL ofType:(NSString *)inTypeName error:(NSError **)outError;

/**
 Handles reading non-Core Data content in the additional content directory in the document’s file package.
 
 @param absoluteURL The URL for the additional content directory in the document’s file package.
 @param error Upon return, if a problem occurs, contains an error object that describes the problem.
 @return `YES` if the read operation is successful, otherwise `NO`.
 
 You override this method to read non-Core Data content from the additional
 content directory in the document’s file package.
 
 If you implement this method, it is invoked automatically by
 `readFromURL:ofType:error:`.
 
 There is no need to invoke `super`’s implementation.
 */
- (BOOL)readAdditionalContentFromURL:(NSURL *)absoluteURL error:(NSError **)error;

/**
 Handles writing non-Core Data content to the additional content directory in the document’s file package.
 
 @param absoluteURL The URL for the additional content directory in the document’s file package.
 @param saveOperation The type of save operation being performed.
 @param error Upon return, if a problem occurs, contains an error object that describes the problem.
 @return An object that contains the additional content for the document at `absoluteURL`, or `nil` if there is a problem.
 
 You override this method to perform to manage non-Core Data content to be
 stored in the additional content directory in the document’s file package.
 
 If you implement this method, it is invoked automatically by `BSManagedDocument`
 while saving. The returned object is passed to
 `-writeAdditionalContent:toURL:originalContentsURL:error:`.
 
 Called before any contexts are saved, so this may be a good point to do some
 last-minute adjustments to your Core Data objects.
 
 There is no need to invoke `super`’s implementation.
 
 ### Special Considerations
 
 A return value of `nil` indicates an error condition. To avoid generating an
 exception, you must return a value from this method. If it is not always the
 case that there will be additional content, you should return a sentinel value
 (for example, an `NSNull` instance) that you check for in
 `-writeAdditionalContent:toURL:originalContentsURL:error:`.
 
 The object returned from this method is passed to
 `-writeAdditionalContent:toURL:originalContentsURL:error:`. Because
 `-writeAdditionalContent:toURL:originalContentsURL:error:` is likely executed
 on a different thread, you must ensure that the object you return is
 thread-safe. For example, you might return an `NSData` object containing an
 archive of the state you want to capture.
 */
- (id)additionalContentForURL:(NSURL *)absoluteURL saveOperation:(NSSaveOperationType)saveOperation error:(NSError **)error;

/**
 Handles writing non-Core Data content to the document’s file package.
 
 @param content An object that represents the additional content for the document. This is the object returned from `-additionalContentForURL:error:`.
 @param absoluteURL The URL to which to write the additional content.
 @param absoluteOriginalContentsURL The current URL of the document that is being saved.
 @param error Upon return, if a problem occurs, contains an error object that describes the problem.
 @return `YES` if the write operation is successful, otherwise `NO`.
 
 You override this method to perform to write non-Core Data content in the additional content directory in the document’s file package. There are several issues to consider:
 
 * You should typically implement this method only if you have also implemented
 `-additionalContentForURL:error:`.
 * Because this method is executed asynchronously, it is possible that the
 document’s state may be different from that at which the save operation was
 initiated. If you need to capture the document state at save time, you should
 do so in `-additionalContentForURL:error:`.
 * If you implement this method, it is invoked automatically by
 `-writeContents:andAttributes:safelyToURL:forSaveOperation:error:`.
 * There is no need to invoke `super`’s implementation.
 
 ### Special Considerations
 
 This method is called after context(s) have been saved to disk, so the document
 is already partially written. You should avoid returning `NO` if possible, as
 that reports an error to the user, but leaves the document in a partially
 updated state.
 */
- (BOOL)writeAdditionalContent:(id)content toURL:(NSURL *)absoluteURL originalContentsURL:(NSURL *)absoluteOriginalContentsURL error:(NSError **)error;

/**
 Handles updating the persistent store's metadata.
 
 @param store The persistent store being saved.
 @param error Upon return, if a problem occurs, contains an error object that describes the problem.
 @return `YES` if the update is successful, otherwise `NO`.
 
 Called just before the context is saved, giving you a chance to adjust the
 store's metadata. The default implementation leaves the existing metadata
 untouched and returns `YES`. You should only override to return `NO` if storing
 the metadata went wrong in a critical way that stops the doc from being saved.
 Called on an arbitrary thread, so up to you to bounce over to the correct one
 if needed.
 */
- (BOOL)updateMetadataForPersistentStore:(NSPersistentStore *)store error:(NSError **)error;

/**
 Handles writing a backup copy of the document.
 
 @param backupURL The URL to which to write the backup.
 @param outError Upon return, if a problem occurs, contains an error object that describes the problem.
 @return `YES` if the write operation is successful, otherwise `NO`.
 
 Called on 10.8+ when the OS decides it wants to store a version of the existing
 doc *before* writing out the updated version. The default implementation simply
 makes a copy of the document. You might override to speed it up by hard linking
 some files instead.
 
 In the event of a failure, `BSManagedDocument` will attempt
 to take care of cleanup for you.
 */
- (BOOL)writeBackupToURL:(NSURL *)backupURL error:(NSError **)outError;

/* BSManagedDocument supports asynchronous saving on 10.7+ (on earlier releases this method returns NO).
 */
- (BOOL)canAsynchronouslyWriteToURL:(NSURL *)url ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation;

/* No-ops
 */
-(void)setUndoManager:(NSUndoManager *)undoManager;
-(void)setHasUndoManager:(BOOL)hasUndoManager;

@end
