// DO NOT EDIT. This file is machine-generated and constantly overwritten.
// Make changes to Ebook.h instead.

#import <CoreData/CoreData.h>


extern const struct EbookAttributes {
	__unsafe_unretained NSString *contents;
	__unsafe_unretained NSString *title;
	__unsafe_unretained NSString *type;
} EbookAttributes;

extern const struct EbookRelationships {
} EbookRelationships;

extern const struct EbookFetchedProperties {
} EbookFetchedProperties;






@interface EbookID : NSManagedObjectID {}
@end

@interface _Ebook : NSManagedObject {}
+ (id)insertInManagedObjectContext:(NSManagedObjectContext*)moc_;
+ (NSString*)entityName;
+ (NSEntityDescription*)entityInManagedObjectContext:(NSManagedObjectContext*)moc_;
- (EbookID*)objectID;





@property (nonatomic, strong) NSData* contents;



//- (BOOL)validateContents:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSString* title;



//- (BOOL)validateTitle:(id*)value_ error:(NSError**)error_;





@property (nonatomic, strong) NSNumber* type;



@property int16_t typeValue;
- (int16_t)typeValue;
- (void)setTypeValue:(int16_t)value_;

//- (BOOL)validateType:(id*)value_ error:(NSError**)error_;






@end

@interface _Ebook (CoreDataGeneratedAccessors)

@end

@interface _Ebook (CoreDataGeneratedPrimitiveAccessors)


- (NSData*)primitiveContents;
- (void)setPrimitiveContents:(NSData*)value;




- (NSString*)primitiveTitle;
- (void)setPrimitiveTitle:(NSString*)value;




- (NSNumber*)primitiveType;
- (void)setPrimitiveType:(NSNumber*)value;

- (int16_t)primitiveTypeValue;
- (void)setPrimitiveTypeValue:(int16_t)value_;




@end
