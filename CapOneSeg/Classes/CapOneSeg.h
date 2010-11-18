//
//  CapOneSeg.h
//  cap-oseg-mac
//
//  Created by ito on 平成22/09/30.
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

#import <Foundation/Foundation.h>
#import <IOKit/IOCFPlugIn.h>
#import <IOKit/IOKitLib.h>
#import <IOKit/usb/IOUSBLib.h>
#import <mach/mach.h>

@protocol CapOneSegDelegate<NSObject>

@required
- (void)capOneSegDidReceiveData:(NSData*)rawData validData:(NSData*)validData;

@optional
//- (void)capOneSegWillStartRecording;
//- (void)capOneSegDidFinishRecording;

@end



@class CapTSCreator;

@interface CapOneSeg : NSObject
{
	CapTSCreator* _tsCreator_;
	id<CapOneSegDelegate> delegate;
}

+ (id)sharedInstance;

@property (nonatomic, assign) id<CapOneSegDelegate> delegate;

- (void)startRecWithChannel:(int)ch;
- (void)stopRec;



// Private
- (void)_dataReceivedFromDevice:(NSData*)rawData;

@end
