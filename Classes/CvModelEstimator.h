/*
 *  CvModelEstimator.h
 *  trackingTest
 *
 *  Created by kronick on 4/8/11.
 *  Copyright 2011 __MyCompanyName__. All rights reserved.
 *
 */

#ifndef _CV_MODEL_EST_H_
#define _CV_MODEL_EST_H_

//#include "precomp.hpp"

#import <opencv2/opencv.hpp>
#include <opencv2/calib3d/calib3d.hpp>

class CvModelEstimator2
{
public:
    CvModelEstimator2(int _modelPoints, CvSize _modelSize, int _maxBasicSolutions);
    virtual ~CvModelEstimator2();
	
    virtual int runKernel( const CvMat* m1, const CvMat* m2, CvMat* model )=0;
    virtual bool runLMeDS( const CvMat* m1, const CvMat* m2, CvMat* model,
						  CvMat* mask, double confidence=0.99, int maxIters=2000 );
    virtual bool runRANSAC( const CvMat* m1, const CvMat* m2, CvMat* model,
						   CvMat* mask, double threshold,
						   double confidence=0.99, int maxIters=2000 );
    virtual bool refine( const CvMat*, const CvMat*, CvMat*, int ) { return true; }
    virtual void setSeed( int64 seed );
	
protected:
    virtual void computeReprojError( const CvMat* m1, const CvMat* m2,
									const CvMat* model, CvMat* error ) = 0;
    virtual int findInliers( const CvMat* m1, const CvMat* m2,
							const CvMat* model, CvMat* error,
							CvMat* mask, double threshold );
    virtual bool getSubset( const CvMat* m1, const CvMat* m2,
						   CvMat* ms1, CvMat* ms2, int maxAttempts=1000 );
    virtual bool checkSubset( const CvMat* ms1, int count );
	
    CvRNG rng;
    int modelPoints;
    CvSize modelSize;
    int maxBasicSolutions;
    bool checkPartialSubsets;
};

class CvHomographyEstimator : public CvModelEstimator2
{
public:
    CvHomographyEstimator( int modelPoints );
	
    virtual int runKernel( const CvMat* m1, const CvMat* m2, CvMat* model );
    virtual bool refine( const CvMat* m1, const CvMat* m2,
						CvMat* model, int maxIters );
protected:
    virtual void computeReprojError( const CvMat* m1, const CvMat* m2,
									const CvMat* model, CvMat* error );
};

template<typename T> int icvCompressPoints( T* ptr, const uchar* mask, int mstep, int count );

#endif // _CV_MODEL_EST_H_