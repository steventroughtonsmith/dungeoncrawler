//
//  main.m
//  DungeonCrawler
//
//  Created by Steven Troughton-Smith on 18/06/2012.
//  Copyright (c) 2012 High Caffeine Content. All rights reserved.
//


#import <Cocoa/Cocoa.h>


#if USE_SDL
#import "OBLevelGenerator.h"
#include <stdio.h>
#include <SDL.h>
#include <SDL_image/SDL_image.h>

#import "DUCLGameEngine.h"

const char* WINDOW_TITLE = "DungeonCrawler";

#define WIDTH 256
#define HEIGHT 256
#define BPP 4
#define DEPTH 32

#if DRAW_MAP_PREVIEW
double map[MAP_WIDTH][MAP_HEIGHT];
void DrawMap(SDL_Surface* screen);
#endif

SDL_Surface* tilemapSurface;
SDL_Surface* characterSheetSurface;

SDL_Color SDLColorMake(int r, int g, int b)
{
	SDL_Color color;
	color.r = r;
	color.g = g;
	color.b = b;
	return color;
}

SDL_Color SDLColorMakeF(CGFloat r, CGFloat g, CGFloat b)
{
	SDL_Color color;
	color.r = (int)(r*255);
	color.g = (int)(g*255);
	color.b = (int)(b*255);
	return color;
}

Uint32 GetPixel(SDL_Surface *screen, int x, int y)
{
	Uint32 *pixmem32 = (((Uint32*)((char*)screen->pixels + (y)*screen->pitch) + (x)));
	
	return *pixmem32;
}

void SetPixel(SDL_Surface *screen, int x, int y, Uint32 pixel)
{
    Uint32 *pixmem32 = (((Uint32*)((char*)screen->pixels + (y)*screen->pitch) + (x)));
	
    *pixmem32 = pixel;
}

void DrawScreen(SDL_Surface* screen)
{
    if(SDL_MUSTLOCK(screen))
    {
        if(SDL_LockSurface(screen) < 0) return;
    }
	
	int bgColor = SDL_MapRGB(screen->format, 0, 0, 0);
    SDL_Rect screenRect = { 0, 0, screen->w, screen->h };
    SDL_FillRect(screen, &screenRect, bgColor);
	
#if DRAW_MAP_PREVIEW
	DrawMap(screen);
#endif
	
    if(SDL_MUSTLOCK(screen)) SDL_UnlockSurface(screen);
	
	SDL_Rect tile;
	tile.x = 1;
	tile.y = 1;
	tile.w = TILE_SIZE;
	tile.h = TILE_SIZE;
	
	for (int y = 0; y < MAP_HEIGHT; y++)
	{
		for (int x = 0; x < MAP_WIDTH; x++)
		{
			SDL_Rect dstRect;
			dstRect.x = x*TILE_SIZE;
			dstRect.y = y*TILE_SIZE;
			dstRect.w = TILE_SIZE;
			dstRect.h = TILE_SIZE;
			
			SDL_BlitSurface(tilemapSurface, &tile, screen, &dstRect);
		}
	}
	
    SDL_Flip(screen);
}

#if DRAW_MAP_PREVIEW

void DrawMap(SDL_Surface* screen)
{
	for (int y = 0; y < MAP_HEIGHT; y++)
	{
		for (int x = 0; x < MAP_WIDTH; x++)
		{
			double gen = map[x][y];
			
			SDL_Color nscolor;
			
			SDL_Color grassColor = SDLColorMakeF(0.514, 0.800, 0.475);
			SDL_Color mudColor = SDLColorMakeF(0.676, 0.577, 0.412);
			SDL_Color treeColor = SDLColorMakeF(0.388, 0.588, 0.188);
			SDL_Color waterColor = SDLColorMakeF(0.227, 0.482, 0.557);
			
			if (gen > 110 && gen < 150)
			{
				nscolor = mudColor;
			}
			else if (gen >= 150 && gen < 180)
			{
				nscolor = grassColor;
			}
			else if (gen >= 180)
			{
				nscolor = treeColor;
			}
			else
			{
				nscolor = waterColor;
			}
			
			Uint32 colour;
			
			
			colour = SDL_MapRGB( screen->format, nscolor.r, nscolor.g, nscolor.b );
			
			SetPixel(screen, x, y, colour);
		}
	}
}
#endif

void initSprites()
{
	
	NSString *tilemapPNGPath = [[NSBundle mainBundle] pathForImageResource:@"ob-tilemap.png"];
	
	SDL_RWops *rwop = SDL_RWFromFile([tilemapPNGPath UTF8String], "rb");
	
	tilemapSurface = IMG_LoadPNG_RW(rwop);
	
	NSString *characterPNGPath = [[NSBundle mainBundle] pathForImageResource:@"charactersprites.png"];
	
	SDL_RWops *rwop2 = SDL_RWFromFile([characterPNGPath UTF8String], "rb");
	
	characterSheetSurface = IMG_LoadPNG_RW(rwop2);

}

int SDL_main(int argc, char *argv[])
{
	
	
#if DRAW_MAP_PREVIEW
	OBLevelGenerator *levelGen = [[OBLevelGenerator alloc] init];
	
	[levelGen gen:64];
	for (int y = 0; y < MAP_HEIGHT; y++){
		for (int x = 0; x < MAP_WIDTH; x++){
			map[x][y] = [levelGen valueForX:x Y:y];
		}
	}
#endif
	
	DUCLGameEngine *gameEngine = [[DUCLGameEngine alloc] init];
	
	SDL_Surface *screen;
	SDL_Event event;
	
    int quit = 0;
	
    if (SDL_Init(SDL_INIT_VIDEO) < 0 ) return 1;
	
	screen = SDL_SetVideoMode(WIDTH, HEIGHT, DEPTH,
							  SDL_HWSURFACE);
	SDL_WM_SetCaption( WINDOW_TITLE, 0 );
	
    if (!screen)
    {
        SDL_Quit();
        return 1;
    }
	
	initSprites();
		
    while(!quit)
    {
		[gameEngine tick];
		[gameEngine drawGame:screen];
		while(SDL_PollEvent(&event))
		{
			[gameEngine passEvent:event];
		}
		
		usleep(USEC_PER_SEC/60);
    }
	
    SDL_Quit();
	SDL_FreeSurface(tilemapSurface);
	SDL_FreeSurface(characterSheetSurface);
	
}


#else
int main(int argc, char *argv[])
{
	return NSApplicationMain(argc, (const char **)argv);
}
#endif

