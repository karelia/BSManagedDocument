//
//  BSManagedDocument.m
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

#import "BSManagedDocument.h"


@interface BSManagedDocument ()
@property(nonatomic, copy) NSURL *autosavedContentsTempDirectoryURL;
@end


@implementation BSManagedDocument

#pragma mark UIManagedDocument-inspired methods

+ (NSString *)storeContentName; { return @"StoreContent"; }
+ (NSString *)persistentStoreName; { return @"persistentStore"; }

+ (NSURL *)persistentStoreURLForDocumentURL:(NSURL *)fileURL;
{
    NSString *storeContent = [self storeContentName];
    if (storeContent) fileURL = [fileURL URLByAppendingPathComponent:storeContent];
    
    fileURL = [fileURL URLByAppendingPathComponent:[self persistentStoreName]];
    return fileURL;
}

- (NSManagedObjectContext *)managedObjectContext;
{
    if (!_managedObjectContext)
    {
        // Need 10.7+ to support concurrency types
        __block NSManagedObjectContext *context;
        if ([NSManagedObjectContext instancesRespondToSelector:@selector(initWithConcurrencyType:)])
        {
            context = [[self.class.managedObjectContextClass alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        }
        else
        {
            // On 10.6, context MUST be created on the thread/queue that's going to use it
            if ([NSThread isMainThread])
            {
                context = [[self.class.managedObjectContextClass alloc] init];
            }
            else
            {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    context = [[self.class.managedObjectContextClass alloc] init];
                });
            }
        }
        
        [self setManagedObjectContext:context];
#if ! __has_feature(objc_arc)
        [context release];
#endif
    }
    
    return _managedObjectContext;
}

- (void)setManagedObjectContext:(NSManagedObjectContext *)context;
{
    // Setup the rest of the stack for the context

    NSPersistentStoreCoordinator *coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:[self managedObjectModel]];
    
    // Need 10.7+ to support parent context
    if ([context respondsToSelector:@selector(setParentContext:)])
    {
        NSManagedObjectContext *parentContext = [[self.class.managedObjectContextClass alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        
        [parentContext performBlockAndWait:^{
            [parentContext setUndoManager:nil]; // no point in it supporting undo
            [parentContext setPersistentStoreCoordinator:coordinator];
        }];
        
        [context setParentContext:parentContext];

#if !__has_feature(objc_arc)
        [parentContext release];
#endif
    }
    else
    {
        [context setPersistentStoreCoordinator:coordinator];
    }

#if __has_feature(objc_arc)
    _managedObjectContext = context;
#else
    [context retain];
    [_managedObjectContext release]; _managedObjectContext = context;
#endif
    

#if !__has_feature(objc_arc)
    [coordinator release];  // context hangs onto it for us
#endif
    
    [super setUndoManager:[context undoManager]]; // has to be super as we implement -setUndoManager: to be a no-op
}

// Having this method is a bit of a hack for Sandvox's benefit. I intend to remove it in favour of something neater
+ (Class)managedObjectContextClass; { return [NSManagedObjectContext class]; }

- (NSManagedObjectModel *)managedObjectModel;
{
    if (!_managedObjectModel)
    {
        _managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:[NSArray arrayWithObject:[NSBundle mainBundle]]];

#if ! __has_feature(objc_arc)
        [_managedObjectModel retain];
#endif
    }

    return _managedObjectModel;
}

/*  Called whenever a document is opened *and* when a new document is first saved.
 */
- (BOOL)configurePersistentStoreCoordinatorForURL:(NSURL *)storeURL
                                           ofType:(NSString *)fileType
                               modelConfiguration:(NSString *)configuration
                                     storeOptions:(NSDictionary *)storeOptions
                                            error:(NSError **)error
{
	// On 10.8+, the coordinator whinges but doesn't fail if you leave out this key and the file turns out to be read-only. Supplying a value makes it fail with a (not very helpful) error when the store is read-only
    if (![storeOptions objectForKey:NSReadOnlyPersistentStoreOption])
    {
        NSMutableDictionary *mutableOptions = [NSMutableDictionary dictionaryWithDictionary:storeOptions];
        [mutableOptions setObject:@NO forKey:NSReadOnlyPersistentStoreOption];
        storeOptions = mutableOptions;
    }
    
	NSPersistentStoreCoordinator *storeCoordinator = [[self managedObjectContext] persistentStoreCoordinator];
	
    _store = [storeCoordinator addPersistentStoreWithType:[self persistentStoreTypeForFileType:fileType]
                                            configuration:configuration
                                                      URL:storeURL
                                                  options:storeOptions
                                                    error:error];
#if ! __has_feature(objc_arc)
    [_store retain];
#endif
    
	return (_store != nil);
}

- (NSString *)persistentStoreTypeForFileType:(NSString *)fileType { return NSSQLiteStoreType; }

