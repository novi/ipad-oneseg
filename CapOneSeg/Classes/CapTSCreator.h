//
//  CapTSCreator.h
//  new-ts-creator
//
//  Created by ito on 平成22/11/15.
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


@interface CapTSCreator : NSObject
{
	NSMutableDictionary* _pidCounts_;
	NSData* _patData_;
	
	int _patCounter;	
	UInt16 _videoPID;	
	UInt16 _audioPID;	
	UInt16 _pcrPID;	
	int _isValidPacket;
	int _patInsertCounter;
}

- (NSData*)createValidTSPacketWithRawPacket:(NSData*)data;

@end
