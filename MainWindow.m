/*
 *  Copyright (c) 2013, Stefan Johnson                                                  
 *  All rights reserved.                                                                
 *                                                                                      
 *  Redistribution and use in source and binary forms, with or without modification,    
 *  are permitted provided that the following conditions are met:                       
 *                                                                                      
 *  1. Redistributions of source code must retain the above copyright notice, this list 
 *     of conditions and the following disclaimer.                                      
 *  2. Redistributions in binary form must reproduce the above copyright notice, this   
 *     list of conditions and the following disclaimer in the documentation and/or other
 *     materials provided with the distribution.                                        
 *  
 * THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
 * AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
 * DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
 * FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
 * DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
 * SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
 * CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
 * OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
 * OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
 */

#import "MainWindow.h"
#import <Carbon/Carbon.h>
#import <libproc.h>


static CGEventRef EventTap(CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *userInfo)
{
    switch (type)
    {
        case kCGEventLeftMouseDown:
        case kCGEventLeftMouseUp:
        case kCGEventLeftMouseDragged:;
            char ProcName[PROC_PIDPATHINFO_MAXSIZE];
            if (!proc_name((pid_t)CGEventGetIntegerValueField(event, kCGEventTargetUnixProcessID), ProcName, sizeof(ProcName))) return event;
            
            NSString *Target = [NSString stringWithUTF8String: ProcName];
            
            if ([Target isEqualToString: @"Finder"])
            {
                for (NSDictionary *Window in [(NSArray*)CGWindowListCopyWindowInfo(kCGWindowListOptionIncludingWindow, CGEventGetIntegerValueField(event, kCGMouseEventWindowUnderMousePointer)) autorelease])
                {
                    if ([[Window objectForKey: (NSString*)kCGWindowName] length] == 0)
                    {
                        NSDictionary *Bounds = [Window objectForKey: (NSString*)kCGWindowBounds];
                        if (NSEqualRects([[NSScreen mainScreen] frame], NSMakeRect([[Bounds objectForKey: @"X"] floatValue], 
                                                                                   [[Bounds objectForKey: @"Y"] floatValue], 
                                                                                   [[Bounds objectForKey: @"Width"] floatValue], 
                                                                                   [[Bounds objectForKey: @"Height"] floatValue])))
                        {
                            NSEvent *FocusedEvent = [NSEvent mouseEventWithType: type location: CGEventGetUnflippedLocation(event) modifierFlags: CGEventGetFlags(event) timestamp: GetCurrentEventTime()  windowNumber: [(MainWindow*)userInfo windowNumber] context: [NSGraphicsContext currentContext] eventNumber: CGEventGetIntegerValueField(event, kCGMouseEventNumber) clickCount: CGEventGetIntegerValueField(event, kCGMouseEventClickState) pressure: CGEventGetDoubleValueField(event, kCGMouseEventPressure)];
                            
                            [NSApp postEvent: FocusedEvent atStart: NO];
                        }
                    }
                }
            }
            break;
            
        case kCGEventTapDisabledByTimeout:
        case kCGEventTapDisabledByUserInput: //may wish to comment this out, since leaving it you won't be able to call -disableTap
            [(MainWindow*)userInfo enableTap];
            break;
    }
        
    return event;
}


@implementation MainWindow
{
    CFMachPortRef tap;
    CFRunLoopSourceRef source;
}

-(id) initWithContentRect: (NSRect)contentRect styleMask: (NSUInteger)aStyle backing: (NSBackingStoreType)bufferingType defer: (BOOL)flag
{
    if ((self = [super initWithContentRect: [[NSScreen mainScreen] frame] styleMask: NSBorderlessWindowMask backing: bufferingType defer: flag]))
    {
        [self setCollectionBehavior: NSWindowCollectionBehaviorCanJoinAllSpaces];
        [self setOpaque: NO];
        [self setBackgroundColor: [NSColor clearColor]];
        [[self contentView] setFrame: [[NSScreen mainScreen] frame]];
        [self setLevel: kCGDesktopWindowLevel];
        
        /* Enable/Disable what you need and don't need */
        CGEventMask Mask = 
        //CGEventMaskBit(kCGEventNull) |
        CGEventMaskBit(kCGEventLeftMouseDown) | 
        CGEventMaskBit(kCGEventLeftMouseUp) | 
        //CGEventMaskBit(kCGEventRightMouseDown) | 
        //CGEventMaskBit(kCGEventRightMouseUp) | 
        //CGEventMaskBit(kCGEventMouseMoved) |
        CGEventMaskBit(kCGEventLeftMouseDragged) |
        //CGEventMaskBit(kCGEventRightMouseDragged) |
        //CGEventMaskBit(kCGEventKeyDown) |
        //CGEventMaskBit(kCGEventKeyUp) |
        //CGEventMaskBit(kCGEventFlagsChanged) |
        //CGEventMaskBit(kCGEventScrollWheel) |
        //CGEventMaskBit(kCGEventTabletPointer) |
        //CGEventMaskBit(kCGEventTabletProximity) |
        //CGEventMaskBit(kCGEventOtherMouseDown) |
        //CGEventMaskBit(kCGEventOtherMouseUp) |
        //CGEventMaskBit(kCGEventOtherMouseDragged) |
        0;
        tap = CGEventTapCreate(kCGAnnotatedSessionEventTap, kCGTailAppendEventTap, kCGEventTapOptionDefault, Mask, EventTap, self);
        source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0);
        CFRunLoopAddSource(CFRunLoopGetCurrent(), source, kCFRunLoopCommonModes);
    }
    
    return self;
}

-(void) enableTap
{
    CGEventTapEnable(tap, TRUE);
}

-(void) disableTap
{
    CGEventTapEnable(tap, FALSE);
}

-(void) dealloc
{
    CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, kCFRunLoopCommonModes);
    CFRelease(source);
    CFRelease(tap);
    
    [super dealloc];
}

@end
