/*
 * Copyright (c) 2012 Matias Muhonen <mmu@iki.fi>
 * All rights reserved.
 *
 * Redistribution and use in source and binary forms, with or without
 * modification, are permitted provided that the following conditions
 * are met:
 * 1. Redistributions of source code must retain the above copyright
 *    notice, this list of conditions and the following disclaimer.
 * 2. Redistributions in binary form must reproduce the above copyright
 *    notice, this list of conditions and the following disclaimer in the
 *    documentation and/or other materials provided with the distribution.
 * 3. The name of the author may not be used to endorse or promote products
 *    derived from this software without specific prior written permission.
 *
 * THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
 * IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
 * OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
 * IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
 * INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
 * NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
 * DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
 * THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
 * (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
 * THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "MATrainViewController.h"

#import "MATrain.h"
#import "MATrainStation.h"
#import "MATrainInformationService.h"
#import "MALoadTrainRequest.h"
#import "MATrainMapViewController.h"

typedef enum {
	kTrainViewSectionTrain,
    kTrainViewSectionWaypoints,
    kTrainViewSectionTrainLocation,
} MATrainViewSection;

@interface MATrainViewController (PrivateMethods)
@property (readonly) MATrainInformationService *service;
@property (readonly) UIActivityIndicatorView *activityIndicator;
@property (readonly) NSDateFormatter *timeFormatter;
@end

@implementation MATrainViewController

@synthesize navigationController=_navigationController;
@synthesize trainMapController=_trainMapController;
@synthesize train=_train;

/*
 * =======================================
 * View controller
 * =======================================
 */

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    return YES;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.tableView.tableFooterView = self.activityIndicator;
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    
    self.train = nil;
    
    _service = nil;
    
    [_request cancel];
    _request = nil;
    
    _activityIndicator = nil;
    _timeFormatter = nil;
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    self.navigationItem.title = self.train.identifier;
    [_request.train.waypoints removeAllObjects];
    [self.tableView reloadData];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    if (_request) {
        [_request cancel];
        _request = nil;
        
        [self.activityIndicator stopAnimating];
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    }
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    __weak MATrainViewController *weakSelf = self;
    _request = [self.service loadTrainWithIdentifier:self.train.identifier];
    _request.onCompletion = ^(void) {
        [weakSelf.activityIndicator stopAnimating];
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        
        [weakSelf.tableView reloadData];
    };
    _request.onFailure = ^(void) {
        [weakSelf.activityIndicator stopAnimating];
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        
        UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error"
                                                        message:@"Error loading the train."
                                                       delegate:nil
                                              cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
        [alert show];
    };
    [_request start];
    [_activityIndicator startAnimating];
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
}

/*
 * =======================================
 * Table view
 * =======================================
 */

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section
{
	if (section == kTrainViewSectionTrain) {
		return @"Train";
	} else if (section == kTrainViewSectionWaypoints) {
        return @"Waypoints";
    }
	return nil;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 3;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    NSInteger numberOfRows = 0;
    if (section == kTrainViewSectionTrain) {
        numberOfRows = 2;
    } else if (section == kTrainViewSectionTrainLocation) {
        numberOfRows = 1;
    } else if (section == kTrainViewSectionWaypoints) {
        numberOfRows = [_request.train.waypoints count];
    }
    return numberOfRows;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    UITableViewCell *cell = nil;

    if (indexPath.section == kTrainViewSectionTrain) {
        static NSString *CellIdentifier = @"MATrainViewCell";
        
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleValue2 reuseIdentifier:CellIdentifier];
        }
        
        if (indexPath.row == 0) {
            MATrainWaypoint *origin = ([_request.train.waypoints count] > 0 ? [_request.train.waypoints objectAtIndex:0] : nil);
            cell.textLabel.text = @"From";
            cell.detailTextLabel.text = (origin.scheduledDepartureTime ?
                                         [NSString stringWithFormat:@"%@ %@",
                                          [self.timeFormatter stringFromDate:origin.scheduledDepartureTime],
                                          self.train.from.name] :
                                         self.train.from.name);
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        } else if (indexPath.row == 1) {
            MATrainWaypoint *destination = [_request.train.waypoints lastObject];
            cell.textLabel.text = @"To";
            cell.detailTextLabel.text = (destination.scheduledArrivalTime ?
                                         [NSString stringWithFormat:@"%@ %@",
                                          [self.timeFormatter stringFromDate:destination.scheduledArrivalTime],
                                          self.train.to.name] :
                                         self.train.to.name);
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
        }
    } else if (indexPath.section == kTrainViewSectionTrainLocation) {
        static NSString *CellIdentifier = @"MATrainViewLocationCell";
        
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier];
        }
        
        if (indexPath.row == 0) {
            cell.textLabel.text = @"Show train on a Map...";
            cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
        }
    } else if (indexPath.section == kTrainViewSectionWaypoints) {
        static NSString *CellIdentifier = @"MATrainViewWaypointCell";
        
        cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
        if (cell == nil) {
            cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleSubtitle reuseIdentifier:CellIdentifier];
        }
        
        MATrainWaypoint *waypoint = [_request.train.waypoints objectAtIndex:indexPath.row];
        
        if (waypoint.completed) {
            cell.textLabel.textColor = [UIColor grayColor];
        } else {
            cell.textLabel.textColor = [UIColor blackColor];
        }
        
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.textLabel.text = waypoint.trainStation.name;
        
        if (waypoint != [_request.train.waypoints lastObject]) {
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@",
                                         [self.timeFormatter stringFromDate:waypoint.scheduledDepartureTime]];
        } else {
            cell.detailTextLabel.text = [NSString stringWithFormat:@"%@",
                                         [self.timeFormatter stringFromDate:waypoint.scheduledArrivalTime]];
        }
    }
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (indexPath.section == kTrainViewSectionTrainLocation) {
        CLLocationCoordinate2D coordinate = _request.train.location.coordinate;
        if (coordinate.latitude > 0 && coordinate.longitude > 0) {
            self.trainMapController.train = _request.train;
            [self.navigationController pushViewController:self.trainMapController animated:YES];
        } else {
            UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Location not available"
                                                            message:@"Train location is unknown."
                                                           delegate:nil
                                                  cancelButtonTitle:@"Ok" otherButtonTitles:nil, nil];
            [alert show];
        }
    }
}

/*
 * =======================================
 * Properties
 * =======================================
 */

- (MATrainInformationService *)service
{
    if (!_service) {
        _service = [[MATrainInformationService alloc] init];
    }
    return _service;
}

- (UIActivityIndicatorView *)activityIndicator
{
    if (!_activityIndicator) {
        _activityIndicator = [UIActivityIndicatorView new];
        _activityIndicator.frame = CGRectMake(0.0, 0.0, 40.0, 40.0);
        _activityIndicator.hidesWhenStopped = YES;
    }
    return _activityIndicator;
}

- (NSDateFormatter *)timeFormatter
{
    if (!_timeFormatter) {
        _timeFormatter = [[NSDateFormatter alloc] init];
        [_timeFormatter setDateFormat:@"HH:mm"];
    }
    return _timeFormatter;
}

@end
