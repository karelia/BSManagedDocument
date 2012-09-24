//
//  BSManagedDocument.h
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


#import <Cocoa/Cocoa.h>


/**
 A document class that supports Core Data background operations. 
 Just like UIManagedDocument but for OS X.
 */
@interface BSManagedDocument : NSDocument

+ (NSString *)persistentStoreName;

- (NSString *)persistentStoreTypeForFileType:(NSString *)fileType;

- (BOOL)configurePersistentStoreCoordinatorForURL:(NSURL *)url ofType:(NSString *)fileType modelConfiguration:(NSString *)configuration storeOptions:(NSDictionary *)storeOptions error:(NSError * __autoreleasing*)error;

- (BOOL)readAdditionalContentFromURL:(NSURL *)absoluteURL error:(NSError * __autoreleasing*)error;

- (BOOL)writeAdditionalContent:(id)content toURL:(NSURL *)absoluteURL originalContentsURL:(NSURL *)absoluteOriginalContentsURL error:(NSError * __autoreleasing*)error;

- (id)additionalContentForURL:(NSURL *)absoluteURL error:(NSError * __autoreleasing*)error;

- (BOOL)readFromURL:(NSURL *)absoluteURL ofType:(NSString *)typeName error:(NSError * __autoreleasing*)error;


/**
 No-op, like NSPersistentDocument
 */
-(void)setUndoManager:(NSUndoManager *)undoManager;

/**
 No-op, like NSPersistentDocument
 */
-(void)setHasUndoManager:(BOOL)hasUndoManager;


-(BOOL)isDocumentEdited;


-(void) managedObjectContextDidSave:(NSNotification*) notification;


@property( strong, readonly) NSManagedObjectModel *managedObjectModel;

@property(strong, readonly) NSManagedObjectContext *managedObjectContext;


@end


// ---
