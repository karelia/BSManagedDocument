// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to Ebook.m instead.

#import "_Ebook.h"

const struct EbookAttributes EbookAttributes = {
	.contents = @"contents",
	.title = @"title",
	.type = @"type",
};

const struct EbookRelationships EbookRelationships = {
};

const struct EbookFetchedProperties EbookFetchedProperties = {
};

@implementation EbookID
@end

@implementation _Ebook

+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription insertNewObjectForEntityForName:@"Ebook" inManagedObjectContext:moc_];
}

+ (NSString*)entityName {
	return @"Ebook";
}

+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_ {
	NSParameterAssert(moc_);
	return [NSEntityDescription entityForName:@"Ebook" inManagedObjectContext:moc_];
}

- (EbookID*)objectID {
	return (EbookID*)[super objectID];
}

+ (NSSet*)keyPathsForValuesAffectingValueForKey:(NSString*)key {
	NSSet *keyPaths = [super keyPathsForValuesAffectingValueForKey:key];
	
	if ([key isEqualToString:@"typeValue"]) {
		NSSet *affectingKey = [NSSet setWithObject:@"type"];
		keyPaths = [keyPaths setByAddingObjectsFromSet:affectingKey];
		return keyPaths;
	}

	return keyPaths;
}




@dynamic contents;






@dynamic title;






@dynamic type;



- (int16_t)typeValue {
	NSNumber *result = [self type];
	return [result shortValue];
}

- (void)setTypeValue:(int16_t)value_ {
	[self setType:[NSNumber numberWithShort:value_]];
}

- (int16_t)primitiveTypeValue {
	NSNumber *result = [self primitiveType];
	return [result shortValue];
}

- (void)setPrimitiveTypeValue:(int16_t)value_ {
	[self setPrimitiveType:[NSNumber numberWithShort:value_]];
}










@end