- (id)additionalContentForURL:(NSURL *)absoluteURL saveOperation:(NSSaveOperationType)saveOperation error:(NSError **)error;
{
	// Need to hand back something so as not to indicate there was an error
    return [NSNull null];
}

- (BOOL)writeAdditionalContent:(id)content toURL:(NSURL *)absoluteURL originalContentsURL:(NSURL *)absoluteOriginalContentsURL error:(NSError **)error;
{
    return YES;
}

#pragma mark Core Data-Specific

- (BOOL)updateMetadataForPersistentStore:(NSPersistentStore *)store error:(NSError **)error;
{
    return YES;
}

#pragma mark Lifecycle

- (void)close;
{
    [super close];
    [self deleteAutosavedContentsTempDirectory];
}

// It's simpler to wrap the whole method in a conditional test rather than using a macro for each line.
#if ! __has_feature(objc_arc)
- (void)dealloc;
{
    [_managedObjectContext release];
    [_managedObjectModel release];
    [_store release];
    
    // _additionalContent is unretained so shouldn't be released here
    
    [super dealloc];
}
#endif

#pragma mark Reading Document Data

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
    // Preflight the URL
    //  A) If the file happens not to exist for some reason, Core Data unhelpfully gives "invalid file name" as the error. NSURL gives better descriptions
    //  B) When reverting a document, the persistent store will already have been removed by the time we try adding the new one (see below). If adding the new store fails that most likely leaves us stranded with no store, so it's preferable to catch errors before removing the store if possible
    if (![absoluteURL checkResourceIsReachableAndReturnError:outError]) return NO;
    
    
    // If have already read, then this is a revert-type affair, so must reload data from disk
    if (_store)
    {
        if (!([NSThread isMainThread])) {
            [NSException raise:NSInternalInconsistencyException format:@"%@: I didn't anticipate reverting on a background thread!", NSStringFromSelector(_cmd)];
        }
        
        // NSPersistentDocument states: "Revert resets the document’s managed object context. Objects are subsequently loaded from the persistent store on demand, as with opening a new document."
        // I've found for atomic stores that -reset only rolls back to the last loaded or saved version of the store; NOT what's actually on disk
        // To force it to re-read from disk, the only solution I've found is removing and re-adding the persistent store
        NSManagedObjectContext *context = self.managedObjectContext;
        if ([context respondsToSelector:@selector(parentContext)])
        {
            // In my testing, HAVE to do the removal using parent's private queue. Otherwise, it deadlocks, trying to acquire a _PFLock
            NSManagedObjectContext *parent = context.parentContext;
            while (parent)
            {
                context = parent;   parent = context.parentContext;
            }
            
            __block BOOL result;
            [context performBlockAndWait:^{
                result = [context.persistentStoreCoordinator removePersistentStore:_store error:outError];
            }];
        }
        else
        {
            if (![context.persistentStoreCoordinator removePersistentStore:_store error:outError])
            {
                return NO;
            }
        }

#if !__has_feature(objc_arc)
        [_store release];
#endif

        _store = nil;
    }
    
    
    // Setup the store
    // If the store happens not to exist, because the document is corrupt or in the wrong format, -configurePersistentStoreCoordinatorForURL:… will create a placeholder file which is likely undesirable! The only way to avoid that that I can see is to preflight the URL. Possible race condition, but not in any truly harmful way
    NSURL *storeURL = [[self class] persistentStoreURLForDocumentURL:absoluteURL];
    if (![storeURL checkResourceIsReachableAndReturnError:outError])
    {
        // The document architecture presents such an error as "file doesn't exist", which makes no sense to the user, so customize it
        if (outError && [*outError code] == NSFileReadNoSuchFileError && [[*outError domain] isEqualToString:NSCocoaErrorDomain])
        {
            *outError = [NSError errorWithDomain:NSCocoaErrorDomain
                                            code:NSFileReadCorruptFileError
                                        userInfo:@{ NSUnderlyingErrorKey : *outError }];
        }
        
        return NO;
    }
    
    BOOL readonly = ([self respondsToSelector:@selector(isInViewingMode)] && [self isInViewingMode]);
    
    BOOL result = [self configurePersistentStoreCoordinatorForURL:storeURL
                                                           ofType:typeName
                                               modelConfiguration:nil
                                                     storeOptions:@{NSReadOnlyPersistentStoreOption : @(readonly)}
                                                            error:outError];
    
    
    return result;
}

#pragma mark Writing Document Data

