//
//  DUCLGameEngine.m
//  DungeonCrawler
//
//  Created by Steven Troughton-Smith on 17/07/2012.
//  Copyright (c) 2012 High Caffeine Content. All rights reserved.
//

#import "DUCLGameEngine.h"
#import "AStar.h"

#import "DUCLMob.h"
#import "DUCLPlayer.h"
#import "DUCLZombie.h"

#import "DUCLTile.h"

#import "OBLevelGenerator.h"

#import "NS2DArray.h"

#import "hqx.h"

#import "DDHidLib.h"

CGSize viewportSize = {256, 256};

#define DRAW_MINIMAP 0
#define DESIRED_FPS 60.0
#define NOCLIP 0
#define USE_LEVEL_GENERATOR 1
#define USE_HQ2X 0

#define DRAW_MOBS 1
#define USE_MOBS 1
#define USE_ZOMBIES 0

typedef struct _Keyboard
{
	BOOL up;
	BOOL down;
	BOOL left;
	BOOL right;
	BOOL run;
	
} Keyboard;

Keyboard keyboard;

typedef struct {
    int x;
    int y;
} PathNode;


SDL_Color SDLColorMake(int r, int g, int b);
SDL_Color SDLColorMakeF(CGFloat r, CGFloat g, CGFloat b);

Uint32 GetPixel(SDL_Surface *screen, int x, int y);

void SetPixel(SDL_Surface *screen, int x, int y, Uint32 pixel);

DUCLMob* player;

DUCLTile * TileAt(int x, int y)
{
	NS2DArray *gameWorld = gameWorldLayers[GameWorldLayerMap];
	
	if (x >= 0 && x < MAP_WIDTH && y >= 0 && y < MAP_HEIGHT) {
		
		DUCLTile * t = gameWorld[x][y];
		
		return t;
	}
	
	return nil;
}

static int ShouldCollideAt(int x, int y)
{
	
	NS2DArray *gameWorld = gameWorldLayers[GameWorldLayerMap];
	NS2DArray *gameWorldOverlays = gameWorldLayers[GameWorldLayerOverlays];
	
	if (x >= 0 && x < MAP_WIDTH && y >= 0 && y < MAP_HEIGHT) {
		
		BOOL tile = ((DUCLTile *)gameWorld[x][y]).collision;
		
		BOOL overlay = ((DUCLTile *)gameWorldOverlays[x][y]).collision;
		
		return (tile || overlay);
	}
	
	return YES;
}

static void PathNodeNeighbors(ASNeighborList neighbors, void *node, void *context)
{
    const PathNode *pathNode = (const PathNode *)node;
	
    if (!ShouldCollideAt(pathNode->x+1, pathNode->y)) {
        ASNeighborListAdd(neighbors, &(PathNode){pathNode->x+1, pathNode->y}, 1);
    }
    if (!ShouldCollideAt(pathNode->x-1, pathNode->y)) {
        ASNeighborListAdd(neighbors, &(PathNode){pathNode->x-1, pathNode->y}, 1);
    }
    if (!ShouldCollideAt(pathNode->x, pathNode->y+1)) {
        ASNeighborListAdd(neighbors, &(PathNode){pathNode->x, pathNode->y+1}, 1);
    }
    if (!ShouldCollideAt(pathNode->x, pathNode->y-1)) {
        ASNeighborListAdd(neighbors, &(PathNode){pathNode->x, pathNode->y-1}, 1);
    }
}

static float PathNodeHeuristic(void *fromNode, void *toNode, void *context)
{
    const PathNode *from = (const PathNode *)fromNode;
    const PathNode *to = (const PathNode *)toNode;
	
    // using the manhatten distance since this is a simple grid and you can only move in 4 directions
    return (fabs(from->x - to->x) + fabs(from->y - to->y));
}

static const ASPathNodeSource PathNodeSource =
{
    sizeof(PathNode),
    &PathNodeNeighbors,
    &PathNodeHeuristic,
    NULL,
    NULL
};


@implementation DUCLGameEngine

