//
//  Browser+WebUIDelegate.h
//  Vienna
//
//  Created by Tassilo Karge on 12.10.18.
//  Copyright © 2018 uk.co.opencommunity. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WebViewBrowser.h"
@import WebKit;

NS_ASSUME_NONNULL_BEGIN

@interface WebViewBrowser (WebUIDelegate) <WebUIDelegate>

@end

NS_ASSUME_NONNULL_END
