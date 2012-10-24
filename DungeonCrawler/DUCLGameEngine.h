//
//  DUCLGameEngine.h
//  DungeonCrawler
//
//  Created by Steven Troughton-Smith on 17/07/2012.
//  Copyright (c) 2012 High Caffeine Content. All rights reserved.
//

#import <Foundation/Foundation.h>
#include <SDL.h>
#include <SDL_image/SDL_image.h>

enum GameWorldLayer {
	GameWorldLayerMap = 0,
	GameWorldLayerElevation,
	GameWorldLayerOverlays
};

static	NSMutableArray *gameWorldLayers = nil;

@interface DUCLGameEngine : NSObject

@property (nonatomic, strong) NSMutableArray *mobs;

-(void)drawGame:(SDL_Surface *) screen;
-(void)passEvent:(SDL_Event)event;

-(void)tick;

@end