- (id)contentsForURL:(NSURL *)url ofType:(NSString *)typeName saveOperation:(NSSaveOperationType)saveOperation error:(NSError **)outError;
{
    NSAssert([NSThread isMainThread], @"Somehow -%@ has been called off of the main thread", NSStringFromSelector(_cmd));
    
    
    // Grab additional content that a subclass might provide
    id additionalContent = [self additionalContentForURL:url saveOperation:saveOperation error:outError];
    if (!additionalContent) return nil;
    
    
    // On 10.7+, save the main context, ready for parent to be saved in a moment
    NSManagedObjectContext *context = self.managedObjectContext;
    if ([context respondsToSelector:@selector(parentContext)])
    {
        if (![context save:outError]) additionalContent = nil;
    }
    
    
    // What we consider to be "contents" is actually a worker block
    BOOL (^contents)(NSURL *, NSSaveOperationType, NSURL *, NSError**) = ^(NSURL *url, NSSaveOperationType saveOperation, NSURL *originalContentsURL, NSError **error) {
        
        // For the first save of a document, create the folders on disk before we do anything else
        // Then setup persistent store appropriately
        BOOL result = YES;
        NSURL *storeURL = [self.class persistentStoreURLForDocumentURL:url];
        
        if (!_store)
        {
            result = [self createPackageDirectoriesAtURL:url
                                                  ofType:typeName
                                        forSaveOperation:saveOperation
                                     originalContentsURL:originalContentsURL
                                                   error:error];
            if (!result) return NO;
            
            result = [self configurePersistentStoreCoordinatorForURL:storeURL
                                                              ofType:typeName
                                                  modelConfiguration:nil
                                                        storeOptions:nil
                                                               error:error];
            if (!result) return NO;
        }
        else if (saveOperation == NSSaveAsOperation)
        {
            result = [self createPackageDirectoriesAtURL:url
                                                  ofType:typeName
                                        forSaveOperation:saveOperation
                                     originalContentsURL:originalContentsURL
                                                   error:error];
            if (!result) return NO;
            
            /*  Save As for an existing store should be special, migrating the store instead of saving
             However, in our testing it can cause the next save to blow up if you go:
             
             1. New doc
             2. Autosave
             3. Save (As)
             4. Save
             
             The last step will throw an exception claiming "Object's persistent store is not reachable from this NSManagedObjectContext's coordinator".
             
             
             NSPersistentStoreCoordinator *coordinator = [_store persistentStoreCoordinator];
             
             [coordinator lock]; // so it knows it's in use
             @try
             {
             NSPersistentStore *migrated = [coordinator migratePersistentStore:_store
             toURL:storeURL
             options:nil
             withType:[self persistentStoreTypeForFileType:typeName]
             error:error];
             
             if (!migrated) return NO;
             
             #if ! __has_feature(objc_arc)
             [migrated retain];
             [_store release];
             #endif
             
             _store = migrated;
             }
             @finally
             {
             [coordinator unlock];
             }
             */
            
            // Instead, we shall fallback to copying the store to the new location
            // -writeStoreContent… routine will adjust store URL for us
            if (![[NSFileManager defaultManager] copyItemAtURL:[self.class persistentStoreURLForDocumentURL:self.mostRecentlySavedFileURL]
                                                         toURL:storeURL
                                                         error:error]) return NO;
        }
        else
        {
            if (self.class.autosavesInPlace)
            {
                if (saveOperation == NSAutosaveElsewhereOperation)
                {
                    // Special-case autosave-elsewhere for 10.7+ documents that have been saved
                    // e.g. reverting a doc that has unautosaved changes
                    // The system asks us to autosave it to some temp location before closing
                    // CAN'T save-in-place to achieve that, since the doc system is expecting us to leave the original doc untouched, ready to load up as the "reverted" version
                    // But the doc system also asks to do this when performing a Save As operation, and choosing to discard unsaved edits to the existing doc. In which case the SQLite store moves out underneath us and we blow up shortly after
                    // Doc system apparently considers it fine to fail at this, since it passes in NULL as the error pointer
                    // With great sadness and wretchedness, that's the best workaround I have for the moment
                    NSURL *fileURL = self.fileURL;
                    if (fileURL)
                    {
                        NSURL *autosaveURL = self.autosavedContentsFileURL;
                        if (!autosaveURL)
                        {
                            // Make a copy of the existing doc to a location we control first
                            NSURL *autosaveTempDirectory = self.autosavedContentsTempDirectoryURL;
                            NSAssert(autosaveTempDirectory == nil, @"Somehow have a temp directory, but no knowledge of a doc inside it");
                            
                            autosaveTempDirectory = [[NSFileManager defaultManager] URLForDirectory:NSItemReplacementDirectory
                                                                                           inDomain:NSUserDomainMask
                                                                                  appropriateForURL:fileURL
                                                                                             create:YES
                                                                                              error:error];
                            if (!autosaveTempDirectory) return NO;
                            self.autosavedContentsTempDirectoryURL = autosaveTempDirectory;
                            
                            autosaveURL = [autosaveTempDirectory URLByAppendingPathComponent:fileURL.lastPathComponent];
                            if (![self writeBackupToURL:autosaveURL error:error]) return NO;
                            
                            self.autosavedContentsFileURL = autosaveURL;
                        }
                        
                        // Bring the autosaved doc up-to-date
                        result = [self writeStoreContentToURL:[self.class persistentStoreURLForDocumentURL:autosaveURL]
                                                        error:error];
                        if (!result) return NO;
                        
                        result = [self writeAdditionalContent:additionalContent
                                                        toURL:autosaveURL
                                          originalContentsURL:originalContentsURL
                                                        error:error];
                        if (!result) return NO;
                        
                        
                        // Then copy that across to the final URL
                        return [self writeBackupToURL:url error:error];
                    }
                }
            }
            else
            {
                if (saveOperation != NSSaveOperation && saveOperation != NSAutosaveInPlaceOperation)
                {
                    if (![storeURL checkResourceIsReachableAndReturnError:NULL])
                    {
                        result = [self createPackageDirectoriesAtURL:url
                                                              ofType:typeName
                                                    forSaveOperation:saveOperation
                                                 originalContentsURL:originalContentsURL
                                                               error:error];
                        if (!result) return NO;
                        
                        // Fake a placeholder file ready for the store to save over
                        if (![[NSData data] writeToURL:storeURL options:0 error:error]) return NO;
                    }
                }
            }
        }
        
        
        // Right, let's get on with it!
        if (![self writeStoreContentToURL:storeURL error:error]) return NO;
        
            result = [self writeAdditionalContent:additionalContent toURL:url originalContentsURL:originalContentsURL error:error];
            
            if (result)
            {
                // Update package's mod date. Two circumstances where this is needed:
                //  user requests a save when there's no changes; SQLite store doesn't bother to touch the disk in which case
                //  saving where +storeContentName is non-nil; that folder's mod date updates, but the overall package needs prompting
                // Seems simplest to just apply this logic all the time
                NSError *error;
                if (![url setResourceValue:[NSDate date] forKey:NSURLContentModificationDateKey error:&error])
                {
                    NSLog(@"Updating package mod date failed: %@", error);  // not critical, so just log it
                }
            }
        
        
        // Restore persistent store URL after Save To-type operations. Even if save failed (just to be on the safe side)
        if (saveOperation == NSSaveToOperation)
        {
            if (![[_store persistentStoreCoordinator] setURL:originalContentsURL forPersistentStore:_store])
            {
                NSLog(@"Failed to reset store URL after Save To Operation");
            }
        }
        
        
        return result;
    };
    
#if !__has_feature(objc_arc)
    return [[contents copy] autorelease];
#else
    return [contents copy];
#endif
}

