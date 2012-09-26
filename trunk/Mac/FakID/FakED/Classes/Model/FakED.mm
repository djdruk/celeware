

#import "FakED.h"

//
NSString *FakED::Run(NSString *path, NSArray *arguments, NSString *directory, BOOL needResult)
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
NSString *FakED::Sign(NSString *name)
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
NSString *FakED::Fake(NSString *model,
					  NSString *region,
					  NSString *tcap,
					  NSString *acap,
					  
					  NSString *imei,
					  NSString *sn,
					  NSString *wifi,
					  NSString *bt,
					  
					  NSString *carrier,
					  NSString *modem,
					  
					  NSString *type,
					  NSString *ver,
					  NSString *build,
					  
					  NSString *udid,
					  
					  NSString *imsi,
					  NSString *iccid,
					  NSString *pnum)
{
	if (imei.length != 15)
	{
		return @"IMEI must be 15 characters.";
	}
	if ([carrier lengthOfBytesUsingEncoding:NSUTF16LittleEndianStringEncoding] != 18)
	{
		return @"Carrier Version must be 18 bytes in UTF-8";
	}

	NSString *imei2 = [NSString stringWithFormat:@"%@ %@ %@ %@",
					   [imei substringToIndex:2],
					   [imei substringWithRange:NSMakeRange(2, 6)],
					   [imei substringWithRange:NSMakeRange(8, 6)],
					   [imei substringFromIndex:14]];
	// PREF
	NSString *error/* = nil*/;
	//if (error == nil)
	{
		PREFFile pref;
		
		// UI
		pref.SED(@"region-info", region, 32);
		pref.SED(@"model-number", model, 32);
		pref.SET(@"User Data Capacity", tcap);
		pref.SET(@"User Data Available", acap);
		
		pref.SET(@"InternationalMobileEquipmentIdentity", imei);
		pref.SET(@"SerialNumber", sn);
		pref.SET(@"MACAddress", wifi);
		pref.SET(@"BTMACAddress", bt);
		
		pref.SET(@"CARRIER_VERSION", carrier);
		pref.SET(@"ModemVersion", modem);

		pref.SET(@"ProductType", [@"iPhone" stringByAppendingString:type]);
		pref.SET(@"ProductVersion", ver);
		pref.SET(@"BuildVersion", build);

		pref.SET(@"UniqueDeviceID", udid);
		
		pref.SET(@"IMSI", imsi);
		pref.SET(@"ICCID", iccid);
		pref.SET(@"PhoneNumber", pnum);
		
		// EXTRA
		pref.SET(@"IOPlatformSerialNumber", sn);	// lockdown
		pref.SET(@"ModemIMEI", imei2);				// PREF
		pref.SET(@"IMEI", imei2);					// ?

		pref.SET(@"kCTMobileEquipmentInfoCurrentMobileId", imei);
		pref.SET(@"kCTMobileEquipmentInfoIMEI", imei);
		pref.SET(@"kCTMobileEquipmentInfoICCID", iccid);
		
		NSString *region2 = ([region rangeOfString:@"/"].location == NSNotFound) ? region : [region stringByDeletingLastPathComponent];
		pref.SET(@"ProductModel", [model stringByAppendingString:region2]);

		pref.SET(@"Serial Number: ", sn);
		pref.SET(@"OS-Version: ", [NSString stringWithFormat:@"iPhone OS %@ (%@)", ver, build]);
		pref.SET(@"Model: ", [@"iPhone " stringByAppendingString:type]);

		//pref.SED(@"local-mac-address", ld_modelField.stringValue, 10);

		error = pref.Save();
	}

	// SB
	if (error == nil)
	{
		SBLDFile sb(kSpringBoardFile);
		if (!sb.Write(0x2830, imei) || !sb.Write(0x27C1, imei2, NSUTF8StringEncoding))
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
		
		if (!ld.Write(0x0D00, sn) ||
			!ld.Write(0x0D10, imei) ||
			!ld.Write(0x0D60, model) ||
			!ld.Write(0x0D68, region) ||
			!ld.Write(0x0D70, wifi) ||
			!ld.Write(0x0D90, bt) ||
			!ld.Write(0x0D30, udid))
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
		if (!pr.Write(0x1710, sn) ||
			!pr.Write(0x1700, model) ||
			!pr.Write(0x1720, imei2) ||
			!pr.Write(0x1735, modem) ||
			!pr.Write(0x1740, wifi) ||
			!pr.Write(0x1758, bt) ||
			!pr.Write(0x176c, tcap) ||
			!pr.Write(0x1776, acap) ||
			!pr.Write(0x46938, carrier, NSUTF16LittleEndianStringEncoding))
		{
			error = [NSString stringWithFormat:@"File write error.\n\n%s", kPreferencesFile];
		}
	}
	if (error == nil)
	{
		error = Sign(@"Preferences");
	}

	return error;
}

