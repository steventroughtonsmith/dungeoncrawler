//
//  DUCLGameView.m
//  DungeonCrawler
//
//  Created by Steven Troughton-Smith on 18/06/2012.
//  Copyright (c) 2012 High Caffeine Content. All rights reserved.
//

#import <QuartzCore/QuartzCore.h>
#import "DUCLGameView.h"
#import "AStar.h"

#import "DUCLMob.h"
#import "DUCLPlayer.h"
#import "DUCLZombie.h"

#import "DUCLTile.h"

#import "OBLevelGenerator.h"

#import "NS2DArray.h"

#import "hqx.h"

#import "DDHidLib.h"
#include <mach/mach.h>
#include <mach/mach_time.h>


#define DRAW_MINIMAP 1
#define DESIRED_FPS 30.0
#define NOCLIP 0
#define USE_LEVEL_GENERATOR 1
#define USE_HQ2X 0
#define USE_IOSURFACE 0
#define DRAW_MOBS 1
#define USE_MOBS 0
#define USE_ZOMBIES 0
#define BUILDING_PLACEMENT 0

CGSize viewportSize = {640/2, 480/2};

CGContextRef gameRenderContext;

IOSurfaceRef overlay_surface;

NSImage *spriteSheet = nil;
NSImage *characterSheet = nil;
NSImage *terrainSheet = nil;



BOOL showFPS = YES;

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

DUCLMob* player;

DUCLTile * TileAt(int x, int y)
{
	NS2DArray *gameWorld = gameWorldLayers[GameWorldLayerMap];
	
	if (x >= 0 && x < MAP_WIDTH && y >= 0 && y < MAP_HEIGHT) {
		
		DUCLTile * t = [gameWorld objectAtPosition:NS2DPointMake(x, y)];
		
		return t;
	}
	
	return nil;
}