- (id)init
{
    self = [super init];
    if (self) {
        NS2DArray *gameWorld = nil;
		NS2DArray *gameWorldOverlays = nil;
		
		gameWorldLayers = [[NSMutableArray alloc ] initWithCapacity:3];
		gameWorld = [[NS2DArray alloc] initWithSize:CGSizeMake(MAP_WIDTH, MAP_HEIGHT)];
		gameWorldOverlays = [[NS2DArray alloc] initWithSize:CGSizeMake(MAP_WIDTH, MAP_HEIGHT)];
		
		NS2DArray *gameWorldElevation = [[NS2DArray alloc] initWithSize:CGSizeMake(MAP_WIDTH, MAP_HEIGHT)];
		

		
		gameWorldLayers[GameWorldLayerMap] = gameWorld;
		gameWorldLayers[GameWorldLayerElevation] = gameWorldElevation;
		gameWorldLayers[GameWorldLayerOverlays] = gameWorldOverlays;
		
		player = [[DUCLPlayer alloc] init];
		player.health = 100;
		
		
		self.mobs = [[NSMutableArray alloc] initWithArray:@[ player ]];
		
		[self generateMapWithScale:1.];
		
//		[NSTimer scheduledTimerWithTimeInterval:1./DESIRED_FPS target:self selector:@selector(tick) userInfo:nil repeats:YES];
		
		
		
    }
    return self;
}

-(void)generateMapWithScale:(CGFloat)scale
{

	OBLevelGenerator *levelGen = [[OBLevelGenerator alloc] init];
	
	NS2DArray *gameWorld = gameWorldLayers[GameWorldLayerMap];
	NS2DArray *gameWorldOverlays = gameWorldLayers[GameWorldLayerOverlays];
	
	
		
	[levelGen gen:16];
	
	player.direction = CGPointMake(0, -1);
	player.direction = CGPointMake(0, 0);
	
	//	player.position = CGPointMake(floor(MAP_WIDTH/2), floor(MAP_HEIGHT/2));
	
	BOOL placedPlayer = NO;
	
	
	for (int y = 0; y < MAP_HEIGHT; y++){
		for (int x = 0; x < MAP_WIDTH; x++){
			
			__strong DUCLTile * tile = [[DUCLTile alloc] init];
			tile.position = CGPointMake(x, y);
			tile.connectsToWater = NO;
			
			DUCLTile *elevation = [[DUCLTile alloc] init];
			elevation.type = TileBlank;
			elevation.position = CGPointMake(x, y);
			elevation.collision = NO;
			
			double gen = [levelGen valueForX:x Y:y];
			
			tile.elevation = (CGFloat)gen;
			
			if (gen > 160)
			{
				elevation.type = TileGrass;
			}
			
			if (gen > 110 && gen < 130)
			{
				tile.type = TileDirt;
				tile.collision = NO;
			}
			else if (gen >= 130 && gen < 200)
			{
				if (!placedPlayer)
				{
					
					if (x > MAP_WIDTH/2 && x < MAP_WIDTH && y > MAP_HEIGHT/2 && y < MAP_HEIGHT)
					{
						player.position = CGPointMake(x, y);
						player.desiredPosition = player.position;
						
						DUCLTile *starGate1 = [DUCLTile new];
						
						starGate1.type = TileStargate1;
						starGate1.collision = YES;
						
						DUCLTile *starGate2 = [DUCLTile new];
						
						starGate2.type = TileStargate2;
						starGate2.collision = YES;
						
						gameWorldOverlays[x][y-1] = starGate1;
						gameWorldOverlays[x][y-0] = starGate2;
						
						placedPlayer = YES;
						
						
						player.direction = CGPointMake(0, -1);
						player.desiredPosition = CGPointMake(x, y+1);
						player.moving = YES;
						
						double delayInSeconds = 0.5;
						dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, delayInSeconds * NSEC_PER_SEC);
						dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
							player.direction = CGPointZero;
							player.moving = NO;
						});
						
					}
				}
				tile.type = TileGrass;
				tile.collision = NO;
				
				
				
				
				
				if (arc4random()%64 == 16)
				{
					DUCLTile *flourishTile = [[DUCLTile alloc] init];
					
					if(arc4random()%2 == 0)
					{
						flourishTile.type = TileLongGrass;
					}
					else
					{
						flourishTile.type = TileFlower;
					}
					
					
					flourishTile.collision = NO;
					flourishTile.position = tile.position;
					
					if (!gameWorldOverlays[x][y])
						gameWorldOverlays[x][y] = flourishTile;
					
				}
				
				
				
			}
			else if (gen >= 200)
			{
				tile.type = TileTree;
				tile.collision = YES;
			}
			else
			{
				tile.type = TileWater;
				tile.collision = YES;
			}
			
			
			if (tile.type != TileTree)
			{
				gameWorld[x][y] = tile;
				
								
			}
			else
			{
				DUCLTile *underneath = [[DUCLTile alloc] init];
				
				underneath.type = TileGrass;
				underneath.collision = YES;
				underneath.position = CGPointMake(x, y);
				
				
				gameWorld[x][y] = underneath;
				
				if (!gameWorldOverlays[x][y])
					gameWorldOverlays[x][y] = tile;
			}
			
			//			[gameWorldLayers[GameWorldLayerElevation] setObject:elevation atPosition:NS2DPointMake(x, y)];
			
			
