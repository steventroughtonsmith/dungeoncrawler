//
//  DUCLGameView.h
//  DungeonCrawler
//
//  Created by Steven Troughton-Smith on 18/06/2012.
//  Copyright (c) 2012 High Caffeine Content. All rights reserved.
//

#import <Cocoa/Cocoa.h>

enum GameWorldLayer {
	GameWorldLayerMap = 0,
	GameWorldLayerElevation,
	GameWorldLayerOverlays
};

static	NSMutableArray *gameWorldLayers = nil;

@interface DUCLGameView : NSView
{
	CALayer *renderLayer;
	NSArray *joysticks;
	


}

@property (nonatomic, strong) NSMutableArray *mobs;

@property (nonatomic, strong) NSTextField *fpsLabel;

@end