static int ShouldCollideAt(int x, int y)
{
	NS2DArray *gameWorld = gameWorldLayers[GameWorldLayerMap];
	NS2DArray *gameWorldOverlays = gameWorldLayers[GameWorldLayerOverlays];
	
	if (x >= 0 && x < MAP_WIDTH && y >= 0 && y < MAP_HEIGHT) {
		
		BOOL tile = ((DUCLTile *)[gameWorld objectAtPosition:NS2DPointMake((NSUInteger)x, (NSUInteger)y)]).collision;
		
		BOOL overlay = ((DUCLTile *)[gameWorldOverlays objectAtPosition:NS2DPointMake((NSUInteger)x, (NSUInteger)y)]).collision;
		
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

#if 0
static void RenderPath(void)
{
    ASPath path = ASPathCreate(&PathNodeSource, NULL, &pathFrom, &pathTo);
	
    if (ASPathGetCount(path) > 1) {
        NSBezierPath *line = [NSBezierPath bezierPath];
        NSPoint p;
		
        for (int i=0; i<ASPathGetCount(path); i++) {
            const PathNode *pathNode = ASPathGetNode(path, i);
            p = NSMakePoint((TILE_SIZE / 2.f)+pathNode->x*TILE_SIZE, (TILE_SIZE / 2.f)+pathNode->y*TILE_SIZE);
            //pathNode->x, pathNode->y);
			//
            if (i == 0) {
                [line moveToPoint:p];
            } else {
                [line lineToPoint:p];
            }
			
			
			//			NSLog(@"point = %f, %f", p.x, p.y);
			
			
			//[[NSColor greenColor] set];
			//NSRectFill(CGRectMake(p.x*TILE_SIZE, p.y*TILE_SIZE, TILE_SIZE, TILE_SIZE));
			
			//gameWorld[(int)p.x][(int)p.y] = 2;
		}
		
		CGFloat dash[2];
		
		dash[0] = 2.0;
		dash[1] = 4.0;
		
		[line setLineDash:dash count:2 phase:0.0];
        [line setLineWidth:2];
        [[NSColor whiteColor] setStroke];
		//        [line stroke];
        
        [[NSString stringWithFormat:@"%g", ASPathGetCost(path)] drawAtPoint:p withAttributes:nil];
    }
    
    ASPathDestroy(path);
}
#endif

@implementation DUCLGameView

- (id)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
		
		renderLayer = [CALayer layer];
		renderLayer.anchorPoint = CGPointZero;
		renderLayer.position = CGPointZero;
		renderLayer.bounds = CGRectMake(0, 0, viewportSize.width, viewportSize.height);
		renderLayer.magnificationFilter = kCAFilterNearest;
		
#if USE_HQ2X
		renderLayer.transform = CATransform3DMakeScale(2.0, 2.0, 1.0);
#else
		//		renderLayer.transform = CATransform3DMakeScale(4.0, 4.0, 1.0);
#endif
		
		NSUInteger width = self.bounds.size.width;
		NSUInteger height = self.bounds.size.height;
		
		
		
#if USE_IOSURFACE
		
		unsigned pixelFormat = 'BGRA';
		unsigned bytesPerElement = 4;
		
		CFMutableDictionaryRef ioSurfaceProperties;
		
		ioSurfaceProperties = CFDictionaryCreateMutable(NULL, 3, &kCFTypeDictionaryKeyCallBacks, &kCFTypeDictionaryValueCallBacks);
		
		
		CFDictionarySetValue(ioSurfaceProperties, (void *)kIOSurfaceWidth, (__bridge const void *)([NSNumber numberWithInt:(int)(viewportSize.width)]));
		
		CFDictionarySetValue(ioSurfaceProperties, (void *)kIOSurfaceHeight, (__bridge const void *)([NSNumber numberWithInt:(int)(viewportSize.height)]));
		
		CFDictionarySetValue(ioSurfaceProperties, (void *)kIOSurfaceBytesPerElement, (__bridge const void *)([NSNumber numberWithInt:4]));
		
		//		CFDictionarySetValue(ioSurfaceProperties, (void *)kIOSurfaceHeight, (__bridge const void *)([NSNumber numberWithInt:(int)(viewportSize.height)]));
		
		CFDictionarySetValue(ioSurfaceProperties, (void *)kIOSurfacePixelFormat, (__bridge const void *)([NSNumber numberWithInt:pixelFormat]));
		
		// Get color space
		
		CGColorSpaceRef color_space = CGColorSpaceCreateDeviceRGB();
		
		
		overlay_surface = IOSurfaceCreate(ioSurfaceProperties);//overlay_surface is type IOSurfaceRef
		
		
		// Lock it
		
		//		IOSurfaceLock(overlay_surface, 0, NULL);
		
		
		// Create CG bitmap context for rendering into the surface
		
		gameRenderContext = CGBitmapContextCreate(IOSurfaceGetBaseAddress(overlay_surface),                                                                                                                                                                                                 viewportSize.width, viewportSize.height, 8, IOSurfaceGetBytesPerRow(overlay_surface),                                                                                                                                                                                                    color_space, kCGBitmapByteOrder32Host|kCGImageAlphaPremultipliedFirst);
		
#else
		
		
		gameRenderContext = CGBitmapContextCreate(NULL, width, height, 8, 0, [[NSColorSpace genericRGBColorSpace] CGColorSpace], kCGBitmapByteOrder32Host|kCGImageAlphaPremultipliedFirst);
#endif
		
		NS2DArray *gameWorld = nil;
		NS2DArray *gameWorldOverlays = nil;
		
		gameWorldLayers = [NSMutableArray arrayWithCapacity:3];
		gameWorld = [[NS2DArray alloc] initWithSize:CGSizeMake(MAP_WIDTH, MAP_HEIGHT)];
		gameWorldOverlays = [[NS2DArray alloc] initWithSize:CGSizeMake(MAP_WIDTH, MAP_HEIGHT)];
		
		NS2DArray *gameWorldElevation = [[NS2DArray alloc] initWithSize:CGSizeMake(MAP_WIDTH, MAP_HEIGHT)];
		
		
		
		gameWorldLayers[GameWorldLayerMap] = gameWorld;
		gameWorldLayers[GameWorldLayerElevation] = gameWorldElevation;
		gameWorldLayers[GameWorldLayerOverlays] = gameWorldOverlays;
		
		spriteSheet = [NSImage imageNamed:@"ob-mobs.png"];
		characterSheet = [NSImage imageNamed:@"charactersprites.png"];
		terrainSheet = [NSImage imageNamed:@"ob-tilemap.png"];
		
		player = [[DUCLPlayer alloc] init];
		player.health = 100;
		
		
		self.mobs = [[NSMutableArray alloc] initWithArray:@[ player ]];
		
		[self generateMapWithScale:1./2.];
		
		
//		[NSTimer scheduledTimerWithTimeInterval:1./DESIRED_FPS target:self selector:@selector(refreshScreen) userInfo:nil repeats:YES];
		[self beginGameThread];
		[self becomeFirstResponder];
		
		
		NSTextField *fps = [[NSTextField alloc] initWithFrame:CGRectMake(0, 0, 100, 20)];
		[fps setBordered:NO];
		[fps setEditable:NO];
		[fps setBackgroundColor:nil];
		[fps setTextColor:[NSColor whiteColor]];
		fps.stringValue = @"";
		fps.font = [NSFont fontWithName:@"Monaco" size:10.0];
		self.fpsLabel = fps;
		
		[self addSubview:self.fpsLabel];
		
    }
    return self;
}