#if USE_ZOMBIES
			if (!tile.collision && arc4random()%1024 == 16)
			{
				DUCLZombie *zombie = [[DUCLZombie alloc] init];
				zombie.position = CGPointMake(x, y);
				zombie.health = 100;
				
				[self.mobs addObject:zombie];
			}
#endif
		}
	}
	
	DUCLTile *temp = gameWorld[0][1];
	
	NSLog(@"test = %f, %f", temp.position.x , temp.position.y);
	

	
	/* Water Pass */
	for (int y = 0; y < MAP_HEIGHT; y++){
		for (int x = 0; x < MAP_WIDTH; x++){
			
			DUCLTile * tile = gameWorld[x][y];
			
			if (tile.type != TileWater)
				tile.connectsToWater = [self connectsToWaterForX:x Y:y];
		}
	}
	

}


-(BOOL)connectsToWaterForX:(int)x Y:(int)y
{
	NS2DArray *gameWorld = gameWorldLayers[GameWorldLayerMap];
	
	return NO;
		
	if (x >= 0 && x < MAP_WIDTH && y >= 0 && y < MAP_HEIGHT) {
		
		if (((DUCLTile *)gameWorld[x+1][y]).type == TileWater)
		{
			return YES;
		}
		
		if (((DUCLTile *)gameWorld[x+1][y+1]).type == TileWater)
		{
			return YES;
		}
		
		if (((DUCLTile *)gameWorld[x][y+1]).type == TileWater)
		{
			return YES;
		}
		
		if (((DUCLTile *)gameWorld[x-1][y]).type == TileWater)
		{
			return YES;
		}
		
		if (((DUCLTile *)gameWorld[x-1][y-1]).type == TileWater)
		{
			return YES;
		}
		
		if (((DUCLTile *)gameWorld[x][y-1]).type == TileWater)
		{
			return YES;
		}
	}
	
	return NO;
}


int gametick = 0;

int frames = 0;

NSTimeInterval lastTick = 0;
NSTimeInterval lastFrame = 0;

-(void)tick
{
	NSTimeInterval _start = [NSDate timeIntervalSinceReferenceDate];
	
	NSTimeInterval actualFrame = [NSDate timeIntervalSinceReferenceDate]-lastFrame;
	
	if (actualFrame >= 1.0)
	{
		printf("\nFPS = %f", (CGFloat)frames*1.0/actualFrame);
		
		//		self.fpsLabel.stringValue  = [NSString stringWithFormat:@"%.0ffps", (CGFloat)frames*1.0/actualFrame];
		lastFrame = [NSDate timeIntervalSinceReferenceDate];
		
		frames = 0;
	}
	
	[self calculateMobPosition];
	
#if USE_MOBS
	if (_start-lastTick > 0.15)
#endif
		[self calculatePlayerPosition];
	
#if USE_ZOMBIES
	[self calculateAI];
#endif
	if (_start-lastTick > 0.3)
	{
		gametick++;
		
		if (gametick == 2)
			gametick = 0;
		
		
		NSTimeInterval _end = [NSDate timeIntervalSinceReferenceDate];
		lastTick = _end;
	}
		
	frames++;
}

BOOL seesYou = NO;

NSTimeInterval lastMobPositionTick = 0;

