//
//  NS2DArray.h
//  DungeonCrawler
//
//  Created by Steven Troughton-Smith on 12/07/2012.
//  Copyright (c) 2012 High Caffeine Content. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef struct _NS2DPoint {
	NSInteger x;
	NSInteger y;
} NS2DPoint;

inline NS2DPoint NS2DPointMake(NSInteger x, NSInteger y);

@interface NS2DArray : NSObject
{
	NSMutableArray *storage;
}

-(id)initWithSize:(CGSize)size;
-(id)objectAtPosition:(NS2DPoint)pos;
-(void)setObject:(id)obj atPosition:(NS2DPoint)pos;
- (NSMutableArray *)objectAtIndexedSubscript:(NSUInteger)idx;
- (void)setObject:(id)obj atIndexedSubscript:(NSUInteger)idx;
@end
