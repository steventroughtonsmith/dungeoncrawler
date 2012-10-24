//
//  DUCLMob.m
//  DungeonCrawler
//
//  Created by Steven Troughton-Smith on 20/06/2012.
//  Copyright (c) 2012 High Caffeine Content. All rights reserved.
//

#import "DUCLMob.h"



@implementation DUCLMob

#if USE_SDL
-(void)draw:(SDL_Surface *)screen translation:(CGPoint)translation

#else
-(void)draw
#endif
{

	// left to subclasses

}

@end
