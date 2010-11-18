//
//  CapTSCreator.m
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


#import "CapTSCreator.h"

#define CapTSCreatorDebugMode (0)



// http://d.hatena.ne.jp/querulous/20090730
int GetCrc32(
			 unsigned char* data,				// [in]		CRC 計算対象データ
			 int len)							// [in]		CRC 計算対象データ長
{
	int crc;
	int i, j;
	
	crc = 0xFFFFFFFF;
	for (i = 0; i < len; i++)
	{
		char x;
		x = data[i];
		
		for (j = 0; j < 8; j++)
		{
			int c;
			int bit;
			
			bit = (x >> (7 - j)) & 0x1;
			
			c = 0;
			if (crc & 0x80000000)
			{
				c = 1;
			}
			
			crc = crc << 1;
			
			if (c ^ bit)
			{
				crc ^= 0x04C11DB7;
			}
			
			crc &= 0xFFFFFFFF;
		}
	}
	
	return crc;
}

void parsePAT(UInt8* buf)
{
	NSLog(@"----------------------------------");
	NSLog(@"Table ID = 0x%x", buf[1]);
	UInt16 secLen = (0xff00 & ((UInt16)buf[2] << 8)) | (buf[3] & 0xff);
	secLen &= 0x0fff;
	NSLog(@"Sec Len = %d byte", secLen);
	
	UInt16 tsID = (0xff00 & ((UInt16)buf[4] << 8)) | (buf[5] & 0xff);
	NSLog(@"TS ID = 0x%x", tsID);
	
	UInt8 verNo = buf[6] & 0x3e;
	NSLog(@"Ver No. = %d", verNo >> 1);
	NSLog(@"Sec No = %d", buf[7]);
	NSLog(@"Sec Latest No = %d", buf[8]);
	
	for (int i = 9; i <= secLen-4; ) {
		
		UInt16 progNo = (buf[i] << 8) | (buf[i+1] & 0xff);
		NSLog(@"Prog No = 0x%x", progNo);
		i+=2;
		
		UInt16 esPID = (buf[i] << 8) | (buf[i+1] & 0xff);
		esPID &= 0x1fff;
		NSLog(@"ES PID = 0x%x", esPID);
		i+=2;
	}
	NSLog(@"CRC32 = 0x%02x%02x%02x%02x", buf[secLen], buf[secLen+1], buf[secLen+2], buf[secLen+3]);
	NSLog(@"CRC32 c = %x", GetCrc32(buf+1, secLen-1));
	NSLog(@"----------------------------------");
}

void parsePMT(UInt8* buf)
{
	NSLog(@"----------------------------------");
	NSLog(@"Table ID = 0x%x", buf[1]);
	UInt16 secLen = (0xff00 & ((UInt16)buf[2] << 8)) | (buf[3] & 0xff);
	secLen &= 0x0fff;
	NSLog(@"Sec Len = %d byte", secLen);
	UInt16 progNo = (buf[4] << 8) | (buf[5] & 0xff);
	NSLog(@"Prog No. = %d(0x%x)", progNo, progNo);
	UInt8 verNo = buf[6] & 0x3e;
	NSLog(@"Ver No. = %d", verNo >> 1);
	NSLog(@"Sec No = %d", buf[7]);
	NSLog(@"Sec Latest No = %d", buf[8]);
	UInt16 pcrPID = (buf[9] << 8) | (buf[10] & 0xff);
	pcrPID &= 0x1fff;
	NSLog(@"PCR PID = 0x%x", pcrPID);
	UInt16 datLen = (buf[11] << 8) | (buf[12] & 0xff);
	datLen &= 0xfff;
	NSLog(@"Dat Len = %d byte", datLen);
	for (int i = datLen+13; i <= secLen-4; ) {
		NSLog(@"ES Type = 0x%02x", buf[i]);
		i++;
		UInt16 esPID = (buf[i] << 8) | (buf[i+1] & 0xff);
		esPID &= 0x1fff;
		NSLog(@"ES PID = 0x%x", esPID);
		i+=2;
		UInt16 esInfoLen = (buf[i] << 8) | (buf[i+1] & 0xff);
		esInfoLen &= 0xfff;
		NSLog(@"ES Info Len = %d byte", esInfoLen,esInfoLen);
		i+=2;
		i+=esInfoLen;
	}
	NSLog(@"CRC32 = 0x%02x%02x%02x%02x", buf[secLen], buf[secLen+1], buf[secLen+2], buf[secLen+3]);
	NSLog(@"CRC32 c = %x", GetCrc32(buf+1, secLen-1));
	NSLog(@"----------------------------------");
	
	
	//exit(0);
}



@implementation CapTSCreator

- (NSData*)_patDataCreate
{
	UInt8 buf[188];
	memcpy(buf, [_patData_ bytes], 188);
	buf[3] = 0x1f & (_patCounter % 10);
	buf[3] |= 0x10;
	_patCounter++;
	return [NSData dataWithBytes:buf length:188];
}