-(void)refreshScreen
{
	[self display];
}

-(void)beginGameThread
{
	dispatch_async(dispatch_get_global_queue(0, 0), ^{
		while (1)
			[self tick];
	});
}


-(void)awakeFromNib
{
	[self.layer addSublayer:renderLayer];
	
	
	
	
#if !USE_HQ2X
	self.layer.anchorPoint = CGPointMake(0, 0);
	CATransform3D tx = CATransform3DIdentity;
	tx = CATransform3DScale(tx, 2.0, 2.0, 1.0);
	
	self.layer.transform =  tx;
	
#endif
	
	
	self.layer.magnificationFilter = kCAFilterNearest;
	
	[self addSubview:self.fpsLabel];
	
	[self startWatchingJoysticks];
	
	self.window.backgroundColor = [NSColor blackColor];
	
	NSTrackingArea *mouseOver = [[NSTrackingArea alloc] initWithRect:self.bounds options:NSTrackingMouseMoved|NSTrackingActiveAlways owner:self userInfo:nil];
	
	[self addTrackingArea:mouseOver];
	
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
						
						[gameWorldOverlays setObject:starGate1 atPosition:NS2DPointMake(x, y+1)];
						[gameWorldOverlays setObject:starGate2 atPosition:NS2DPointMake(x, y+0)];
						
						
						placedPlayer = YES;
						
						
						player.direction = CGPointMake(0, -1);
						player.desiredPosition = CGPointMake(x, y-1);
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
					
					if (![gameWorldOverlays objectAtPosition:NS2DPointMake(x, y)])
						[gameWorldOverlays setObject:flourishTile atPosition:NS2DPointMake(x, y)];
					
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
				[gameWorld setObject:tile atPosition:NS2DPointMake(x, y)];
			}
			else
			{
				DUCLTile *underneath = [[DUCLTile alloc] init];
				
				underneath.type = TileGrass;
				underneath.collision = YES;
				underneath.position = CGPointMake(x, y);
				
				[gameWorld setObject:underneath atPosition:NS2DPointMake(x, y)];
				
				if (![gameWorldOverlays objectAtPosition:NS2DPointMake(x, y)])
					[gameWorldOverlays setObject:tile atPosition:NS2DPointMake(x, y)];
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
	
	/* Water Pass */
	for (int y = 0; y < MAP_HEIGHT; y++){
		for (int x = 0; x < MAP_WIDTH; x++){
			
			DUCLTile * tile = [gameWorld objectAtPosition:NS2DPointMake(x, y)];
			
			if (tile.type != TileWater)
				tile.connectsToWater = [self connectsToWaterForX:x Y:y];
		}
	}
}

-(BOOL)connectsToWaterForX:(int)x Y:(int)y
{
	NS2DArray *gameWorld = gameWorldLayers[GameWorldLayerMap];
	
	if (x >= 0 && x < MAP_WIDTH && y >= 0 && y < MAP_HEIGHT) {
		
		if (((DUCLTile *)[gameWorld objectAtPosition:NS2DPointMake(x+1, y)]).type == TileWater)
		{
			return YES;
		}
		
		if (((DUCLTile *)[gameWorld objectAtPosition:NS2DPointMake(x+1, y+1)]).type == TileWater)
		{
			return YES;
		}
		
		if (((DUCLTile *)[gameWorld objectAtPosition:NS2DPointMake(x, y+1)]).type == TileWater)
		{
			return YES;
		}
		
		if (((DUCLTile *)[gameWorld objectAtPosition:NS2DPointMake(x-1, y)]).type == TileWater)
		{
			return YES;
		}
		
		if (((DUCLTile *)[gameWorld objectAtPosition:NS2DPointMake(x-1, y-1)]).type == TileWater)
		{
			return YES;
		}
		
		if (((DUCLTile *)[gameWorld objectAtPosition:NS2DPointMake(x, y-1)]).type == TileWater)
		{
			return YES;
		}
	}
	
	return NO;
}

