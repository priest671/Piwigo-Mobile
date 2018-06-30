//
//  AppDelegate.h
//  piwigo
//
//  Created by Spencer Baker on 1/14/15.
//  Copyright (c) 2015 bakercrew. All rights reserved.
//

#import <UIKit/UIKit.h>

FOUNDATION_EXPORT NSString * const kPiwigoNotificationPaletteChanged;

@interface AppDelegate : UIResponder <UIApplicationDelegate>

@property (strong, nonatomic) UIWindow *window;

-(void)loadLoginView;
-(void)loadNavigation;
-(void)screenBrightnessChanged:(NSNotification *)note;

@end
