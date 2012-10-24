//
//  DUCLZombie.m
//  DungeonCrawler
//
//  Created by Steven Troughton-Smith on 20/06/2012.
//  Copyright (c) 2012 High Caffeine Content. All rights reserved.
//

#import "DUCLZombie.h"

#define CHARACTER_WIDTH TILE_SIZE
#define CHARACTER_HEIGHT 20
#define flipOffset 0.0;

#if USE_SDL
extern SDL_Surface* characterSheetSurface;
#undef flipOffset
#define flipOffset 11.-
#else
extern NSImage *spriteSheet;
extern NSImage *characterSheet;
#endif

@implementation DUCLZombie

@synthesize direction=_direction;

-(void)setDirection:(CGPoint)d
{
	_direction = d;
	
	if (!CGPointEqualToPoint(d, CGPointZero))
		lastKnownDirection = d;
}

#if USE_SDL
-(void)draw:(SDL_Surface *)screen translation:(CGPoint)translation

#else
-(void)draw
#endif
{
	int row = flipOffset+1;
	
	CGPoint position = CGPointMake(0, row);
	
	if (lastKnownDirection.x > 0.)
	{
		if (self.step == 0|| !self.moving)
			position = CGPointMake(9, row);
		else if (self.step == 1)
			position = CGPointMake(10, row);
		else if (self.step == 2)
			position = CGPointMake(9, row);
		else if (self.step == 3)
			position = CGPointMake(11, row);
		else
			position = CGPointMake(9, row);
		
	}
	else if (lastKnownDirection.x < 0.)
	{
		if (self.step == 0|| !self.moving)
			position = CGPointMake(3, row);
		else if (self.step == 1)
			position = CGPointMake(4, row);
		else if (self.step == 2)
			position = CGPointMake(3, row);
		
		
		
		else if (self.step == 3)
			position = CGPointMake(5, row);
		else
			position = CGPointMake(3, row);
	}
	
	
	if (lastKnownDirection.y > 0.)
	{
		if (self.step == 0|| !self.moving)
			position = CGPointMake(6, row);
		else if (self.step == 1)
			position = CGPointMake(7, row);
		else if (self.step == 2)
			position = CGPointMake(6, row);
		
		else if (self.step == 3)
			position = CGPointMake(8, row);
		
		else
			position = CGPointMake(6, row);
	}
	
	else if (lastKnownDirection.y < 0.)
	{
		
		if (self.step == 0 || !self.moving)
			position = CGPointMake(0, row);
		else if (self.step == 1)
			position = CGPointMake(1, row);
		else if (self.step == 2)
			position = CGPointMake(0, row);
		
		else if (self.step == 3)
			
			position = CGPointMake(2, row);
		else
			position = CGPointMake(0, row);

	}
	
	if (position.x == 0 && position.y == 0 && self.direction.x == 0 && self.direction.y == 0)
	{
		//		NSLog(@"nopos");
		
		
		
	}
	
#if USE_SDL
	
	SDL_Rect imageRect = {(1+position.x*CHARACTER_WIDTH)+position.x, (1+position.y)+position.y*CHARACTER_HEIGHT, CHARACTER_WIDTH, CHARACTER_HEIGHT};
	
	SDL_Rect destRect = { translation.x, translation.y, CHARACTER_WIDTH, CHARACTER_HEIGHT};
	
	SDL_BlitSurface(characterSheetSurface, &imageRect, screen, &destRect);
	
#else
	
	[characterSheet drawInRect:CGRectMake(0, 0, CHARACTER_WIDTH, CHARACTER_HEIGHT) fromRect:CGRectMake((1+position.x*CHARACTER_WIDTH)+position.x, (1+position.y)+position.y*CHARACTER_HEIGHT, CHARACTER_WIDTH, CHARACTER_HEIGHT) operation:NSCompositeSourceOver fraction:1.0];
	
#endif
	
	int maxSteps = 4;
	
	if (abs(lastKnownDirection.y))
	{
		
		maxSteps = 4;
	}
	
	if (self.step == maxSteps)
		self.step = 0;
	
	
}
@end
