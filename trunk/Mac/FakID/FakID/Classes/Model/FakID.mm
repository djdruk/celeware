

#import "FakID.h"


//
NSString *FakID::Run(NSString *path, NSArray *arguments, NSString *directory, BOOL needResult)
{
	NSTask *task = [[NSTask alloc] init];
	task.launchPath = path;
	task.arguments = arguments;
	if (directory) task.currentDirectoryPath = directory;
	
	if (needResult)
	{
		NSPipe *pipe = [NSPipe pipe];
		task.standardOutput = pipe;
		task.standardError = pipe;
		
		NSFileHandle *file = [pipe fileHandleForReading];
		
		[task launch];
		
		NSData *data = [file readDataToEndOfFile];
		NSString *result = data.length ? [[[NSString alloc] initWithData:data encoding:NSUTF8StringEncoding] autorelease] : nil;
		
		_Log(@"CMD:\n%@\n%@\n=>\n{\n%@\n}\n\n", path, arguments, (result ? result : @""));
		return result;
	}
	else
	{
		[task launch];
		return nil;
	}
}

//
NSString *FakID::Sign(NSString *name)
{
	NSString *file = [NSString stringWithFormat:@"Contents/Resources/%@", name];
	NSString *path = kBundleSubPath(file);
	
	NSString *res = [NSString stringWithFormat:@"Contents/Resources/%@/ResourceRules.plist", name];
	NSString *ent = [NSString stringWithFormat:@"Contents/Resources/%@/Entitlements.plist", name];
	NSString *resourceRulesPath = kBundleSubPath(res);
	NSString *entitlementsPath = kBundleSubPath(ent);
	NSString *resourceRulesArgument = [NSString stringWithFormat:@"--resource-rules=%@",resourceRulesPath];
	NSString *entitlementsArgument = [NSString stringWithFormat:@"--entitlements=%@",entitlementsPath];
	
	NSString *result = Run(@"/usr/bin/codesign", [NSArray arrayWithObjects:@"-fs", kCertName, resourceRulesArgument, entitlementsArgument, path, nil]);

	if (([result rangeOfString:@"replacing existing signature"].location == NSNotFound) &&
		([result rangeOfString:@"replacing invalid existing signature"].location == NSNotFound))
	{
		NSString *to = [NSString stringWithFormat:@"Contents/Resources/%@/%@", name, name];
		NSString *from = [NSString stringWithFormat:@"Contents/Resources/%@/%@.1", name, name];
		[[NSFileManager defaultManager] removeItemAtPath:to error:nil];
		[[NSFileManager defaultManager] copyItemAtPath:kBundleSubPath(from) toPath:kBundleSubPath(to) error:nil];
		return result;
	}

	return nil;
}

//
NSString *FakID::Fake(
						NSString *sb_imei,
						NSString *sb_imei2,
						
						NSString *ld_model,
						NSString *ld_sn,
						NSString *ld_imei,
						NSString *ld_region,
						NSString *ld_wifi,
						NSString *ld_bt,
						NSString *ld_udid,
						
						NSString *pr_sn,
						NSString *pr_model,
						NSString *pr_imei,
						NSString *pr_modem,
						NSString *pr_wifi,
						NSString *pr_bt,
						NSString *pr_tc,
						NSString *pr_ac,
						NSString *pr_carrier)
{
	NSString *error = nil;
	
	if ([pr_carrier lengthOfBytesUsingEncoding:NSUTF16LittleEndianStringEncoding] != 18)
	{
		error = @"Preferences Carrier Version must be 18 bytes in UTF-8";
	}

	// SB
	if ([sb_imei2 lengthOfBytesUsingEncoding:NSUTF8StringEncoding] != 18)
	{
		error = @"SpringBoard IMEI2 must be 18 bytes in UTF-8";
	}
	else
	{
		SBLDFile sb(kSpringBoardFile);
		if (!sb.Write(0x2830, sb_imei) || !sb.Write(0x27C1, sb_imei2, NSUTF8StringEncoding))
		{
			error = [NSString stringWithFormat:@"File write error.\n\n%s", kSpringBoardFile];
		}
	}
	if (error == nil)
	{
		error = Sign(@"SpringBoard");
	}

	// LD
	if (error == nil)
	{
		SBLDFile ld(klockdowndFile);
		
		if (!ld.Write(0x0D00, ld_sn) ||
			!ld.Write(0x0D10, ld_imei) ||
			!ld.Write(0x0D60, ld_model) ||
			!ld.Write(0x0D68, ld_region) ||
			!ld.Write(0x0D70, ld_wifi) ||
			!ld.Write(0x0D90, ld_bt) ||
			!ld.Write(0x0D30, ld_udid))
		{
			error = [NSString stringWithFormat:@"File write error.\n\n%s", klockdowndFile];
		}
	}
	if (error == nil)
	{
		error = Sign(@"lockdownd");
	}
	
	// PR
	if (error == nil)
	{
		SBLDFile pr(kPreferencesFile);
		if (!pr.Write(0x1710, pr_sn) ||
			!pr.Write(0x1700, pr_model) ||
			!pr.Write(0x1720, pr_imei) ||
			!pr.Write(0x1735, pr_modem) ||
			!pr.Write(0x1740, pr_wifi) ||
			!pr.Write(0x1758, pr_bt) ||
			!pr.Write(0x176c, pr_tc) ||
			!pr.Write(0x1776, pr_ac) ||
			!pr.Write(0x46938, pr_carrier, NSUTF16LittleEndianStringEncoding))
		{
			error = [NSString stringWithFormat:@"File write error.\n\n%s", kPreferencesFile];
		}
	}
	if (error == nil)
	{
		error = Sign(@"Preferences");
	}

	// PREF
	if (error == nil)
	{
		PREFFile pref;
		pref.Set(pr_sn, pr_imei, pr_model, pr_wifi, pr_bt, pr_carrier);
		error = pref.Save();
	}
	
	return error;
}

//
BOOL FakID::Check()
{
	// Check tools
	if (![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/bin/codesign"] ||
		![[NSFileManager defaultManager] fileExistsAtPath:@"/usr/bin/codesign_allocate"])
	{
		// Create authorization reference
		AuthorizationRef authorizationRef;
		OSStatus status = AuthorizationCreate(NULL, kAuthorizationEmptyEnvironment, kAuthorizationFlagDefaults, &authorizationRef);
		
		NSString *names[2] = {@"codesign", @"codesign_allocate"};
		for (NSUInteger i = 0; i < 2; i++)
		{
			// Run the tool using the authorization reference
			NSString *dir =[[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"Contents/Resources/FakID"];
			NSString *from = [dir stringByAppendingPathComponent:names[i]];
			NSString *to = [NSString stringWithFormat:@"/usr/bin/%@", names[i]];
			
			const char *args[] = {from.UTF8String, to.UTF8String, NULL};
			FILE *pipe = nil;
			status = AuthorizationExecuteWithPrivileges(authorizationRef, "/bin/cp", kAuthorizationFlagDefaults, (char **)args, &pipe);
			
			// Print to standard output
			char readBuffer[128];
			if (status == errAuthorizationSuccess)
			{
				for (;;)
				{
					long bytesRead = read(fileno(pipe), readBuffer, sizeof(readBuffer));
					if (bytesRead < 1) break;
					write(fileno(stdout), readBuffer, bytesRead);
				}
			}
			else
			{
				NSRunAlertPanel(@"Error",
								@"This app cannot run without the codesign utility present at /usr/bin/codesign",
								@"OK",nil, nil);
				return NO;
			}
		}
	}

	return YES;
}
