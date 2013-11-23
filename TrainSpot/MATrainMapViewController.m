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

#import "MATrainMapViewController.h"
#import "MATrain.h"
#import "MATrainInformationService.h"
#import "MALoadTrainRequest.h"

@interface MATrainMapViewController (PrivateMethods)
- (void)updateTrainCallback;
- (void)updateMap;
@end

@implementation MATrainMapViewController

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

- (void)viewDidUnload
{
    [super viewDidUnload];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Map supports only portrait orientation
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    self.navigationItem.title = [NSString stringWithFormat:@"%@", self.train.identifier];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    _trainUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:15.0
                                                         target:self
                                                       selector:@selector(updateTrainCallback)
                                                       userInfo:nil
                                                        repeats:YES];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
    
    [_request cancel], _request = nil;
    
    if (_trainUpdateTimer) {
        [_trainUpdateTimer invalidate];
    }
}

/*
 * =======================================
 * Properties
 * =======================================
 */

- (void)setTrain:(MATrain *)train
{
    MKMapView *mapView = (MKMapView *)self.view;
    [mapView removeAnnotation:self.train];
    
    _train = train;
    
    [self updateMap];
}

- (MATrain *)train
{
    return _train;
}

/*
 * =======================================
 * Private
 * =======================================
 */

- (void)updateMap
{
    MKMapView *mapView = (MKMapView *)self.view;
    
    [mapView addAnnotation:self.train];
    
    MKCoordinateRegion region = {.span = {.latitudeDelta = 0.2, .longitudeDelta = 0.2}, .center = self.train.coordinate};
    [mapView setRegion:region animated:TRUE];
    [mapView regionThatFits:region];
}

- (void)updateTrainCallback
{    
    if (!_service) {
        _service = [[MATrainInformationService alloc] init];
    }
    
    __weak MATrainMapViewController *weakSelf = self;
    
    [_request cancel], _request = [_service loadTrainWithIdentifier:self.train.identifier];
    _request.onCompletion = ^(void) {
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
        
        weakSelf.train = _request.train;
        
        [weakSelf updateMap];
    };
    _request.onFailure = ^(void) {
        [UIApplication sharedApplication].networkActivityIndicatorVisible = NO;
    };
    
    [UIApplication sharedApplication].networkActivityIndicatorVisible = YES;
    [_request start];
}

@end
