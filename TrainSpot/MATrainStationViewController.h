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

#import <Foundation/Foundation.h>

@class MATrainStation;
@class MATrainInformationService;
@class MALoadTrainStationRequest;
@class MATrainViewController;

typedef enum {
    kTrainTypeSelectionAll = 0,
    kTrainTypeSelectionLocal,
    kTrainTypeSelectionLongDistance,
} MATrainTypeSelection;

@interface MATrainStationViewController : UIViewController<UITableViewDataSource,UITableViewDelegate> {
    MATrainInformationService *_service;
    UINavigationController *_navigationController;
    MATrainViewController *_trainViewController;
    UITableView *_tableView;
    UISegmentedControl *_trainTypeControl;
    
    MATrainTypeSelection _trainTypeSelection;
    MATrainStation *_trainStation;
    NSMutableArray *_trains;
    NSMutableArray *_filteredTrainList;
    
    BOOL _resetDataWhenViewWillAppear;
    MALoadTrainStationRequest *_request;
    
    UIActivityIndicatorView *_activityIndicator;
    NSDateFormatter *_timeFormatter;
}

@property (strong, nonatomic) IBOutlet UINavigationController *navigationController;
@property (strong, nonatomic) IBOutlet MATrainViewController *trainController;
@property (strong, nonatomic) IBOutlet UITableView *tableView;
@property (strong, nonatomic) IBOutlet UISegmentedControl *trainTypeControl;
@property (strong, nonatomic) MATrainStation *trainStation;
@property (nonatomic, assign) BOOL resetDataWhenViewWillAppear;

- (IBAction)chooseTrainType:(id)sender;

@end