- (BOOL)createPackageDirectoriesAtURL:(NSURL *)url
                               ofType:(NSString *)typeName
                     forSaveOperation:(NSSaveOperationType)saveOperation
                  originalContentsURL:(NSURL *)originalContentsURL
                                error:(NSError **)error;
{
    // Create overall package
    NSDictionary *attributes = [self fileAttributesToWriteToURL:url
                                                         ofType:typeName
                                               forSaveOperation:saveOperation
                                            originalContentsURL:originalContentsURL
                                                          error:error];
    if (!attributes) return NO;
    
    BOOL result = [[NSFileManager defaultManager] createDirectoryAtPath:[url path]
                                            withIntermediateDirectories:NO
                                                             attributes:attributes
                                                                  error:error];
    if (!result) return NO;
    
    // Create store content folder too
    NSString *storeContent = self.class.storeContentName;
    if (storeContent)
    {
        NSURL *storeContentURL = [url URLByAppendingPathComponent:storeContent];
        
        result = [[NSFileManager defaultManager] createDirectoryAtPath:[storeContentURL path]
                                           withIntermediateDirectories:NO
                                                            attributes:attributes
                                                                 error:error];
        if (!result) return NO;
    }
    
    // Set the bundle bit for good measure, so that docs won't appear as folders on Macs without your app installed. Don't care if it fails
    [self setBundleBitForDirectoryAtURL:url];
    
    return YES;
}

