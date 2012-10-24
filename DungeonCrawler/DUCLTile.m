//
//  DUCLTile.m
//  DungeonCrawler
//
//  Created by Steven Troughton-Smith on 20/06/2012.
//  Copyright (c) 2012 High Caffeine Content. All rights reserved.
//

#import "DUCLTile.h"

#define flipOffset 0.0

#if !USE_SDL
extern NSImage *terrainSheet;

#else

#undef flipOffset
#define flipOffset 15.-

extern SDL_Surface* tilemapSurface;

#endif

#define SMOOTH_EDGES 0

TileImageMap TileImageMapWater = {.position = {4,flipOffset+13}};
TileImageMap TileImageMapDirt = {.position = {1, flipOffset+13}};
TileImageMap TileImageMapGrass = {.position = {0, flipOffset+15}};
TileImageMap TileImageMapTree = {.position = {0, flipOffset+4}};
TileImageMap TileImageMapLongGrass = {.position = {1, flipOffset+15}};
TileImageMap TileImageMapFlower = {.position = {2, flipOffset+15}};

Tile1x2ImageMap TileImageMapStargate = {
	.top = {11,flipOffset+15},
	.bottom = {11,flipOffset+14},
};

Tile1x2ImageMap TileImageMapStargateInactive = {
	.top = {12,flipOffset+15},
	.bottom = {12,flipOffset+14},
};

Tile9PartImageMap TileImageMapHouse = {
	.tl = {0,flipOffset+6},
	.tc = {1,flipOffset+6},
	.tr = {2,flipOffset+6},
	
	.cl = {3,flipOffset+6},
	.cc = {4,flipOffset+5},
	.cr = {4,flipOffset+6},
	
	.bl = {0,flipOffset+5},
	.bc = {3,flipOffset+5},
	.br = {2,flipOffset+5},
};

@implementation DUCLTile


#if USE_SDL
-(void)draw:(SDL_Surface *)screen translation:(CGPoint)translation

