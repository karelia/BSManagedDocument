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
//  NOTE: There is currently a MAJOR flaw in Core Data's handling of EXTERNALLY STORE DATA ATTRIBUTES if you're planning to use them in your document's model
//  The subsystem that deals with externally stored attributes is unable to deal with the persistent store being moved/renamed. It will attempt to work with external data at the OLD store location, instead of the new, and throw an exception when it fails to do that
//  The described scenario happens whenever a user moves or renames the document (this is supposed to be support behaviour on OS X). But just as importantly, when a new document gets explicitly saved by the user for the first time, it transitions from being stored in a temporary folder, to the real location, also triggering the bug
//  Only happens when there is data added to the document large enough for Core Data to try and store it externally, so make sure you take that into account if trying to repro!
//  Reported as rdar://problem/13023874
//  Filing a duplicate of the report, highly appreciated. It might be worth filing a DTS incident if this affects your app to see if they can offer a workaround
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
}

/*  The name of folder directly inside the document which the persistent store will be saved to.
 *  The default name is @"StoreContent" to match UIManagedDocument
 *  You can override to customize, including returning nil which means the persistent store will be saved directly inside the document package with no intermediate folder
 */
+ (NSString *)storeContentName;

/* The name for the persistent store file.
 * The default name is @"persistentStore" to match UIManagedDocument
 */
+ (NSString *)persistentStoreName;

/* Persistent documents always have a managed object context and a persistent store coordinator through that context.
 * A default context is created on-demand. You can override to use your own instead
 * -setManagedObjectContext: automatically sets a persistence stack for the context and uses its undo manager
 */
@property (nonatomic, strong) NSManagedObjectContext *managedObjectContext;

/* Persistent documents always have a managed object model.  The default model is the union of all models in the main bundle.
 */
@property (nonatomic, strong, readonly) NSManagedObjectModel* managedObjectModel;

/* Subclasses can override to customize the loading or creation of a persistent store to the coordinator.
 */
- (BOOL)configurePersistentStoreCoordinatorForURL:(NSURL *)storeURL ofType:(NSString *)fileType modelConfiguration:(NSString *)configuration storeOptions:(NSDictionary *)storeOptions error:(NSError **)error;

/* Returns the Core Data store type string for the given document fileType. The default returns NSSQLiteStoreType. See NSPersistentStoreCoordinator.h for store type information.
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

/* An optional call out on the main thread to handle non-Core Data content in the document's file wrapper. The returned object will be passed to -writeAdditionalContent:… It is not necessary to call super.
 *  Called before any contexts are saved, so may be a good point to do some last-minute adjustments to your Core Data objects
 */
- (id)additionalContentForURL:(NSURL *)absoluteURL saveOperation:(NSSaveOperationType)saveOperation error:(NSError **)error;

/* An optional call out by writeToURL:ofType:forSaveOperation:originalContentsURL:error: to handle non-Core Data content in the document's package. The Core Data content is handled by the primary NSDocument -writeToURL:ofType:forSaveOperation:originalContentsURL:error: method.  It is not necessary to call super.
 * This method is called after context(s) have been saved to disk, so the document is already partially written. You should avoid returning NO as that reports an error to the user, but leaves the document in a partially updated state.
 * You should NEVER attempt to access the main context's objects or other document state from this methods, as user interaction may have been unblocked, causing the state to be out of sync with that being written. Instead, override -additionalContentForURL:… to capture such information
 */
- (BOOL)writeAdditionalContent:(id)content toURL:(NSURL *)absoluteURL originalContentsURL:(NSURL *)absoluteOriginalContentsURL error:(NSError **)error;

/* Called just before the context is saved, giving you a chance to adjust the store's metadata. Default implementation leaves the existing metadata untouched and returns YES. You should only override to return NO if storing the metadata went wrong in a critical way that stops the doc from being saved. Called on an arbitrary thread, so up to you to bounce over to the correct one if needed.
 */
- (BOOL)updateMetadataForPersistentStore:(NSPersistentStore *)store error:(NSError **)error;

/* Called on 10.8+ when the OS decides it wants to store a version of the existing doc *before* writing out the updated version. Default implementation simply makes a copy of the doc. You might override to speed it up by hard linking some files instead. In the event of a failure, BSManagedDocument will attempt to take care of cleanup for you.
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