#if 0
-(BOOL)hasNeighborsForX:(int)x Y:(int)y
{
	if (((DUCLTile *)[gameWorld objectAtPosition:NS2DPointMake(x+1, y)]).type == TileGrass)
	{
		return YES;
	}
	else if (((DUCLTile *)[gameWorld objectAtPosition:NS2DPointMake(x+1, y+1)]).type == TileGrass)
	{
		return YES;
	}
	else if (((DUCLTile *)[gameWorld objectAtPosition:NS2DPointMake(x, y+1)]).type == TileGrass)
	{
		return YES;
	}
	else if (((DUCLTile *)[gameWorld objectAtPosition:NS2DPointMake(x-1, y)]).type == TileGrass)
	{
		return YES;
	}
	else if (((DUCLTile *)[gameWorld objectAtPosition:NS2DPointMake(x-1, y-1)]).type == TileGrass)
	{
		return YES;
	}
	else if (((DUCLTile *)[gameWorld objectAtPosition:NS2DPointMake(x, y-1)]).type == TileGrass)
	{
		return YES;
	}
	
	return NO;
}
#endif

- (BOOL)acceptsFirstResponder {
    return YES;
}

int gametick = 0;

int frames = 0;

NSTimeInterval lastTick = 0;
NSTimeInterval lastFrame = 0;

uint64_t lastCycle;

-(void)tick
{
//	NSTimeInterval _start = [NSDate timeIntervalSinceReferenceDate];
	
	
	
//	NSTimeInterval actualFrame = [NSDate timeIntervalSinceReferenceDate]-lastFrame;
	
	if (mach_absolute_time() - lastCycle > NSEC_PER_SEC)
	{
		NSLog(@"FPS = %f", (CGFloat)frames);
		
		self.fpsLabel.stringValue  = [NSString stringWithFormat:@"%.0ffps", (CGFloat)frames];
		lastFrame = [NSDate timeIntervalSinceReferenceDate];
		
		frames = 0;
	}
	
	[self calculateMobPosition];
	
#if USE_MOBS
	if (mach_absolute_time() - lastCycle > NSEC_PER_SEC*0.15 )//_start-lastTick > 0.15)
#endif
		[self calculatePlayerPosition];
	
	
	if (mach_absolute_time() - lastCycle > NSEC_PER_SEC*0.3)
	{
//		[self calculateAI];
		
		gametick++;
		
		if (gametick == 2)
			gametick = 0;
		
		
		NSTimeInterval _end = [NSDate timeIntervalSinceReferenceDate];
		lastTick = _end;
	}
	
//	[self setNeedsDisplay:YES];
	
	
//	if (gametick == 2)
//		gametick = 0;
	frames++;
	
//	gametick++;
	
	lastCycle = mach_absolute_time();
	
	dispatch_async(dispatch_get_main_queue(), ^{

	[self refreshScreen];
	});
	
	
	while (mach_absolute_time() < lastCycle+(NSEC_PER_SEC/DESIRED_FPS))
	{
	}
	
	
	
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
		
		newPlayerPos.y +=distanceDelta;
		newPlayerDirection = CGPointMake(0, 1);
	}
	
	else if (keyboard.down)
	{
		newPlayerPos.y-=distanceDelta;
		newPlayerDirection = CGPointMake(0, -1);
	}
	else
	{
		return;
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
							mob.direction = CGPointMake(0,-1);
						else if (currentPosition.y < desiredPosition.y)
							mob.direction = CGPointMake(0,1);
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
	}
}

#define KEY_RIGHT 124
#define KEY_LEFT 123
#define KEY_UP 126
#define KEY_DOWN 125

