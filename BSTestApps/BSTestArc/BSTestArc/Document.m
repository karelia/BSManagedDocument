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

@end
