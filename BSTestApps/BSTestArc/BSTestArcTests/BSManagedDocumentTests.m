//
//  BSManagedDocumentTests.m
//  BSTestArc
//
//  Created by Abizer Nasir on 26/01/2013.
//  Copyright (c) 2013 Jungle Candy Software. All rights reserved.
//

#import <SenTestingKit/SenTestingKit.h>
#import "Document.h"

@interface BSManagedDocumentTests : SenTestCase
@end


@implementation BSManagedDocumentTests {
    BSManagedDocument *_document;
}

#pragma mark - Set up and tear down

- (void)setUp {
    _document = [[Document alloc] init];    // use subclass for automatic migration
}

- (void)tearDown {
    _document = nil;
}

#pragma mark - Tests

- (void)testAutomaticDocumentMigrationFromVersion1 {
    NSURL *version1URL = [[NSBundle bundleForClass:[self class]] URLForResource:@"version1ARC" withExtension:@"bstest_arc"];

    NSError *error;
    BOOL readingResult = [_document readFromURL:version1URL ofType:@"DocumentType" error:&error];

    STAssertTrue(readingResult, @"Should be able to read version1 files. Error is %@", error);
    
}

@end