-(void)keyUp:(NSEvent *)theEvent
{
	
	if (theEvent.keyCode == KEY_RIGHT)
	{
		
		keyboard.right = NO;
	}
	
	else if (theEvent.keyCode == KEY_LEFT)
	{
		keyboard.left = NO;
	}
	
	else if (theEvent.keyCode == KEY_UP)
	{
		keyboard.up = NO;
		
	}
	
	else if (theEvent.keyCode == KEY_DOWN)
	{
		
		keyboard.down = NO;
		
	}
	
	player.moving = NO;
}

- (void)flagsChanged:(NSEvent *)theEvent
{
	if (theEvent.modifierFlags & NSShiftKeyMask)
	{
		keyboard.run = YES;
	}
	else
	{
		keyboard.run = NO;
	}
}
-(void)keyDown:(NSEvent *)theEvent
{
	//	NSLog(@"keycode = %li", theEvent.modifierFlags);
	
	
	
	CGPoint newPlayerPos = CGPointMake(round(player.position.x), round(player.position.y));
	CGPoint newPlayerDirection = CGPointZero;
	
	CGFloat distanceDelta = 1.;
	
	
	
	
	if (theEvent.keyCode == KEY_RIGHT)
	{
		
		keyboard.right = YES;
		
		newPlayerPos.x+=distanceDelta;
		newPlayerDirection = CGPointMake(1, 0);
	}
	
	else if (theEvent.keyCode == KEY_LEFT)
	{
		keyboard.left = YES;
		
		newPlayerPos.x -=distanceDelta;
		newPlayerDirection = CGPointMake(-1, 0);
	}
	
	else if (theEvent.keyCode == KEY_UP)
	{
		keyboard.up = YES;
		
		newPlayerPos.y +=distanceDelta;
		newPlayerDirection = CGPointMake(0, 1);
	}
	
	else if (theEvent.keyCode == KEY_DOWN)
	{
		
		keyboard.down = YES;
		newPlayerPos.y-=distanceDelta;
		
		newPlayerDirection = CGPointMake(0, -1);
		
	}
	else
	{
		return;
	}
	
}

NSMutableArray *highlightedTiles = nil;

-(void)mouseDown:(NSEvent *)theEvent
{
#if !BUILDING_PLACEMENT
	return;
#endif
	NS2DArray *gameWorld = gameWorldLayers[GameWorldLayerMap];
	NS2DArray *gameWorldOverlays = gameWorldLayers[GameWorldLayerOverlays];
	
	for (DUCLTile *t in highlightedTiles)
	{
		DUCLTile *existingOverlay = [gameWorldOverlays objectAtPosition:NS2DPointMake((NSInteger)t.position.x, (NSInteger)t.position.y)];
		DUCLTile *existingTile = [gameWorld objectAtPosition:NS2DPointMake((NSInteger)t.position.x, (NSInteger)t.position.y)];
		
		if (existingTile.type == TileWater || (existingOverlay.type >= TileTree && existingOverlay.type <= TileHouse9) )
		{
			return;
		}
		
		if (CGPointEqualToPoint(player.position, t.position))
		{
			return;
		}
		
	}
	
	TileType lastComponent = TileHouse1;
	
	for (DUCLTile *t in highlightedTiles)
	{
		
		DUCLTile *newTile = [[DUCLTile alloc] init];
		
		newTile.type = lastComponent;
		newTile.position = t.position;
		newTile.collision = YES;
		
		[gameWorldOverlays setObject:newTile atPosition:NS2DPointMake((NSInteger)t.position.x, (NSInteger)t.position.y)];
		
		lastComponent++;
	}
	
	[highlightedTiles removeAllObjects];
	
}



