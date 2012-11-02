//
//  BSManagedDocument.h
//
//  Created by Sasmito Adibowo on 29-08-12.
//  Rewritten by Mike Abdullah on 02-11-12.
//  Copyright (c) 2012 Karelia Software, Basil Salad Software. All rights reserved.
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
//  *   If multiple validation errors occur during saving, the presented error is adjusted to make debugging a little easier
//
//  *   And of course, full support for Autosave-In-Place and Versions
//


#import <Cocoa/Cocoa.h>


@interface BSManagedDocument : NSDocument
{
  @private
    NSManagedObjectContext	*_managedObjectContext;
    NSManagedObjectModel    *_managedObjectModel;
	NSPersistentStore       *_store;
    
    id  _additionalContent;
}

/* The name for the persistent store file inside the document's file wrapper.  When working with the Core Data APIs, this path component is appended to the document URL provided by the NSDocument APIs.  The default name is persistentStore
 */
+ (NSString *)persistentStoreName;

/* Persistent documents always have a managed object context and a persistent store coordinator through that context.
 */
@property (nonatomic, retain, readonly) NSManagedObjectContext *managedObjectContext;

/* Persistent documents always have a managed object model.  The default model is the union of all models in the main bundle.
 */
@property (nonatomic, retain, readonly) NSManagedObjectModel* managedObjectModel;

/* Customize the loading or creation of a persistent store to the coordinator.
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
- (id)additionalContentForURL:(NSURL *)absoluteURL ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation error:(NSError **)error;

/* An optional call out by writeToURL:ofType:forSaveOperation:originalContentsURL:error: to handle non-Core Data content in the document's package. The Core Data content is handled by the primary NSDocument -writeToURL:ofType:forSaveOperation:originalContentsURL:error: method.  It is not necessary to call super.
 * This method is called after context(s) have been saved to disk, so the document is already partially written. You should avoid returning NO as that reports an error to the user, but leaves the document in a partially updated state.
 */
- (BOOL)writeAdditionalContent:(id)content toURL:(NSURL *)absoluteURL forSaveOperation:(NSSaveOperationType)saveOperation originalContentsURL:(NSURL *)absoluteOriginalContentsURL error:(NSError **)error;

/* Called just before the context is saved, giving you a chance to adjust the store's metadata. Default implementation leaves the existing metadata untouched and returns YES. You should only override to return NO if storing the metadata went wrong in a critical way that stops the doc from being saved. Called on an arbitrary thread, so up to you to bounce over to the correct one if needed.
 */
- (BOOL)updateMetadataForPersistentStore:(NSPersistentStore *)store error:(NSError **)error;

/* BSManagedDocument supports asynchronous saving on 10.7+ (on earlier releases this method returns NO).
 */
- (BOOL)canAsynchronouslyWriteToURL:(NSURL *)url ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation;

/* No-ops
 */
-(void)setUndoManager:(NSUndoManager *)undoManager;
-(void)setHasUndoManager:(BOOL)hasUndoManager;

@end