-(void)calculatePlayerPosition
{
	
	CGPoint newPlayerPos = CGPointMake(round(player.position.x), round(player.position.y));
	CGPoint newPlayerDirection = CGPointZero;
	
	CGFloat distanceDelta = 1.;
	
	if (keyboard.right)
	{
		newPlayerPos.x+=distanceDelta;
		newPlayerDirection = CGPointMake(1, 0);
	}
	
	else if (keyboard.left)
	{
		
		newPlayerPos.x -=distanceDelta;
		newPlayerDirection = CGPointMake(-1, 0);
	}
	
	else if (keyboard.up)
	{
		
		newPlayerPos.y -=distanceDelta;
		newPlayerDirection = CGPointMake(0, 1);
	}
	
	else if (keyboard.down)
	{
		newPlayerPos.y+=distanceDelta;
		newPlayerDirection = CGPointMake(0, -1);
	}
	
	player.direction = newPlayerDirection;
	
	player.moving = YES;
	
	if ([self canMob:player moveToPosition:newPlayerPos])
		player.desiredPosition = newPlayerPos;
}

-(void)calculateMobPosition
{
	
	BOOL _animate = NO;
	
	if ([NSDate timeIntervalSinceReferenceDate]-lastMobPositionTick > 1.0/7.)
	{
		_animate = YES;
		
		
		
		
		lastMobPositionTick = [NSDate timeIntervalSinceReferenceDate];
	}
	
	for (DUCLMob *mob in self.mobs)
	{
		
#if USE_MOBS
		
		CGFloat newX = mob.position.x + mob.direction.x/TILE_SIZE;
		CGFloat newY = mob.position.y + mob.direction.y/TILE_SIZE;
		
		if (keyboard.run && [mob isEqual:player])
		{
			newX = mob.position.x + (mob.direction.x/TILE_SIZE)*2;
			newY = mob.position.y + (mob.direction.y/TILE_SIZE)*2;
		}
		
#else
		CGFloat newX = mob.position.x + (mob.direction.x/TILE_SIZE)*4;
		CGFloat newY = mob.position.y + (mob.direction.y/TILE_SIZE)*4;
#endif
		
		BOOL gotThereX = NO;
		BOOL gotThereY = NO;
		
		if (mob.direction.x < 0)
		{
			if (mob.position.x <= mob.desiredPosition.x)
				gotThereX = YES;
		}
		else if (mob.direction.x > 0)
		{
			
			if (mob.position.x >= mob.desiredPosition.x)
				gotThereX = YES;
		}
		
		if (mob.direction.y < 0)
		{
			if (mob.position.y <= mob.desiredPosition.y)
				gotThereY = YES;
		}
		else if (mob.direction.y > 0)
		{
			if (mob.position.y >= mob.desiredPosition.y)
				gotThereY = YES;
		}
		
		if (!gotThereX && !gotThereY)
			mob.position = CGPointMake(newX, newY);
		else
		{
			mob.position = mob.desiredPosition;
			mob.direction = CGPointZero;
		}
		
		//		NSLog(@"MobPos = {%f, %f} - desired = {%f, %f}", mob.position.x, mob.position.y, mob.desiredPosition.x, mob.desiredPosition.y);
		
		if (_animate)
			mob.step++;
	}
}

-(void)calculateAI
{
	for (DUCLMob *mob in self.mobs)
	{
		if ([mob isEqual:player])
			continue;
		
		dispatch_async(dispatch_get_global_queue(0, 0), ^{
			PathNode pathFrom = {mob.position.x,mob.position.y};
			PathNode pathTo = {player.position.x,player.position.y};
			
			ASPath path = ASPathCreate(&PathNodeSource, NULL, &pathFrom, &pathTo);
			if (ASPathGetCount(path) > 1) {
				
				for (int i=1; i<ASPathGetCount(path); i++) {
					const PathNode *pathNode = ASPathGetNode(path, i);
					if (ASPathGetCount(path) < 15)
					{
						seesYou = YES;
						
						if (1)//arc4random()%2 == 1)
						{
							
							CGPoint currentPosition = CGPointMake(floor(mob.position.x), floor(mob.position.y));
							CGPoint desiredPosition = CGPointMake(pathNode->x, pathNode->y);
							
							if ([self canMob:mob moveToPosition:desiredPosition])
							{
								//mob.position = desiredPosition;
								mob.desiredPosition = desiredPosition;
								mob.moving = YES;
							}
							
							if (currentPosition.x > desiredPosition.x)
								mob.direction = CGPointMake(-1, 0);
							else if (currentPosition.x < desiredPosition.x)
								mob.direction = CGPointMake(1, 0);
							
							if (currentPosition.y > desiredPosition.y)
								mob.direction = CGPointMake(0,1);
							else if (currentPosition.y < desiredPosition.y)
								mob.direction = CGPointMake(0,-1);
						}
						else{
							mob.moving = NO;
							
						}
						
					}
					else
					{
						seesYou = NO;
						mob.moving = NO;
					}
					
					break;
					
				}
				
				ASPathDestroy(path);
			}
			
		});
	}
}

