//
//  BSManagedDocument.m
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

#import "BSManagedDocument.h"


@implementation BSManagedDocument

#pragma mark UIManagedDocument-inspired methods

+ (NSString *)persistentStoreName; { return @"persistentStore"; }

- (NSManagedObjectContext *)managedObjectContext;
{
    if (!_managedObjectContext)
    {
        // Need 10.7+ to support concurrency types
        __block NSManagedObjectContext *context;
        if ([NSManagedObjectContext instancesRespondToSelector:@selector(initWithConcurrencyType:)])
        {
            context = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
        }
        else
        {
            // On 10.6, context MUST be created on the thread/queue that's going to use it
            if ([NSThread isMainThread])
            {
                context = [[NSManagedObjectContext alloc] init];
            }
            else
            {
                dispatch_sync(dispatch_get_main_queue(), ^{
                    context = [[NSManagedObjectContext alloc] init];
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
        NSManagedObjectContext *parentContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        
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
        NSMutableDictionary *mutableOptions = [NSMutableDictionary dictionaryWithCapacity:([storeOptions count] + 1)];
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

- (id)additionalContentForURL:(NSURL *)absoluteURL ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation error:(NSError **)error;
{
	// Need to hand back something so as not to indicate there was an error
    return [NSNull null];
}

- (BOOL)writeAdditionalContent:(id)content toURL:(NSURL *)absoluteURL forSaveOperation:(NSSaveOperationType)saveOperation originalContentsURL:(NSURL *)absoluteOriginalContentsURL error:(NSError **)error;
{
    return YES;
}

#pragma mark Core Data-Specific

- (BOOL)updateMetadataForPersistentStore:(NSPersistentStore *)store error:(NSError **)error;
{
    return YES;
}

#pragma mark Lifecycle

// It's simpler to wrap the whole method in a conditional test rather than using a macro for each line.
#if ! __has_feature(objc_arc)
- (void)dealloc;
{
    [_managedObjectContext release];
    [_managedObjectModel release];
    [_store release];
    
    [super dealloc];
}
#endif

#pragma mark Reading From and Writing to URLs

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError
{
    // Preflight the URL
    //  A) If the file happens not to exist for some reason, Core Data unhelpfully gives "invalid file name" as the error. NSURL gives better descriptions
    //  B) When reverting a document, the persistent store will already have been removed by the time we try adding the new one (see below). If adding the new store fails that most likely leaves us stranded with no store, so it's preferable to catch errors before removing the store if possible
    if (![absoluteURL checkResourceIsReachableAndReturnError:outError]) return NO;
    
    
    BOOL result = YES;
    
    
    // If have already read, then this is a revert-type affair, so must reload data from disk
    if (_store)
    {
        if (!([NSThread isMainThread])) {
            [NSException raise:NSInternalInconsistencyException format:@"%@: I didn't anticipate reverting on a background thread!", NSStringFromSelector(_cmd)];
        }
        
        // NSPersistentDocument states: "Revert resets the document’s managed object context. Objects are subsequently loaded from the persistent store on demand, as with opening a new document."
        // I've found for atomic stores that -reset only rolls back to the last loaded or saved version of the store; NOT what's actually on disk
        // To force it to re-read from disk, the only solution I've found is removing and re-adding the persistent store
        if (![[[self managedObjectContext] persistentStoreCoordinator] removePersistentStore:_store error:outError])
        {
            return NO;
        }

#if !__has_feature(objc_arc)
        [_store release];
#endif

        _store = nil;
    }
    
    
    // Setup the store
    NSURL *newStoreURL = [absoluteURL URLByAppendingPathComponent:[[self class] persistentStoreName]];
    BOOL readonly = ([self respondsToSelector:@selector(isInViewingMode)] && [self isInViewingMode]);
    
    result = [self configurePersistentStoreCoordinatorForURL:newStoreURL
                                                      ofType:typeName
                                          modelConfiguration:nil
                                                storeOptions:@{NSReadOnlyPersistentStoreOption : @(readonly)}
                                                       error:outError];
    
    
    return result;
}

- (void)saveToURL:(NSURL *)url ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation completionHandler:(void (^)(NSError *))completionHandler
{
    NSAssert(_additionalContent == nil, @"Can't begin save; another is already in progress. Perhaps you forgot to wrap the call inside of -performActivityWithSynchronousWaiting:usingBlock:");
    
    /* The docs say "be sure to invoke super", but by my understanding it's fine not to if it's because of a failure, and the filesystem hasn't been touched yet.
     */
    
    NSError *error;
    _additionalContent = [self additionalContentForURL:url ofType:typeName forSaveOperation:saveOperation error:&error];

    if (!_additionalContent)
    {
        NSAssert(error, @"-additionalContentForURL:ofType:forSaveOperation:error: failed with a nil error");
        completionHandler(error);
        return;
    }
    
#if !__has_feature(objc_arc)
    [_additionalContent retain];
#endif
    
    
    // Completion handler *has* to run at some point, so extend it to do cleanup for us
    completionHandler = ^(NSError *error) {
        
#if !__has_feature(objc_arc)
        [_additionalContent release];
#endif
        _additionalContent = nil;
        
        completionHandler(error);
    };
    
    
    // Save the main context on the main thread before handing off to the background
    if ([[self managedObjectContext] save:&error])
    {
        [super saveToURL:url ofType:typeName forSaveOperation:saveOperation completionHandler:completionHandler];
    }
    else
    {
        NSAssert(error, @"-[NSManagedObjectContext save:] failed with a nil error");
        completionHandler(error);
    }
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
			// As of 10.8, need to make a backup of the document when saving in-place
			// Unfortunately, it turns out 10.7 includes -backupFileURL, just that it's private. Checking AppKit number seems to be our best bet, and I have to hardcode that since 10_8 is not defined in the SDK yet. (1187 was found simply by looking at the GM)
			if (NSAppKitVersionNumber >= 1187 &&
				[self respondsToSelector:@selector(backupFileURL)] &&
				(saveOperation == NSSaveOperation || saveOperation == NSAutosaveInPlaceOperation) &&
				[[self class] preservesVersions])			// otherwise backupURL has a different meaning
			{
				NSURL *backupURL = [self backupFileURL];
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
			
			
            // NSDocument attempts to write a copy of the document out at a temporary location.
            // Core Data cannot support this, so we override it to save directly.
            BOOL result = [self writeToURL:absoluteURL
                                    ofType:typeName
                          forSaveOperation:saveOperation
                       originalContentsURL:[self fileURL]
                                     error:outError];
            
            // The -write… method maybe wasn't to know that it's writing to the live document, so might have modified it. #179730
            // We can patch up a bit by updating modification date so user doesn't get baffling document-edited warnings again!
            if (!result)
            {
                NSDate *modDate;
                if ([absoluteURL getResourceValue:&modDate forKey:NSURLContentModificationDateKey error:NULL] &&
                    modDate)    // some file systems don't support mod date
                {
                    [self setFileModificationDate:modDate];
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
	return [[NSFileManager defaultManager] copyItemAtURL:[self fileURL] toURL:backupURL error:outError];
}

- (BOOL)writeToURL:(NSURL *)inURL
            ofType:(NSString *)typeName
  forSaveOperation:(NSSaveOperationType)saveOp
originalContentsURL:(NSURL *)originalContentsURL
             error:(NSError **)error
{
    // Can't write on worker thread if caller somehow bypassed additional content & saving main context
    if (!_additionalContent)
    {
		// For example, duplicating a document calls -writeSafely… directly. Also, using the old synchronous saving APIs bring you to this point
        if ([NSThread isMainThread])
        {
            _additionalContent = [self additionalContentForURL:inURL ofType:typeName forSaveOperation:saveOp error:error];
            if (!_additionalContent) return NO;
            
            // Worried that _additionalContent hasn't been retained? Never fear, we'll set it straight back to nil before exiting this method, I promise
            
            // On 10.7+, save the main context, ready for parent to be saved in a moment
            NSManagedObjectContext *context = [self managedObjectContext];
            if ([context respondsToSelector:@selector(parentContext)])
            {
                if (![context save:error])
                {
                    _additionalContent = nil;
                    return NO;
                }
            }
            
            // And now we're ready to write for real
            BOOL result = [self writeToURL:inURL ofType:typeName forSaveOperation:saveOp originalContentsURL:originalContentsURL error:error];
            
            
            // Finish up. Don't worry, _additionalContent was never retained on this codepath, so doesn't need to be released
            _additionalContent = nil;
            return result;
        }
        else
        {
            [NSException raise:NSInvalidArgumentException format:@"Attempt to write document on background thread, bypassing usual save methods"];
            return NO;
        }
    }
    
    
    // For the first save of a document, create the package on disk before we do anything else
    __block BOOL result = YES;
    if (saveOp == NSSaveAsOperation ||
        (saveOp == NSAutosaveOperation && ![[self autosavedContentsFileURL] isEqual:inURL]))
    {
        NSDictionary *attributes = [self fileAttributesToWriteToURL:inURL
                                                             ofType:typeName
                                                   forSaveOperation:saveOp
                                                originalContentsURL:originalContentsURL
                                                              error:error];
        
        if (!attributes) return NO;
        
        result = [[NSFileManager defaultManager] createDirectoryAtPath:[inURL path]
                                           withIntermediateDirectories:NO
                                                            attributes:attributes
                                                                 error:error];
        
        // Set the bundle bit for good measure, so that docs won't appear as folders on Macs without your app installed
        if (result)
        {
#if (defined MAC_OS_X_VERSION_10_8) && MAC_OS_X_VERSION_MIN_REQUIRED >= MAC_OS_X_VERSION_10_8   // have to check as NSURLIsPackageKey only became writable in 10.8
            NSError *error;
            if (![inURL setResourceValue:@YES forKey:NSURLIsPackageKey error:&error])
            {
                NSLog(@"Error marking document as a package: %@", error);
            }
#else
            FSRef fileRef;
            if (CFURLGetFSRef((CFURLRef)inURL, &fileRef))
            {
                // Get the file's current info
                FSCatalogInfo fileInfo;
                OSErr error = FSGetCatalogInfo(&fileRef, kFSCatInfoFinderInfo, &fileInfo, NULL, NULL, NULL);
                
                if (!error)
                {
                    // Adjust the bundle bit
                    FolderInfo *finderInfo = (FolderInfo *)fileInfo.finderInfo;
                    finderInfo->finderFlags |= kHasBundle;
                    
                    // Set the altered flags of the file
                    error = FSSetCatalogInfo(&fileRef, kFSCatInfoFinderInfo, &fileInfo);
                }
                
                if (error) NSLog(@"OSError %i setting bundle bit for %@", error, [inURL path]);
            }
#endif
        }
    }
    
    
    
    NSURL *storeURL = [inURL URLByAppendingPathComponent:[[self class] persistentStoreName]];
    
    // Setup persistent store appropriately
    if (!_store)
    {
        if (![self configurePersistentStoreCoordinatorForURL:storeURL
                                                      ofType:typeName
                                          modelConfiguration:nil
                                                storeOptions:nil
                                                       error:error])
        {
            return NO;
        }
    }
    else if (saveOp == NSSaveAsOperation)
    {
        /* Save As for an existing store is special. Migrates the store instead of saving
         */
        
        if (![self updateMetadataForPersistentStore:_store error:error]) return NO;
        
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
            
            return [self writeAdditionalContent:_additionalContent
                                          toURL:inURL
                               forSaveOperation:saveOp
                            originalContentsURL:originalContentsURL
                                          error:error];
        }
        @finally
        {
            [coordinator unlock];
        }
    }
    else if (saveOp != NSSaveOperation && saveOp != NSAutosaveInPlaceOperation)
    {
        // Fake a placeholder file ready for the store to save over
        if (![storeURL checkResourceIsReachableAndReturnError:NULL])
        {
            if (![[NSData data] writeToURL:storeURL options:0 error:error]) return NO;
        }
        
        // Make sure existing store is saving to right place
        [[_store persistentStoreCoordinator] setURL:storeURL forPersistentStore:_store];
    }
    
    
    
    
    // Update metadata
    result = [self updateMetadataForPersistentStore:_store error:error];
    if (!result) return NO;
    
    
    // Do the save. On 10.6 it's just one call, all on main thread. 10.7+ have to work on the context's private queue
    NSManagedObjectContext *context = [self managedObjectContext];
    
    if ([context respondsToSelector:@selector(parentContext)])
    {
        [self unblockUserInteraction];
        
        NSManagedObjectContext *parent = [context parentContext];
        
        [parent performBlockAndWait:^{
            result = [self preflightURL:storeURL thenSaveContext:parent error:error];

#if ! __has_feature(objc_arc)
            // Errors need special handling to guarantee surviving crossing the block
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
    
    if (result)
    {
        result = [self writeAdditionalContent:_additionalContent toURL:inURL forSaveOperation:saveOp originalContentsURL:originalContentsURL error:error];
    }
    
    
    // Restore persistent store URL after Save To-type operations. Even if save failed (just to be on the safe side)
    if (saveOp == NSSaveToOperation)
    {
        if (![[_store persistentStoreCoordinator] setURL:originalContentsURL forPersistentStore:_store])
        {
            NSLog(@"Failed to reset store URL after Save To Operation");
        }
    }
    
    
    return result;
}

- (BOOL)preflightURL:(NSURL *)storeURL thenSaveContext:(NSManagedObjectContext *)context error:(NSError **)error;
{
    // Preflight the save since it tends to crash upon failure pre-Mountain Lion. rdar://problem/10609036
    // Could use this code on 10.7+:
    //NSNumber *writable;
    //result = [URL getResourceValue:&writable forKey:NSURLIsWritableKey error:&error];
    
    BOOL result = [[NSFileManager defaultManager] isWritableFileAtPath:[storeURL path]];
    if (result)
    {
        result = [context save:error];
    }
    else if (error)
    {
        // Generic error. Doc/error system takes care of supplying a nice generic message to go with it
        *error = [NSError errorWithDomain:NSCocoaErrorDomain code:NSFileWriteNoPermissionError userInfo:nil];
    }
    
    return result;
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
    
    NSURL *storeURL = [absoluteURL URLByAppendingPathComponent:[[self class] persistentStoreName]];
    
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

- (BOOL)saveToURL:(NSURL *)absoluteURL ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation error:(NSError * __autoreleasing*)outError
{
    if (_managedObjectContext) {
        NSError* mainContextError = nil;
        if(![_managedObjectContext save:&mainContextError]) {
            if (outError) {
                *outError = mainContextError;
            }
            return NO;
        }
    }
    return [super saveToURL:absoluteURL ofType:typeName forSaveOperation:saveOperation error:outError];
}

- (void)setAutosavedContentsFileURL:(NSURL *)absoluteURL;
{
    [super setAutosavedContentsFileURL:absoluteURL];
    
    // If this the only copy, tell the store its new location
    if (absoluteURL)
    {
        [self setURLForPersistentStoreUsingFileURL:absoluteURL];
    }
    else if ([self fileURL])
    {
        [self setURLForPersistentStoreUsingFileURL:[self fileURL]];
    }
}

#pragma mark Reverting Documents

- (BOOL)revertToContentsOfURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError **)outError;
{
    // Tear down old windows
    NSArray *controllers = [[self windowControllers] copy]; // we're sometimes handed underlying mutable array. #156271
    for (NSWindowController *aController in controllers)
    {
        [self removeWindowController:aController];
        [aController close];
    }
#if ! __has_feature(objc_arc)
    [controllers release];
#endif


    @try
    {
        return [super revertToContentsOfURL:absoluteURL ofType:typeName error:outError];
    }
    @finally
    {
        [self makeWindowControllers];
        [self showWindows];
    }
}

#pragma mark Undo

// No-ops, like NSPersistentDocument
- (void)setUndoManager:(NSUndoManager *)undoManager { }
- (void)setHasUndoManager:(BOOL)hasUndoManager { }

// Could also implement -hasUndoManager. The NSPersistentDocument docs just say "Returns YES", which you could construe to mean it's overriden there. But I think what it actually means is that the default value for documents is YES, and we've overridden -setHasUndoManager: to be a no-op, so there's no reasonable way for it to return NO

#pragma mark Error Presentation

/*! we override willPresentError: here largely to deal with
 any validation issues when saving the document
 */
- (NSError *)willPresentError:(NSError *)inError
{
	NSError *result = inError;
    
    // customizations for NSCocoaErrorDomain
	if ( [[inError domain] isEqualToString:NSCocoaErrorDomain] )
	{
		NSInteger errorCode = [inError code];
		
		// is this a Core Data validation error?
		if ( (errorCode >= NSValidationErrorMinimum) && (errorCode <= NSValidationErrorMaximum) )
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
    
    
    return result;
}

@end


