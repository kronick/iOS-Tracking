/*
 *  OverlayRenderer.cpp
 *  trackingTest
 *
 *  Created by kronick on 4/5/11.
 *  Copyright 2011 __MyCompanyName__. All rights reserved.
 *
 */

#include "OverlayRenderer.hpp"

OverlayRenderer::OverlayRenderer() {
	glGenRenderbuffersOES(1, &m_renderbuffer);
	glBindRenderbufferOES(GL_RENDERBUFFER_OES, m_renderbuffer);
	frameCount = 0;
}

void OverlayRenderer::Initialize(int width, int height) {
	glGenFramebuffersOES(1, &m_framebuffer);
	glBindFramebufferOES(GL_FRAMEBUFFER_OES, m_framebuffer);
	glFramebufferRenderbufferOES(GL_FRAMEBUFFER_OES, GL_COLOR_ATTACHMENT0_OES, GL_RENDERBUFFER_OES, m_renderbuffer);
	
	glViewport(0, 0, width, height);
	
	m_modelviewMatrix[0] = 1;	m_modelviewMatrix[4] = 0;	m_modelviewMatrix[8] = 0;	m_modelviewMatrix[12] = 0;
	m_modelviewMatrix[1] = 0;	m_modelviewMatrix[5] = 1;	m_modelviewMatrix[9] = 0;	m_modelviewMatrix[13] = 0;
	m_modelviewMatrix[2] = 0;	m_modelviewMatrix[6] = 0;	m_modelviewMatrix[10] = 1;	m_modelviewMatrix[14] = 0;
	m_modelviewMatrix[3] = 0;	m_modelviewMatrix[7] = 0;	m_modelviewMatrix[11] = 0;	m_modelviewMatrix[15] = 1;
	
	m_drawOverlay = false;
	m_overlayFade = OVERLAY_FADE_TIME;

	memcpy(m_modelviewMatrix_target, m_modelviewMatrix, sizeof(GLfloat) * 16);
}

void OverlayRenderer::Render()  {
	frameCount++;
	
	// Draw 2D stuff
	// -------------
	glMatrixMode(GL_PROJECTION);
	
	const float maxX = 480;
	const float maxY = 640;
	glLoadIdentity();
	glOrthof(maxX, 0, maxY, 0, -1, 1);
	
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	
	glClearColor(0,0,0, 0);
	glClear(GL_COLOR_BUFFER_BIT);
	
	glPushMatrix();
	
	/*
	glColor4f(0, 1, 0, 1);
	for(int i=0; i<m_keypoints.size(); i++) {
		DrawRect(m_keypoints[i].pt.y, m_keypoints[i].pt.x, 2,2);
	}
	*/
	
	
	glColor4f(1, 1, 1, 1);
	for(int i=0; i<4; i++) {
		DrawLine(foundCorners[0].y, foundCorners[0].x, foundCorners[1].y, foundCorners[1].x);
		DrawLine(foundCorners[1].y, foundCorners[1].x, foundCorners[2].y, foundCorners[2].x);
		DrawLine(foundCorners[2].y, foundCorners[2].x, foundCorners[3].y, foundCorners[3].x);
		DrawLine(foundCorners[3].y, foundCorners[3].x, foundCorners[0].y, foundCorners[0].x);
	}
	
	glPopMatrix();
	
	
	// Draw 3D stuff
	// -------------
	glMatrixMode(GL_PROJECTION);
	glLoadIdentity();
	double f_x = 786.42938232;	// Focal length in x axis
	double f_y = 786.42938232;	// Focal length in y axis (usually the same?)
	double c_x = 217.01358032;	// Camera primary point x
	double c_y = 311.25384521;	// Camera primary point y
	//c_x = 480-c_x*2; c_y = 640-c_y*2;
	double screen_width = 480;
	double screen_height = 640;

	//double fovY = 1/(f_x/screen_height * 2);
	double fovY = 1/(f_x * 2);
	double aspectRatio = screen_width/screen_height * f_y/f_x;
	double near = .1;
	double far = 1000;

	float cameraMatrix[] = {2*f_x/screen_width, 0, 0, 0,
							0, 2*f_y/screen_height, 0, 0,
							2*(c_x/screen_width) - 1, 2*(c_y/screen_height) - 1, (far + near)/(near-far), -1,
							0, 0, 2 * near * far / (near - far), 0};
	//glTranslatef(0.5, -0.5 * screen_width/screen_height, 0);
	glMultMatrixf(cameraMatrix);
	
	// Ease into view
	double dist;
	for(int i=0; i<16; i++)	{	// Rotation
		dist = m_modelviewMatrix_target[i] - m_modelviewMatrix[i];
		m_modelviewMatrix[i] += 1 * dist * dist * (dist > 0 ? 1 : -1);
		m_modelviewMatrix[i] = m_modelviewMatrix_target[i];
	}
	/*
	for(int i=12; i<16; i++)	// Translation
		m_modelviewMatrix[i] += 0.2f * sqrt(m_modelviewMatrix_target[i] - m_modelviewMatrix[i]);
	*/
	glMatrixMode(GL_MODELVIEW);
	glLoadIdentity();
	glRotatef(-90, 0, 0, 1);
	//glTranslatef(0.5, -0.5*screen_width/screen_height, 0);
	//glTranslatef(0.5, -0.5*screen_width/screen_height, 0);
	glMultMatrixf(m_modelviewMatrix);
	//glTranslatef(0.5, -240./640., 0);
	//glTranslatef(-0.5, 0.5*screen_width/screen_height, 0);
	//glTranslatef(0, -1*screen_width/screen_height, 0);
	glRotatef(90, 0, 0, 1);
	
	if(!m_drawOverlay) {
		m_overlayFade--;
	}
	else {
		if(m_overlayFade < 0) m_overlayFade = 0;
		m_overlayFade++;
		if(m_overlayFade > OVERLAY_FADE_TIME) m_overlayFade = OVERLAY_FADE_TIME;
	}
	
	if(true || m_overlayFade > 0) {
		//glLoadIdentity();
		//glRotatef(-90, 0, 0, 1);
		//glTranslatef(0, 0, -2);
		//glRotatef(-45, 0, 1, 0);
		
		//float alpha = m_overlayFade/(float)OVERLAY_FADE_TIME;
		float alpha = 1;
		//float alpha = m_overlayFade%3 == 0 ? 1 : 0;	// Flicker
		
		//glTranslatef(0, 0, -2);
		glColor4f(0.5*alpha, 0.5*alpha, 0.5*alpha, alpha*0.5);
		//DrawRect(.125*2, .125*3, .25*2, .25*3);
		for(int i=-50; i<=50; i++) {
			DrawLine(.05*i,2.5,0, .05*i,-2.5,0);
			DrawLine(-2.5,.05*i,0, 2.5,.05*i,0);
			
			DrawLine(-2.5,.05*i,0, -2.5,.05*i,5);
			DrawLine(.05*i,-2.5,0, .05*i,-2.5,5);			
			DrawLine(2.5,.05*i,0, 2.5,.05*i,5);
			DrawLine(.05*i,2.5,0, .05*i,2.5,5);
			
			DrawLine(-2.5,-2.5,.05*(i+50), -2.5,2.5,.05*(i+50));
			DrawLine(-2.5,-2.5,.05*(i+50), 2.5,-2.5,.05*(i+50));
			DrawLine(2.5,2.5,.05*(i+50), -2.5,2.5,.05*(i+50));
			DrawLine(2.5,2.5,.05*(i+50), 2.5,-2.5,.05*(i+50));
			//DrawLine(.05*i,-2.5,0, .05*i,-2.5,5);			
			//DrawLine(2.5,.05*i,0, 2.5,.05*i,5);
			//DrawLine(.05*i,2.5,0, .05*i,2.5,5);
		}
		//DrawRect(0,0, 1,640./480.);
	
		
		// Draw axes
		glColor4f(1*alpha, 0, 0, alpha);
		DrawLine(0,0,0, 1,0,0);
		DrawLine(.5,0,0, .5,.05,0);
		DrawLine(.25,0,0, .25,.05,0);
		DrawLine(.75,0,0, .75,.05,0);
		
		glColor4f(0, 1*alpha, 0, alpha);
		DrawLine(0,0,0, 0,1,0);
		
		glColor4f(0, 0, 1*alpha, alpha);
		DrawLine(0,0,0, 0,0,1);
		
	}
}