-(void) _createAndStorePATWithProgNo:(UInt16)progNo
{
	UInt8 buf[188];
	memset(buf, 0xff, 188);
	buf[0] = 0x47;
	buf[1] = 0x40;
	buf[2] = 0;
	buf[3] = 10;
	
	buf[4] = 0;
	
	buf[5] = 0; // Table ID = 0
	buf[6] = 0xb0;
	buf[7] = 13; // Sec Len
	buf[8] = 0x7f; // TS ID
	buf[9] = 0xc1;
	buf[10] = 0xc3;
	buf[11] = 0;
	buf[12] = 0;
	
	buf[13] = progNo >> 8;
	buf[14] = progNo;
	
	buf[15] = 0xff; // PID
	buf[16] = 0xc8;
	
	UInt32 crc = GetCrc32(buf+5, 12);
	buf[17] = crc >> 24;
	buf[18] = crc >> 16;
	buf[19] = crc >> 8;
	buf[20] = crc;
	
	[_patData_ release];
	_patData_ = [NSData dataWithBytes:buf length:188];
	[_patData_ retain];
}

- (void)_findPID:(UInt8*)buf
{
	_isValidPacket = 0;
	_audioPID = 0;
	_videoPID = 0;
	int foundAudio = 0;
	int foundVideo = 0;
	
	UInt16 progNo = (buf[4] << 8) | (buf[5] & 0xff);
	if (! _patData_) {
		[self _createAndStorePATWithProgNo:progNo];
		parsePAT(((UInt8*)[_patData_ bytes])+4);
	}
	
	UInt16 secLen = (0xff00 & ((UInt16)buf[2] << 8)) | (buf[3] & 0xff);
	secLen &= 0x0fff;
	
	UInt16 datLen = (buf[11] << 8) | (buf[12] & 0xff);
	datLen &= 0xfff;
	
	UInt16 pcrPID = (buf[9] << 8) | (buf[10] & 0xff);
	pcrPID &= 0x1fff;
	_pcrPID = pcrPID;
	
	for (int i = datLen+13; i < secLen-4; ) {
		//NSLog(@"ES Type = 0x%02x", buf[i]);
		if (buf[i] == 0x1b) {
			foundVideo = 1;
		}
		if (buf[i] == 0x0f) {
			foundAudio = 1;
		}
		i++;
		UInt16 esPID = (buf[i] << 8) | (buf[i+1] & 0xff);
		esPID &= 0x1fff;
		if (foundAudio && _audioPID == 0) {
			_audioPID = esPID;
		} else if (foundVideo && _videoPID == 0) {
			_videoPID = esPID;
		}
		//NSLog(@"ES PID = 0x%x", esPID);
		i+=2;
		UInt16 esInfoLen = (buf[i] << 8) | (buf[i+1] & 0xff);
		esInfoLen &= 0xfff;
		//NSLog(@"ES Info Len = %d byte", esInfoLen,esInfoLen);
		i+=2;
		i+=esInfoLen;
	}
	
	if (foundAudio && foundVideo) {
		NSLog(@"Got Video And Audio PID");
		_isValidPacket = 1;
	}
}



- (NSData*)createValidTSPacketWithRawPacket:(NSData*)data
{
	NSMutableData* outData = nil;
	if (_patInsertCounter % 10 == 0 && _patData_) {
		outData = [NSMutableData dataWithData:[self _patDataCreate]];
	}
	_patInsertCounter++;
	
	UInt8* buf = (void*)[data bytes];
	if (buf[0] != 0x47) {
		NSLog(@"Invalid Packet, No SYNC");
		return outData;
	}
	
	UInt8 error = buf[1] & 0x80;
	if (error) {
		NSLog(@"Packet Error Flag Detected.");
		//return outData;
	}
	
	UInt16 PID = (0xff00 & ((UInt16)buf[1] << 8)) | (0x00ff & buf[2]);
	PID &= 0x1fff;
	
	// Skip NULL Packet
	if (PID == 0x1fff) {
		return outData;
	}
	
	if (_isValidPacket == 0 && PID == 0x1fc8) {
		parsePMT(buf+4);
		//findPID(buf+4);
		[self _findPID:buf+4];
	}
	
	if (! _isValidPacket) {
		return outData;
	}
	
	
	BOOL valid = NO;
	if (PID == _pcrPID || PID == _audioPID || PID == _videoPID || PID == 0x1fc8) {
		//[newData appendData:data];
		//outData = [[data mutableCopy] autorelease];
		if (outData) {
			[outData appendData:data];
		} else {
			outData = (id)data;
		}
		valid = YES;
	}
	
#if CapTSCreatorDebugMode
	if (valid) {
		NSNumber* PIDKey = [NSNumber numberWithUnsignedShort:PID];
		NSNumber* curPIDCount = [_pidCounts_ objectForKey: PIDKey];
		NSUInteger count = 1;
		if (curPIDCount) {
			count = [curPIDCount unsignedIntegerValue];
			count++;
		}
		[_pidCounts_ setObject:[NSNumber numberWithUnsignedInteger:count] forKey: PIDKey];
	}
#endif
	
	
	
	
	return outData;
	
}


- (id) init
{
	self = [super init];
	if (self != nil) {
		//newData = [[NSMutableData alloc] init];
		_pidCounts_ = [[NSMutableDictionary alloc] init];
	}
	return self;
}

-(NSString *) description
{
	if ([[_pidCounts_ allKeys] count]) {
		return [_pidCounts_ description];
	}
	return [super description];
}


- (void) dealloc
{
	[_pidCounts_ release];
	[_patData_ release];
	[super dealloc];
}


@end
