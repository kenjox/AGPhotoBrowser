//
//  AGPhotoBrowserView.m
//  AGPhotoBrowser
//
//  Created by Hellrider on 7/28/13.
//  Copyright (c) 2013 Andrea Giavatto. All rights reserved.
//

#import "AGPhotoBrowserView.h"

#import <QuartzCore/QuartzCore.h>
#import "AGPhotoBrowserOverlayView.h"
#import "AGPhotoBrowserZoomableView.h"
#import "AGPhotoBrowserCell.h"
#import "AGPhotoBrowserCellProtocol.h"

@interface AGPhotoBrowserView () <
AGPhotoBrowserOverlayViewDelegate,
AGPhotoBrowserCellDelegate,
UITableViewDataSource,
UITableViewDelegate,
UIGestureRecognizerDelegate
> {
	CGPoint _startingPanPoint;
	BOOL _wantedFullscreenLayout;
    BOOL _navigationBarWasHidden;
	CGRect _originalParentViewFrame;
	NSInteger _currentlySelectedIndex;
}

@property (nonatomic, strong, readwrite) UIButton *doneButton;
@property (nonatomic, strong) UITableView *photoTableView;
@property (nonatomic, strong) AGPhotoBrowserOverlayView *overlayView;

@property (nonatomic, strong) UIWindow *previousWindow;
@property (nonatomic, strong) UIWindow *currentWindow;

@property (nonatomic, assign, readonly) CGFloat cellHeight;

@property (nonatomic, assign, getter = isDisplayingDetailedView) BOOL displayingDetailedView;

@end


static NSString *CellIdentifier = @"AGPhotoBrowserCell";

@implementation AGPhotoBrowserView

const NSInteger AGPhotoBrowserThresholdToCenter = 150;

- (instancetype)initWithFrame:(CGRect)frame
{
    self = [super initWithFrame:[UIScreen mainScreen].bounds];
    if (self) {
        // Initialization code
		[self setupView];
    }
    return self;
}

- (void)setupView
{
	self.userInteractionEnabled = NO;
	self.backgroundColor = [UIColor colorWithWhite:0. alpha:0.];
	_currentlySelectedIndex = NSNotFound;
	
	[self addSubview:self.photoTableView];
	[self addSubview:self.doneButton];
	[self addSubview:self.overlayView];
	/*
	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(statusBarDidChangeFrame:)
                                                 name:UIDeviceOrientationDidChangeNotification
                                               object:nil];*/
}


#pragma mark - Getters

- (UIButton *)doneButton
{
	if (!_doneButton) {
		int currentScreenWidth = CGRectGetWidth([[UIScreen mainScreen] bounds]);
		_doneButton = [[UIButton alloc] initWithFrame:CGRectMake(currentScreenWidth - 60 - 10, 20, 60, 32)];
		[_doneButton setTitle:NSLocalizedString(@"Done", @"Title for Done button") forState:UIControlStateNormal];
		_doneButton.layer.cornerRadius = 3.0f;
		_doneButton.layer.borderColor = [UIColor colorWithWhite:0.9 alpha:0.9].CGColor;
		_doneButton.layer.borderWidth = 1.0f;
		[_doneButton setBackgroundColor:[UIColor colorWithWhite:0.1 alpha:0.5]];
		[_doneButton setTitleColor:[UIColor colorWithWhite:0.9 alpha:0.9] forState:UIControlStateNormal];
		[_doneButton setTitleColor:[UIColor colorWithWhite:0.9 alpha:0.9] forState:UIControlStateHighlighted];
		[_doneButton.titleLabel setFont:[UIFont boldSystemFontOfSize:14.0f]];
		_doneButton.alpha = 0.;
		
		[_doneButton addTarget:self action:@selector(p_doneButtonTapped:) forControlEvents:UIControlEventTouchUpInside];
	}
	
	return _doneButton;
}