-(void)mouseMoved:(NSEvent *)theEvent
{
#if !BUILDING_PLACEMENT
	return;
#endif
	NS2DArray *gameWorld = gameWorldLayers[GameWorldLayerMap];
	NS2DArray *gameWorldOverlays = gameWorldLayers[GameWorldLayerOverlays];
	
	CGPoint point = [theEvent locationInWindow];
	
	CGRect bounds = self.bounds;
	
	CGPoint pointOffset = CGPointMake(CGRectGetWidth(bounds)/2-viewportSize.width/2, CGRectGetHeight(bounds)/2-viewportSize.width/2);
	
	
	//point.x -= pointOffset.x;
	//point.y -= pointOffset.y;
	
	int offset = (viewportSize.width/2)/TILE_SIZE;
	
	CGFloat xOffset = (player.position.x+offset)-TILE_SIZE;
	CGFloat yOffset = (player.position.y+offset)-TILE_SIZE;
	
	
	int tileX = xOffset+point.x/TILE_SIZE * 0.5;
	int tileY = yOffset+point.y/TILE_SIZE * 0.5;
	
	
	for (int y = 0; y < MAP_HEIGHT; y++)
	{
		for (int x = 0; x < MAP_WIDTH; x++)
		{
			
			DUCLTile *t = [gameWorld objectAtPosition:NS2DPointMake(x, y)];
			t.highlighted = NO;
			
			DUCLTile *overlay = [gameWorldOverlays objectAtPosition:NS2DPointMake(x, y)];
			overlay.highlighted = NO;
		}
	}
	
	[self highlight3X3AroundPointAt:NS2DPointMake(tileX, tileY)];
	
}


-(void)highlight3X3AroundPointAt:(NS2DPoint)point
{
	[self highlightAreaFrom:NS2DPointMake(point.x-1, point.y-1) to:NS2DPointMake(point.x+2, point.y+2)];
}

-(void)highlightPointAt:(NS2DPoint)point
{
	[self highlightAreaFrom:NS2DPointMake(point.x, point.y) to:NS2DPointMake(point.x+1, point.y+1)];
}

-(void)highlightAreaFrom:(NS2DPoint)topLeft to:(NS2DPoint)bottomRight
{
	NS2DArray *gameWorld = gameWorldLayers[GameWorldLayerMap];
	NS2DArray *gameWorldOverlays = gameWorldLayers[GameWorldLayerOverlays];
	
	[highlightedTiles removeAllObjects];
	
	
	if (!highlightedTiles)
		highlightedTiles = [[NSMutableArray alloc] initWithCapacity:9];
	
	for (NSInteger y = topLeft.y; y < bottomRight.y; y++)
	{
		for (NSInteger x = topLeft.x; x < bottomRight.x; x++)
		{
			DUCLTile *t = [gameWorld objectAtPosition:NS2DPointMake(x, y)];
			t.highlighted = YES;
			
			DUCLTile *overlay = [gameWorldOverlays objectAtPosition:NS2DPointMake(x, y)];
			overlay.highlighted = YES;
			
			
			if (t)
				[highlightedTiles addObject:t];
		}
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
		
		if (((DUCLTile *)[gameWorld objectAtPosition:NS2DPointMake((NSUInteger)pos.x, (NSUInteger)pos.y)]).collision == NO)
		{
			for (DUCLMob *m in self.mobs)
			{
				if (m != mob && CGPointEqualToPoint(pos, m.desiredPosition))
					return NO;
			}
			
			DUCLTile *overlayTile = ((DUCLTile *)[gameWorldOverlays objectAtPosition:NS2DPointMake((NSUInteger)pos.x, (NSUInteger)pos.y)]);
			if (overlayTile && overlayTile.collision == YES)
			{
				return NO;
				
			}
			
			
			return YES;
		}
	}
	
	return NO;
}

NSImage *miniMap = nil;