- (void)saveToURL:(NSURL *)url ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation completionHandler:(void (^)(NSError *))completionHandler
{
    // Can't touch _additionalContent etc. until existing save has finished
    // At first glance, -performActivityWithSynchronousWaiting:usingBlock: seems the right way to do that. But turns out:
    //  * super is documented to use -performAsynchronousFileAccessUsingBlock: internally
    //  * Autosaving (as tested on 10.7) is declared to the system as *file access*, rather than an *activity*, so a regular save won't block the UI waiting for autosave to finish
    //  * If autosaving while quitting, calling -performActivity… here resuls in deadlock
    [self performAsynchronousFileAccessUsingBlock:^(void (^fileAccessCompletionHandler)(void)) {
        
        NSAssert(_contents == nil, @"Can't begin save; another is already in progress. Perhaps you forgot to wrap the call inside of -performActivityWithSynchronousWaiting:usingBlock:");
        
        
        // Stash contents temporarily into an ivar so -writeToURL:… can access it from the worker thread
        NSError *error = nil;   // unusually for me, be forgiving of subclasses which forget to fill in the error
        _contents = [self contentsForURL:url ofType:typeName saveOperation:saveOperation error:&error];
        
        if (!_contents)
        {
            NSAssert(error, @"-additionalContentForURL:ofType:forSaveOperation:error: failed with a nil error");
            
            // The docs say "be sure to invoke super", but by my understanding it's fine not to if it's because of a failure, as the filesystem hasn't been touched yet.
            fileAccessCompletionHandler();
            if (completionHandler) completionHandler(error);
            return;
        }
        
#if !__has_feature(objc_arc)
        [_contents retain];
#endif
        
        
        // Kick off async saving work
        [super saveToURL:url ofType:typeName forSaveOperation:saveOperation completionHandler:^(NSError *error) {
            
            // Cleanup
#if !__has_feature(objc_arc)
            [_contents release];
#endif
            _contents = nil;
            
            if (!error &&
                (saveOperation == NSSaveOperation || saveOperation == NSAutosaveInPlaceOperation || saveOperation == NSSaveAsOperation))
            {
                [self deleteAutosavedContentsTempDirectory];
            }
            
            fileAccessCompletionHandler();
            if (completionHandler) completionHandler(error);
        }];
    }];
}

- (BOOL)saveToURL:(NSURL *)url ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation error:(NSError **)outError;
{
    BOOL result = [super saveToURL:url ofType:typeName forSaveOperation:saveOperation error:outError];
    
    if (result &&
        (saveOperation == NSSaveOperation || saveOperation == NSAutosaveInPlaceOperation || saveOperation == NSSaveAsOperation))
    {
        [self deleteAutosavedContentsTempDirectory];
    }
    
    return result;
}

/*	Regular Save operations can write directly to the existing document since Core Data provides atomicity for us
 */
- (BOOL)writeSafelyToURL:(NSURL *)absoluteURL
				  ofType:(NSString *)typeName
		forSaveOperation:(NSSaveOperationType)saveOperation
				   error:(NSError **)outError
{
	if ([typeName isEqualToString:[self fileType]]) // custom doc types probably want standard saving
    {
		// At this point, we've either captured all document content, or are writing on the main thread, so it's fine to unblock the UI
		if ([self respondsToSelector:@selector(unblockUserInteraction)]) [self unblockUserInteraction];
		
		
        if (saveOperation == NSSaveOperation || saveOperation == NSAutosaveInPlaceOperation ||
            (saveOperation == NSAutosaveElsewhereOperation && [absoluteURL isEqual:[self autosavedContentsFileURL]]))
        {
            NSURL *backupURL = nil;
            
			// As of 10.8, need to make a backup of the document when saving in-place
			// Unfortunately, it turns out 10.7 includes -backupFileURL, just that it's private. Checking AppKit number seems to be our best bet, and I have to hardcode that since 10_8 is not defined in the SDK yet. (1187 was found simply by looking at the GM)
			if (NSAppKitVersionNumber >= 1187 &&
				[self respondsToSelector:@selector(backupFileURL)] &&
				(saveOperation == NSSaveOperation || saveOperation == NSAutosaveInPlaceOperation) &&
				[[self class] preservesVersions])			// otherwise backupURL has a different meaning
			{
				backupURL = [self backupFileURL];
				if (backupURL)
				{
					if (![self writeBackupToURL:backupURL error:outError])
					{
						// If backup fails, seems it's our responsibility to clean up
						NSError *error;
						if (![[NSFileManager defaultManager] removeItemAtURL:backupURL error:&error])
						{
							NSLog(@"Unable to cleanup after failed backup: %@", error);
						}
						
						return NO;
					}
				}
			}
			
			
            // This may be invoked from a background thread if the user chose to save anyway in response to a "file modified by another application" prompt. Thus take care to invoke it from the main thread.
            BOOL __block result = NO;
            void (^writerBlock)() = ^{
            // NSDocument attempts to write a copy of the document out at a temporary location.
            // Core Data cannot support this, so we override it to save directly.
                result = [self writeToURL:absoluteURL
                                        ofType:typeName
                              forSaveOperation:saveOperation
                           originalContentsURL:[self fileURL]
                                         error:outError];
            };
            if ([NSThread isMainThread]) {
                writerBlock();
            } else {
                dispatch_sync(dispatch_get_main_queue(), writerBlock);
            }
        
            
            if (!result)
            {
                // Clean up backup if one was made
                // If the failure was actualy NSUserCancelledError thanks to
                // autosaving being implicitly cancellable and a subclass deciding
                // to bail out, this HAS to be done otherwise the doc system will
                // weirdly complain that a file by the same name already exists
                if (backupURL)
                {
                    NSError *error;
                    if (![[NSFileManager defaultManager] removeItemAtURL:backupURL error:&error])
                    {
                        NSLog(@"Unable to remove backup after failed write: %@", error);
                    }
                }
                
                // The -write… method maybe wasn't to know that it's writing to the live document, so might have modified it. #179730
                // We can patch up a bit by updating modification date so user doesn't get baffling document-edited warnings again!
                NSDate *modDate;
                if ([absoluteURL getResourceValue:&modDate forKey:NSURLContentModificationDateKey error:NULL])
                {
                    if (modDate)    // some file systems don't support mod date
                    {
                        [self setFileModificationDate:modDate];
                    }
                }
            }
            
            return result;
        }
    }
    
    // Other situations are basically fine to go through the regular channels
    return [super writeSafelyToURL:absoluteURL
                            ofType:typeName
                  forSaveOperation:saveOperation
                             error:outError];
}

