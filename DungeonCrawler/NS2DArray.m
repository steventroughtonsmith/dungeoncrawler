//
//  NS2DArray.m
//  DungeonCrawler
//
//  Created by Steven Troughton-Smith on 12/07/2012.
//  Copyright (c) 2012 High Caffeine Content. All rights reserved.
//

#import "NS2DArray.h"

@implementation NS2DArray

NS2DPoint NS2DPointMake(NSInteger x, NSInteger y)
{
	NS2DPoint p;
	
	p.x = x;
	p.y = y;
	
	return p;
}

-(id)initWithSize:(CGSize)size
{
	self = [super init];
    if (self) {
		
		storage = [[NSMutableArray alloc] initWithCapacity:size.height];
		
		for (int i = 0; i < size.height; i++)
		{
			NSMutableArray *line = [[NSMutableArray alloc] initWithCapacity:size.width];
			
			for (int j = 0; j < size.width; j++){
				[line addObject:[NSNull null]];
			}
			
			[storage addObject:line];
		}		
    }
    return self;
}

-(void)setObject:(id)obj atPosition:(NS2DPoint)pos
{
//	[NSException raise:@"NS2DArray setObject:" format:@""];

	if (pos.y >= 0 && pos.y < storage.count)
	{
		storage[pos.x][pos.y] = obj;
	}
}

-(id)objectAtPosition:(NS2DPoint)pos
{
//	[NSException raise:@"NS2DArray objectAtPosition:" format:@""];
	
	if (pos.y >= 0 && pos.y < storage.count)
	{
		if (pos.x >= 0 && pos.x < [storage[pos.y] count])
		{
			id foundObject = storage[pos.x][pos.y];
			
			if (![foundObject isEqual:[NSNull null]])
			{
				return foundObject;
			}
		}
	}
	
	//			[NSException raise:@"NS2DArray objectAtPosition:" format:@"position (%li, %li) is outside of bounds", pos.x, pos.y];


	return nil;
}

- (NSArray *)objectAtIndexedSubscript:(NSUInteger)idx
{
	return [storage objectAtIndexedSubscript:idx];
}

@end