-(BOOL)canMob:(DUCLMob *)mob moveToPosition:(CGPoint)pos
{
	NS2DArray *gameWorld = gameWorldLayers[GameWorldLayerMap];
	NS2DArray *gameWorldOverlays = gameWorldLayers[GameWorldLayerOverlays];
	
#if NOCLIP
	
	if ([mob isEqual:player])
	{
		if (pos.x > 0 && pos.x < MAP_WIDTH && pos.y > 0 && pos.y < MAP_HEIGHT) {
			return YES;
			
		}
	}
#endif
	
	if (pos.x > 0 && pos.x < MAP_WIDTH && pos.y > 0 && pos.y < MAP_HEIGHT) {
		
		if (((DUCLTile *)gameWorld[(NSUInteger)pos.x][(NSUInteger)pos.y]).collision == NO)
		{
			for (DUCLMob *m in self.mobs)
			{
				if (m != mob && CGPointEqualToPoint(pos, m.desiredPosition))
					return NO;
			}
			
			DUCLTile *overlayTile = ((DUCLTile *)gameWorldOverlays[(NSUInteger)pos.x][(NSUInteger)pos.y]);
			if (overlayTile && overlayTile.collision == YES)
			{
				return NO;
				
			}
			
			
			return YES;
		}
	}
	
	return NO;
}