- (BOOL)writeBackupToURL:(NSURL *)backupURL error:(NSError **)outError;
{
    NSURL *source = self.mostRecentlySavedFileURL;
	return [[NSFileManager defaultManager] copyItemAtURL:source toURL:backupURL error:outError];
}

- (BOOL)writeToURL:(NSURL *)inURL
            ofType:(NSString *)typeName
  forSaveOperation:(NSSaveOperationType)saveOp
originalContentsURL:(NSURL *)originalContentsURL
             error:(NSError **)error
{
    // Grab additional content before proceeding. This should *only* happen when writing entirely on the main thread
    // (e.g. Using one of the old synchronous -save… APIs. Note: duplicating a document calls -writeSafely… directly)
    // To have gotten here on any thread but the main one is a programming error and unworkable, so we throw an exception
    if (!_contents)
    {
		_contents = [self contentsForURL:inURL ofType:typeName saveOperation:saveOp error:error];
        if (!_contents) return NO;
        
        // Worried that _contents hasn't been retained? Never fear, we'll set it straight back to nil before exiting this method, I promise
        
        
        // And now we're ready to write for real
        BOOL result = [self writeToURL:inURL ofType:typeName forSaveOperation:saveOp originalContentsURL:originalContentsURL error:error];
        
        
        // Finish up. Don't worry, _additionalContent was never retained on this codepath, so doesn't need to be released
        _contents = nil;
        return result;
    }
    
    
    // We implement contents as a block which is called to perform the writing
    BOOL (^contentsBlock)(NSURL *, NSSaveOperationType, NSURL *, NSError**) = _contents;
    return contentsBlock(inURL, saveOp, originalContentsURL, error);
}

- (void)setBundleBitForDirectoryAtURL:(NSURL *)url;
{
#if (defined MAC_OS_X_VERSION_10_8) && MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_8   // have to check as NSURLIsPackageKey only became writable in 10.8
    NSError *error;
    if (![url setResourceValue:@YES forKey:NSURLIsPackageKey error:&error])
    {
        NSLog(@"Error marking document as a package: %@", error);
    }
#else
    FSRef fileRef;
    if (CFURLGetFSRef((CFURLRef)url, &fileRef))
    {
        FSCatalogInfo fileInfo;
        OSErr error = FSGetCatalogInfo(&fileRef, kFSCatInfoFinderInfo, &fileInfo, NULL, NULL, NULL);
        
        if (!error)
        {
            FolderInfo *finderInfo = (FolderInfo *)fileInfo.finderInfo;
            finderInfo->finderFlags |= kHasBundle;
            
            error = FSSetCatalogInfo(&fileRef, kFSCatInfoFinderInfo, &fileInfo);
        }
        
        if (error) NSLog(@"OSError %i setting bundle bit for %@", error, [url path]);
    }
#endif
}

- (BOOL)writeStoreContentToURL:(NSURL *)storeURL error:(NSError **)error;
{
    // First update metadata
    __block BOOL result = [self updateMetadataForPersistentStore:_store error:error];
    if (!result) return NO;
    
    
    // On 10.6 saving is just one call, all on main thread. 10.7+ have to work on the context's private queue
    NSManagedObjectContext *context = [self managedObjectContext];
    
    if ([context respondsToSelector:@selector(parentContext)])
    {
        [self unblockUserInteraction];
        
        NSManagedObjectContext *parent = [context parentContext];
        
        [parent performBlockAndWait:^{
            result = [self preflightURL:storeURL thenSaveContext:parent error:error];
            
#if ! __has_feature(objc_arc)
            // Errors need special handling to guarantee surviving crossing the block. http://www.mikeabdullah.net/cross-thread-error-passing.html
            if (!result && error) [*error retain];
#endif
            
        }];
        
#if ! __has_feature(objc_arc)
        if (!result && error) [*error autorelease]; // tidy up since any error was retained on worker thread
#endif
        
    }
    else
    {
        result = [self preflightURL:storeURL thenSaveContext:context error:error];
    }
    
    
    return result;
}

