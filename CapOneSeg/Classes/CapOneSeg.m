//
//  CapOneSeg.m
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


#import "CapOneSeg.h"
#import "initdata.h"
#import "CapTSCreator.h"

static io_iterator_t	g_DeviceAddedIter = 0;
static io_iterator_t	g_DeviceRemovedIter = 0;
static IONotificationPortRef g_NotificationPort = NULL;
static IOUSBInterfaceInterface245**	g_interface = NULL;

static UInt8* g_readBuffer = NULL;
static int channel = 27;

//static NSMutableArray* g_RecData = nil;
static BOOL g_StopFlag = NO;

static NSUInteger g_RecvDataBytes = 0;

static id g_sharedInstance = nil;

//static NSFileHandle* g_fileHandle = nil;

#define SEND_WAIT 10 /**< for USB hub delay. */
#define RECV_WAIT 20 /**< for USB hub delay. */
#define RECV_TIMEOUT 200
#define UOT100_PACKET_SIZE	197

#define BULKENDP (0x2)

void CapDeviceReady(void)
{
	IOReturn ret;
	CFRunLoopSourceRef	cfSource;
	ret = (*g_interface)->CreateInterfaceAsyncEventSource(g_interface, &cfSource);
	if(ret) {
		NSLog(@"_recWorker: Unable to create event source.\n");
		return;
    }
	
	// イベントソースを登録
	CFRunLoopAddSource(CFRunLoopGetCurrent(), cfSource, kCFRunLoopDefaultMode);
}

IOReturn CapFindInterfaces(IOUSBDeviceInterface245** dev)
{
    IOReturn					kr;
    IOUSBFindInterfaceRequest	request;
    io_iterator_t				iterator;
    io_service_t				usbInterface;
    IOCFPlugInInterface			**plugInInterface = NULL;
    IOUSBInterfaceInterface245	**intf = NULL;
    HRESULT						res;
    SInt32						score;
    
    request.bInterfaceClass    = kIOUSBFindInterfaceDontCare;
    request.bInterfaceSubClass = kIOUSBFindInterfaceDontCare;
    request.bInterfaceProtocol = kIOUSBFindInterfaceDontCare;
    request.bAlternateSetting  = kIOUSBFindInterfaceDontCare;
	/*
	 UInt8 numOfConf = 0;
	 (*dev)->GetNumberOfConfigurations(dev, &numOfConf);
	 NSLog(@"num of conf %d", numOfConf);
	 */
    kr = (*dev)->CreateInterfaceIterator(dev, &request, &iterator);
    
    while((usbInterface = IOIteratorNext(iterator))) {
		
		NSLog(@"CapFindInterfaces");
		
        kr = IOCreatePlugInInterfaceForService(usbInterface, kIOUSBInterfaceUserClientTypeID, kIOCFPlugInInterfaceID, &plugInInterface, &score);
        kr = IOObjectRelease(usbInterface);
        if((kIOReturnSuccess != kr) || !plugInInterface) {
            break;
        }
		
        res = (*plugInInterface)->QueryInterface(plugInInterface, CFUUIDGetUUIDBytes(kIOUSBInterfaceInterfaceID245), (LPVOID) &intf);
		IODestroyPlugInInterface(plugInInterface);
        if(res || !intf) {
            break;
        }
        
		kr = (*intf)->USBInterfaceOpen(intf);
        if(kIOReturnSuccess != kr) {
            (void) (*intf)->Release(intf);
            break;
        }
		
		// Get Interface
		g_interface = intf;
		
		// Use First Interface
		break;
    }
	return kr;
}

static IOReturn CapConfigureAnchorDevice(IOUSBDeviceInterface245** dev)
{
	//return kIOReturnSuccess;
    UInt8							numConf;
    IOReturn						kr;
    IOUSBConfigurationDescriptorPtr	confDesc;
    
    kr = (*dev)->GetNumberOfConfigurations(dev, &numConf);
    if(!numConf) {
        return -1;
	}
	
	NSLog(@"Num of conf = %d\n", numConf);
    
    kr = (*dev)->GetConfigurationDescriptorPtr(dev, 0, &confDesc);
    if(kr) {
        return kr;
    }
    kr = (*dev)->SetConfiguration(dev, confDesc->bConfigurationValue);
    if(kr) {
		printf("\tunable to set configuration to value %d (err=%08x)\n", 0, kr);
        return kr;
    }
    return kIOReturnSuccess;
}

