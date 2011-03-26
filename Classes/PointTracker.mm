//
//  PointTracker.mm
//  trackingTest
//
//  Created by kronick on 2/7/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "PointTracker.h"


@implementation PointTracker
using namespace std;
using namespace cv;

- (id) init {
	[super init];
	gridX = 12;
	gridY = 8;
	maxAge = 20;
	
	// Initialize the point grid
	for(int a=0; a<gridX; a++) {
		vector<vector<TrackedPoint *> > _column;
		for(int b=0; b<gridY; b++) {
			vector<TrackedPoint *> _rowcell;
			_column.push_back(_rowcell);
		}
		mTrackedPointGrid.push_back(_column);
	}
	
	tracking = NO;
	
	return self;
}

- (void)checkPoint:(CGPoint)point inImage:(cv::Mat *)img {
	// Figure out which cell the point that's being checked belongs in
	Cell cell = [self getCellForPoint:point inImage:img];
	
	Cell bestMatchCell;
	int bestMatchNumber;
	CGFloat bestMatchSum = 9999;
	BOOL matchFound = NO;
	
	CGFloat matchSum = 0;
	// Look in the surrounding cells, too, for an unguided search
	for(int a=-1; a<=1; a++) {
		for(int b=-1; b<=1; b++) {
			if(cell.col+a >=0 && cell.col+a<mTrackedPointGrid.size() && cell.row+b >=0 && cell.row+b<mTrackedPointGrid[0].size()) {
				for(int n=0; n<mTrackedPointGrid[cell.col+a][cell.row+b].size(); n++) {
					if(mTrackedPointGrid[cell.col+a][cell.row+b][n]->active) {
						// For each keypoint at this cell position
						matchSum = [mTrackedPointGrid[cell.col+a][cell.row+b][n] sumOfDifferencesWithPoint:point inImage:img];
						if(matchSum != 0 && matchSum < bestMatchSum && matchSum < mTrackedPointGrid[cell.col+a][cell.row+b][n]->differenceThreshold) {
							matchFound = YES;
							bestMatchSum = matchSum;
							bestMatchCell.col = cell.col+a;
							bestMatchCell.row = cell.row+b;
							bestMatchNumber = n;
						}
					}
				}
			}
		}
	}	
	
	
	if(matchFound) {
		//NSLog(@"Best match: %f", bestMatchSum);
		[mTrackedPointGrid[bestMatchCell.col][bestMatchCell.row][bestMatchNumber] setNewPoint:point];
		
		TrackedPoint *found = mTrackedPointGrid[bestMatchCell.col][bestMatchCell.row][bestMatchNumber];
		mTrackedPointGrid[bestMatchCell.col][bestMatchCell.row].erase(mTrackedPointGrid[bestMatchCell.col][bestMatchCell.row].begin() + bestMatchNumber);
		mTrackedPointGrid[cell.col][cell.row].push_back(found);
		
	}
}

- (Cell)getCellForPoint:(CGPoint)point inImage:(cv::Mat *)img {
	Cell _c;
	float scaledX = point.x / (float)img->cols;
	float scaledY = point.y / (float)img->rows;
	_c.col = (int)(scaledX * gridX);
	_c.row = (int)(scaledY * gridY);
	
	return _c;
}

- (void)addPoint:(CGPoint)point inImage:(cv::Mat *)img {
	// Create new TrackedPoint
	TrackedPoint *_tp = [[TrackedPoint alloc] initWithPoint:point andImage:img];
	
	trackedPoints.push_back(_tp);
	
	// Insert the point into the grid
	Cell cell = [self getCellForPoint:point inImage:img];
	mTrackedPointGrid[cell.col][cell.row].push_back(_tp);
}


- (void)clearTrackedPoints {
	for(int i=0; i<trackedPoints.size(); i++)
		[trackedPoints[i] release];

	trackedPoints.clear();
	mTrackedPointGrid.clear();
	
	// Initialize the point grid
	for(int a=0; a<gridX; a++) {
		vector<vector<TrackedPoint *> > _column;
		for(int b=0; b<gridY; b++) {
			vector<TrackedPoint *> _rowcell;
			_column.push_back(_rowcell);
		}
		mTrackedPointGrid.push_back(_column);
	}	
}

- (std::vector<TrackedPoint *>) getTrackedPoints {
	return trackedPoints;
}

- (void)tick {
	for(int i=0; i<trackedPoints.size(); i++) {
		if(trackedPoints[i] != nil) {
			[trackedPoints[i] tick];
			if(trackedPoints[i]->age > maxAge) {
				trackedPoints[i]->active = NO;
			}
		}
	}
}

- (int)countActivePoints {
	int out = 0;
	for(int i=0; i<trackedPoints.size(); i++) {
		if(trackedPoints[i]->active)
			out++;
	}
	return out;
}

@end