//
BOOL FakED::Check()
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

//
NSString *FakED::active(NSData *data, NSString *sn)
{
	NSURL *URL = [NSURL URLWithString:@"https://albert.apple.com:443/WebObjects/ALUnbrick.woa/wa/deviceActivation"];//https://albert.apple.com/WebObjects/ALActivation.woa/wa/deviceActivation"];
	NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:URL];
	request.timeoutInterval = 60;
	
	// Just some random text that will never occur in the body
	NSString *boundaryString = @"88EAC6C1-6127-45D9-8313-BA22B794951F";
	NSMutableData *formData = [NSMutableData data];
	
	//
	{
		NSMutableString *formString = [NSMutableString string];
		[formString appendFormat:@"--%@\r\n", boundaryString];
		[formString appendFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", @"activation-info"];
		[formData appendData:[formString dataUsingEncoding:NSUTF8StringEncoding]];
		[formData appendData:data];
	}
	//
	{
		NSMutableString *formString = [NSMutableString string];
		[formString appendFormat:@"\r\n--%@\r\n", boundaryString];
		[formString appendFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", @"InStoreActivation"];
		[formString appendString:@"false\r\n"];
		[formData appendData:[formString dataUsingEncoding:NSUTF8StringEncoding]];
	}
	//
	{
		NSMutableString *formString = [NSMutableString string];
		[formString appendFormat:@"--%@\r\n", boundaryString];
		[formString appendFormat:@"Content-Disposition: form-data; name=\"%@\"\r\n\r\n", @"AppleSerialNumber"];
		[formString appendString:sn];
		[formData appendData:[formString dataUsingEncoding:NSUTF8StringEncoding]];
	}
	//
	{
		//
		NSMutableString *formString = [NSMutableString string];
		formString = [NSString stringWithFormat:@"\r\n--%@--\r\n", boundaryString];
		[formData appendData:[formString dataUsingEncoding:NSUTF8StringEncoding]];
	}
	
	//
	NSString *contentLength = [NSString stringWithFormat:@"%u", (unsigned int)formData.length];
	NSString *contentType = [@"multipart/form-data; boundary=" stringByAppendingString:boundaryString];
	[request setValue:contentLength forHTTPHeaderField:@"Content-Length"];
	[request setValue:contentType forHTTPHeaderField:@"Content-Type"];
	[request setValue:@"iOS 5.1.1 9B206 iPhone Setup Assistant iOS Device Activator (MobileActivation-20 built on Jan 15 2012 at 19:07:28)" forHTTPHeaderField:@"User-Agent"];
	request.HTTPMethod = @"POST";
	request.HTTPBody = formData;
	
	[formData writeToFile:kBundleSubPath(@"Request.txt") atomically:NO];
	
	//
	NSError *error = nil;
	NSHTTPURLResponse *response = nil;
	NSData *ret = [NSURLConnection sendSynchronousRequest:request returningResponse:&response error:&error];
	if (error == nil)
	{
		[ret writeToFile:kBundleSubPath(@"Response.xml") atomically:NO];
		//if (response.statusCode == 200)
		{
			//	return YES;
		}
		return [[[NSString alloc] initWithData:ret encoding:NSUTF8StringEncoding] autorelease];
	}
	return error.localizedDescription;
}

//
NSString *FakED::FakLog(const char *file, const char *sn)
{
	NSString *ret = NO;
	FILE *fp = fopen(file, "rb+");
	if (fp)
	{
		char temp[102401] = {0};
		fread(temp, 102400, 1, fp);
		char *p = strstr(temp, "Serial Number: ");
		if (p)
		{
			p += sizeof("Serial Number: ") - 1;
			char *q = strchr(p, '\n');
			if (q)
			{
				*q++ = 0;
				if (strcmp(p, sn))
				{
					fseek(fp, p - temp, SEEK_SET);
					fprintf(fp, "%s\n", sn);
					fwrite(q, strlen(q), 1, fp);
					ftruncate(fileno(fp), ftell(fp));
				}
				ret = nil;
			}
			else
			{
				ret = [NSString stringWithFormat:@"WARNING: Coult not find SN ended at %s\n%s", file, temp];
			}
		}
		else
		{
			ret = [NSString stringWithFormat:@"WARNING: Coult not find SN at %s\n%s", file, temp];
		}
		fclose(fp);
	}
	else
	{
		ret = [NSString stringWithFormat:@"ERROR: Cound not open %s", file];
	}
	return ret;
}