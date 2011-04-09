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
#include "CvModelEstimator.h"

using namespace cv;
using namespace std;
@implementation Homography

- (id)init {
    
    self = [super init];
    if (self) {
		useFerns = YES;
        // Initialization code.
		matrix = Mat(3,3, CV_64F);
		
		cameraMatrix = Mat(3,3, CV_64F);
		cameraMatrix.at<double>(0,0) = 786.42938232;	// f_x (Focal length)
		cameraMatrix.at<double>(1,1) = 786.42938232;	// f_y
		cameraMatrix.at<double>(2,2) = 1;
		cameraMatrix.at<double>(0,2) = 311.25384521;	// c_x (Lens center)
		cameraMatrix.at<double>(1,2) = 217.01358032;	// c_y 
		
		rotationVector.create(3,1,CV_32FC1);
		translationVector.create(3,1,CV_32FC1);
		
		double cameraValues[] = {786.42938232, 0, 311.25384521,
								 0, 786.42938232, 217.01358032,
								 0, 0, 1};
		cameraMat = cvMat(3,3, CV_64F, cameraValues);
		rotationVec = cvMat(3,1, CV_64F);
		translationVec = cvMat(3,1, CV_64F);
		trained = NO;
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
		trained = NO;
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
- (cv::Mat) getModelviewMatrix {
	return modelviewMatrix;
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
	trained = NO;
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
	trained = NO;
	sourceImage = *imageMat;
	sourceDescriptorsAreFresh = NO;	
}
- (void) setDestImage: (cv::Mat*) imageMat {
	destImage = imageMat;
	destDescriptorsAreFresh = NO;
}

#pragma mark -
#pragma mark File handling

- (void) loadTrainingData:(NSString *)resourceName {
	NSLog(@"Trying to load \"%@\"", resourceName);
	NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	string filePath([[NSString stringWithFormat:@"%@/%@", documentsDirectory, resourceName] cString]);
	
    FileStorage fs(filePath, FileStorage::READ);
    if(fs.isOpened()) {
		FileNode node = fs.getFirstTopLevelNode();
        fern.read(node["fern-classifier"]);
		cv::read(node["model-points"], sourceKeyPoints);
        NSLog(@"Training data successfully loaded.");
		trained = YES;
    }
    else {
		NSLog(@"That file does not exist.");
	}
}

- (void) saveTrainingData:(NSString *)resourceName {
	NSLog(@"Trying to save to \"%@\"", resourceName);
	NSString *documentsDirectory = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) objectAtIndex:0];
	string filePath([[NSString stringWithFormat:@"%@/%@", documentsDirectory, resourceName] cString]);
	
    FileStorage fs(filePath, FileStorage::WRITE);	
	if(fs.isOpened()) {
		WriteStructContext ws(fs, "ferns_model", CV_NODE_MAP);
		cv::write(fs, "model-points", sourceKeyPoints);
		fern.write(fs, "fern-classifier");
		NSLog(@"Training data written!");
	}
	else {
		NSLog(@"Training data file could not be opened.");
	}
}

#pragma mark -
#pragma mark Calculation

- (void) train {
	trained = NO;
	NSLog(@"Need to train to source image...");
	//scale  z-rotation       tilt
	PatchGenerator patchGen(0,256,5,true,0.05,1.0,-CV_PI/6,CV_PI/6,-CV_PI/2,CV_PI/2);
	fern.setVerbose(true);
	//for(int i=0; i<sourceKeyPoints.size(); i++) 
	//	NSLog(@"%f , %f", sourceKeyPoints[i].pt.x, sourceKeyPoints[i].pt.y);
	//NSLog(@"Source keypoint size: %i", sourceKeyPoints[0].pt.y);
	fern.trainFromSingleView(sourceImage, sourceKeyPoints,
							 32, (int)sourceKeyPoints.size(), 20, 10, 2000,
							 FernClassifier::COMPRESSION_NONE, patchGen);
	NSLog(@"Training complete!");
	sourceDescriptorsAreFresh = YES;
	trained = YES;
}
- (BOOL) isTrained {
	return trained;
}

