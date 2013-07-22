//
//  Document.m
//  BSTestArc
//
//  Created by Abizer Nasir on 19/12/2012.
//  Copyright (c) 2012 Jungle Candy Software. All rights reserved.
//

#import "Document.h"
#import "WindowController.h"

@implementation Document

- (void)makeWindowControllers {
    WindowController *windowController = [WindowController new];
    [self addWindowController:windowController];
}

- (BOOL)configurePersistentStoreCoordinatorForURL:(NSURL *)storeURL ofType:(NSString *)fileType modelConfiguration:(NSString *)configuration storeOptions:(NSDictionary *)storeOptions error:(NSError **)error;
{
    NSMutableDictionary *options = [NSMutableDictionary dictionaryWithDictionary:storeOptions];
    [options setObject:@YES forKey:NSMigratePersistentStoresAutomaticallyOption];
    [options setObject:@YES forKey:NSInferMappingModelAutomaticallyOption];
    
    return [super configurePersistentStoreCoordinatorForURL:storeURL ofType:fileType modelConfiguration:configuration storeOptions:options error:error];
}

@end
