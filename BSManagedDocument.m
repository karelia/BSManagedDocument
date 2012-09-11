//
//  BSManagedDocument.m
//
//  Created by Sasmito Adibowo on 29-08-12.
//  Copyright (c) 2012 Basil Salad Software. All rights reserved.
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

#if !__has_feature(objc_arc)
#error Need automatic reference counting to compile this.
#endif


#import "FoundationAdditionsMacros.h"
#import "BSManagedDocument.h"
#import "AppKitAdditions.h"


@interface BSManagedDocument()

@end

@implementation BSManagedDocument {
    NSPersistentStoreCoordinator* _persistentStoreCoordinator;
    NSPersistentStore* _persistentStore;
    NSManagedObjectContext* _rootManagedObjectContext;
    NSManagedObjectContext* _managedObjectContext;
    NSManagedObjectModel* _managedObjectModel;
}


/*
 Returns the URL for the wrapped Core Data store file. This appends the StoreFileName to the document's path.
 */
+ (NSURL *)_storeURLFromURL:(NSURL *)containerURL {
    
    NSURL* storeURL =  [containerURL URLByAppendingPathComponent:[self persistentStoreName]];
    return storeURL;
}


-(void)managedObjectContextDidSave:(NSNotification *)notification
{
    id sender = notification.object;
    if (sender == _managedObjectContext) {
        NSFileManager* fileManager = [NSFileManager defaultManager];
        NSURL* fileURL = [self fileURL];
        NSDictionary* fileAttributes = [fileManager attributesOfItemAtPath:[fileURL path] error:nil];
        NSDate* modificationDate = fileAttributes[NSFileModificationDate];
        if (modificationDate) {
            // set the modification date to prevent NSDocument's "file was saved by another application" error.
            [self setFileModificationDate:modificationDate];
        }
    }
}


#pragma mark UIManagedDocument-inspired methods


+(NSString *)persistentStoreName
{
    return @"persistentStore";
}


-(NSManagedObjectModel *)managedObjectModel
{
    if (!_managedObjectModel) {
        NSBundle* modelBundle = [NSBundle mainBundle];
        NSArray* bundleArray = [NSArray arrayWithObject:modelBundle];
        _managedObjectModel = [NSManagedObjectModel mergedModelFromBundles:bundleArray];
    }
    return _managedObjectModel;
}


-(NSString *)persistentStoreTypeForFileType:(NSString *)fileType
{
    return NSSQLiteStoreType;
}


- (BOOL)configurePersistentStoreCoordinatorForURL:(NSURL *)url ofType:(NSString *)fileType modelConfiguration:(NSString *)configuration storeOptions:(NSDictionary *)storeOptions error:(NSError * __autoreleasing*)error
{
    NSManagedObjectModel* model = [self managedObjectModel];
    NSPersistentStoreCoordinator* coordinator = [[NSPersistentStoreCoordinator alloc] initWithManagedObjectModel:model];
    NSError* pscError = nil;
    NSPersistentStore* persistentStore = [coordinator addPersistentStoreWithType:[self persistentStoreTypeForFileType:fileType] configuration:configuration URL:url options:storeOptions error:&pscError];
    if (persistentStore) {
        NSManagedObjectContext* parentContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSPrivateQueueConcurrencyType];
        [parentContext performBlockAndWait:^{
            [parentContext setPersistentStoreCoordinator:coordinator];
        }];
        
        @synchronized(self) {
            _rootManagedObjectContext = parentContext;
            _persistentStoreCoordinator = coordinator;
            _persistentStore = persistentStore;
        }
        
        return YES;
    } else {
        if (error) {
            *error = pscError;
        }
        return NO;
    }
    return NO;
}


- (id)additionalContentForURL:(NSURL *)absoluteURL error:(NSError * __autoreleasing*)error
{
    return nil;
}


- (BOOL)readAdditionalContentFromURL:(NSURL *)absoluteURL error:(NSError * __autoreleasing*)error
{
    return YES;
}


- (BOOL)writeAdditionalContent:(id)content toURL:(NSURL *)absoluteURL originalContentsURL:(NSURL *)absoluteOriginalContentsURL error:(NSError * __autoreleasing*)error
{
    return YES;
}


#pragma mark NSDocument


+ (BOOL)canConcurrentlyReadDocumentsOfType:(NSString *)typeName
{
    return YES;
}


+ (BOOL)autosavesInPlace
{
    return YES;
}


