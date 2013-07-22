//
//  Document.m
//  BSTest
//
//  Created by Abizer Nasir on 19/12/2012.
//  Copyright (c) 2012 Jungle Candy Software. All rights reserved.
//

#import "Document.h"
#import "WindowController.h"

@implementation Document

- (id)init {
    self = [super init];
    if (self) {
        // Add your subclass-specific initialization here.
    }
    return self;
}

- (void)makeWindowControllers {
    WindowController *windowController = [WindowController new];
    [self addWindowController:windowController];
    [windowController release];
}

- (void)windowControllerDidLoadNib:(NSWindowController *)aController {
    [super windowControllerDidLoadNib:aController];
    // Add any code here that needs to be executed once the windowController has loaded the document's window.
}

- (BOOL)configurePersistentStoreCoordinatorForURL:(NSURL *)storeURL ofType:(NSString *)fileType modelConfiguration:(NSString *)configuration storeOptions:(NSDictionary *)storeOptions error:(NSError **)error;
{
    NSMutableDictionary *options = [NSMutableDictionary dictionaryWithDictionary:storeOptions];
    [options setObject:@YES forKey:NSMigratePersistentStoresAutomaticallyOption];
    [options setObject:@YES forKey:NSInferMappingModelAutomaticallyOption];
    
    return [super configurePersistentStoreCoordinatorForURL:storeURL ofType:fileType modelConfiguration:configuration storeOptions:options error:error];
}

@end
