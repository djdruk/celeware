
#import "AlertView.h"

//
@implementation AlertView

#pragma mark Simulate UIAlertView

//
+ (UIButton *)buttonWithTitle:(NSString *)title
{
	UIImage *image = UIUtil::ImageNamed(@"CommonButton.png");
	UIFont *font = [UIFont systemFontOfSize:16];
	
	CGRect frame = {0, 0, [title sizeWithFont:font].width + 40, image.size.height};
	UIButton *button = [[[UIButton alloc] initWithFrame:frame] autorelease];
	button.titleLabel.font = font;
	[button setBackgroundImage:image.stretchableImage forState:UIControlStateNormal];
	[button setTitle:title forState:UIControlStateNormal];
	
	return button;
}

//
- (id)initWithTitle:(NSString *)title message:(NSString *)message delegate:(id /*<UIUIAlertViewDelegate>*/)delegate cancelButtonTitle:(NSString *)cancelButtonTitle otherButtonTitle:(NSString *)otherButtonTitle
{
	return [self initWithTitle:title message:message delegate:delegate cancelButtonTitle:cancelButtonTitle otherButtonTitle:otherButtonTitle accessoryView:nil];
}

//
#ifndef kAlertBoxTopPad
#define kAlertBoxTopPad 30
#endif
#ifndef kAlertBoxBottomPad
#define kAlertBoxBottomPad 15
#endif
- (id)initWithTitle:(NSString *)title message:(NSString *)message delegate:(id /*<UIUIAlertViewDelegate>*/)delegate cancelButtonTitle:(NSString *)cancelButtonTitle otherButtonTitle:(NSString *)otherButtonTitle accessoryView:(UIView *)accessoryView
{
	//
	CGRect frame = UIUtil::ScreenFrame();
	self = [super initWithFrame:frame];
	
	_delegate = delegate;
	self.userInteractionEnabled = YES;
	self.backgroundColor = [UIColor colorWithWhite:0.1 alpha:0.4];
	self.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	
	//
	UIImage *image = UIUtil::ImageNamed(@"AlertBox.png");
	
	//
	CGFloat y = kAlertBoxTopPad;
	
	if (accessoryView)
	{
		accessoryView.center = CGPointMake(image.size.width / 2, y + accessoryView.frame.size.height / 2);
		accessoryView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin;
		y += accessoryView.frame.size.height + 20;
	}
	
	if (title)
	{
		UIFont *font = [UIFont boldSystemFontOfSize:17];
		CGSize size = [title sizeWithFont:font constrainedToSize:CGSizeMake(image.size.width - 40, frame.size.height)];
		
		_titleLabel = [[[UILabel alloc] initWithFrame:CGRectMake(20, y, image.size.width - 40, size.height)] autorelease];
		_titleLabel.text = title;
		_titleLabel.backgroundColor = UIColor.clearColor;
		_titleLabel.textColor = [UIColor whiteColor];
		_titleLabel.numberOfLines = 0;
		_titleLabel.font = font;
		_titleLabel.textAlignment = NSTextAlignmentCenter;
		
		y = CGRectGetMaxY(_titleLabel.frame) + 10;
	}
	
	//
	if (message)
	{
		UIFont *font = [UIFont systemFontOfSize:17];
		CGSize size = [message sizeWithFont:font constrainedToSize:CGSizeMake(image.size.width - 40, frame.size.height)];
		
		_messageLabel = [[[UILabel alloc] initWithFrame:CGRectMake(20, y, image.size.width - 40, size.height)] autorelease];
		_messageLabel.text = message;
		_messageLabel.backgroundColor = UIColor.clearColor;
		_messageLabel.textColor = [UIColor whiteColor];
		_messageLabel.numberOfLines = 0;
		_messageLabel.font = font;
		
		y = CGRectGetMaxY(_messageLabel.frame) + 10;
	}
	
	//
	if (cancelButtonTitle)
	{
		_cancelButton = [AlertView buttonWithTitle:cancelButtonTitle];
		[_cancelButton addTarget:self action:@selector(onCancelButton) forControlEvents:UIControlEventTouchUpInside];
	}
	
	//
	if (otherButtonTitle)
	{
		_otherButton = [AlertView buttonWithTitle:otherButtonTitle];
		[_otherButton addTarget:self action:@selector(onOtherButton) forControlEvents:UIControlEventTouchUpInside];
		
	}
	
	if (_cancelButton)
	{
		if (_otherButton)
		{
			_cancelButton.center = CGPointMake((image.size.width - _cancelButton.frame.size.width) / 2 - 6, y + _cancelButton.frame.size.height / 2);
			_otherButton.center = CGPointMake((image.size.width + _otherButton.frame.size.width) / 2 + 6, y + _otherButton.frame.size.height / 2);
		}
		else
		{
			_cancelButton.center = CGPointMake((image.size.width / 2), y + _cancelButton.frame.size.height / 2);
		}
		y = CGRectGetMaxY(_cancelButton.frame) + 10;
	}
	else if (_otherButton)
	{
		_otherButton.center = CGPointMake((image.size.width / 2), y + _otherButton.frame.size.height / 2);
		y = CGRectGetMaxY(_otherButton.frame) + 10;
	}
	else
	{
		y += 15;
	}
	
	frame.origin.x = (frame.size.width - image.size.width) / 2;
	frame.origin.y = (frame.size.height - y) / 2;
	frame.size.width = image.size.width;
	frame.size.height = y + kAlertBoxBottomPad;
	_alertCanvas = [[[UIImageView alloc] initWithFrame:frame] autorelease];
	_alertCanvas.userInteractionEnabled = YES;
	_alertCanvas.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleBottomMargin;
	_alertCanvas.image = image.stretchableImage;
	[self addSubview:_alertCanvas];
	
	if (accessoryView) [_alertCanvas addSubview:accessoryView];
	if (_titleLabel) [_alertCanvas addSubview:_titleLabel];
	if (_messageLabel) [_alertCanvas addSubview:_messageLabel];
	if (_cancelButton) [_alertCanvas addSubview:_cancelButton];
	if (_otherButton) [_alertCanvas addSubview:_otherButton];
	
	return self;
}

