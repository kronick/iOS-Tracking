/*
 *  PoseFilter.cpp
 *  trackingTest
 *
 *  Created by kronick on 4/18/11.
 *  Copyright 2011 __MyCompanyName__. All rights reserved.
 *
 */

#include "PoseFilter.h"

using namespace cv;

void printMat(Mat m) {
	for(int i=0; i<m.rows; i++) {
		for(int j=0; j<m.cols; j++) {
			printf("%4.4f\t",m.at<float>(i,j));
		}
		printf("\n");
	}
	printf("\n\n");
}

PoseFilter::PoseFilter() {
	// Set the various matrices to their defaults
	stateCount				= 15;		// X,Y,Z, dX,dY,dZ, 3x3 rotation matrix
	statePre				= Mat::zeros(stateCount,1, CV_32F);
	statePost				= (Mat_<float>(stateCount,1) << 1.575203,-0.311393,1.097323, 0,0,0, 0,1,0, 1,0,0, 0,0,1);	// Initial estimate
	covariancePre			= Mat::eye(stateCount,stateCount, CV_32F);
	covariancePost			= Mat::eye(stateCount,stateCount, CV_32F);
	
	cameraMeasurementCount	= 15;		// X,Y,Z, dX,dY,dZ, 3x3 rotation matrix
	gyrosMeasurementCount	= 9;		// 3x3 rotation matrix
	gpsMeasurementCount		= 6;		// X,Y,Z, dX,dY,dZ
	
	cameraCovariance		= Mat::eye(cameraMeasurementCount,cameraMeasurementCount, CV_32F) * 0.001f;
	//cameraCovariance.at<float>(0,0) = 0.01f;
	//cameraCovariance.at<float>(1,1) = 0.01f;
	//cameraCovariance.at<float>(2,2) = 0.01f;
	//cameraCovariance.at<float>(3,3) = 0.00001f;
	//cameraCovariance.at<float>(4,4) = 0.00001f;
	//cameraCovariance.at<float>(5,5) = 0.00001f;
	
	gyrosCovariance			= Mat::eye(gyrosMeasurementCount,gyrosMeasurementCount, CV_32F) * 0.0005f;
	gpsCovariance			= Mat::eye(gpsMeasurementCount,gpsMeasurementCount, CV_32F) * 0.001f;
	processCovariance		= Mat::eye(15,15, CV_32F) * 0.0001f;
	
	// Build observation models
	cameraObservationModel	= Mat::eye(cameraMeasurementCount,stateCount, CV_32F);
	
	gyrosObservationModel	= Mat::zeros(gyrosMeasurementCount,stateCount, CV_32F);
	gyrosObservationModel.at<float>(0,6) = 1;
	gyrosObservationModel.at<float>(1,7) = 1;
	gyrosObservationModel.at<float>(2,8) = 1;
	gyrosObservationModel.at<float>(3,9) = 1;
	gyrosObservationModel.at<float>(4,10) = 1;
	gyrosObservationModel.at<float>(5,11) = 1;
	gyrosObservationModel.at<float>(6,12) = 1;
	gyrosObservationModel.at<float>(7,13) = 1;
	gyrosObservationModel.at<float>(8,14) = 1;
	
	gpsObservationModel		= Mat::eye(gpsMeasurementCount,stateCount, CV_32F);
	
	// Set what we can on the state transition model... dT terms will need to be set in predict method
	velocityDrag = 1;
	stateTransitionModel	= Mat::eye(stateCount,stateCount, CV_32F);
	stateTransitionModel.at<float>(3,3) = velocityDrag;
	stateTransitionModel.at<float>(4,4) = velocityDrag;
	stateTransitionModel.at<float>(5,5) = velocityDrag;
	
	lastPredictionTime = 0;
	lastCameraMeasurementTime = 0;
	lastGpsMeasurementTime = 0;
	
	lastCameraMeasurement	= Mat::zeros(cameraMeasurementCount-3,1, CV_32F);	// Used for automatic velocity calculation
	lastGpsMeasurement		= Mat::zeros(gpsMeasurementCount-3,1, CV_32F);			// Used for automatic velocity calculation
	cameraTarget			= Mat::zeros(cameraMeasurementCount-3,1, CV_32F);
	//cameraState				= Mat::zeros(cameraMeasurementCount,1, CV_32F);
}

Mat PoseFilter::Predict(double timestamp) {
	// Set dT
	if(lastPredictionTime == 0) lastPredictionTime = timestamp;
	double dT = timestamp - lastPredictionTime;
	if(dT < 0.001) dT = 0;
	if(dT > 0.5) dT = 0.5;
	dT = 0;
	lastPredictionTime = timestamp;
	stateTransitionModel.at<float>(0,3) = (float)dT;
	stateTransitionModel.at<float>(1,4) = (float)dT;
	stateTransitionModel.at<float>(2,5) = (float)dT;
	statePre = stateTransitionModel * statePost;	// x- = [A][x]
	//printf("Predicted velocity: %4.3f\t%4.3f\t%4.3f * dT = %4.10f\n", statePre.at<float>(3,0), statePre.at<float>(4,0), statePre.at<float>(5,0), (float)dT);
	covariancePre = ((stateTransitionModel * covariancePost) * stateTransitionModel.t()) + processCovariance;	// [A][P_k-1][A^T] + [Q]

	return statePre;
}