- (BOOL)preflightURL:(NSURL *)storeURL thenSaveContext:(NSManagedObjectContext *)context error:(NSError **)error;
{
    // Preflight the save since it tends to crash upon failure pre-Mountain Lion. rdar://problem/10609036
    // Could use this code on 10.7+:
    //NSNumber *writable;
    //result = [URL getResourceValue:&writable forKey:NSURLIsWritableKey error:&error];
    
    if ([[NSFileManager defaultManager] isWritableFileAtPath:[storeURL path]])
    {
        // Ensure store is saving to right location
        if ([context.persistentStoreCoordinator setURL:storeURL forPersistentStore:_store])
        {
            return [context save:error];
        }
    }
    
    if (error)
    {
        // Generic error. Doc/error system takes care of supplying a nice generic message to go with it
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteNoPermissionError userInfo:nil];
    }
    
    return NO;
}

#pragma mark NSDocument

+ (BOOL)canConcurrentlyReadDocumentsOfType:(NSString *)typeName { return YES; }

- (BOOL)isEntireFileLoaded { return NO; }

- (BOOL)canAsynchronouslyWriteToURL:(NSURL *)url ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation;
{
    return [NSDocument instancesRespondToSelector:_cmd];    // opt in on 10.7+
}

- (void)setFileURL:(NSURL *)absoluteURL
{
    // Mark persistent store as moved
    if (![self autosavedContentsFileURL])
    {
        [self setURLForPersistentStoreUsingFileURL:absoluteURL];
    }
    
    [super setFileURL:absoluteURL];
}

- (void)setURLForPersistentStoreUsingFileURL:(NSURL *)absoluteURL;
{
    if (!_store) return;
    
    NSPersistentStoreCoordinator *coordinator = [[self managedObjectContext] persistentStoreCoordinator];
    
    NSURL *storeURL = [[self class] persistentStoreURLForDocumentURL:absoluteURL];
    
    if (![coordinator setURL:storeURL forPersistentStore:_store])
    {
        NSLog(@"Unable to set store URL");
    }
}

#pragma mark Autosave

/*  Enable autosave-in-place and versions browser on 10.7+
 */
+ (BOOL)autosavesInPlace { return [NSDocument respondsToSelector:_cmd]; }
+ (BOOL)preservesVersions { return [self autosavesInPlace]; }

- (void)setAutosavedContentsFileURL:(NSURL *)absoluteURL;
{
    [super setAutosavedContentsFileURL:absoluteURL];
    
    // Point the store towards the most recent known URL
    absoluteURL = [self mostRecentlySavedFileURL];
    if (absoluteURL) [self setURLForPersistentStoreUsingFileURL:absoluteURL];
}

- (NSURL *)mostRecentlySavedFileURL;
{
    // Before the user chooses where to place a new document, it has an autosaved URL only
    // On 10.6-, autosaves save newer versions of the document *separate* from the original doc
    NSURL *result = [self autosavedContentsFileURL];
    if (!result) result = [self fileURL];
    return result;
}

/*
 When asked to autosave an existing doc elsewhere, we do so via an
 intermedate, temporary copy of the doc. This code tracks that temp folder
 so it can be deleted when no longer in use.
 */

@synthesize autosavedContentsTempDirectoryURL = _autosavedContentsTempDirectoryURL;

- (void)deleteAutosavedContentsTempDirectory;
{
    NSURL *autosaveTempDir = self.autosavedContentsTempDirectoryURL;
    if (autosaveTempDir)
    {
#if ! __has_feature(objc_arc)
        [[autosaveTempDir retain] autorelease];
#endif
        self.autosavedContentsTempDirectoryURL = nil;
        
        NSError *error;
        if (![[NSFileManager defaultManager] removeItemAtURL:autosaveTempDir error:&error])
        {
            NSLog(@"Unable to remove temporary directory: %@", error);
        }
    }
}

#pragma mark Reverting Documents

- (BOOL)revertToContentsOfURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError;
{
    // Tear down old windows. Wrap in an autorelease pool to get us much torn down before the reversion as we can
    @autoreleasepool
    {
    NSArray *controllers = [[self windowControllers] copy]; // we're sometimes handed underlying mutable array. #156271
    for (NSWindowController *aController in controllers)
    {
        [self removeWindowController:aController];
        [aController close];
    }
#if ! __has_feature(objc_arc)
    [controllers release];
#endif
    }


    @try
    {
        if (![super revertToContentsOfURL:absoluteURL ofType:typeName error:outError]) return NO;
        [self deleteAutosavedContentsTempDirectory];
        
        return YES;
    }
    @finally
    {
        [self makeWindowControllers];
        [self showWindows];
    }
}

