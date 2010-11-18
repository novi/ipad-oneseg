//
//  RootViewController.h
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
#import "CapOneSeg.h"

enum {
	CapTableViewModeChannel = 1,
	CapTableViewModeLibrary,
};

typedef NSUInteger CapTableViewMode;

@class CapPlayerController;

@interface MasterViewController : UITableViewController<CapOneSegDelegate>
{
    CapPlayerController* playerController;
	CapTableViewMode _tableViewMode;
	BOOL _isRecording;
	int _channel;
}

@property (nonatomic, retain) IBOutlet CapPlayerController *playerController;

@property (nonatomic, retain) IBOutlet UISegmentedControl* tableViewSelector;
- (IBAction)tableViewSelectorSelected:(UISegmentedControl*)sender;


@property (nonatomic, readonly, getter=isRecording) BOOL recording;
- (void)startRecording;
- (void)stopRecording;


@end