- (BOOL) calculate {
	if(useFerns) {	// Use Ferns
		// Based on find_obj_ferns.cpp in OpenCV samples directory
		// Edited to remove LDetector, as corner detection is done using FAST
		// ------------------------------------------------------------------
		if(trained) {
			// Below is modified from planardetect.cpp OpenCV sample
			int i, j;
			int m = fern.getClassCount();
			int n = (int)destKeyPoints->size();
			vector<int> bestMatches(m, -1);
			vector<float> maxLogProb(m, -FLT_MAX);
			vector<float> signature;
			vector<Point2f> fromPt, toPt;
			
			float firstBestIndex = -1, secondBestIndex = -1;
			float firstBestProb = -FLT_MAX, secondBestProb = -FLT_MAX;
			for( i = 0; i < n; i++ )
			{
				firstBestIndex = -1; secondBestIndex = -1;
				firstBestProb = -FLT_MAX; secondBestProb = -FLT_MAX;
				KeyPoint kpt = (*destKeyPoints)[i];
				int firstBestIndex = fern(*destImage, kpt.pt, signature);	// Returns the point index of the most likely match
																// Signature contains probabilities of a match with each source keypoint
				if( firstBestIndex >= 0 && (bestMatches[firstBestIndex] < 0 || signature[firstBestIndex] > maxLogProb[firstBestIndex]))	// If this is the new best match for a point, update the match index array
				{
					firstBestProb = signature[firstBestIndex];
					// Find second best match
					for(j=0; j<m; j++) {
						if(j != firstBestIndex && signature[j] > secondBestProb) {
							secondBestIndex = j;
							secondBestProb = signature[j];
						}
					}
					// Compare ratio of first and second best matches
					
					//if(firstBestProb-secondBestProb > 3) {
					if(firstBestProb > -90 && firstBestProb-secondBestProb > 4) {
						//NSLog(@"Good point ratio: %f", firstBestProb-secondBestProb);
						//NSLog(@"Good point: %f", firstBestProb);
						
						//NSLog(@"New best match for point %i with probability %f (beats %f)", k, signature[k], maxLogProb[k]);
						maxLogProb[firstBestIndex] = signature[firstBestIndex];
						bestMatches[firstBestIndex] = i;
					}
					//else
						//NSLog(@"Bad point ratio: %f", firstBestProb-secondBestProb);
				}
			}
			
			pairs.resize(0);
			
			vector<Point3f> threeDPoints;
			
			float sumLogProb = 0;
			for( i = 0; i < m; i++ ) {
				if( bestMatches[i] >= 0 )
				{
					fromPt.push_back(sourceKeyPoints[i].pt);
					threeDPoints.push_back(Point3f(sourceKeyPoints[i].pt.x, sourceKeyPoints[i].pt.y, 0));
					toPt.push_back((*destKeyPoints)[bestMatches[i]].pt);
					//NSLog(@"Log prob: %f", maxLogProb[i]);
					sumLogProb += maxLogProb[i];
				}
			}
			
			//NSLog(@"Found %i points with average log prob %f", (int)fromPt.size(), sumLogProb/(float)fromPt.size());
			if( fromPt.size() >= 20 ) {
				vector<uchar> mask;
			
				//matrix = findHomography(Mat(fromPt), Mat(toPt), mask, RANSAC, 2);
				Mat from = Mat(fromPt);
				Mat to = Mat(toPt);
				HomographyEstimate estimate = [self findHomographyFrom:from To:to];
				matrix = estimate.homography;
				
				
				if(matrix.data ==0 || estimate.inliers < 10) {
					NSLog(@"Did not detect object.");
					return NO;
				}
				
				NSLog(@"Successfully found homography!");
				
				// Find the corners
				vector<Point2f> foundCorners;
				vector<Point3f> originalCorners;
				float foundCornerValues[8];
				float originalCornerValues[12];
				for(int i=0; i<4; i++) {
					double x,y;
					switch(i) {
						case 0:
							x=0; y=0; break;
						case 1:
							x=destImage->cols; y=0; break;
						case 2:
							x=destImage->cols; y=destImage->rows; break;
						case 3:
							x=0; y=destImage->rows; break;
							
					}
					double Z = 1./(matrix.at<double>(2,0)*x + matrix.at<double>(2,1)*y + matrix.at<double>(2,2));
					double X = (matrix.at<double>(0,0)*x + matrix.at<double>(0,1)*y + matrix.at<double>(0,2))*Z;
					double Y = (matrix.at<double>(1,0)*x + matrix.at<double>(1,1)*y + matrix.at<double>(1,2))*Z;
					foundCorners.push_back(Point2f((float)X, (float)Y));
					originalCorners.push_back(Point3f((float)x,(float)y,0));
					
					foundCornerValues[i*2] = X;
					foundCornerValues[i*2+1] = Y;
					
					originalCornerValues[i*3] = x;
					originalCornerValues[i*3+1] = y;
					originalCornerValues[i*3+2] = 0;
					
					//NSLog(@"Corner %i: (%f, %f)", i, X, Y);
				}				
				
				// Decompose the Homography into translation and rotation vectors
				// Based on: https://gist.github.com/740979/97f54a63eb5f61f8f2eb578d60eb44839556ff3f
				
				Mat inverseCameraMatrix = (Mat_<double>(3,3) << 1/cameraMatrix.at<double>(0,0) , 0 , -cameraMatrix.at<double>(0,2)/cameraMatrix.at<double>(0,0) ,
																0 , 1/cameraMatrix.at<double>(1,1) , -cameraMatrix.at<double>(1,2)/cameraMatrix.at<double>(1,1) ,
																0 , 0 , 1);
				// Column vectors of homography
				Mat h1 = (Mat_<double>(3,1) << matrix.at<double>(0,0) , matrix.at<double>(1,0) , matrix.at<double>(2,0));
				Mat h2 = (Mat_<double>(3,1) << matrix.at<double>(0,1) , matrix.at<double>(1,1) , matrix.at<double>(2,1));
				Mat h3 = (Mat_<double>(3,1) << matrix.at<double>(0,2) , matrix.at<double>(1,2) , matrix.at<double>(2,2));
				
				Mat inverseH1 = inverseCameraMatrix * h1;
				double lambda = sqrt(h1.at<double>(0,0)*h1.at<double>(0,0) +
									 h1.at<double>(1,0)*h1.at<double>(1,0) +
									 h1.at<double>(2,0)*h1.at<double>(2,0));	// Just calculating the euclidean length of this column...
				
				
				Mat rotationMatrix; 
				
				if(lambda != 0) {
					lambda = 1/lambda;
					// Normalize inverseCameraMatrix
					inverseCameraMatrix.at<double>(0,0) *= lambda;
					inverseCameraMatrix.at<double>(1,0) *= lambda;
					inverseCameraMatrix.at<double>(2,0) *= lambda;
					inverseCameraMatrix.at<double>(0,1) *= lambda;
					inverseCameraMatrix.at<double>(1,1) *= lambda;
					inverseCameraMatrix.at<double>(2,1) *= lambda;
					inverseCameraMatrix.at<double>(0,2) *= lambda;
					inverseCameraMatrix.at<double>(1,2) *= lambda;
					inverseCameraMatrix.at<double>(2,2) *= lambda;
					
					// Column vectors of rotation matrix
					Mat r1 = inverseCameraMatrix * h1;
					Mat r2 = inverseCameraMatrix * h2;
					Mat r3 = r1.cross(r2);				// Orthogonal to r1 and r2
					
					//NSLog(@"R1: %f\t%f\t%f", r1.at<double>(0,0)*100, r1.at<double>(1,0)*100, r1.at<double>(2,0)*100);
					//NSLog(@"R2: %f\t%f\t%f", r2.at<double>(0,0)*100, r2.at<double>(1,0)*100, r2.at<double>(2,0)*100);
					//NSLog(@"R3: %f\t%f\t%f", r3.at<double>(0,0)*100, r3.at<double>(1,0)*100, r3.at<double>(2,0)*100);
					
					// Put rotation columns into rotation matrix
					rotationMatrix = (Mat_<double>(3,3) <<		r1.at<double>(0,0) , -r2.at<double>(0,0) , -r3.at<double>(0,0) ,
																-r1.at<double>(1,0) , r2.at<double>(1,0) , r3.at<double>(1,0) ,
																-r1.at<double>(2,0) , r2.at<double>(2,0) , r3.at<double>(2,0));
					
					//rotationMatrix = rotationMatrix.t();
					
					// Translation vector T
					translationVector = inverseCameraMatrix * h3;
					translationVector.at<double>(0,0) *= 1;
					translationVector.at<double>(1,0) *= -1;
					translationVector.at<double>(2,0) *= -1;
					
					SVD decomposed(rotationMatrix);	// I don't really know what this does. But it works. Maybe it removes the translation components?
					rotationMatrix = decomposed.u * decomposed.vt;
					
				}
				else {
					NSLog(@"Lambda was 0...");
				}
				
				//rotationMatrix = rotationMatrix.t();
				
				modelviewMatrix = (Mat_<float>(4,4) <<	rotationMatrix.at<double>(0,0), rotationMatrix.at<double>(0,1), rotationMatrix.at<double>(0,2), translationVector.at<double>(0,0),
														rotationMatrix.at<double>(1,0), rotationMatrix.at<double>(1,1), rotationMatrix.at<double>(1,2), translationVector.at<double>(1,0),
														rotationMatrix.at<double>(2,0), rotationMatrix.at<double>(2,1), rotationMatrix.at<double>(2,2), translationVector.at<double>(2,0),
														0,0,0,1);
				
				///cv::solvePnP(Mat(originalCorners), Mat(foundCorners), cameraMatrix, Mat(), rotationVector, translationVector);
				//NSLog(@"Translation: %f, %f, %f", translationVector.at<double>(0,0), translationVector.at<double>(1,0), translationVector.at<double>(2,0));
				//NSLog(@"Rotation:");
				//NSLog(@"%f, %f, %f", rotationMatrix.at<double>(0,0), rotationMatrix.at<double>(0,1), rotationMatrix.at<double>(0,2));			
				//NSLog(@"%f, %f, %f", rotationMatrix.at<double>(1,0), rotationMatrix.at<double>(1,1), rotationMatrix.at<double>(1,2));			
				//NSLog(@"%f, %f, %f", rotationMatrix.at<double>(2,0), rotationMatrix.at<double>(2,1), rotationMatrix.at<double>(2,2));			
				return YES;
			}
			else {
				//NSLog(@"Source image not detected.");
				return NO;
			}
		}			
	}
	/*
	else { // Use SURF
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
			return YES;
		}
		else {
			NSLog(@"NOT ENOUGH MATCHES FOUND");
		}
		
		return NO;
	}
	*/
	
	return NO;
}


