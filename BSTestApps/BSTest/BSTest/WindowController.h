//
//  WindowController.h
//  BSTest
//
//  Created by Abizer Nasir on 19/12/2012.
//  Copyright (c) 2012 Jungle Candy Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface WindowController : NSWindowController <NSTableViewDelegate>

@property (assign) IBOutlet NSArrayController *arrayController;
@property (assign) IBOutlet NSTextView *contentView;

- (IBAction)addAFile:(id)sender;

@end