#pragma mark Duplicating Documents

- (NSDocument *)duplicateAndReturnError:(NSError **)outError;
{
    // If the doc is brand new, have to force the autosave to write to disk
    if (!self.fileURL && !self.autosavedContentsFileURL && !self.hasUnautosavedChanges)
    {
        [self updateChangeCount:NSChangeDone];
        NSDocument *result = [self duplicateAndReturnError:outError];
        [self updateChangeCount:NSChangeUndone];
        return result;
    }
    
    
    // Make sure copy on disk is up-to-date
    if (![self fakeSynchronousAutosaveAndReturnError:outError]) return nil;
    
    
    // Let super handle the overall duplication so it gets the window-handling
    // right. But use custom writing logic that actually copies the existing doc
    BOOL (^contentsBlock)(NSURL*, NSSaveOperationType, NSURL*, NSError**) = ^(NSURL *url, NSSaveOperationType saveOperation, NSURL *originalContentsURL, NSError **error) {
        return [self writeBackupToURL:url error:error];
    };
    
    _contents = contentsBlock;
    NSDocument *result = [super duplicateAndReturnError:outError];
    _contents = nil;
    
    return result;
}

/*  Approximates a synchronous version of -autosaveDocumentWithDelegate:didAutosaveSelector:contextInfo:    */
- (BOOL)fakeSynchronousAutosaveAndReturnError:(NSError **)outError;
{
    // Kick off an autosave
    __block BOOL result = YES;
    [self autosaveWithImplicitCancellability:NO completionHandler:^(NSError *errorOrNil) {
        if (errorOrNil)
        {
            result = NO;
            *outError = [errorOrNil copy];  // in case there's an autorelease pool
        }
    }];
    
    // Somewhat of a hack: wait for autosave to finish
    [self performSynchronousFileAccessUsingBlock:^{ }];
    
#if ! __has_feature(objc_arc)
    if (!result) [*outError autorelease];   // match the -copy above
#endif
    
    return result;
}

#pragma mark Undo

// No-ops, like NSPersistentDocument
- (void)setUndoManager:(NSUndoManager *)undoManager { }
- (void)setHasUndoManager:(BOOL)hasUndoManager { }

// Could also implement -hasUndoManager. The NSPersistentDocument docs just say "Returns YES", which you could construe to mean it's overriden there. But I think what it actually means is that the default value for documents is YES, and we've overridden -setHasUndoManager: to be a no-op, so there's no reasonable way for it to return NO
// Update: Some poking around tells me that NSPersistentDocument does in fact override -hasUndoManager. But what that implementation does, who knows! Perhaps it handles the edge case of the MOC having no undo manager

#pragma mark Error Presentation

/*! we override willPresentError: here largely to deal with
 any validation issues when saving the document
 */
- (NSError *)willPresentError:(NSError *)inError
{
	NSError *result = nil;
    
    // customizations for NSCocoaErrorDomain
	if ( [[inError domain] isEqualToString:NSCocoaErrorDomain] )
	{
		NSInteger errorCode = [inError code];
		
		// is this a Core Data validation error?
		if ( (NSValidationErrorMinimum <= errorCode) && (errorCode <= NSValidationErrorMaximum) )
		{
			// If there are multiple validation errors, inError will be a NSValidationMultipleErrorsError
			// and all the validation errors will be in an array in the userInfo dictionary for key NSDetailedErrorsKey
			NSArray *detailedErrors = [[inError userInfo] objectForKey:NSDetailedErrorsKey];
			if ( detailedErrors != nil )
			{
				NSUInteger numErrors = [detailedErrors count];
				NSMutableString *errorString = [NSMutableString stringWithFormat:@"%lu validation errors have occurred.", (unsigned long)numErrors];
				NSMutableString *secondary = [NSMutableString string];
				if ( numErrors > 3 )
				{
					[secondary appendString:NSLocalizedString(@"The first 3 are:\n", @"To be followed by 3 error messages")];
				}
				
				NSUInteger i;
				for ( i = 0; i < ((numErrors > 3) ? 3 : numErrors); i++ )
				{
					[secondary appendFormat:@"%@\n", [[detailedErrors objectAtIndex:i] localizedDescription]];
				}
				
				NSMutableDictionary *userInfo = [NSMutableDictionary dictionaryWithDictionary:[inError userInfo]];
				[userInfo setObject:errorString forKey:NSLocalizedDescriptionKey];
				[userInfo setObject:secondary forKey:NSLocalizedRecoverySuggestionErrorKey];
                
				result = [NSError errorWithDomain:[inError domain] code:[inError code] userInfo:userInfo];
			}
		}
	}
    
	// for errors we didn't customize, call super, passing the original error
	if ( !result )
	{
		result = [super willPresentError:inError];
	}
    
    return result;
}

@end


