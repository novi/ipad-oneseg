//
//  DetailViewController.m
//  CapOneSeg
//
//  Created by ito on 平成22/10/15.
//  Copyright 2010 Yusuke Ito. All rights reserved.
//

/*
 Licensed under the Apache License, Version 2.0 (the "License");
 you may not use this file except in compliance with the License.
 You may obtain a copy of the License at
 
 http://www.apache.org/licenses/LICENSE-2.0
 
 Unless required by applicable law or agreed to in writing, software
 distributed under the License is distributed on an "AS IS" BASIS,
 WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 See the License for the specific language governing permissions and
 limitations under the License.
 */


#import "CapPlayerController.h"
#import "MasterViewController.h"


@interface CapPlayerController ()
@property (nonatomic, retain) UIPopoverController *popoverController;

@property (nonatomic, retain) VLCMediaPlayer*	_mediaPlayer_;
@property (nonatomic, retain) UIView*			_movieView_;

@property (nonatomic, retain) NSFileHandle* _packetFileHandle_;

- (void)configureView;
@end



@implementation CapPlayerController

@synthesize toolbar, popoverController, detailDescriptionLabel, toolbarLabel;
@synthesize _mediaPlayer_, _movieView_, _packetFileHandle_;
@synthesize masterViewController;

#pragma mark -
#pragma mark Managing the detail item


- (void)setDetailItem:(id)newDetailItem
{
    if (detailItem != newDetailItem) {
        [detailItem release];
        detailItem = [newDetailItem retain];
        
        // Update the view.
        [self configureView];
    }

    if (popoverController != nil) {
        [popoverController dismissPopoverAnimated:YES];
    }        
}


- (void)configureView
{
    // Update the user interface for the detail item.
    detailDescriptionLabel.text = [detailItem description];   
}


#pragma mark -
#pragma mark Split view support

- (void)splitViewController: (UISplitViewController*)svc willHideViewController:(UIViewController *)aViewController withBarButtonItem:(UIBarButtonItem*)barButtonItem forPopoverController: (UIPopoverController*)pc
{
    
    barButtonItem.title = @"Menu";
    NSMutableArray *items = [[toolbar items] mutableCopy];
    [items insertObject:barButtonItem atIndex:0];
    [toolbar setItems:items animated:YES];
    [items release];
    self.popoverController = pc;
}

- (void)splitViewController: (UISplitViewController*)svc willShowViewController:(UIViewController *)aViewController invalidatingBarButtonItem:(UIBarButtonItem *)barButtonItem
{
    
    NSMutableArray *items = [[toolbar items] mutableCopy];
    [items removeObjectAtIndex:0];
    [toolbar setItems:items animated:YES];
    [items release];
    self.popoverController = nil;
}


#pragma mark -
#pragma mark Rotation support

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}


#pragma mark -
#pragma mark Movie Player

- (NSString*)_packetFifoPath
{
	NSArray* filePaths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);	
	NSString* documentDir = [filePaths objectAtIndex:0];
	return [documentDir stringByAppendingPathComponent:@"ts.fifo"];
}

- (void)_closePacketFifo
{
	[_mediaPlayer_ stop];
	[_mediaPlayer_ setMedia:nil];
	
	NSFileManager* fm = [NSFileManager defaultManager];
	if ([fm fileExistsAtPath:[self _packetFifoPath] isDirectory:NO]) {
		NSError* error = nil;
		if (! [fm removeItemAtPath:[self _packetFifoPath] error:&error]) {
			NSLog(@"%@", error);
		}
	}
}

- (void)playMediaFileWithPath:(NSString*)path
{
	[self _closePacketFifo];
	
	VLCMedia* media = [[VLCMedia alloc] initWithPath:path];
	NSLog(@"%@", media);
	[_mediaPlayer_ setMedia:media];
	[media release];
	[_mediaPlayer_ play];
}

