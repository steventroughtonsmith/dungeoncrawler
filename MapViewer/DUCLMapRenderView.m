//
//  DUCLMapRenderView.m
//  DungeonCrawler
//
//  Created by Steven Troughton-Smith on 12/07/2012.
//  Copyright (c) 2012 High Caffeine Content. All rights reserved.
//

#import "DUCLMapRenderView.h"
#import "OBLevelGenerator.h"

double map[MAP_WIDTH][MAP_HEIGHT];

@implementation DUCLMapRenderView

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        OBLevelGenerator *levelGen = [[OBLevelGenerator alloc] init];
		
		[levelGen gen:128];
		for (int y = 0; y < MAP_HEIGHT; y++){
			for (int x = 0; x < MAP_WIDTH; x++){
				
				map[x][y] = [levelGen valueForX:x Y:y];				
			}
		}
	}
	return self;
}

- (void)drawRect:(NSRect)dirtyRect
{
    for (int y = 0; y < MAP_HEIGHT; y++){
		for (int x = 0; x < MAP_WIDTH; x++){
			
			double gen = map[x][y];
			NSColor *nscolor = nil;

			NSColor *grassColor = [NSColor colorWithCalibratedRed:0.514 green:0.800 blue:0.475 alpha:1.000];
			NSColor *mudColor = [NSColor colorWithCalibratedRed:0.676 green:0.577 blue:0.412 alpha:1.000];
			NSColor *treeColor = [NSColor colorWithCalibratedRed:0.388 green:0.588 blue:0.188 alpha:1.000];
			NSColor *waterColor = [NSColor colorWithCalibratedRed:0.227 green:0.482 blue:0.557 alpha:1.000];
			
			if (gen > 110 && gen < 150)
			{
				nscolor = mudColor;
			}
			else if (gen >= 150 && gen < 180)
			{
				nscolor = grassColor;
			}
			else if (gen >= 180)
			{
				nscolor = treeColor;
			}
			else
			{
				nscolor = waterColor;
			}
			
			[nscolor set];
			
			NSRectFill(CGRectMake(x, y, 1, 1));
		}
	}
}

@end
