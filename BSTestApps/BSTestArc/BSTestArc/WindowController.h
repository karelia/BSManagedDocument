//
//  WindowController.h
//  BSTestArc
//
//  Created by Abizer Nasir on 20/12/2012.
//  Copyright (c) 2012 Jungle Candy Software. All rights reserved.
//

#import <Cocoa/Cocoa.h>

@interface WindowController : NSWindowController <NSTableViewDelegate>

@property (strong) IBOutlet NSArrayController *arrayController;

- (IBAction)addAFile:(id)sender;


@end
