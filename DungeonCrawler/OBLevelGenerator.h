//
//  OBLevelGenerator.h
//  onebutton
//
//  Created by Steven Troughton-Smith on 24/12/2011.
//  Copyright (c) 2011 High Caffeine Content. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface OBLevelGenerator : NSObject
{
    double values[MAP_WIDTH][MAP_HEIGHT];
}

-(void)gen:(int)featureSize;
-(double)valueForX:(int)x Y:(int)y;

@end