#else
-(void)draw
#endif
{
	
	if (self.type == TileBlank)
		return;
	
	CGPoint tileMapPosition = TileImageMapGrass.position;
	
	if (self.type == TileGrass)
	{
		
#if SMOOTH_EDGES
		BOOL u = !TileAt(self.position.x, self.position.y - 1).connectsToWater;
		BOOL d = !TileAt(self.position.x, self.position.y + 1).connectsToWater;
		BOOL l = !TileAt(self.position.x - 1, self.position.y).connectsToWater;
		BOOL r = !TileAt(self.position.x + 1, self.position.y).connectsToWater;
		
		
		tileMapPosition = CGPointMake(0, 15);
		
		if (u && l)
		{
			tileMapPosition = CGPointMake(5, 14);
		}
		
		if (u && r)
		{
			tileMapPosition = CGPointMake(3, 14);
		}
		
		
		if (d && l){
			tileMapPosition = CGPointMake(5, 12);
			
		}
		
		if (d && r)
		{
			tileMapPosition = CGPointMake(3, 12);
		}
		
		
#endif
		
		
	}
	else if (self.type == TileTree)
	{
		
		
		tileMapPosition = TileImageMapTree.position;
		
		/*
		NSRect imageRect = CGRectMake((1+tileMapPosition.x*TILE_SIZE)+tileMapPosition.x, (1+tileMapPosition.y)+tileMapPosition.y*TILE_SIZE, TILE_SIZE, TILE_SIZE);
		
		[terrainSheet drawAtPoint:CGPointZero fromRect:imageRect operation:NSCompositeSourceOver fraction:1.0];*/

	}
	else if (self.type == TileDirt)
	{
		BOOL u = !TileAt(self.position.x, self.position.y - 1).connectsToWater;
		BOOL d = !TileAt(self.position.x, self.position.y + 1).connectsToWater;
		BOOL l = !TileAt(self.position.x - 1, self.position.y).connectsToWater;
		BOOL r = !TileAt(self.position.x + 1, self.position.y).connectsToWater;
		
		tileMapPosition = TileImageMapDirt.position;
	}
	else if (self.type == TileWater)	// Water
	{
		
		BOOL u = !TileAt(self.position.x, self.position.y - 1).connectsToWater;
		BOOL d = !TileAt(self.position.x, self.position.y + 1).connectsToWater;
		BOOL l = !TileAt(self.position.x - 1, self.position.y).connectsToWater;
		BOOL r = !TileAt(self.position.x + 1, self.position.y).connectsToWater;
		
		tileMapPosition = TileImageMapWater.position;
		
		if (self.gametick == 0)
		{
			tileMapPosition = CGPointMake(4, flipOffset+13);
		}
		else if (self.gametick == 1)
		{
			tileMapPosition = CGPointMake(9, flipOffset+15);
		}
		else if (self.gametick == 2)
		{
			tileMapPosition = CGPointMake(10, flipOffset+15);
		}
		
		/*
		if (!u && !l)
		{
			tileMapPosition = CGPointMake(4, 14);
		}
		else
		{
			tileMapPosition = CGPointMake(l? 5 : 4, u? 14 : 13);
		}
		
		
		if (!u && !r)
		{
			tileMapPosition = CGPointMake(4, 14);
		}
		else
		{
			tileMapPosition = CGPointMake(r? 3 : 4, u? 14 : 13);
		}
		
		
		if (!d && !l)
		{
			tileMapPosition = CGPointMake(4, 12);
		}
		else
		{
			tileMapPosition = CGPointMake(l? 5 : 4, d ? 12 : 13);
		}
		
		
		if (!d && !r)
		{
			tileMapPosition = CGPointMake(4, 12);
		}
		else
		{
			tileMapPosition = CGPointMake(r? 3 : 4, d? 12 : 13);
		}
		*/
		
		
	}
	else if (self.type >= TileHouse1 && self.type <= TileHouse9)
	{
		
		switch (self.type) {
			case TileHouse1:
				tileMapPosition = TileImageMapHouse.bl;
				break;
			case TileHouse2:
				tileMapPosition = TileImageMapHouse.bc;
				break;
			case TileHouse3:
				tileMapPosition = TileImageMapHouse.br;
				break;
				
			case TileHouse4:
				tileMapPosition = TileImageMapHouse.cl;
				break;
			case TileHouse5:
				tileMapPosition = TileImageMapHouse.cc;
				break;
			case TileHouse6:
				tileMapPosition = TileImageMapHouse.cr;
				break;
				
			case TileHouse7:
				tileMapPosition = TileImageMapHouse.tl;
				break;
			case TileHouse8:
				tileMapPosition = TileImageMapHouse.tc;
				break;
			case TileHouse9:
				tileMapPosition = TileImageMapHouse.tr;
				break;
				
			default:
				break;
		}
			
	}
	else if (self.type == TileLongGrass)
	{
		tileMapPosition = TileImageMapLongGrass.position;
		
	}
	else if (self.type == TileFlower)
	{
		tileMapPosition = TileImageMapFlower.position;
	}
	else if (self.type >= TileStargate1 && self.type <= TileStargate2)
	{
		Tile1x2ImageMap sgMap;
		if (self.gametick == 0)
		{
			 sgMap = TileImageMapStargate;
		}
		else if (self.gametick == 1)
		{
			 sgMap = TileImageMapStargateInactive;
		}
		else if (self.gametick == 2)
		{
			 sgMap = TileImageMapStargate;
		}
		
		
		
		
		
		if (self.type == TileStargate1)
			tileMapPosition = sgMap.top;
		else
			tileMapPosition = sgMap.bottom;

	}
	
	
#if USE_SDL
	
	SDL_Rect imageRect = {(1+tileMapPosition.x*TILE_SIZE)+tileMapPosition.x, (1+tileMapPosition.y)+tileMapPosition.y*TILE_SIZE, TILE_SIZE, TILE_SIZE };
	
	SDL_Rect destRect = { translation.x, translation.y, TILE_SIZE, TILE_SIZE};
	
	SDL_BlitSurface(tilemapSurface, &imageRect, screen, &destRect);
	
#else
	
	
	NSRect imageRect = CGRectMake((1+tileMapPosition.x*TILE_SIZE)+tileMapPosition.x, (1+tileMapPosition.y)+tileMapPosition.y*TILE_SIZE, TILE_SIZE, TILE_SIZE);
	
	CGContextRef context = [NSGraphicsContext currentContext].graphicsPort;
	CGContextSaveGState(context);
#if ISOMETRIC

	CGContextScaleCTM(context, 1.0, 0.5);
	CGContextRotateCTM(context, M_PI_4);
#endif
	
	[terrainSheet drawAtPoint:CGPointZero fromRect:imageRect operation:NSCompositeSourceOver fraction:1.0];
	
	CGContextRestoreGState(context);
	
	if (self.highlighted)
	{
		if (self.type >= TileWater && self.type <= TileHouse9)
		{
			[[NSColor colorWithCalibratedRed:1 green:0 blue:0 alpha:0.5] set];
			
		}
		else
			[[NSColor colorWithCalibratedRed:0 green:1 blue:0 alpha:0.5] set];
		
		NSRectFillUsingOperation(CGRectMake(0, 0, TILE_SIZE, TILE_SIZE), NSCompositeSourceOver);
	}
#endif
}

@end
