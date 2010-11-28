/* 
 Boxer is copyright 2010 Alun Bestor and contributors.
 Boxer is released under the GNU General Public License 2.0. A full copy of this license can be
 found in this XCode project at Resources/English.lproj/GNU General Public License.txt, or read
 online at [http://www.gnu.org/licenses/gpl-2.0.txt].
 */


#import "BXFirstRunWindowController.h"
#import "NSWindow+BXWindowEffects.h"
#import "BXAppController+BXGamesFolder.h"
#import "BXValueTransformers.h"
#import "NSString+BXPaths.h"


//Used to determine where to fill the games folder selector with suggested locations

enum {
	BXGamesFolderSelectorStartOfOptionsTag = 1,
	BXGamesFolderSelectorEndOfOptionsTag = 2
};

@interface BXFirstRunWindowController ()

//Generates a new menu item representing the specified path,
//ready for insertion into the games folder selector.
- (NSMenuItem *) _folderItemForPath: (NSString *)path;

@end


@implementation BXFirstRunWindowController
@synthesize gamesFolderSelector, addSampleGamesToggle, useShelfAppearanceToggle;

+ (id) controller
{
	static id singleton = nil;
	
	if (!singleton) singleton = [[self alloc] initWithWindowNibName: @"FirstRunWindow"];
	return singleton;
}

- (void) dealloc
{	
	[self setGamesFolderSelector: nil],			[gamesFolderSelector release];
	[self setAddSampleGamesToggle: nil],		[addSampleGamesToggle release];
	[self setUseShelfAppearanceToggle: nil],	[useShelfAppearanceToggle release];
	
	[super dealloc];
}

- (void) awakeFromNib
{
	//Empty the placeholder items first
	NSMenu *menu = [gamesFolderSelector menu];
	NSUInteger startOfOptions	= [menu indexOfItemWithTag: BXGamesFolderSelectorStartOfOptionsTag];
	NSUInteger endOfOptions		= [menu indexOfItemWithTag: BXGamesFolderSelectorEndOfOptionsTag];
	NSRange optionRange			= NSMakeRange(startOfOptions, endOfOptions - startOfOptions);

	for (NSMenuItem *oldItem in [[menu itemArray] subarrayWithRange: optionRange])
		[menu removeItem: oldItem];
	
	
	//Now populate the menu with new items for each default path
	NSArray *defaultPaths = [BXAppController defaultGamesFolderPaths];
	
	NSUInteger insertionPoint = startOfOptions;
	
	for (NSString *path in defaultPaths)
	{
		NSMenuItem *item = [self _folderItemForPath: path];
		[menu insertItem: item atIndex: insertionPoint++];
	}
	
	[gamesFolderSelector selectItemAtIndex: 0];	
}

- (NSMenuItem *) _folderItemForPath: (NSString *)path
{
	NSValueTransformer *pathTransformer = [NSValueTransformer valueTransformerForName: @"BXDisplayPathWithIcons"];
	
	NSMenuItem *item = [[NSMenuItem alloc] init];
	[item setRepresentedObject: path];
	
	[item setAttributedTitle: [pathTransformer transformedValue: path]];
	
	return [item autorelease];
}

- (void) showWindow: (id)sender
{
	[[self window] revealWithTransition: CGSFlip
							  direction: CGSUp
							   duration: 0.5
						   blockingMode: NSAnimationNonblocking];
	[NSApp runModalForWindow: [self window]];
}

- (void) windowWillClose: (NSNotification *)notification
{
	if ([NSApp modalWindow] == [self window]) [NSApp stopModal];
}

- (IBAction) makeGamesFolder: (id)sender
{
	BXAppController *controller = [NSApp delegate];
	
	NSString *path = [[gamesFolderSelector selectedItem] representedObject];
	
	NSFileManager *manager = [NSFileManager defaultManager];
	if (![manager fileExistsAtPath: path])
	{
		NSError *creationError;
		BOOL created = [manager createDirectoryAtPath: path
						  withIntermediateDirectories: YES
										   attributes: nil
												error: &creationError];
		
		if (!created)
		{
			[self presentError: creationError
				modalForWindow: [self window]
					  delegate: nil
			didPresentSelector: NULL
				   contextInfo: NULL];
			return;
		}
	}
	
	BOOL useShelfAppearance = (BOOL)[useShelfAppearanceToggle state];
	[[NSApp delegate] setAppliesShelfAppearanceToGamesFolder: useShelfAppearance];
	if (useShelfAppearance)
	{
		[controller applyShelfAppearanceToPath: path switchToShelfMode: YES];
	}
	
	if ([addSampleGamesToggle state])
	{
		[controller addSampleGamesToPath: path];
	}
	
	[controller setGamesFolderPath: path];
	
	[[self window] hideWithTransition: CGSFlip
							direction: CGSDown
							 duration: 0.5
						 blockingMode: NSAnimationBlocking];
	
	[[self window] close];
}

- (IBAction) showGamesFolderChooser: (id)sender
{	
	//NOTE: normally our go-to guy for this is BXGamesFolderPanelController,
	//but he insists on asking about sample games and creating the game folder
	//end of the process. We only want to add the chosen location to the list,
	//and will create the folder when the user confirms.
	
	NSOpenPanel *openPanel = [NSOpenPanel openPanel];
	
	[openPanel setCanCreateDirectories: YES];
	[openPanel setCanChooseDirectories: YES];
	[openPanel setCanChooseFiles: NO];
	[openPanel setTreatsFilePackagesAsDirectories: NO];
	[openPanel setAllowsMultipleSelection: NO];
	
	[openPanel setPrompt: NSLocalizedString(@"Select", @"Button label for Open panels when selecting a folder.")];
	[openPanel setMessage: NSLocalizedString(@"Select a folder in which to keep your DOS games:",
											 @"Help text shown at the top of choose-a-games-folder panel.")];
	
	[openPanel beginSheetForDirectory: NSHomeDirectory()
								 file: nil
								types: nil
					   modalForWindow: [self window]
						modalDelegate: self
					   didEndSelector: @selector(setChosenGamesFolder:returnCode:contextInfo:)
						  contextInfo: nil];
}

- (void) setChosenGamesFolder: (NSOpenPanel *)openPanel
				   returnCode: (int)returnCode
				  contextInfo: (void *)contextInfo
{
	if (returnCode == NSOKButton)
	{
		NSString *path = [[openPanel URL] path];
		NSMenuItem *item = [self _folderItemForPath: path];
		
		NSMenu *menu = [gamesFolderSelector menu];
		NSUInteger insertionPoint = [menu indexOfItemWithTag: BXGamesFolderSelectorEndOfOptionsTag];
		[menu insertItem: item atIndex: insertionPoint];
		[gamesFolderSelector selectItemAtIndex: insertionPoint];
	}
	else
	{
		[gamesFolderSelector selectItemAtIndex: 0];
	}
}

@end