-(void)renderGameScene:(CGContextRef)context
{
	[NSGraphicsContext setCurrentContext:[NSGraphicsContext graphicsContextWithGraphicsPort:context flipped:NO]];
	
	[[NSGraphicsContext currentContext] setImageInterpolation:NSImageInterpolationNone];
	
	CGRect bounds = self.bounds;
	
	//	CGContextScaleCTM(context, floor(bounds.height/viewportSize.width), floor(bounds.height/viewportSize.height));
	
	//	self.layer.position = CGPointMake(CGRectGetWidth(bounds)/2-viewportSize.width/2, CGRectGetHeight(bounds)/2-viewportSize.width/2);
	
	//	self.layer.anchorPoint = CGPointMake(0.5, 0.5);
	//	self.layer.transform = CATransform3DMakeScale(floor(bounds.size.height/viewportSize.width), floor(bounds.size.height/viewportSize.height), 1);
	
	[[NSColor blackColor] set];
	NSRectFill(CGRectMake(0, 0, viewportSize.width, viewportSize.height));
	
	CGContextSaveGState(context);
	
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
				
				
				DUCLTile *tile = ((DUCLTile *)[gameWorldLayer objectAtPosition:NS2DPointMake(x, y)]);
				
				if (tile && tile.type != TileBlank)
				{
					[[NSColor colorWithCalibratedRed:0.596 green:0.831 blue:0.565 alpha:0.25*(CGFloat)(tile.elevation/255.0)] set];
					
					CGContextSaveGState(context);
					CGContextTranslateCTM(context, round(xPos), round(yPos));
					
					tile.gametick = gametick;
					[tile draw];
											
						NSRectFillUsingOperation(CGRectMake(0, 0, TILE_SIZE, TILE_SIZE), NSCompositePlusLighter);
										
					CGContextRestoreGState(context);
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
		CGRect mapRect = CGRectMake(round((xOffset+mob.position.x)*TILE_SIZE), round((yOffset+mob.position.y)*TILE_SIZE), TILE_SIZE, TILE_SIZE);
		
		CGContextSaveGState(context);
		CGContextTranslateCTM(context, mapRect.origin.x, mapRect.origin.y);
		
		[mob draw];
		
		CGContextRestoreGState(context);
	}
	
#endif
	
	
#if DRAW_MINIMAP
	int scale = MINIMAP_ZOOM_SCALE;

	if (!miniMap)
	{
		

		miniMap = [[NSImage alloc] initWithSize:CGSizeMake(viewportSize.width-(MAP_WIDTH/scale)-2, viewportSize.height-(MAP_HEIGHT/scale)-2)];
	
		[miniMap lockFocus];
		
	NS2DArray *gameWorld = gameWorldLayers[GameWorldLayerMap];
	NS2DArray *gameWorldOverlays = gameWorldLayers[GameWorldLayerOverlays];
	
	
	/* Draw minimap */
	
//	CGContextTranslateCTM(context, viewportSize.width-(MAP_WIDTH/scale)-2, viewportSize.height-(MAP_HEIGHT/scale)-2);
	
	
	for (int yy = 0; yy < MAP_HEIGHT; yy+=scale){
		for (int xx = 0; xx < MAP_WIDTH; xx+=scale){
			
			int x = xx/scale;
			int y = yy/scale;
			
			DUCLTile * tile = ((DUCLTile *)[gameWorld objectAtPosition:NS2DPointMake(x, y)]);
			
			TileType gen = tile.type;
			TileType overlayGen = ((DUCLTile *)[gameWorldOverlays objectAtPosition:NS2DPointMake(x, y)]).type;
			
			if (overlayGen)
				gen = overlayGen;
			
			NSColor *nscolor = nil;
			
			CGFloat alpha = 1.0;
			
			NSColor *grassColor = [NSColor colorWithCalibratedRed:0.514 green:0.800 blue:0.475 alpha:alpha];
			NSColor *mudColor = [NSColor colorWithCalibratedRed:0.676 green:0.577 blue:0.412 alpha:alpha];
			NSColor *treeColor = [NSColor colorWithCalibratedRed:0.388 green:0.588 blue:0.188 alpha:alpha];
			NSColor *waterColor = [NSColor colorWithCalibratedRed:0.227 green:0.482 blue:0.557 alpha:alpha];
			
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
				nscolor = [NSColor darkGrayColor];
			}
			else
			{
				nscolor = waterColor;
			}
			
			[nscolor set];
			
			/*
			 for (DUCLMob *mob in self.mobs)
			 {
			 if (x == (int)mob.position.x && y == (int)mob.position.y)
			 {
			 [[NSColor redColor] set];
			 }
			 }*/
			
//			if (x == (int)player.position.x/scale && y == (int)player.position.y/scale)
//			{
//				[[NSColor whiteColor] set];
//			}

			NSRectFill(CGRectMake(x, y, 1, 1));
			
			[[NSColor colorWithCalibratedRed:0.596 green:0.831 blue:0.565 alpha:0.25*(CGFloat)(tile.elevation/255.0)] set];
			NSRectFillUsingOperation(CGRectMake(x, y, 1, 1), NSCompositePlusLighter);
		}
	}
		
		[miniMap unlockFocus];
	}
	
	[miniMap drawAtPoint:CGPointMake(0, 0) fromRect:CGRectZero operation:NSCompositeSourceOver fraction:1.0];
	
	[[NSColor whiteColor] set];
	NSRectFill(CGRectMake(player.position.x/scale, player.position.y/scale, 1, 1));

	
