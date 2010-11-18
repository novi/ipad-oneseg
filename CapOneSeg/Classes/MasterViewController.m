//
//  RootViewController.m
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


#import "MasterViewController.h"
#import "CapPlayerController.h"

@interface MasterViewController()

-(void) _refreshLibraryList;
-(NSString *) _documentPathWithFileName:(NSString *)fileName;
@property (nonatomic, retain) NSArray* _libraryLists_;
@property (nonatomic, retain) NSMutableData* _recDataCache_;
@property (nonatomic, retain) NSFileHandle* _recFileHandle_;

@end



@implementation MasterViewController

@synthesize playerController;
@synthesize tableViewSelector;
@synthesize _libraryLists_, _recDataCache_, _recFileHandle_;
@synthesize recording = _isRecording;

#pragma mark -
#pragma mark Recording Method

- (void)_recStoreThread:(NSThread*)thread
{
	id pool = [[NSAutoreleasePool alloc] init];
	while (1) {
		@synchronized(_recFileHandle_) {
			if (_recFileHandle_ && [_recDataCache_ length] >= 188+1) {
				[_recFileHandle_ writeData:_recDataCache_];
				NSLog(@"wrote rec data %d bytes", [_recDataCache_ length]);
			}
			self._recDataCache_ = [NSMutableData dataWithLength:188];
			if (NO == _isRecording) {
				
				[_recFileHandle_ synchronizeFile];
				[_recFileHandle_ closeFile];
				self._recFileHandle_ = nil;
				self._recDataCache_ = nil;
				
				break;
			}
		}
		sleep(1);
	}
	[pool drain];
}

- (void)startRecording
{	
	if (self.isRecording) {
		NSLog(@"Already Recording.");
		return;
	}
	
	if (_recFileHandle_) {
		NSLog(@"Rec data flushing.");
		return;
	}
	
	_isRecording = YES;
	
	NSString* fileName = [NSString stringWithFormat:@"%ld-%02d.ts", time(NULL), _channel];
	NSString* filePath = [self _documentPathWithFileName:fileName];
	NSData* nullData = [NSData data];
	[nullData writeToFile:filePath atomically:NO];
	NSFileHandle* fileHandle = [NSFileHandle fileHandleForWritingAtPath:filePath];
	self._recFileHandle_ = fileHandle;
	
	[NSThread detachNewThreadSelector:@selector(_recStoreThread:) toTarget:self withObject:nil];
}

- (void)stopRecording
{
	_isRecording = NO;
}

#pragma mark -
#pragma mark ￼Capture Method

-(void) capOneSegDidReceiveData:(NSData*)rawData validData:(NSData*)validData
{
	@synchronized(_recFileHandle_) {
		if (_recDataCache_) {
			[_recDataCache_ appendData:validData];
		}
	}
	
	[playerController playTSPacketWithData:validData];
}

- (void)_testSubThread:(NSThread*)thread
{
	id pool = [[NSAutoreleasePool alloc] init];
	NSLog(@"%@", [NSThread currentThread]);
	NSData* data = [NSData dataWithContentsOfFile:[self _documentPathWithFileName:@"fileSequence0.ts"]];
	
	for (int i = 0; i < [data length]; i+= 188) {
		NSData* packetData = [data subdataWithRange:NSMakeRange(i, 188)];
		[playerController playTSPacketWithData:packetData];
		usleep(1000*1);
		if ((i % (188*10) == 0) && i != 0) {
			NSLog(@"send %d bytes", i);
		}
	}
	
	[pool drain];
}


#pragma mark -
#pragma mark Library Management

- (NSString*)_documentPathWithFileName:(NSString*)fileName
{
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,  NSUserDomainMask, YES);
	NSString* path = [paths objectAtIndex:0];
	
	if (fileName) {
		return [path stringByAppendingPathComponent:fileName];
	}
	return path;
}

- (void)_refreshLibraryList
{
	NSFileManager* fm = [NSFileManager defaultManager];
	
	NSMutableArray* library = [NSMutableArray arrayWithCapacity:10];
	
	for (NSString* file in [fm contentsOfDirectoryAtPath:[self _documentPathWithFileName:nil] error:nil]) {
		if ([[[file pathExtension] lowercaseString] isEqualToString:@"ts"]) {
			[library addObject:file];
		}
	}
	
	self._libraryLists_ = library;
}

#pragma mark -
#pragma mark View lifecycle

