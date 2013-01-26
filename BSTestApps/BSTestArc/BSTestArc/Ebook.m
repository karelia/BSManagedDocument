//
//  Ebook.m
//  BSTestArc
//
//  Created by Abizer Nasir on 26/01/2013.
//  Copyright (c) 2013 Jungle Candy Software. All rights reserved.
//

#import "Ebook.h"


@implementation Ebook

@dynamic contents;
@dynamic title;
@dynamic importDate;

- (void)awakeFromInsert {
    self.importDate = [NSDate date];
}

@end
