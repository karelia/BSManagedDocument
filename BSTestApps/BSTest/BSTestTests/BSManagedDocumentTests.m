//
//  BSManagedDocumentTests.m
//  BSTest
//
//  Created by Abizer Nasir on 26/01/2013.
//  Copyright (c) 2013 Jungle Candy Software. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "BSManagedDocument.h"

@interface BSManagedDocumentTests : SenTestCase
@end

@implementation BSManagedDocumentTests {
    BSManagedDocument *_document;
}

#pragma mark - Set up and tear down

- (void)setUp {
    _document = [[BSManagedDocument alloc] init];
}

- (void)tearDown {
    [_document release], _document = nil;
}

#pragma mark -  Tests

- (void)testAutomaticDocumentMigrationFromVersion1 {

}

@end