#pragma mark -
#pragma mark Setters/getters
void OverlayRenderer::setKeypoints(std::vector<cv::KeyPoint> newKeypoints) {
	m_keypoints = newKeypoints;
}
void OverlayRenderer::setCorners(CGPoint corners[]) {
	for(int i=0; i<4; i++)
		foundCorners[i] = corners[i];
}
void OverlayRenderer::setModelviewMatrix(cv::Mat matrix) {
	if(matrix.data != 0)
		for(int i=0; i<16; i++)
			m_modelviewMatrix_target[i] = matrix.at<float>(i%4, (int)i/4);
}

void OverlayRenderer::setDrawOverlay(bool draw) {
	m_drawOverlay = draw;
}

#pragma mark -
#pragma mark Drawing functions

void OverlayRenderer::DrawRect(float x, float y, float width, float height) {
	float h_width  = width  * 0.5f;
	float h_height = height * 0.5f;
	vertex2 Vertices[] = {
		{x-h_width, y-h_height},
		{x+h_width, y-h_height},
		{x+h_width, y+h_height},
		{x-h_width, y-h_height},
		{x+h_width, y+h_height},
		{x-h_width, y+h_height}
	};
	
	glEnableClientState(GL_VERTEX_ARRAY);
	
	glVertexPointer(2, GL_FLOAT, sizeof(vertex2), &Vertices[0].x);
	
	GLsizei vertexCount = sizeof(Vertices) / sizeof(vertex2);
	glDrawArrays(GL_TRIANGLES, 0, vertexCount);
	
	glDisableClientState(GL_VERTEX_ARRAY);
}

void OverlayRenderer::DrawLine(float x1, float y1, float z1, float x2, float y2, float z2) {
	vertex3 vertices[] = {
		{x1,y1,z1},
		{x2,y2,z2}
	};
	
	glEnableClientState(GL_VERTEX_ARRAY);
	
	glVertexPointer(3, GL_FLOAT, sizeof(vertex3), &vertices[0].x);
	
	GLsizei vertexCount = sizeof(vertices) / sizeof(vertex3);
	glLineWidth(3);
	glDrawArrays(GL_LINES, 0, vertexCount);
	
	glDisableClientState(GL_VERTEX_ARRAY);
}


void OverlayRenderer::DrawLine(float x1, float y1, float x2, float y2) {
	vertex2 Vertices[] = {
		{x1, y1},
		{x2, y2},
	};
	
	glEnableClientState(GL_VERTEX_ARRAY);
	
	glVertexPointer(2, GL_FLOAT, sizeof(vertex2), &Vertices[0].x);
	
	GLsizei vertexCount = sizeof(Vertices) / sizeof(vertex2);
	glLineWidth(3);
	glDrawArrays(GL_LINES, 0, vertexCount);
	
	glDisableClientState(GL_VERTEX_ARRAY);	
}