- (UITableView *)photoTableView
{
	if (!_photoTableView) {
		CGRect screenBounds = [[UIScreen mainScreen] bounds];
		_photoTableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, CGRectGetHeight(screenBounds), CGRectGetWidth(screenBounds))];
		_photoTableView.autoresizingMask = UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleWidth;
		_photoTableView.dataSource = self;
		_photoTableView.delegate = self;
		_photoTableView.separatorStyle = UITableViewCellSeparatorStyleNone;
		_photoTableView.backgroundColor = [UIColor clearColor];
		_photoTableView.pagingEnabled = YES;
		_photoTableView.showsVerticalScrollIndicator = NO;
		_photoTableView.showsHorizontalScrollIndicator = NO;
		_photoTableView.alpha = 0.;
		
		// -- Rotate table horizontally
		CGAffineTransform rotateTable = CGAffineTransformMakeRotation(-M_PI_2);
		CGPoint origin = _photoTableView.frame.origin;
		_photoTableView.transform = rotateTable;
		CGRect frame = _photoTableView.frame;
		frame.origin = origin;
		_photoTableView.frame = frame;
	}
	
	return _photoTableView;
}

- (AGPhotoBrowserOverlayView *)overlayView
{
	if (!_overlayView) {
		_overlayView = [[AGPhotoBrowserOverlayView alloc] initWithFrame:CGRectMake(0, CGRectGetHeight(self.frame) - AGPhotoBrowserOverlayInitialHeight, CGRectGetWidth(self.frame), AGPhotoBrowserOverlayInitialHeight)];
		_overlayView.delegate = self;
	}
	
	return _overlayView;
}

- (CGFloat)cellHeight
{
    /*NSLog(@"Current window frame %@", NSStringFromCGRect(self.currentWindow.frame));
	UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    NSLog(@"Orientation %d", orientation);
	if (orientation == UIDeviceOrientationLandscapeLeft || orientation == UIDeviceOrientationLandscapeRight) {
		NSLog(@"LANDSCAPE");
        return CGRectGetHeight(self.currentWindow.frame);
	}
    NSLog(@"PORTRAIT");
	
	return CGRectGetWidth(self.currentWindow.frame);*/
    
    return CGRectGetWidth([UIScreen mainScreen].bounds);
}


#pragma mark - Setters

- (void)setDisplayingDetailedView:(BOOL)displayingDetailedView
{
	_displayingDetailedView = displayingDetailedView;
	
	CGFloat newAlpha;
	
	if (_displayingDetailedView) {
		[self.overlayView showOverlayAnimated:YES];
		newAlpha = 1.;
	} else {
		[self.overlayView hideOverlayAnimated:YES];
		newAlpha = 0.;
	}
	
	[UIView animateWithDuration:AGPhotoBrowserAnimationDuration
					 animations:^(){
						 self.doneButton.alpha = newAlpha;
					 }];
}


#pragma mark - UITableViewDataSource

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return self.cellHeight;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	NSInteger number = [_dataSource numberOfPhotosForPhotoBrowser:self];
    
    if (number > 0 && _currentlySelectedIndex == NSNotFound) {
        // initialize with info for the first photo in photoTable
        [self setupPhotoForIndex:0];
    }
    
    return number;
}