static void CapDeviceAdded(void *refCon, io_iterator_t iterator)
{
    kern_return_t			kr;
    io_service_t			usbDevice;
    IOCFPlugInInterface 	**plugInInterface=NULL;
    IOUSBDeviceInterface245 	**dev=NULL;
    HRESULT					res;
    SInt32					score;
	
    while ( (usbDevice = IOIteratorNext(iterator)) )
    {
		NSLog(@"Cap Device Added");
		
        kr = IOCreatePlugInInterfaceForService(usbDevice, kIOUSBDeviceUserClientTypeID, kIOCFPlugInInterfaceID, &plugInInterface, &score);
        kr = IOObjectRelease(usbDevice);
        if ((kIOReturnSuccess != kr) || !plugInInterface) {
            continue;
        }
		
        res = (*plugInInterface)->QueryInterface(plugInInterface, CFUUIDGetUUIDBytes(kIOUSBDeviceInterfaceID245), (LPVOID)&dev);
        (*plugInInterface)->Release(plugInInterface);
        if (res || !dev) {
            continue;
        }
		
        kr = (*dev)->USBDeviceOpen(dev);
        if (kIOReturnSuccess != kr) {
            (*dev)->Release(dev);
            continue;
        }
		
		NSLog(@"Device opend");
		
		kr = CapConfigureAnchorDevice(dev);
        if (kIOReturnSuccess != kr) {
            (*dev)->USBDeviceClose(dev);
            (*dev)->Release(dev);
            continue;
        }
		
		NSLog(@"Device configured");
		
		kr = CapFindInterfaces(dev);
        if (kIOReturnSuccess != kr) {
            (*dev)->USBDeviceClose(dev);
            (*dev)->Release(dev);
            continue;
        }
		
		NSLog(@"Found Interface");
		
		
		//ReadyDevice();
		CapDeviceReady();
		
    }
}

static void CapDeviceRemoved(void *refCon, io_iterator_t iterator)
{
	//Capusb		*capusb = (Capusb*)refCon;
    kern_return_t	result;
    io_service_t	obj;
    
    while((obj = IOIteratorNext(iterator))) {
        result = IOObjectRelease(obj);
		IONotificationPortDestroy(g_NotificationPort);
		g_NotificationPort = NULL;
		NSLog(@"Cap Device Removed");
    }	
	
	
}

void cap_msleep(int ms)
{
	usleep(1000*ms);
}

void cap_rec_bulk_main(void *refcon,
					   IOReturn result,
					   void *arg0)
{
	if (g_StopFlag) {
		return;
	}
	// Check data
	if ((int)arg0 == 196 && g_readBuffer[0] == 0x47) {
		// Valid data
		if (g_RecvDataBytes % (188*1000) == 0) {
			NSLog(@"data received %d bytes, %@", g_RecvDataBytes, [NSThread currentThread]);
		}
		CapOneSeg* cap = g_sharedInstance;
		[cap _dataReceivedFromDevice:[NSData dataWithBytes:g_readBuffer length:188]];
		//				[g_RecData addObject:[NSData dataWithBytes:g_readBuffer length:188]];
		g_RecvDataBytes	+= 188;
	}
	
	
	if ((int)arg0 == 0) {
		NSLog(@"No Data");
	}
	
	IOReturn ret;
	ret = (*g_interface)->ReadPipeAsyncTO(g_interface, BULKENDP, g_readBuffer, UOT100_PACKET_SIZE, RECV_TIMEOUT, RECV_TIMEOUT, cap_rec_bulk_main, NULL);	
	if (ret != 0) {
		NSLog(@"rec error");
	}
}

void cap_read_bulk_callback(void *refcon,
							IOReturn result,
							void *arg0)
{
	/*	UInt8* buf = refcon;
	 //NSLog(@"get data %02x %02x %02x %02x %02x", buf[0], buf[1],buf[2],buf[3],buf[4]);
	 if ((int)arg0 && (int)arg0 < 30) {
	 NSMutableString* str = [NSMutableString string];
	 for (int i = 0; i < (int)(arg0); i++) {
	 [str appendFormat:@"%02x ", buf[i]];
	 }
	 NSLog(@"data = %@", str);
	 }
	 */
	printf("read data %d byte\n", (int)arg0);
}



static int cap_send5data_wait(unsigned char *p, int waitok)
{
	int result;
	unsigned char buf[5];
	
	while((*p) != 0xff){
		memcpy(buf,p,5);
		result = (*g_interface)->WritePipeTO(g_interface, 1, buf, 5, RECV_TIMEOUT, RECV_TIMEOUT);
		
		if(result!=0){
			fprintf(stderr, "send5data(%x) %02x %02x %02x %02x %02x\n", result, p[0], p[1], p[2], p[3], p[4]);
			return result;
		}
		if (result == 0) {
			//fprintf(stderr, "send5data(OK) %02x %02x %02x %02x %02x\n", p[0], p[1], p[2], p[3], p[4]);
		}
		if (waitok) {
			cap_msleep(SEND_WAIT);
		}
		p+=5;
	}
	
	return 0;
}