//
- (void)onCancelButton
{
	[self dismissWithClickedButtonIndex:0 animated:YES];
}

//
- (void)onOtherButton
{
	[self dismissWithClickedButtonIndex:1 animated:YES];
}

//
- (void)show
{
	UIView *parent = [UIUtil::KeyWindow().subviews objectAtIndex:0];
	[self showInView:parent];
}

//
- (void)showInView:(UIView *)parent
{
	CGRect frame = parent.bounds;
	if ([[UIApplication sharedApplication].keyWindow findFirstResponder])
	{
		_fitKeyboard = YES;
		frame.size.height -= 216;
	}
	self.frame = frame;
	[parent addSubview:self];
	
	self.alpha = 0;
	
	if ([_delegate respondsToSelector:@selector(willPresentAlertView:)])
	{
		[_delegate willPresentAlertView:(UIAlertView *)self];
	}
	
	[UIView animateWithDuration:0.3 animations:^()
	 {
		 self.alpha = 1;
	 } completion:^(BOOL finished)
	 {
		 if ([_delegate respondsToSelector:@selector(didPresentAlertView:)])
		 {
			 [_delegate didPresentAlertView:(UIAlertView *)self];
		 }
	 }];
	
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(keyboardDidShow:)
												 name:UIKeyboardDidShowNotification
											   object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self
											 selector:@selector(keyboardWillHide:)
												 name:UIKeyboardWillHideNotification
											   object:nil];
	
	[_textField becomeFirstResponder];
}

//
- (void)dismissWithClickedButtonIndex:(NSInteger)buttonIndex
{
	if ([_delegate respondsToSelector:@selector(alertView: didDismissWithButtonIndex:)])
	{
		[_delegate alertView:(UIAlertView *)self didDismissWithButtonIndex:buttonIndex];
	}
	
	[self removeFromSuperview];
	
	if (_clickAction && [_delegate respondsToSelector:_clickAction])
	{
		[_delegate performSelector:_clickAction withObject:_clickParam];
	}
	else if ([_delegate respondsToSelector:@selector(alertView: clickedButtonAtIndex:)])
	{
		[_delegate alertView:(UIAlertView *)self clickedButtonAtIndex:buttonIndex];
	}
}

//
- (void)dismissWithClickedButtonIndex:(NSInteger)buttonIndex animated:(BOOL)animated
{
	if ([_delegate respondsToSelector:@selector(alertView: willDismissWithButtonIndex:)])
	{
		[_delegate alertView:(UIAlertView *)self willDismissWithButtonIndex:buttonIndex];
	}
	
	if (animated)
	{
		[UIView animateWithDuration:0.3 animations:^()
		 {
			 self.alpha = 0;
		 } completion:^(BOOL finished)
		 {
			 [self dismissWithClickedButtonIndex:buttonIndex];
		 }];
	}
	else
	{
		[self dismissWithClickedButtonIndex:buttonIndex];
	}
}


#pragma mark Keyboard handler

//
//- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event
//{
//	[[self findFirstResponder] resignFirstResponder];
//	[super touchesBegan:touches withEvent:event];
//}

//
- (void)removeFromSuperview
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	[super removeFromSuperview];
}

//
- (void)keyboardDidShow:(NSNotification *)notification
{
	if (_fitKeyboard) return;
	_fitKeyboard = YES;
	
	CGRect rect;
	NSValue *value = [notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey];
	[value getValue:&rect];
	
	[UIView animateWithDuration:0.3 animations:^()
	 {
		 CGRect frame = self.frame;
		 frame.size.height -= rect.size.height;
		 self.frame = frame;
	 }];
}

