//
//  RectifyGridView.mm
//  trackingTest
//
//  Created by kronick on 6/6/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "RectifyGridView.h"


@implementation RectifyGridView


- (id)initWithFrame:(CGRect)frame {
    
    self = [super initWithFrame:frame];
    if (self) {
		// Set the corners to some default values
		corners[0] = CGPointMake(frame.size.width * .1, frame.size.height*.1);
		corners[1] = CGPointMake(frame.size.width * .1, frame.size.height*.9);
		corners[2] = CGPointMake(frame.size.width * .9, frame.size.height*.9);
		corners[3] = CGPointMake(frame.size.width * .9, frame.size.height*.1);
		NSLog(@"%f,%f", corners[0].x, corners[0].y);
    }
    return self;
}

- (void)awakeFromNib {
	// Set the corners to some default values
	corners[0] = CGPointMake(self.frame.size.width * .1, self.frame.size.height*.1);
	corners[1] = CGPointMake(self.frame.size.width * .1, self.frame.size.height*.9);
	corners[2] = CGPointMake(self.frame.size.width * .9, self.frame.size.height*.9);
	corners[3] = CGPointMake(self.frame.size.width * .9, self.frame.size.height*.1);
	NSLog(@"%f,%f", corners[0].x, corners[0].y);	
}

- (void)drawRect:(CGRect)rect {
	CGContextRef context = UIGraphicsGetCurrentContext();
	
	CGContextClearRect(context, self.frame);
	
	// Set stroke color to magenta
	CGContextSetStrokeColorWithColor(context, [UIColor colorWithRed:1 green:0 blue:.75 alpha:1].CGColor);
	CGContextSetLineWidth(context, 2);
	
	// Draw rectangular box
	CGContextMoveToPoint(context, corners[0].x, corners[0].y);
	CGContextAddLineToPoint(context, corners[1].x, corners[1].y);
	CGContextAddLineToPoint(context, corners[2].x, corners[2].y);
	CGContextAddLineToPoint(context, corners[3].x, corners[3].y);
	CGContextAddLineToPoint(context, corners[0].x, corners[0].y);
	CGContextStrokePath(context);
	
	// Draw thick baseline
	CGContextSetLineWidth(context, 8);
	CGContextMoveToPoint(context, corners[1].x, corners[1].y);
	CGContextAddLineToPoint(context, corners[2].x, corners[2].y);
	CGContextStrokePath(context);
	
	// Draw grid in between
	int GRID_X_DIVISIONS = [self frame].size.width/1024. * 30;
	int GRID_Y_DIVISIONS = [self frame].size.width/1024. * 30;
	
	CGContextSetLineWidth(context, 1); // Thinner stroke
	for(int i=0; i<GRID_X_DIVISIONS; i++) {
		CGContextMoveToPoint(context,	corners[0].x + (corners[3].x-corners[0].x) * i/GRID_X_DIVISIONS,
										corners[0].y + (corners[3].y-corners[0].y) * i/GRID_X_DIVISIONS);
		CGContextAddLineToPoint(context,corners[1].x + (corners[2].x-corners[1].x) * i/GRID_X_DIVISIONS,
										corners[1].y + (corners[2].y-corners[1].y) * i/GRID_X_DIVISIONS);
		CGContextStrokePath(context);
	}
	for(int i=0; i<GRID_Y_DIVISIONS; i++) {
		CGContextMoveToPoint(context,	corners[0].x + (corners[1].x-corners[0].x) * i/GRID_Y_DIVISIONS,
										corners[0].y + (corners[1].y-corners[0].y) * i/GRID_Y_DIVISIONS);
		CGContextAddLineToPoint(context,corners[3].x + (corners[2].x-corners[3].x) * i/GRID_Y_DIVISIONS,
										corners[3].y + (corners[2].y-corners[3].y) * i/GRID_Y_DIVISIONS);		
		CGContextStrokePath(context);
	}
	
	/*
	// Draw dots at corners
	const float DOT_SIZE = [self frame].size.width/1024. * 30;
	CGContextSetLineWidth(context, 4); // Thicker stroke
	for(int i=0; i<4; i++) {
		CGContextAddEllipseInRect(context, CGRectMake(corners[i].x-DOT_SIZE/2, corners[i].y-DOT_SIZE/2, DOT_SIZE, DOT_SIZE));
	}
	CGContextStrokePath(context);
	 */
	
}

- (void) setFrame:(CGRect)frame
{
	CGFloat oldWidth  = [self frame].size.width;
	CGFloat oldHeight = [self frame].size.height;
	
	// Move corners to same percentage of the frame width/height as they were before
	for(int i=0; i<4; i++) {
		corners[i] = CGPointMake(corners[i].x/oldWidth * frame.size.width, corners[i].y/oldHeight * frame.size.height);
	}
	
	// Call the parent class to move the view
	[super setFrame:frame];
	[self setNeedsDisplay];
}

- (void) setCorner:(int)cornerIndex toPoint:(CGPoint)point {
	corners[cornerIndex] = point;
	[self setNeedsDisplay];
}

- (void)dealloc {
    [super dealloc];
}


@end