Mat PoseFilter::Correct(const Mat& measurement_in, PoseEstimateType poseType, double timestamp) {
	Mat measurementObservationModel, measurementCovariance, measurement;
	float V_x, V_y, V_z;
	switch(poseType) {
		case CAMERA_POSE:
			assert(measurement_in.rows == cameraMeasurementCount - 3); // Camera gives everything but velocities (x3) which are calculated automatically
			measurementObservationModel		= cameraObservationModel;
			measurementCovariance			= cameraCovariance;
			
			if(lastCameraMeasurementTime == 0 || timestamp <= lastCameraMeasurementTime) {
				printf("Interval too short... not calculating velocity: %f\n", timestamp);
				V_x = V_y = V_z = 0;	// No velocity
			}
			else {
				// Calculate velocity
				double dT = timestamp - lastCameraMeasurementTime;
				if(dT > 0.00001) {
					V_x = (measurement_in.at<float>(0,0) - lastCameraMeasurement.at<float>(0,0)) / dT;
					V_y = (measurement_in.at<float>(1,0) - lastCameraMeasurement.at<float>(1,0)) / dT;
					V_z = (measurement_in.at<float>(2,0) - lastCameraMeasurement.at<float>(2,0)) / dT;
					
					printf("Calculated Velocity: %4.3f\t%4.3f\t%4.3f\n", V_x, V_y, V_z);
				}
				else {
					// No velocity change
					V_x = statePre.at<float>(3,0);
					V_y = statePre.at<float>(4,0);
					V_z = statePre.at<float>(5,0);
				}
			}
			measurement = (Mat_<float>(cameraMeasurementCount, 1) <<
						   measurement_in.at<float>(0,0),measurement_in.at<float>(1,0),measurement_in.at<float>(2,0),
						   V_x,V_y,V_z,
						   measurement_in.at<float>(3,0),measurement_in.at<float>(4,0),measurement_in.at<float>(5,0),
						   measurement_in.at<float>(6,0),measurement_in.at<float>(7,0),measurement_in.at<float>(8,0),
						   measurement_in.at<float>(9,0),measurement_in.at<float>(10,0),measurement_in.at<float>(11,0));
			
			lastCameraMeasurementTime = timestamp;
			lastCameraMeasurement = measurement_in;
			break;
		case GYRO_POSE:
			assert(measurement_in.rows == gyrosMeasurementCount);
			measurementObservationModel		= gyrosObservationModel;
			measurementCovariance			= gyrosCovariance;
			measurement						= measurement_in;
			break;
		case GPS_POSE:
			assert(measurement_in.rows == gpsMeasurementCount - 3);	// GPS gives X,Y,Z, velocities (x3) calculated automatically
			measurementObservationModel		= gpsObservationModel;
			measurementCovariance			= gpsCovariance;
			
			if(lastGpsMeasurementTime == 0)
				V_x = V_y = V_z = 0;	// No velocity
			else {
				// Calculate velocity
				float dT = timestamp - lastGpsMeasurementTime;
				V_x = (measurement_in.at<float>(0,0) - lastGpsMeasurement.at<float>(0,0)) / dT;
				V_y = (measurement_in.at<float>(1,0) - lastGpsMeasurement.at<float>(1,0)) / dT;
				V_z = (measurement_in.at<float>(2,0) - lastGpsMeasurement.at<float>(2,0)) / dT;
			}
			measurement = (Mat_<float>(cameraMeasurementCount, 1) <<
						   measurement_in.at<float>(0,0),measurement_in.at<float>(1,0),measurement_in.at<float>(2,0),
						   V_x,V_y,V_z);
			
			lastGpsMeasurementTime = timestamp;
			lastGpsMeasurement = measurement_in;
			break;
	}
	
	Mat S = ((measurementObservationModel * covariancePre) * (measurementObservationModel.t())) + measurementCovariance;
	Mat KalmanGain = (covariancePre * (measurementObservationModel.t())) * S.inv(DECOMP_SVD);
	statePost = statePre + (KalmanGain * (measurement - (measurementObservationModel * statePre)));
	covariancePost = (Mat::eye(stateCount,stateCount, CV_32F) - (KalmanGain * measurementObservationModel)) * covariancePre;
	return statePost;

}

void PoseFilter::setCameraTarget(const cv::Mat& target) {
	cameraTarget = target;
	if(!cameraState.data) {
		cameraState = target;	// Initial value
	}
}

void PoseFilter::setGyrosCovariance(float cov) {
	gyrosCovariance	= Mat::eye(gyrosMeasurementCount,gyrosMeasurementCount, CV_32F) * cov;
}

void PoseFilter::setCameraCovariance(float cov) {
	cameraCovariance	= Mat::eye(gyrosMeasurementCount,gyrosMeasurementCount, CV_32F) * cov;
}