//
- (void)keyboardWillHide:(NSNotification *)notification
{
	if (!_fitKeyboard) return;
	_fitKeyboard = NO;
	
	CGRect rect;
	NSValue *value = [notification.userInfo objectForKey:UIKeyboardFrameEndUserInfoKey];
	[value getValue:&rect];
	
	[UIView animateWithDuration:0.3 animations:^()
	 {
		 CGRect frame = self.frame;
		 frame.size.height += rect.size.height;
		 self.frame = frame;
	 }];
}


#pragma mark Simulate UIAlertView (AlertViewEx)

//
+ (id)alertWithTitle:(NSString *)title message:(NSString *)message delegate:(id)delegate cancelButtonTitle:(NSString *)cancelButtonTitle otherButtonTitle:(NSString *)otherButtonTitle accessoryView:(UIView *)accessoryView
{
	AlertView *alertView = [[[AlertView alloc] initWithTitle:title
													 message:message
													delegate:delegate
										   cancelButtonTitle:cancelButtonTitle
											otherButtonTitle:otherButtonTitle
											   accessoryView:accessoryView
							 ] autorelease];
	[alertView show];
	return alertView;
}

//
+ (id)alertWithTitle:(NSString *)title message:(NSString *)message delegate:(id)delegate cancelButtonTitle:(NSString *)cancelButtonTitle otherButtonTitle:(NSString *)otherButtonTitle
{
	return [self alertWithTitle:title message:message delegate:delegate cancelButtonTitle:cancelButtonTitle otherButtonTitle:otherButtonTitle accessoryView:nil];
}

//
+ (id)alertWithTitle:(NSString *)title message:(NSString *)message
{
	return [self alertWithTitle:title message:message delegate:nil cancelButtonTitle:NSLocalizedString(@"Dismiss", @"关闭") otherButtonTitle:nil];
}

//
+ (id)alertWithTitle:(NSString *)title
{
	return [self alertWithTitle:title message:nil];
}

//
+ (id)alertWithTask:(id/*<AlertViewExDelegate>*/)delegate title:(NSString *)title
{
	AlertView *alertView = [self alertWithTitle:title message:@" \n " delegate:nil cancelButtonTitle:nil otherButtonTitle:nil];
	[alertView.activityIndicator startAnimating];
	[delegate performSelectorInBackground:@selector(taskForAlertView:) withObject:alertView];
	return alertView;
}

//
+ (id)alertWithTitle:(NSString *)title message:(NSString *)message buttonTitle:(NSString *)buttonTitle target:(id)target action:(SEL)action param:(id)param
{
	AlertView *alertView = [AlertView alertWithTitle:title message:message delegate:target cancelButtonTitle:buttonTitle otherButtonTitle:nil];
	alertView.clickAction = action;
	alertView.clickParam = param;
	return alertView;
}

//
+ (id)alertWithTitle:(NSString *)title message:(NSString *)message buttonTitle:(NSString *)buttonTitle target:(id)target action:(SEL)action
{
	AlertView *alertView = [AlertView alertWithTitle:title message:message buttonTitle:buttonTitle target:target action:action param:nil];
	alertView.clickParam = alertView;
	return alertView;
}

//
- (UITextField *)textField
{
	if (_textField == nil)
	{
		CGRect frame = _messageLabel.frame;
		_textField = [[[UITextField alloc] initWithFrame:CGRectInset(_messageLabel.frame, 0, (frame.size.height - 32) / 2)] autorelease];
		_textField.borderStyle = UITextBorderStyleRoundedRect;
		//_textField.background = UIUtil::ImageNamed(@"AlertEdit.png");
		//_textField.textAlignment = NSTextAlignmentCenter;
		_textField.contentVerticalAlignment = UIControlContentVerticalAlignmentCenter;
		
		[_alertCanvas addSubview:_textField];
		//[textField becomeFirstResponder];
	}
	return _textField;
}

//
#define kActivityIndicatorTag 1924
- (UIActivityIndicatorView *)activityIndicator
{
	UIActivityIndicatorView *activityIndicator = (UIActivityIndicatorView *)[self viewWithTag:kActivityIndicatorTag];
	if (activityIndicator == nil)
	{
		activityIndicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge];
		activityIndicator.center = _messageLabel.center;
		activityIndicator.tag = kActivityIndicatorTag;
		activityIndicator.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
		[_alertCanvas addSubview:activityIndicator];
		[activityIndicator release];
	}
	return activityIndicator;
}

//
- (void)dismissOnMainThread
{
	[self performSelectorOnMainThread:@selector(dismiss) withObject:nil waitUntilDone:YES];
}

//
- (void)dismiss
{
	[self dismissWithClickedButtonIndex:0 animated:YES];
}

@end