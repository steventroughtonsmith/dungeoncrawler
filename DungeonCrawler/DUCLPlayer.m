//
//  DUCLPlayer.m
//  DungeonCrawler
//
//  Created by Steven Troughton-Smith on 20/06/2012.
//  Copyright (c) 2012 High Caffeine Content. All rights reserved.
//

#import "DUCLPlayer.h"

#define CHARACTER_WIDTH TILE_SIZE
#define CHARACTER_HEIGHT 20

#define flipOffset 0.0


#if USE_SDL
extern SDL_Surface* characterSheetSurface;
#undef flipOffset
#define flipOffset 11.-

#else
extern NSImage *spriteSheet;
extern NSImage *characterSheet;
#endif

@implementation DUCLPlayer

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
	CGPoint position = CGPointMake(0, 0);
	
	// Horizontal

	if (lastKnownDirection.x > 0.)
	{
		if (self.step == 0|| !self.moving)
			position = CGPointMake(9, flipOffset+0);
		else if (self.step == 1)
			position = CGPointMake(10, flipOffset+0);
		else if (self.step == 2)
			position = CGPointMake(9, flipOffset+0);
		else if (self.step == 3)
			position = CGPointMake(11, flipOffset+0);
		else
			position = CGPointMake(9, flipOffset+0);


		
	}
	else if (lastKnownDirection.x < 0.)
	{
		if (self.step == 0|| !self.moving)
			position = CGPointMake(3, flipOffset+0);
		else if (self.step == 1)
			position = CGPointMake(4, flipOffset+0);
		else if (self.step == 2)
			position = CGPointMake(3, flipOffset+0);

		
		
		else if (self.step == 3)
			position = CGPointMake(5, flipOffset+0);
		else
			position = CGPointMake(3, flipOffset+0);

	}
	
	// Vertical
	

	if (lastKnownDirection.y > 0.)
	{
	
		if (self.step == 0|| !self.moving)
			position = CGPointMake(6, flipOffset+0);
		else if (self.step == 1)
			position = CGPointMake(7, flipOffset+0);
		else if (self.step == 2)
			position = CGPointMake(6, flipOffset+0);

		else if (self.step == 3)
			position = CGPointMake(8, flipOffset+0);
		else
			position = CGPointMake(6, flipOffset+0);


	}
	
	else if (lastKnownDirection.y < 0.)
	{
		
		if (self.step == 0 || !self.moving)
			position = CGPointMake(0, flipOffset+0);
		else if (self.step == 1)
			position = CGPointMake(1, flipOffset+0);
		else if (self.step == 2)
			position = CGPointMake(0, flipOffset+0);
		
		else if (self.step == 3)
			
			position = CGPointMake(2, flipOffset+0);
		else
			position = CGPointMake(0, flipOffset+0);

	}

	
	
	if (position.x == 0 && position.y == 0 && self.direction.x == 0 && self.direction.y == 0)
	{
		position = lastDrawPosition;
	}
	
	if (!self.moving)
	{
		position = CGPointMake(0, flipOffset+0);
		
		if (lastKnownDirection.y > 0.)
		{
			position = CGPointMake(6, flipOffset+0);
		}
		
		if (lastKnownDirection.x < 0.)
		{
			position = CGPointMake(3, flipOffset+0);
		}
		
		if (lastKnownDirection.x > 0.)
			position = CGPointMake(9, flipOffset+0);
	}
	
#if USE_SDL
	
	SDL_Rect imageRect = {(1+position.x*CHARACTER_WIDTH)+position.x, (1+position.y)+position.y*CHARACTER_HEIGHT, CHARACTER_WIDTH, CHARACTER_HEIGHT};
	
	SDL_Rect destRect = { translation.x, translation.y, CHARACTER_WIDTH, CHARACTER_HEIGHT};
	
	SDL_BlitSurface(characterSheetSurface, &imageRect, screen, &destRect);
	
#else
	
	[characterSheet drawInRect:CGRectMake(0, 0, CHARACTER_WIDTH, CHARACTER_HEIGHT) fromRect:CGRectMake((1+position.x*CHARACTER_WIDTH)+position.x, (1+position.y)+position.y*CHARACTER_HEIGHT, CHARACTER_WIDTH, CHARACTER_HEIGHT) operation:NSCompositeSourceOver fraction:1.0];
	
#endif

	lastDrawPosition = position;

	
	int maxSteps = 4;
	
	if (abs(lastKnownDirection.y))
	{
		
		maxSteps = 4;
	}
	
	if (self.step == maxSteps)
		self.step = 0;
	
	
}
@end
