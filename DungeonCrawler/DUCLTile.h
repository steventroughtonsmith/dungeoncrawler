//
//  DUCLTile.h
//  DungeonCrawler
//
//  Created by Steven Troughton-Smith on 20/06/2012.
//  Copyright (c) 2012 High Caffeine Content. All rights reserved.
//

#import <Foundation/Foundation.h>

#if USE_SDL
#include <SDL.h>
#include <SDL_image/SDL_image.h>
#endif

typedef enum _TileType {
	TileBlank = -1,
	TileWater = 0,
	TileTree,
	
	TileHouse1,
	TileHouse2,
	TileHouse3,
	TileHouse4,
	TileHouse5,
	TileHouse6,
	TileHouse7,
	TileHouse8,
	TileHouse9,
	
	TileStargate1,
	TileStargate2,
	
	TileCollidable,
	TileGrass,
	TileLongGrass,
	TileFlower,
	TileDirt,
	TileRock,
	TileSand
}TileType;

typedef struct _TileImageMap
{
	CGPoint position;
}TileImageMap;

typedef struct _Tile1x2ImageMap
{
	CGPoint top;
	CGPoint bottom;
} Tile1x2ImageMap;

typedef struct _Tile9PartImageMap
{
	CGPoint tl;
	CGPoint tc;
	CGPoint tr;

	CGPoint cl;
	CGPoint cc;
	CGPoint cr;

	CGPoint bl;
	CGPoint bc;
	CGPoint br;

}Tile9PartImageMap;

typedef struct _Tile6PartImageMap
{
	CGPoint tl;
	CGPoint tc;
	CGPoint tr;
	
	CGPoint bl;
	CGPoint bc;
	CGPoint br;
	
}Tile6PartImageMap;

@interface DUCLTile : NSObject
@property (assign) TileType type;
@property (assign) BOOL connectsToWater;
@property (assign) BOOL connectsToRock;
@property (assign) BOOL collision;
@property (assign) BOOL highlighted;

@property (assign) CGPoint position;

@property (assign) int gametick;
@property (assign) CGFloat elevation;

#if USE_SDL
-(void)draw:(SDL_Surface *)screen translation:(CGPoint)translation;

#else
-(void)draw;
#endif
@end

DUCLTile * TileAt(int x, int y);
