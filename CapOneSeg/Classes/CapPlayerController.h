//
//  DetailViewController.h
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


#import <UIKit/UIKit.h>
#import <MobileVLCKit/MobileVLCKit.h>
#include <sys/types.h>
#include <sys/stat.h>

@class MasterViewController;

@interface CapPlayerController : UIViewController <UIPopoverControllerDelegate, UISplitViewControllerDelegate, VLCMediaPlayerDelegate> {
    
    UIPopoverController *popoverController;
    UIToolbar *toolbar;
    
    id detailItem;
    UILabel *detailDescriptionLabel;
	
	VLCMediaPlayer* _mediaPlayer_;
	UIView* _movieView_;
	NSFileHandle* _packetFileHandle_;
}

@property (nonatomic, assign) IBOutlet MasterViewController* masterViewController;

@property (nonatomic, retain) IBOutlet UIToolbar* toolbar;
@property (nonatomic, retain) IBOutlet UILabel* detailDescriptionLabel;
@property (nonatomic, retain) IBOutlet UILabel* toolbarLabel;

//@property (nonatomic, retain) id detailItem;

- (void)stopRec:(id)sender;


- (void)playMediaFileWithPath:(NSString*)path;
- (BOOL)prepareTSPacketPlaying;
- (void)playTSPacketWithData:(NSData*)data;

@end