+ (BOOL)autosavesDrafts
{
    return NO;
}


+(BOOL)preservesVersions
{
    return NO;
}


- (BOOL)isEntireFileLoaded
{
    return NO;
}


- (BOOL)canAsynchronouslyWriteToURL:(NSURL *)url ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation
{
    if (saveOperation == NSSaveToOperation) {
        return NO;
    }
    return YES;
}


- (void)saveToURL:(NSURL *)url ofType:(NSString *)typeName forSaveOperation:(NSSaveOperationType)saveOperation completionHandler:(void (^)(NSError *errorOrNil))completionHandler
{
    // save the main thread context if we have one.
    DebugLog(@"saving to URL: %@",url);
    if (_managedObjectContext) {
        NSError* mainContextError = nil;
        if(![_managedObjectContext save:&mainContextError]) {
            completionHandler(mainContextError);
            return;
        }
    }

    [super saveToURL:url ofType:typeName forSaveOperation:saveOperation completionHandler:completionHandler];
}


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


- (BOOL)writeSafelyToURL:(NSURL *)inAbsoluteURL ofType:(NSString *)inTypeName forSaveOperation:(NSSaveOperationType)inSaveOperation error:(NSError **)outError
{
	DebugLog(@"Saving operation %@ to URL: %@",BSStringFromSaveOperationType(inSaveOperation),inAbsoluteURL);
	
    NSError* additionalContentError = nil;
    id additionalContent = [self additionalContentForURL:inAbsoluteURL error:&additionalContentError];
    if (additionalContentError) {
        if (outError) {
            *outError = additionalContentError;
        }
        return NO;
    }
    
    //NSString *filePath = [inAbsoluteURL path];
    NSURL *originalURL = [self fileURL];
    
    
    NSDictionary *fileAttributes = [self fileAttributesToWriteToURL:inAbsoluteURL ofType:inTypeName forSaveOperation:inSaveOperation originalContentsURL:originalURL error:outError];
    
    /// ----  Main thread unblocked at this point ---- ///
    
    [self unblockUserInteraction];
    
    NSFileWrapper *filewrapper = nil;
    
    // Depending on the type of save operation:
    if (inSaveOperation == NSSaveToOperation) {
        // not supported
        if (outError) {
            NSDictionary* errorInfo = @{
            NSLocalizedDescriptionKey : NSLocalizedString(@"Core Data does not support saving changes to a new document while maintaining the unsaved state in the current document.", @"Managed Document Error"),
                NSURLErrorKey : inAbsoluteURL
            };
            *outError = [NSError errorWithDomain:NSOSStatusErrorDomain code:unimpErr userInfo:errorInfo];
        }
        return NO;
    } else if (inSaveOperation == NSSaveAsOperation || inSaveOperation == NSAutosaveAsOperation) {
		
        // Nothing exists at the URL: set up the directory and migrate the Core Data store.
        filewrapper = [[NSFileWrapper alloc] initDirectoryWithFileWrappers:nil];
        // Need to write once so there's somewhere for the store file to go.
        NSError* fileWrapperFirstWriteError = nil;
        if (![filewrapper writeToURL:inAbsoluteURL options:NSFileWrapperWritingWithNameUpdating originalContentsURL:originalURL error:&fileWrapperFirstWriteError]) {
            if (outError) {
                *outError = fileWrapperFirstWriteError;
            }
            return NO;
        };
        
        
        // Now, the Core Data store...
        NSURL *storeURL = [[self  class] _storeURLFromURL:inAbsoluteURL];
        NSURL *originalStoreURL = [[self class] _storeURLFromURL:originalURL];
		
        if (originalStoreURL != nil) {
            // This is a "Save As", so migrate the store to the new URL.
            NSPersistentStoreCoordinator *coordinator =  nil;
            @synchronized(self) {
                coordinator = _persistentStoreCoordinator;
            }
            id originalStore = [coordinator persistentStoreForURL:originalStoreURL];
            NSPersistentStore* migratedStore = [coordinator migratePersistentStore:originalStore toURL:storeURL options:nil withType:[self persistentStoreTypeForFileType:inTypeName] error:outError];
            if (!migratedStore) {
                return NO;
            }
        } else {
            // just configure the store
            if(![self configurePersistentStoreCoordinatorForURL:storeURL ofType:[self persistentStoreTypeForFileType:inTypeName] modelConfiguration:nil storeOptions:nil error:outError]) {
                return NO;
            }
        }
    } else { // This is not a Save-As operation.
             // Just create a file wrapper pointing to the existing URL.
        NSError* fileWrapperError = nil;
        filewrapper = [[NSFileWrapper alloc] initWithURL:inAbsoluteURL options:0 error:&fileWrapperError];
        if (fileWrapperError) {
            if (outError) {
                *outError = fileWrapperError;
            }
            return NO;
        }
    }
    
    
    NSManagedObjectContext* rootContext = nil;
    @synchronized(self) {
        rootContext = _rootManagedObjectContext;
    }
    
    NSError __block* rootError = nil;
    [rootContext performBlockAndWait:^{
        NSError* parentError = nil;
        [rootContext save:&parentError];
        if (parentError) {
            ErrorLog(@"Could not save root context: %@", parentError);
            rootError = parentError;
        }
    }];
    if (rootError) {
        if (outError) {
            *outError = rootError;
        }
        return NO;
    }
    
    
    //  save non core-data portion.
    if (additionalContent) {
        NSError* additionalContentWriteError = nil;
        if(![self writeAdditionalContent:additionalContent toURL:inAbsoluteURL originalContentsURL:originalURL error:&additionalContentWriteError]) {
            if (additionalContentWriteError) {
                ErrorLog(@"Could not save additioanl content: %@", additionalContentWriteError);
                if (outError) {
                    *outError = additionalContentWriteError;
                }
            }
            return NO;
        }
    }
    
    
    NSFileManager* const fileManager = [NSFileManager defaultManager];

    // Set the appropriate file attributes (such as "Hide File Extension")
    if (fileAttributes) {
        if ([inAbsoluteURL isFileURL]) {
            NSString* path = [inAbsoluteURL path];
            NSError* fileError = nil;
            [fileManager setAttributes:fileAttributes ofItemAtPath:path error:&fileError];
            if (fileError) {
                ErrorLog(@"Error '%@' updating attributes of file '%@' to %@",fileError,path,fileAttributes);
            }
        }
    }
    
    return YES;
}



- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError * __autoreleasing*)outError {
	
    BOOL success = NO;
    // Create a file wrapper for the document package.
    NSError* fileWrapperError = nil;
    NSFileWrapper* directoryFileWrapper = [[NSFileWrapper alloc] initWithURL:absoluteURL options: NSFileWrapperReadingImmediate  error:&fileWrapperError];
    if (fileWrapperError) {
        ErrorLog(@"fileWrapperError: %@",fileWrapperError);
        if (outError) {
            *outError = fileWrapperError;
            return NO;
        }
    }
    // File wrapper for the Core Data store within the document package.
    NSFileWrapper *dataStore = [[directoryFileWrapper fileWrappers] objectForKey:[[self class] persistentStoreName]];
	
    if (dataStore != nil) {
        NSURL* storeURL = [absoluteURL URLByAppendingPathComponent:[dataStore filename]];
        // Set the document persistent store coordinator to use the internal Core Data store.
        success = [self configurePersistentStoreCoordinatorForURL:storeURL ofType:typeName
											   modelConfiguration:nil storeOptions:nil error:outError];
    }
    
    if (!success) {
        return NO;
    }
	
    // Don't read anything else if reading the main store failed.
    if (![self readAdditionalContentFromURL:absoluteURL error:outError]) {
        return NO;
    }
	
    return YES;
}
 

-(NSUndoManager *)undoManager
{
    return [self.managedObjectContext undoManager];
}


-(void)setUndoManager:(NSUndoManager *)undoManager
{
    [self.managedObjectContext setUndoManager:undoManager];
}



#pragma mark NSObject

- (id)init
{
    self = [super init];
    if (self) {
        // Add your subclass-specific initialization here.
    }
    return self;
}


-(void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}


#pragma mark Property Access

-(NSManagedObjectContext *)managedObjectContext
{
    if (!_managedObjectContext) {
        @synchronized(self) {
            if (_rootManagedObjectContext) {
                _managedObjectContext = [[NSManagedObjectContext alloc] initWithConcurrencyType:NSMainQueueConcurrencyType];
                [_managedObjectContext setParentContext:_rootManagedObjectContext];
                
                [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(managedObjectContextDidSave:) name:NSManagedObjectContextDidSaveNotification object:_managedObjectContext];
            }
        }
    }
    return _managedObjectContext;
}


@end


