//
//  AGPhotoBrowserZoomableView.m
//  AGPhotoBrowser
//
//  Created by Dimitris-Sotiris Tsolis on 24/11/13.
//  Copyright (c) 2013 Andrea Giavatto. All rights reserved.
//

#import "AGPhotoBrowserZoomableView.h"

@implementation AGPhotoBrowserZoomableView

- (id)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:frame];
    if (self) {
		self.translatesAutoresizingMaskIntoConstraints = NO;
        self.delegate = self;
        self.imageView = [[UIImageView alloc] initWithFrame:frame];
        self.imageView.contentMode = UIViewContentModeScaleAspectFit;
		self.imageView.translatesAutoresizingMaskIntoConstraints = NO;
        self.frame = frame;
        
        self.minimumZoomScale = 1.0f;
        self.maximumZoomScale = 5.0f;
        
        UITapGestureRecognizer *doubleTap = [[UITapGestureRecognizer alloc] initWithTarget:self
                                                                                    action:@selector(doubleTapped:)];
        doubleTap.numberOfTapsRequired = 2;
        [self addGestureRecognizer:doubleTap];
        
        [self addSubview:self.imageView];
    }
    return self;
}
/*
- (void)updateConstraints
{
	[self removeConstraints:self.constraints];
	
	NSDictionary *constrainedViews = NSDictionaryOfVariableBindings(_imageView);
	
	[self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"H:|[_imageView]|"
																 options:0
																 metrics:@{}
																   views:constrainedViews]];
	[self addConstraints:[NSLayoutConstraint constraintsWithVisualFormat:@"V:|[_imageView]|"
																 options:0
																 metrics:@{}
																   views:constrainedViews]];
	[self addConstraint:[NSLayoutConstraint constraintWithItem:_imageView
													attribute:NSLayoutAttributeCenterX
													relatedBy:NSLayoutRelationEqual
													   toItem:_imageView.superview
													attribute:NSLayoutAttributeCenterX
												   multiplier:1.f constant:0.f]];
	[self addConstraint:[NSLayoutConstraint constraintWithItem:_imageView
													 attribute:NSLayoutAttributeCenterY
													 relatedBy:NSLayoutRelationEqual
														toItem:_imageView.superview
													 attribute:NSLayoutAttributeCenterY
													multiplier:1.f constant:0.f]];
	
	[super updateConstraints];
}*/


#pragma mark - Public methods

- (void)setImage:(UIImage *)image
{
    self.imageView.image = image;
	
	//[self updateConstraints];
}


#pragma mark - Touch handling

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event
{
    if (!self.dragging) {
        if ([self.zoomableDelegate respondsToSelector:@selector(didDoubleTapZoomableView:)])
            [self.zoomableDelegate didDoubleTapZoomableView:self];
    }
}


#pragma mark - Recognizer

- (void)doubleTapped:(UITapGestureRecognizer *)recognizer
{
    if (self.zoomScale > 1.0f) {
        [UIView animateWithDuration:0.4f animations:^{
            self.zoomScale = 1.0f;
        }];
    }
    else {
        [UIView animateWithDuration:0.4f animations:^{
            CGPoint point = [recognizer locationInView:self];
            [self zoomToRect:CGRectMake(point.x, point.y, 0, 0) animated:YES];
        }];
    }
}

#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidEndZooming:(UIScrollView *)scrollView withView:(UIView *)view atScale:(float)scale
{
}

- (UIView *)viewForZoomingInScrollView:(UIScrollView *)scrollView
{
    return self.imageView;
}

@end
