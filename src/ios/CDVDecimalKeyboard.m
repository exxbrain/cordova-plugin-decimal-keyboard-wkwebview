#import <WebKit/WebKit.h>

#import "CDVDecimalKeyboard.h"

@implementation CDVDecimalKeyboard

UIView* ui;
CGRect cgButton;
BOOL isDecimalKeyRequired=YES;
UIButton *decimalButton;

- (void)pluginInitialize {
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(keyboardWillAppear:)
                                                 name: UIKeyboardWillShowNotification
                                               object: nil];
    [[NSNotificationCenter defaultCenter] addObserver: self
                                             selector: @selector(keyboardWillDisappear:)
                                                 name: UIKeyboardWillHideNotification
                                               object: nil];
}

-(UIColor*) textColor {
    if (@available(iOS 12.0, *)) {
        if (self.viewController.traitCollection.userInterfaceStyle == UIUserInterfaceStyleDark) {
            return [UIColor whiteColor];
        }
    }
    return [UIColor blackColor];
}


- (void) keyboardWillDisappear: (NSNotification*) n{
    [self removeDecimalButton];
}

-(void) setDecimalChar {
    [self evaluateJavaScript:@"DecimalKeyboard.getButtonChar();"
           completionHandler:^(NSString * _Nullable response, NSError * _Nullable error) {
               if (response) {
                   [decimalButton setTitle:response forState:UIControlStateNormal];
               }
           }];
}

- (void) addDecimalButton{
    if ( UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad )
    {
        return ; /* Device is iPad and this code works only in iPhone*/
    }
    decimalButton = [UIButton buttonWithType:UIButtonTypeCustom];
    [self setDecimalChar];
    [decimalButton setTitleColor:self.textColor forState:UIControlStateNormal];
    decimalButton.titleLabel.font = [UIFont systemFontOfSize:40.0];
    [decimalButton addTarget:self action:@selector(buttonPressed:)
            forControlEvents:UIControlEventTouchUpInside];

    decimalButton.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
    [decimalButton setTitleEdgeInsets:UIEdgeInsetsMake(-20.0f, 0.0f, 0.0f, 0.0f)];
    [decimalButton setBackgroundColor: [UIColor clearColor]];

    // locate keyboard view
    UIWindow* tempWindow = nil;
    NSArray* openWindows = [[UIApplication sharedApplication] windows];

    for(UIWindow* object in openWindows){
        if([[object description] hasPrefix:@"<UIRemoteKeyboardWindow"] == YES){
            tempWindow = object;
        }
    }

    if(tempWindow ==nil){
        //for ios 8
        for(UIWindow* object in openWindows){
            if([[object description] hasPrefix:@"<UITextEffectsWindow"] == YES){
                tempWindow = object;
            }
        }
    }


    UIView* keyboard;
    for(int i=0; i<[tempWindow.subviews count]; i++) {
        keyboard = [tempWindow.subviews objectAtIndex:i];
        [self listSubviewsOfView: keyboard];
        decimalButton.frame = cgButton;
        [ui addSubview:decimalButton];
    }
}
- (void) removeDecimalButton{
    [decimalButton removeFromSuperview];
    decimalButton=nil;
    stopSearching=NO;

}
- (void) deleteDecimalButton{
    [decimalButton removeFromSuperview];
    decimalButton=nil;
    stopSearching=NO;
}
BOOL isDifferentKeyboardShown=NO;

- (void) keyboardWillAppear: (NSNotification*) n{
    NSDictionary* info = [n userInfo];
    NSNumber* value = [info objectForKey:UIKeyboardAnimationDurationUserInfoKey];
    double dValue = [value doubleValue];

    dispatch_time_t delay = dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC * dValue);
    dispatch_after(delay, dispatch_get_main_queue(), ^(void){
        [self processKeyboardShownEvent];
    });


}
- (void) processKeyboardShownEvent{
    [self isTextOrNumberAndDecimal:^(BOOL isDecimalKeyRequired) {
        // create custom button
        if(decimalButton == nil){
            if(isDecimalKeyRequired){
                [self addDecimalButton];
            }
        }else{
            if(isDecimalKeyRequired){
                decimalButton.hidden=NO;
                [self setDecimalChar];
            }else{
                [self removeDecimalButton];
            }
        }
    }];
}

- (void)buttonPressed:(UIButton *)button {
    [self evaluateJavaScript:@"DecimalKeyboard.addDecimal();" completionHandler:nil];
}

- (void) isTextOrNumberAndDecimal:(void (^)(BOOL isTextOrNumberAndDecimal))completionHandler {
    [self evaluateJavaScript:@"DecimalKeyboard.getActiveElementType();"
           completionHandler:^(NSString * _Nullable response, NSError * _Nullable error) {
               BOOL isText = [response isEqual:@"text"];
               BOOL isNumber = [response isEqual:@"number"];

               if (isText || isNumber) {
                   [self evaluateJavaScript:@"DecimalKeyboard.isDecimal();"
                          completionHandler:^(NSString * _Nullable response, NSError * _Nullable error) {
                              BOOL isDecimal = [response isEqual:@"true"] || [response isEqual:@"1"];
                              BOOL isTextOrNumberAndDecimal = (isText || isNumber) && isDecimal;
                              completionHandler(isTextOrNumberAndDecimal);
                          }];
               } else {
                   completionHandler(NO);
               }
           }];
}

BOOL stopSearching=NO;
- (void)listSubviewsOfView:(UIView *)view {

    // Get the subviews of the view
    NSArray *subviews = [view subviews];

    // Return if there are no subviews
    if ([subviews count] == 0) return; // COUNT CHECK LINE
    
    for (UIView *subview in subviews) {
        if(stopSearching==YES){
            break;
        }
        if([[subview description] hasPrefix:@"<UIKBKeyplaneView"] == YES){
            ui = subview;
            stopSearching = YES;
            CGFloat x = 0;
            
            UIView *lastButton = [ui.subviews sortedArrayUsingComparator:^NSComparisonResult(id a, id b) {
                CGFloat first = ((UIView*)a).frame.origin.y;
                CGFloat second = ((UIView*)b).frame.origin.y;
                if (first - second > 0) {
                    return NSOrderedDescending;
                } else if (first - second < 0) {
                    return NSOrderedAscending;
                }
                return NSOrderedSame;
            }].lastObject;
            cgButton = CGRectMake(x, lastButton.frame.origin.y, lastButton.frame.size.width, lastButton.frame.size.height);
        }

        [self listSubviewsOfView:subview];
    }
}
- (void) evaluateJavaScript:(NSString *)script
          completionHandler:(void (^ _Nullable)(NSString * _Nullable response, NSError * _Nullable error))completionHandler {

        WKWebView *webview = (WKWebView*)self.webView;
        [webview evaluateJavaScript:script completionHandler:^(id result, NSError *error) {
            if (completionHandler) {
                if (error) completionHandler(nil, error);
                else completionHandler([NSString stringWithFormat:@"%@", result], nil);
            }
        }];
}

@end