- (IBAction)tableViewSelectorSelected:(UISegmentedControl*)sender
{
	if (self.tableViewSelector.selectedSegmentIndex == 0) {
		_tableViewMode = CapTableViewModeChannel;
		[self.tableView reloadData];
		if (_channel) {
			[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:_channel-1 inSection:0] animated:NO scrollPosition:UITableViewScrollPositionMiddle];
		} else {
			[self.tableView scrollToRowAtIndexPath:[NSIndexPath indexPathForRow:27 inSection:0] atScrollPosition:UITableViewScrollPositionMiddle animated:NO];
		}

	} else {
		_tableViewMode = CapTableViewModeLibrary;
		[self _refreshLibraryList];
		[self.tableView reloadData];
	}
}


- (void)viewDidLoad {
    [super viewDidLoad];
    self.clearsSelectionOnViewWillAppear = NO;
    self.contentSizeForViewInPopover = CGSizeMake(320.0, 600.0);
	
	self.navigationController.navigationBar.tintColor = [UIColor darkGrayColor];
	
	[self tableViewSelectorSelected:nil];
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

// Ensure that the view controller supports rotation and that the split view can therefore show in both portrait and landscape.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    if (UIInterfaceOrientationIsLandscape(interfaceOrientation)) {
		return YES;
	}
	
	return NO;
}


#pragma mark -
#pragma mark Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)aTableView {
    // Return the number of sections.
    return 1;
}


- (NSInteger)tableView:(UITableView *)aTableView numberOfRowsInSection:(NSInteger)section {
    // Return the number of rows in the section.
	if (_tableViewMode == CapTableViewModeChannel) {
		return 62;
	} else if (_tableViewMode == CapTableViewModeLibrary) {
		
	}
	
	return [_libraryLists_ count];
	
}


- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    
    static NSString *CellIdentifier = @"CellIdentifier";
	static NSString *CellIdentifierLibrary = @"CellIdentifier1";
    
	UITableViewCell *cell = nil;
	
    // Configure the cell.
	if (_tableViewMode == CapTableViewModeChannel) {
		
		cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
		if (cell == nil) {
			cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
			cell.accessoryType = UITableViewCellAccessoryNone;
		}
		
		cell.textLabel.text = [NSString stringWithFormat:@"Channel %d", indexPath.row+1];
	} else if (_tableViewMode == CapTableViewModeLibrary) {
		
		cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifierLibrary];
		if (cell == nil) {
			cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifierLibrary] autorelease];
			cell.accessoryType = UITableViewCellAccessoryNone;
		}
		
		static NSDateFormatter* formatter = nil;
		if (! formatter) {
			formatter = [[NSDateFormatter alloc] init];
			[formatter setDateFormat:@"yyyy/MM/dd HH:mm:ss"];
		}
		
		NSString* fileName = [[_libraryLists_ objectAtIndex:indexPath.row] stringByDeletingPathExtension];
		NSArray* fileNameData = [fileName componentsSeparatedByString:@"-"];
		if ([fileNameData count] == 2) {
			NSDate* date = [NSDate dateWithTimeIntervalSince1970:[[fileNameData objectAtIndex:0] longLongValue]];
			int ch = [[fileNameData objectAtIndex:1] intValue];
			cell.textLabel.text = [NSString stringWithFormat:@"%@ - %d ch", [formatter stringFromDate:date], ch];
		} else {
			cell.textLabel.text = @" ";
		}
		
		cell.detailTextLabel.text = fileName;
	}
	
    return cell;
}

#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)aTableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (_tableViewMode == CapTableViewModeChannel) {
		
		[playerController prepareTSPacketPlaying];
		//	[NSThread detachNewThreadSelector:@selector(_testSubThread:) toTarget:self withObject:nil];
		
		[self stopRecording];
		[playerController stopRec:nil];
		CapOneSeg* cap = [CapOneSeg sharedInstance];
		cap.delegate = self;
		[cap stopRec];
		_channel = indexPath.row +1;
		[cap startRecWithChannel:_channel];
		
	} else if (_tableViewMode == CapTableViewModeLibrary) {
		NSString* filePath = [self _documentPathWithFileName:[_libraryLists_ objectAtIndex:indexPath.row]];
		//detailViewController.detailItem = filePath;
		[self stopRecording];
		CapOneSeg* cap = [CapOneSeg sharedInstance];
		[cap stopRec];
		[playerController stopRec:nil];
		
		@synchronized(_recFileHandle_) {
			if (_recFileHandle_) {
				NSLog(@"File Handle Already opened.");
				[self.tableView deselectRowAtIndexPath:indexPath animated:YES];
			} else {
				[playerController playMediaFileWithPath:filePath];
			}
		}
	}
}


#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}

- (void)viewDidUnload
{
    self.tableViewSelector = nil;
}


- (void)dealloc
{
	self.tableViewSelector = nil;
	
	self._libraryLists_ = nil;
	self.playerController = nil;
    [super dealloc];
}


@end

