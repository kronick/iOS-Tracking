//
//  Homography.m
//  trackingTest
//
//  Created by kronick on 2/22/11.
//  Copyright 2011 __MyCompanyName__. All rights reserved.
//

#import "Homography.h"
#include <opencv2/objdetect/objdetect.hpp>
#include <opencv2/features2d/features2d.hpp>
#include <opencv2/calib3d/calib3d.hpp>
#include <opencv2/imgproc/imgproc_c.h>

using namespace cv;
using namespace std;
@implementation Homography

- (id)init {
    
    self = [super init];
    if (self) {
        // Initialization code.
		matrix = Mat(3,3, CV_64F);
    }
    return self;
}


- (id)initWithSourceImage:(cv::Mat*)sourceMat sourceKeyPoints:(std::vector<cv::KeyPoint>*)sourcePoints destImage:(cv::Mat*)destMat destKeyPoints:(std::vector<cv::KeyPoint>*)destPoints {
	[self init];
	if(self) {
		sourceImage = *sourceMat;
		sourceKeyPoints = *sourcePoints;
		destImage = destMat;
		destKeyPoints = destPoints;
		sourceDescriptorsAreFresh = NO;
		destDescriptorsAreFresh = YES;
	}
	return self;
}



- (void)dealloc {
    [super dealloc];
}


#pragma mark -
#pragma mark Getters/Setters

- (cv::Mat) getMatrix {
	return matrix;
}
- (NSArray *) getArray {
	NSMutableArray *output = [NSMutableArray arrayWithCapacity:9];
	for(int i=0; i<3; i++) {
		for(int j=0; j<3; j++) {
			[output addObject:[NSNumber numberWithDouble:matrix.at<double>(i,j)]];
		}
	}
	
	return output;
}

- (std::vector<cv::KeyPoint>) sourceKeyPoints {
	return sourceKeyPoints;
}
- (std::vector<cv::KeyPoint> *) destKeyPoints {
	return destKeyPoints;
}

- (void) setSourceKeyPoints:(std::vector<cv::KeyPoint> *) keyPointPointer {
	sourceKeyPoints = *keyPointPointer;
}
- (void) setDestKeyPoints:(std::vector<cv::KeyPoint> *) keyPointPointer {
	destKeyPoints = keyPointPointer;
}

- (cv::Mat) sourceImage {
	return sourceImage;
}
- (cv::Mat *) destImage {
	return destImage;
}
- (void) setSourceImage: (cv::Mat*) imageMat {
	sourceImage = *imageMat;
	sourceDescriptorsAreFresh = NO;
}
- (void) setDestImage: (cv::Mat*) imageMat {
	destImage = imageMat;
	destDescriptorsAreFresh = NO;
}

#pragma mark -
#pragma mark Calculation

- (void) calculate {
	// Based on find_obj.cpp in OpenCV samples directory
	// -------------------------------------------------
	// 1) Calculate SURF descriptors and put those in a cv::Mat
	SURF surf;
	if(!sourceDescriptorsAreFresh || !destDescriptorsAreFresh) {
		if(!sourceDescriptorsAreFresh) {
			vector<float> _sourceDescriptors;
			surf(sourceImage, cv::Mat(), sourceKeyPoints, _sourceDescriptors, true);
			// Convert descriptor vector to cv::Mat
			float* a = new float[_sourceDescriptors.size()];	// Array to hold data for matrix conversion
			copy(_sourceDescriptors.begin(), _sourceDescriptors.end(), a);
			sourceDescriptors = Mat(sourceKeyPoints.size(), surf.descriptorSize(), CV_32F, a);
			sourceDescriptorsAreFresh = YES;
		}
		if(!destDescriptorsAreFresh) {
			vector<float> _destDescriptors;
			surf(*destImage, cv::Mat(), *destKeyPoints, _destDescriptors, true);
			// Convert descriptor vector to cv::Mat
			float* a = new float[_destDescriptors.size()];	// Array to hold data for matrix conversion
			copy(_destDescriptors.begin(), _destDescriptors.end(), a);
			destDescriptors = Mat(destKeyPoints->size(), surf.descriptorSize(), CV_32F, a);

			destDescriptorsAreFresh = YES;
		}
		// 2) Use FLANN to calculate nearest-neighbors
		cv::Mat m_indices(sourceDescriptors.rows, 2, CV_32S);
		cv::Mat m_dists(sourceDescriptors.rows, 2, CV_32F);
		
		// Build the search space index, sorting descriptors into a kd-tree
		cv::flann::Index flann_index(destDescriptors, cv::flann::KDTreeIndexParams(4));  // using 4 randomized kdtrees
		// Perform the nearest-neighbor search
		flann_index.knnSearch(sourceDescriptors, m_indices, m_dists, 2, cv::flann::SearchParams(64) ); // maximum number of leafs checked
		
		
		// 3) Throw away matches where difference between 1st and 2nd nearest neighbors is too small
		//		OR the nearest neighbor is further than 0.2 
		keyPointMatches.clear();
		int* indices_ptr = m_indices.ptr<int>(0);
		float* dists_ptr = m_dists.ptr<float>(0);
		for (int i=0;i<m_indices.rows;++i) {
			if (dists_ptr[2*i] < 0.4 && dists_ptr[2*i]<0.6*dists_ptr[2*i+1]) {	// If distance to 1st NN is less than .6 the distance to 2nd NN
				NSLog(@"1st: %f.3  2nd: %f.3", dists_ptr[2*i], dists_ptr[2*i+1]);
				keyPointMatches.push_back(i);
				keyPointMatches.push_back(indices_ptr[2*i]);
			}
		}
		NSLog(@"%i good matches (out of %i points)", keyPointMatches.size()/2, sourceKeyPoints.size());
	}
	
	// Need at least 4 pairs of matching points to calculate homography
	if(keyPointMatches.size() >= 8) {
		// FINDING THE HOMOGRAPHY NEEDS TO HAPPEN EVERY FRAME
		// THE ABOVE CAN HAPPEN ONLY WHEN A NEW SET OF POINTS IS SET TO BE TRACKED
		#pragma todo(Split this into 2 functions)
		
		// 4) Convert matched points INDICES to a vector of Point2f COORDINATES
		vector<Point2f> _sourcePointCoordinates, _destPointCoordinates;
		for(int i=0; i<keyPointMatches.size(); i+=2) {
			if(destKeyPoints->size() > keyPointMatches[i+1] && sourceKeyPoints.size() > keyPointMatches[i]) {
				_sourcePointCoordinates.push_back(sourceKeyPoints.at(keyPointMatches[i]).pt);
				_destPointCoordinates.push_back(destKeyPoints->at(keyPointMatches[i+1]).pt);
			}
		}
		Mat sourcePointCoordinates(_sourcePointCoordinates);
		Mat destPointCoordinates(_destPointCoordinates);
		// 5) Find the homography and set it to matrixData
		matrix = findHomography(sourcePointCoordinates, destPointCoordinates, CV_RANSAC, 5);
	}
	else {
		NSLog(@"NOT ENOUGH MATCHES FOUND");
	}
	
}

@end