static int cap_send5data(unsigned char *p)
{
	return cap_send5data_wait(p, 1);
}

static int cap_ctrl_wr(UInt8 request, UInt8 value)
{
	int status;
	
	IOUSBDevRequestTO req;
	req.bmRequestType = USBmakebmRequestType(kUSBOut, kUSBVendor, kUSBDevice);
	req.bRequest = request;
	req.completionTimeout = RECV_TIMEOUT;
	req.noDataTimeout = RECV_TIMEOUT;
	req.pData = NULL;
	req.wIndex = 0;
	req.wLenDone = 0;
	req.wLength = 0;
	req.wValue = value;
	
	status = (*g_interface)->ControlRequestTO(g_interface, 0, &req);
	
	if (status != 0) {
		NSLog(@"Control Request Error %x", status);
	}
	
	cap_msleep(10);
	
	return status;
}

static int cap_read_data(void )
{
	int ret;
	if (! g_readBuffer) {
		g_readBuffer = malloc(UOT100_PACKET_SIZE);
	}
	
	ret = (*g_interface)->ReadPipeAsyncTO(g_interface, BULKENDP, g_readBuffer, UOT100_PACKET_SIZE, RECV_TIMEOUT, RECV_TIMEOUT, cap_read_bulk_callback, NULL);
	if (ret != 0) {
		(*g_interface)->ClearPipeStall(g_interface, BULKENDP);
		ret = (*g_interface)->ReadPipeAsyncTO(g_interface, BULKENDP, g_readBuffer, UOT100_PACKET_SIZE, RECV_TIMEOUT, RECV_TIMEOUT, cap_read_bulk_callback, NULL);
		//		ret = (*_interface)->ReadPipeTO(_interface, BULKENDP, readbuf, &actlen, RECV_TIMEOUT, RECV_TIMEOUT);
	}
	//printf("read dummy data %d bytes (%x)\n", actlen, ret);
	
	return ret ;
}



void cap_set_channel_senddata(void)
{
	//unsigned int freq=channel2frequency(channel);
	
	senddata4[8]=p1_table[channel-13];
	senddata4[13]=p2_table[channel-13];
	senddata4[18]=(0x1a + ((channel - 13) / 3));
	senddata4[23]=(channel <= 20) ? 0x8c : 0x94;
	
	switch ((channel - 13) % 3) {
		case 0:
			senddata4[28]=0x18;
			senddata4[33]=0x04;
			senddata4[38]=0x05;
			break;
		case 1:
			senddata4[28]=0x6e;
			senddata4[33]=0x59;
			senddata4[38]=0x0a;
			break;
		case 2:
			senddata4[28]=0xc3;
			senddata4[33]=0xae;
			senddata4[38]=0x0f;
			break;
	}
	
	senddata5[3]=p1_table[channel-13]+1;
	senddata5[8]=p2_table[channel-13];
}

static void cap_start_stop(int onoff)
{
	if (onoff){
		cap_ctrl_wr(0x02, 0x01);
		cap_send5data(senddata_start);
	}
	else {
		cap_send5data(senddata_stop);
		cap_ctrl_wr( 0x02, 0x01);
	}
}

void cap_init_device(void)
{
	int result=0;
	struct init_struct *init_struct_p = logj200_init_struct;
	cap_set_channel_senddata();
	
	while(init_struct_p->command){
		switch(init_struct_p->command){
			case 1:
				result = cap_ctrl_wr(init_struct_p->request, init_struct_p->value);
				if(result != 0){
					printf ("control message error. (request = %x, value = %x)\n", init_struct_p->request, init_struct_p->value);
				}
				break;
			case 2:
				result = cap_send5data(init_struct_p->senddata);
				if(result != 0){
					printf("send5data error. (request = %x, value = %x)\n", init_struct_p->request, init_struct_p->value);
				}
				break;
			case 3:
				cap_read_data();
				break;
		}
		init_struct_p++;
	}
	
}


@interface CapOneSeg()

@property (nonatomic, retain) CapTSCreator* _tsCreator_;
-(BOOL) _registerNotificationPort;
-(void) setChannel:(int)ch;

@end


@implementation CapOneSeg

@synthesize _tsCreator_;
@synthesize delegate;


+ (id)sharedInstance
{
	if (! g_sharedInstance) {
		g_sharedInstance = [[self alloc] init];
	}
	
	return g_sharedInstance;
}