- (void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
	cell.backgroundColor = [UIColor clearColor];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell<AGPhotoBrowserCellProtocol> *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (!cell) {
        if ([_dataSource respondsToSelector:@selector(cellForBrowser:withReuseIdentifier:)]) {
            cell = [_dataSource cellForBrowser:self withReuseIdentifier:CellIdentifier];
        } else {
            cell = [[AGPhotoBrowserCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        }
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
		cell.delegate = self;
    }
    
    [self configureCell:cell forRowAtIndexPath:indexPath];
    
    return cell;
}

- (void)configureCell:(UITableViewCell<AGPhotoBrowserCellProtocol> *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    CGRect cellFrame = cell.frame;
    cellFrame.size.width = self.cellHeight;
    cell.frame = cellFrame;
	[cell resetZoomScale];
    
    if ([_dataSource respondsToSelector:@selector(photoBrowser:URLStringForImageAtIndex:)] && [cell respondsToSelector:@selector(setZoomableImageWithURL:)]) {
        [cell setZoomableImageWithURL:[NSURL URLWithString:[_dataSource photoBrowser:self URLStringForImageAtIndex:indexPath.row]]];
    } else {
        [cell setZoomableImage:[_dataSource photoBrowser:self imageAtIndex:indexPath.row]];
    }
}


#pragma mark - UITableViewDelegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    self.displayingDetailedView = !self.isDisplayingDetailedView;
}


#pragma mark - AGPhotoBrowserCellDelegate

- (void)didPanOnZoomableViewForCell:(id<AGPhotoBrowserCellProtocol>)cell withRecognizer:(UIPanGestureRecognizer *)recognizer
{
	[self p_imageViewPanned:recognizer];
}

- (void)didDoubleTapOnZoomableViewForCell:(id<AGPhotoBrowserCellProtocol>)cell
{
	self.displayingDetailedView = !self.isDisplayingDetailedView;
}


#pragma mark - UIScrollViewDelegate

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{
	[self.overlayView resetOverlayView];
	
	CGPoint targetContentOffset = scrollView.contentOffset;
    
	UITableView *tv = (UITableView*)scrollView;
	NSIndexPath *indexPathOfTopRowAfterScrolling = [tv indexPathForRowAtPoint:
													targetContentOffset
													];
	CGRect rectForTopRowAfterScrolling = [tv rectForRowAtIndexPath:
										  indexPathOfTopRowAfterScrolling
										  ];
	targetContentOffset.y = rectForTopRowAfterScrolling.origin.y;
	
	int index = floor(targetContentOffset.y / self.cellHeight);
	
    if ([self.dataSource respondsToSelector:@selector(photoBrowser:willDisplayActionButtonAtIndex:)]) {
        self.overlayView.actionButton.hidden = [self.dataSource photoBrowser:self willDisplayActionButtonAtIndex:index];
    } else {
        self.overlayView.actionButton.hidden = NO;
    }
    
	[self setupPhotoForIndex:index];
}

- (void)setupPhotoForIndex:(int)index
{
    _currentlySelectedIndex = index;
	
	if ([_dataSource respondsToSelector:@selector(photoBrowser:titleForImageAtIndex:)]) {
		self.overlayView.title = [_dataSource photoBrowser:self titleForImageAtIndex:index];
	} else {
        self.overlayView.title = @"";
    }
	
	if ([_dataSource respondsToSelector:@selector(photoBrowser:descriptionForImageAtIndex:)]) {
		self.overlayView.description = [_dataSource photoBrowser:self descriptionForImageAtIndex:index];
	} else {
        self.overlayView.description = @"";
    }
}


#pragma mark - Public methods

- (void)show
{
    self.previousWindow = [[UIApplication sharedApplication] keyWindow];
    
    self.currentWindow = [[UIWindow alloc] initWithFrame:self.previousWindow.bounds];
    //self.currentWindow.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight | UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
    self.currentWindow.windowLevel = UIWindowLevelStatusBar;
    self.currentWindow.hidden = NO;
    self.currentWindow.backgroundColor = [UIColor clearColor];
    [self.currentWindow makeKeyAndVisible];
    [self.currentWindow addSubview:self];
	
	[UIView animateWithDuration:AGPhotoBrowserAnimationDuration
					 animations:^(){
						 self.backgroundColor = [UIColor colorWithWhite:0. alpha:1.];
					 }
					 completion:^(BOOL finished){
						 if (finished) {
							 self.userInteractionEnabled = YES;
							 self.displayingDetailedView = YES;
							 self.photoTableView.alpha = 1.;
							 [self.photoTableView reloadData];
						 }
					 }];
}

- (void)showFromIndex:(NSInteger)initialIndex
{
	if (initialIndex < [_dataSource numberOfPhotosForPhotoBrowser:self]) {
		[self.photoTableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:initialIndex inSection:0] atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
	}
	
	[self show];
}

- (void)hideWithCompletion:( void (^) (BOOL finished) )completionBlock
{
	[UIView animateWithDuration:AGPhotoBrowserAnimationDuration
					 animations:^(){
						 self.photoTableView.alpha = 0.;
						 self.backgroundColor = [UIColor colorWithWhite:0. alpha:0.];
					 }
					 completion:^(BOOL finished){
						 self.userInteractionEnabled = NO;
                         [self removeFromSuperview];
                         [self.previousWindow makeKeyAndVisible];
                         self.currentWindow.hidden = YES;
                         self.currentWindow = nil;
						 if(completionBlock) {
							 completionBlock(finished);
						 }
					 }];
}


#pragma mark - AGPhotoBrowserOverlayViewDelegate

- (void)sharingView:(AGPhotoBrowserOverlayView *)sharingView didTapOnActionButton:(UIButton *)actionButton
{
	if ([_delegate respondsToSelector:@selector(photoBrowser:didTapOnActionButton:atIndex:)]) {
		[_delegate photoBrowser:self didTapOnActionButton:actionButton atIndex:_currentlySelectedIndex];
	}
}

- (void)sharingView:(AGPhotoBrowserOverlayView *)sharingView didTapOnSeeMoreButton:(UIButton *)actionButton
{
	CGSize descriptionSize;
	if (floor(NSFoundationVersionNumber) <= NSFoundationVersionNumber_iOS_6_1) {
		descriptionSize = [sharingView.description sizeWithFont:sharingView.descriptionLabel.font constrainedToSize:CGSizeMake(CGRectGetWidth([UIScreen mainScreen].bounds) - 40, MAXFLOAT)];
	} else {
		NSDictionary *textAttributes = @{NSFontAttributeName : sharingView.descriptionLabel.font};
		CGRect descriptionBoundingRect = [sharingView.description boundingRectWithSize:CGSizeMake(CGRectGetWidth([UIScreen mainScreen].bounds) - 40, MAXFLOAT)
																			   options:NSStringDrawingUsesLineFragmentOrigin|NSStringDrawingUsesFontLeading attributes:textAttributes
																			   context:nil];
		descriptionSize = CGSizeMake(ceil(CGRectGetWidth(descriptionBoundingRect)), ceil(CGRectGetHeight(descriptionBoundingRect)));
	}
	
	CGRect currentOverlayFrame = self.overlayView.frame;
	int newSharingHeight = CGRectGetHeight(currentOverlayFrame) -20 + ceil(descriptionSize.height);
	
	[UIView animateWithDuration:AGPhotoBrowserAnimationDuration
					 animations:^(){
						 self.overlayView.frame = CGRectMake(0, floor(CGRectGetHeight(self.frame) - newSharingHeight), CGRectGetWidth(self.frame), newSharingHeight);
					 }];
}


#pragma mark - Recognizers

- (void)p_imageViewPanned:(UIPanGestureRecognizer *)recognizer
{
	AGPhotoBrowserZoomableView *imageView = (AGPhotoBrowserZoomableView *)recognizer.view;
	
	if (recognizer.state == UIGestureRecognizerStateBegan) {
		// -- Disable table view scrolling
		self.photoTableView.scrollEnabled = NO;
		// -- Hide detailed view
		self.displayingDetailedView = NO;
		_startingPanPoint = imageView.center;
		return;
	}
	
	if (recognizer.state == UIGestureRecognizerStateEnded) {
		// -- Enable table view scrolling
		self.photoTableView.scrollEnabled = YES;
		// -- Check if user dismissed the view
		CGPoint endingPanPoint = [recognizer translationInView:self];
		CGPoint translatedPoint = CGPointMake(_startingPanPoint.x - endingPanPoint.y, _startingPanPoint.y);
		int heightDifference = abs(floor(_startingPanPoint.x - translatedPoint.x));
		
		if (heightDifference <= AGPhotoBrowserThresholdToCenter) {
            
			// -- Back to original center
			[UIView animateWithDuration:AGPhotoBrowserAnimationDuration
							 animations:^(){
								 self.backgroundColor = [UIColor colorWithWhite:0. alpha:1.];
								 imageView.center = self->_startingPanPoint;
							 } completion:^(BOOL finished){
								 // -- show detailed view?
								 self.displayingDetailedView = YES;
							 }];
		} else {
			// -- Animate out!
			typeof(self) weakSelf __weak = self;
			[self hideWithCompletion:^(BOOL finished){
				typeof(weakSelf) strongSelf __strong = weakSelf;
				if (strongSelf) {
					imageView.center = strongSelf->_startingPanPoint;
				}
			}];
		}
	} else {
		CGPoint middlePanPoint = [recognizer translationInView:self];
		
		UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
		CGPoint translatedPoint;
		
		if (orientation == UIDeviceOrientationLandscapeLeft || orientation == UIDeviceOrientationLandscapeRight) {
			translatedPoint = CGPointMake(_startingPanPoint.x + middlePanPoint.x, _startingPanPoint.y);
		} else {
			translatedPoint = CGPointMake(_startingPanPoint.x - middlePanPoint.y, _startingPanPoint.y);
		}
		
		imageView.center = translatedPoint;
		int heightDifference = abs(floor(_startingPanPoint.x - translatedPoint.x));
		CGFloat ratio = (_startingPanPoint.x - heightDifference)/_startingPanPoint.x;
		self.backgroundColor = [UIColor colorWithWhite:0. alpha:ratio];
	}
}


#pragma mark - Private methods

- (void)p_doneButtonTapped:(UIButton *)sender
{
	if ([_delegate respondsToSelector:@selector(photoBrowser:didTapOnDoneButton:)]) {
		self.displayingDetailedView = NO;
		[_delegate photoBrowser:self didTapOnDoneButton:sender];
	}
}

/*
#pragma mark - Orientation change

- (void)statusBarDidChangeFrame:(NSNotification *)notification
{
    UIDeviceOrientation orientation = [[UIDevice currentDevice] orientation];
    CGFloat angle = UIInterfaceOrientationAngleOfOrientation(orientation);
    CGAffineTransform viewTransform = CGAffineTransformMakeRotation(angle);
    CGRect frame = [UIScreen mainScreen].bounds;
	[self setTableIfNotEqualTransform:viewTransform frame:frame];
    [self.photoTableView reloadData];
}

- (void)setIfNotEqualTransform:(CGAffineTransform)transform frame:(CGRect)frame
{
    if (!CGAffineTransformEqualToTransform(self.transform, transform)) {
        self.transform = transform;
    }
    if (!CGRectEqualToRect(self.frame, frame)) {
        self.frame = frame;
    }
}

- (void)setTableIfNotEqualTransform:(CGAffineTransform)transform frame:(CGRect)frame
{
    if(!CGAffineTransformEqualToTransform(self.photoTableView.transform, transform)) {
        self.photoTableView.transform = transform;
    }
	if (!CGRectEqualToRect(self.photoTableView.frame, frame)) {
        self.photoTableView.frame = frame;
    }
}

CGFloat UIInterfaceOrientationAngleOfOrientation(UIDeviceOrientation orientation)
{
    CGFloat angle;
    
    switch (orientation) {
        case UIDeviceOrientationPortraitUpsideDown:
            angle = -M_PI_2;
            break;
        case UIDeviceOrientationLandscapeLeft:
            angle = 0;
            break;
        case UIDeviceOrientationLandscapeRight:
            angle = M_PI;
            break;
        default:
            angle = -M_PI_2;
            break;
    }
    
    return angle;
}*/

@end