- (BOOL)prepareTSPacketPlaying
{
	[self _closePacketFifo];
	NSString* fifoPath = [self _packetFifoPath];
	
	if (mkfifo([fifoPath fileSystemRepresentation], S_IRUSR | S_IWUSR | S_IRGRP | S_IROTH) == 0) {
		// Success
		
		// Create Media
		VLCMedia* media = [[VLCMedia alloc] initWithPath:fifoPath];
		NSLog(@"%@", media);
		[_mediaPlayer_ setMedia:media];
		[media release];
		
		[_mediaPlayer_ play];
		
		// Create File Handle for Packet
		NSFileHandle* fh = [NSFileHandle fileHandleForUpdatingAtPath:fifoPath];
		self._packetFileHandle_ = fh;
		
		return YES;
	}
	return NO;
}

- (void)playTSPacketWithData:(NSData*)data
{
	[self._packetFileHandle_ writeData:data];
}

#pragma mark -
#pragma mark View lifecycle

- (void)_startRec:(id)sender
{
	self.toolbarLabel.text = @"Recording...";
	[masterViewController startRecording];
}

- (void)stopRec:(id)sender
{
	self.toolbarLabel.text = nil;
	[masterViewController stopRecording];
}

- (void)viewDidLoad {
    [super viewDidLoad];
	
	if (! self._mediaPlayer_) {
		
		
		VLCMediaPlayer* player = [[VLCMediaPlayer alloc] init];
		[player setDelegate:self];
		self._mediaPlayer_ = player;
		[player release];
	}
	
	self.toolbar.tintColor = [UIColor darkGrayColor];
	self.view.backgroundColor = [UIColor darkGrayColor];
	
	float aspect = 480.0/640.0;
	CGSize viewSize;// = self.view.bounds.size;
	viewSize.height = 768-20;
	viewSize.width = 703;
	CGSize movieSize = CGSizeMake(viewSize.width, viewSize.width*aspect);
	UIView* movieView = [[UIView alloc] initWithFrame:CGRectMake(0, 44+(viewSize.height-44-movieSize.height)*0.5,
																 movieSize.width, movieSize.height)];
	movieView.backgroundColor = [UIColor blackColor];
	//movieView.center = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds)+44);
	
	
	[_mediaPlayer_ setDrawable:movieView];
	//[_mediaPlayer_ play];
	
	[self.view addSubview:movieView];
	self._movieView_ = movieView;
	[movieView release];
	
	UIBarButtonItem* recItem = [[UIBarButtonItem alloc] initWithTitle:@"Rec" style:UIBarButtonItemStyleBordered 
															   target:self action:@selector(_startRec:)];
	UIBarButtonItem* stopItem = [[UIBarButtonItem alloc] initWithTitle:@"Stop" style:UIBarButtonItemStyleBordered
																target:self action:@selector(stopRec:)];
	UIBarButtonItem* flexItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemFlexibleSpace target:nil action:nil];
	
	self.toolbar.items = [NSArray arrayWithObjects:flexItem, recItem, stopItem, nil];
	
	[recItem release];
	[stopItem release];
	[flexItem release];
	
	self.toolbarLabel.text = nil;
	self.detailDescriptionLabel.text = nil;
}


/*
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}
*/
/*
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
	
	
	
}
*/
/*
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}
*/
/*
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}
*/

- (void)viewDidUnload
{
    self.popoverController = nil;
	self.toolbar = nil;
	self.detailDescriptionLabel = nil;
	self._movieView_ = nil;
	self.toolbarLabel = nil;
}


#pragma mark -
#pragma mark Memory management


- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)dealloc
{
	self.popoverController = nil;
	self.toolbar = nil;
	self.detailDescriptionLabel = nil;
	self._movieView_ = nil;
	self.toolbarLabel = nil;
	
	self.detailItem = nil;
	
    [super dealloc];
}

#pragma mark -
#pragma mark Media Player Delegate

-(void) mediaPlayerStateChanged:(NSNotification *)aNotification
{
	NSLog(@"%s, %@, %@", _cmd, aNotification, VLCMediaPlayerStateToString([_mediaPlayer_ state]));
	if ([_mediaPlayer_ state] == VLCMediaStateError) {
		//[self performSelector:@selector(_playMedia) withObject:nil afterDelay:1];
	}
}

-(void) mediaPlayerTimeChanged:(NSNotification *)aNotification
{
	
}

@end
