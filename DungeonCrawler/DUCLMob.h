//
//  DUCLMob.h
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
@interface DUCLMob : NSObject
{
	CGPoint lastKnownDirection;
	CGPoint lastDrawPosition;

}

@property (assign) CGPoint position;
@property (assign) CGPoint desiredPosition;
@property (assign) CGPoint direction;
@property (assign) int step;
@property (assign) int type;
@property (assign) BOOL moving;
@property (assign) int health;

#if USE_SDL
-(void)draw:(SDL_Surface *)screen translation:(CGPoint)translation;

#else
-(void)draw;
#endif
@end