#endif
	
	CGContextRestoreGState(context);
}


-(void)redrawRenderLayer
{
	[self renderGameScene:gameRenderContext];
	
	//
	
	CGImageRef cgImage = CGBitmapContextCreateImage(gameRenderContext);
	
#if USE_HQ2X
	DrawCGImageWithHQXScaling(gameRenderContext, cgImage, 2);
	CGImageRelease(cgImage);
	
	cgImage = CGBitmapContextCreateImage(gameRenderContext);
	
#endif
#if USE_IOSURFACE
	IOSurfaceLock(overlay_surface, 0, NULL);
	
	[CATransaction begin];
	[CATransaction setDisableActions:YES];
	
	renderLayer.contents = (__bridge id)overlay_surface;
	
	[CATransaction commit];
	IOSurfaceUnlock(overlay_surface, 0, NULL);
#else
	[CATransaction begin];
	[CATransaction setDisableActions:YES];
	
	renderLayer.contents = (__bridge id)cgImage;
	
	[CATransaction commit];
#endif
	
	//	CGImageRelease(cgImage);
	
}

-(void)drawRect:(NSRect)dirtyRect
{
	CGContextRef ctx = [NSGraphicsContext currentContext].graphicsPort;
	
	[self renderGameScene:ctx];
	
	
#if USE_HQ2X
	CGImageRef cgImage = CGBitmapContextCreateImage(ctx);
	
	DrawCGImageWithHQXScaling(ctx, cgImage, 2);
	CGImageRelease(cgImage);
	
#endif
	
}


#pragma mark - Joystick input

/*
 
 Xbox Controller Mapping
 
 */

#define ABUTTON  0
#define BBUTTON  1
#define XBUTTON  2
#define YBUTTON  3


- (void)startWatchingJoysticks
{
    joysticks = [DDHidJoystick allJoysticks] ;
    
    if ([joysticks count]) // assume only one joystick connected
    {
        [[joysticks lastObject] setDelegate:self];
        [[joysticks lastObject] startListening];
    }
}
- (void)ddhidJoystick:(DDHidJoystick *)joystick buttonDown:(unsigned)buttonNumber
{
    NSLog(@"JOYSTICK = %i", buttonNumber);
 	
	if (buttonNumber == XBUTTON)
	{
		
	}
    
    if (buttonNumber == ABUTTON)
	{
		
	}
}

- (void)ddhidJoystick:(DDHidJoystick *)joystick buttonUp:(unsigned)buttonNumber
{
	if (buttonNumber == XBUTTON)
	{
		
        
	}
}

int lastStickX = 0;
int lastStickY = 0;


- (void) ddhidJoystick: (DDHidJoystick *)  joystick
                 stick: (unsigned) stick
              xChanged: (int) value;
{
    value/=SHRT_MAX;
    
    lastStickX = value;
    
    if (abs(lastStickY) > abs(lastStickX))
        return;
	
    
    
    if (value == 0)
    {
        player.moving = NO;
		
		keyboard.left = NO;
		keyboard.right = NO;
        
    }
	else
	{
		
		keyboard.up = NO;
		keyboard.down = NO;
		
		if (value > 0 )
		{
			keyboard.right = YES;
		}
		else if (value < 0 )
		{
			keyboard.left = YES;
		}
		
		
		player.moving =YES;
	}
}

- (void) ddhidJoystick: (DDHidJoystick *)  joystick
                 stick: (unsigned) stick
              yChanged: (int) value;
{
    value/=SHRT_MAX;
    
    lastStickY = value;
    
    if (abs(lastStickY) < abs(lastStickX))
        return;
    
    if (value == 0)
    {
        player.moving = NO;
		keyboard.up = NO;
		keyboard.down = NO;
		
    }
	else
	{
		keyboard.left = NO;
		keyboard.right = NO;
		
		if (value > 0 )
		{
			
			keyboard.down = YES;
		}
		else if (value < 0 )
		{
			
			keyboard.up = YES;
		}
		
		player.moving = YES;
	}
}

@end