-(void)drawGame:(SDL_Surface *) screen
{
	return;
	if(SDL_MUSTLOCK(screen))
    {
        if(SDL_LockSurface(screen) < 0) return;
    }
	
	int bgColor = SDL_MapRGB(screen->format, 0, 0, 0);
    SDL_Rect screenRect = { 0, 0, screen->w, screen->h };
    SDL_FillRect(screen, &screenRect, bgColor);
	
	if(SDL_MUSTLOCK(screen)) SDL_UnlockSurface(screen);
	
	
	int offset = (viewportSize.width/2)/TILE_SIZE;
	
	/*
	 CGFloat xOffset = (-player.position.x+offset);
	 CGFloat yOffset = (-player.position.y+offset);
	 */
	
	CGFloat xOffset = (-player.position.x+offset);
	CGFloat yOffset = (-player.position.y+offset);
	
	int blocksWide = offset;
	int blocksHigh = offset;
	
	/*
	 
	 Centering the map around the player and only drawing $offset tiles each direction.
	 Should only ever draw ($offset*2)^2 tiles
	 
	 */
	
	int elevation = 0;
	
	for (NS2DArray *gameWorldLayer in gameWorldLayers)
	{
		for (int y = player.position.y-blocksHigh; y < player.position.y+blocksHigh; y++)
		{
			for (int x = player.position.x-blocksWide; x < player.position.x+blocksWide; x++)
			{
				if (x >= MAP_WIDTH || x <= 0)
					continue;
				
				if (y >= MAP_HEIGHT || y <= 0)
					continue;
				
#if ISOMETRIC
				CGFloat xPos = -((yOffset+y)*TILE_SIZE/2) + ((xOffset+x)*TILE_SIZE/2);
				CGFloat yPos = ((xOffset+x)*TILE_SIZE/2) + ((yOffset+y)*TILE_SIZE/2);
#else
				CGFloat xPos =(xOffset+x)*TILE_SIZE;
				CGFloat yPos = (yOffset+y)*TILE_SIZE;
#endif
				
				
				DUCLTile *tile = ((DUCLTile *)gameWorldLayer[x][y]);
				
				if (tile && tile.type != TileBlank)
				{
															
					tile.gametick = gametick;
					
					[tile draw:screen translation:CGPointMake(round(xPos), round(yPos))];
					
					
				}
			}
		}
		
		elevation++;
	}
	
	
	/* Simple depth sort - mobs in the background should be underneath foreground mobs */
	
	[self.mobs sortUsingComparator:^NSComparisonResult(DUCLMob* obj1, DUCLMob* obj2) {
		if (obj1.position.y > obj2.position.y)
			return NSOrderedAscending;
		else
			return NSOrderedDescending;
	}];
	
#if DRAW_MOBS
	
	/* Draw ALL the mobs! (including the player) */
	
	for (DUCLMob *mob in self.mobs)
	{
		
		[mob draw:screen translation:CGPointMake(round((xOffset+mob.position.x)*TILE_SIZE), round((yOffset+mob.position.y)*TILE_SIZE))];
		
		
	}
	
#endif
	
	
#if DRAW_MINIMAP
	
	NS2DArray *gameWorld = gameWorldLayers[GameWorldLayerMap];
	NS2DArray *gameWorldOverlays = gameWorldLayers[GameWorldLayerOverlays];
	
	
	/* Draw minimap */
	int scale = MINIMAP_ZOOM_SCALE;
	
	//	CGContextTranslateCTM(context, viewportSize.width-(MAP_WIDTH/scale)-2, viewportSize.height-(MAP_HEIGHT/scale)-2);
	
	
	for (int yy = 0; yy < MAP_HEIGHT; yy+=scale){
		for (int xx = 0; xx < MAP_WIDTH; xx+=scale){
			
			int x =  (viewportSize.width-(MAP_WIDTH/scale)-2)+xx/scale;
			int y = (viewportSize.height-(MAP_HEIGHT/scale)-2)+yy/scale;
			
			DUCLTile * tile = ((DUCLTile *)gameWorld[x][y]);
			
			TileType gen = tile.type;
			TileType overlayGen = ((DUCLTile *)gameWorldOverlays[x][y]).type;
			
			if (overlayGen)
				gen = overlayGen;
			
			SDL_Color nscolor;
			
			SDL_Color grassColor = SDLColorMakeF(0.514, 0.800, 0.475);
			SDL_Color mudColor = SDLColorMakeF(0.676, 0.577, 0.412);
			SDL_Color treeColor = SDLColorMakeF(0.388, 0.588, 0.188);
			SDL_Color waterColor = SDLColorMakeF(0.227, 0.482, 0.557);
			SDL_Color whiteColor = SDLColorMakeF(1.0, 1.0, 1.0);
			
			
			if (gen == TileDirt)
			{
				nscolor = mudColor;
			}
			else if (gen == TileGrass || gen == TileFlower || gen == TileLongGrass)
			{
				nscolor = grassColor;
			}
			else if (gen == TileTree)
			{
				nscolor = treeColor;
			}
			else if (gen >= TileHouse1 && gen < TileCollidable)
			{
				nscolor = waterColor;
			}
			else
			{
				nscolor = waterColor;
			}
			
			
			/*
			 for (DUCLMob *mob in self.mobs)
			 {
			 if (x == (int)mob.position.x && y == (int)mob.position.y)
			 {
			 [[NSColor redColor] set];
			 }
			 }*/
			
			if (x == (int)player.position.x/scale && y == (int)player.position.y/scale)
			{
				nscolor = whiteColor;
			}
			
			Uint32 colour;
			
			
			colour = SDL_MapRGB( screen->format, nscolor.r, nscolor.g, nscolor.b );
			
			SetPixel(screen, x, y, colour);
		
		}
	}
	
#endif
	
	SDL_Flip(screen);
	
}

#pragma mark -

#define KEY_RIGHT SDLK_RIGHT
#define KEY_LEFT SDLK_LEFT
#define KEY_UP SDLK_UP
#define KEY_DOWN SDLK_DOWN

-(void)passEvent:(SDL_Event)event
{
	if (event.type == SDL_KEYDOWN)
	{
		[self keyDown:event];
	}
	else if (event.type == SDL_KEYUP)
	{
		[self keyUp:event];
	}
}

-(void)keyUp:(SDL_Event)theEvent
{
	
	switch (theEvent.key.keysym.sym ) {
		case KEY_RIGHT:
			keyboard.right = NO;
			
			break;
		case KEY_LEFT:
			keyboard.left = NO;
			
			break;
		case KEY_UP:
			keyboard.up = NO;
			
			break;
		case KEY_DOWN:
			keyboard.down = NO;
			
			break;
			
		default:
			break;
	}
	
	
	
	player.moving = NO;
	
}

-(void)keyDown:(SDL_Event)theEvent
{
	
	
	switch (theEvent.key.keysym.sym ) {
		case KEY_RIGHT:
			keyboard.right = YES;
			
			break;
		case KEY_LEFT:
			keyboard.left = YES;
			
			break;
		case KEY_UP:
			keyboard.up = YES;
			
			break;
		case KEY_DOWN:
			keyboard.down = YES;
			
			break;
			
		default:
			break;
	}
	
}


@end