- (id) init
{
	self = [super init];
	if (self != nil) {
		if ([self _registerNotificationPort]) {
			// Init OK
			NSLog(@"Init OK, %@", self);
		} else {
			[self release];
			self = nil;
		}
	}
	g_sharedInstance = self;
	return self;
}

- (BOOL)_registerNotificationPort
{
	SInt32	vendor2 = 0x10c4;
	SInt32	product2 = 0x1312;
	
	mach_port_t				masterPort = 0;
	CFMutableDictionaryRef  matchingDict = 0;
	CFRunLoopSourceRef		runLoopSource = 0;
	kern_return_t			result;
	
	// Create Master Port
	result = IOMasterPort(MACH_PORT_NULL, &masterPort);
	if(result || !masterPort) {
		NSLog(@"ERROR : Could not create a master IOKit Port(%08x).", result);
		goto bail;
	}
	
	// Create Device Matching Dictionary
	matchingDict = IOServiceMatching(kIOUSBDeviceClassName);
	if(!matchingDict) {
		NSLog(@"ERROR : Could not create a USB matching dictionary.");
		goto bail;
	}
	
	// Create Notification Port and Register it to RunLoop
	g_NotificationPort   = IONotificationPortCreate(masterPort);
	runLoopSource = IONotificationPortGetRunLoopSource(g_NotificationPort);
	CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, kCFRunLoopDefaultMode);
	
	
	// Configure Vender and Product IDs
	CFDictionarySetValue(matchingDict, 
						 CFSTR(kUSBVendorID), 
						 CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &vendor2)); 
	CFDictionarySetValue(matchingDict, 
						 CFSTR(kUSBProductID), 
						 CFNumberCreate(kCFAllocatorDefault, kCFNumberSInt32Type, &product2)); 
	
	[(id)matchingDict retain];
	[(id)matchingDict retain];
	[(id)matchingDict retain];
	
	result = IOServiceAddMatchingNotification(g_NotificationPort,
											  kIOFirstMatchNotification,
											  matchingDict,
											  CapDeviceAdded,
											  NULL,
											  &g_DeviceAddedIter);
	result = IOServiceAddMatchingNotification(g_NotificationPort,
											  kIOTerminatedNotification,
											  matchingDict,
											  CapDeviceRemoved,
											  NULL,
											  &g_DeviceRemovedIter);
	
	CapDeviceRemoved(NULL, g_DeviceRemovedIter);	
	CapDeviceAdded(NULL, g_DeviceAddedIter);
	
	mach_port_deallocate(mach_task_self(), masterPort);
	masterPort = 0;
	
	if (g_interface) {
		return YES;
	} else {
		IONotificationPortDestroy(g_NotificationPort);
		g_NotificationPort = NULL;
		return NO;
	}
	
bail:
	if(masterPort) {
		mach_port_deallocate(mach_task_self(), masterPort);
		masterPort = 0;
	}
	return NO;
}



- (void)setChannel:(int)ch
{
	channel = ch;
	cap_init_device();
	cap_start_stop(1);
}

- (void)_createNewTSPacketCreator
{
	NSLog(@"%s", _cmd);
	
	CapTSCreator* creator = [[CapTSCreator alloc] init];
	self._tsCreator_ = creator;
	[creator release];
	
}

-(void)_dataReceivedFromDevice:(NSData*)rawData
{
	if (_tsCreator_) {
		[self.delegate capOneSegDidReceiveData:rawData validData:[_tsCreator_ createValidTSPacketWithRawPacket:rawData]];
	} else {
		//NSLog(@"TS Creator not created yet.");
	}
}

- (void)startRecWithChannel:(int)ch
{
	[self setChannel:ch];
	
	g_StopFlag = NO;
	g_RecvDataBytes = 0;
	
	IOReturn ret;
	(*g_interface)->ClearPipeStall(g_interface, BULKENDP);
	
	ret = (*g_interface)->ReadPipeAsyncTO(g_interface, BULKENDP, g_readBuffer, UOT100_PACKET_SIZE, RECV_TIMEOUT, RECV_TIMEOUT, cap_rec_bulk_main, NULL);
	if (ret != 0) {
		NSLog(@"Rec error");
	}
	
	NSLog(@"Rec start");
	
	self._tsCreator_ = nil;
	[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(_createNewTSPacketCreator) object:nil];
	[self performSelector:@selector(_createNewTSPacketCreator) withObject:nil afterDelay:1];
	//g_fileHandle = [[NSFileHandle fileHandleForWritingAtPath:@"/Users/ito/Desktop/b.ts"] retain];
}

- (void)stopRec
{
	g_StopFlag = YES;
	/*
	 [g_fileHandle synchronizeFile];
	 [g_fileHandle closeFile];
	 [g_fileHandle release];
	 g_fileHandle = nil;
	 */
}

@end