- (HomographyEstimate) findHomographyFrom:(cv::Mat&)fromPoints To:(cv::Mat&) toPoints {
	// Make sure we have valid matrices with enough (4) points
	CV_Assert(fromPoints.isContinuous() && toPoints.isContinuous() &&
              fromPoints.type() == toPoints.type() &&
              ((fromPoints.rows == 1 && fromPoints.channels() == 2) ||
               fromPoints.cols*fromPoints.channels() == 2) &&
              ((toPoints.rows == 1 && toPoints.channels() == 2) ||
               toPoints.cols*toPoints.channels() == 2));

	int count = MAX(fromPoints.cols, fromPoints.rows);
	NSLog(@"Using %i points", count);
	
	// Convert cv::Mat to CvMat
	CvMat _pt1 = Mat(toPoints), _pt2 = Mat(fromPoints);
	
	// Convert points to homogeneous coordinates
	cv::Ptr<CvMat> fromPoints_homogeneous, toPoints_homogeneous;
	
	fromPoints_homogeneous = cvCreateMat(1, count, CV_64FC2);
	cvConvertPointsHomogeneous(&_pt1, fromPoints_homogeneous);	// m
	
	toPoints_homogeneous = cvCreateMat( 1, count, CV_64FC2);
	cvConvertPointsHomogeneous(&_pt2, toPoints_homogeneous);	// M
	
	// Set the input mask to all 1's
	cv::Ptr<CvMat> tempMask;
	tempMask = cvCreateMat( 1, count, CV_8U );
	cvSet( tempMask, cvScalarAll(1.) );
	
	// Set RANSAC parameters
	const double confidence = 0.995;			// 0.995
	const int maxIters = 500;					// OpenCV default is hardcoded to 2000
	const double ransacReprojThreshold = 3;		// 3
	bool result = false;
	
	Mat H(3, 3, CV_64F);    
    CvMat matH = H;			// matH points to H, our return value
	
	CvHomographyEstimator estimator(MIN(count, 4));
	result = estimator.runRANSAC(toPoints_homogeneous, fromPoints_homogeneous, &matH, tempMask, ransacReprojThreshold, confidence, maxIters);
	
	if(result && count > 4) {
		icvCompressPoints((CvPoint2D64f*)toPoints_homogeneous->data.ptr, tempMask->data.ptr, 1, count);
		count = icvCompressPoints((CvPoint2D64f*)fromPoints_homogeneous->data.ptr, tempMask->data.ptr, 1, count);
		toPoints_homogeneous->cols = fromPoints_homogeneous->cols = count;

		estimator.runKernel(toPoints_homogeneous, fromPoints_homogeneous, &matH);	// RANSAC only?
		estimator.refine(toPoints_homogeneous, fromPoints_homogeneous, &matH, 10);
	}
	
	NSLog(@"Inliers? %i", count);
	
	if(!result)
		H = Scalar(0);
	
	HomographyEstimate estimate;
	estimate.homography = H;
	estimate.inliers = count;
	return estimate;
}

template<typename T> int icvCompressPoints( T* ptr, const uchar* mask, int mstep, int count )
{
    int i, j;
    for( i = j = 0; i < count; i++ )
        if( mask[i*mstep] )
        {
            if( i > j )
                ptr[j] = ptr[i];
            j++;
        }
    return j;
}

@end
