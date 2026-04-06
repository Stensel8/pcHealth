# pcHealth

Check the health of your Windows installation and much more!

![GitHub](https://img.shields.io/github/license/REALSDEALS/pcHealth?label=License) ![GitHub release (latest SemVer)](https://img.shields.io/github/v/release/REALSDEALS/pcHealth?label=Release) ![GitHub release (latest SemVer including pre-releases)](https://img.shields.io/github/v/release/REALSDEALS/pcHealth?include_prereleases&label=Release) ![GitHub Repo Size](https://img.shields.io/github/repo-size/REALSDEALS/pcHealth?label=Repo%20Size)

## Supported Versions

| Platform   | Latest Supported Build | Status |
|------------|------------------------|--------|
| Windows 10 | 22H2                   | ![Maintenance](https://img.shields.io/badge/status-no%20longer%20maintained-red) These scripts are no longer actively maintained. Be aware of this when using or running them. |
| Windows 11 | 25H2                   | ![Active](https://img.shields.io/badge/status-active-brightgreen) These scripts target the current stable branch of Windows 11. |

## What is the main purpose of pcHealth?

The main purpose of pcHealth is to assist users working in IT to quickly check and repair Windows systems. It covers system scans, hardware info, network tools, key grabbing, and common program downloads — all from a single interface.

## How to use?

If you have any tips/tricks or remarks, feel free to contact me on Discord: **REALSDEALS**.

### Windows 10 (CMD/batch — legacy, no longer maintained):
- Download this repository and extract it.
- Open the `Windows 10/CLI` folder and run `pcHealth.bat` as administrator.
- Enter the number of the desired command and press ENTER.

### Windows 11 (PowerShell — actively maintained):
- Open the `Windows 11/CLI` folder.
- Right-click the desired `.ps1` script and select *Run with PowerShell* (as administrator).
- Or run directly from an elevated PowerShell terminal.

### For users that are not that known about what everything may or may not do...

## Tools Menu:
The entries that you may enter in this menu will execute some standard line of code.
So keep in mind that the .exe (this script) needs to be in administrator mode, it will prompt you when you open the program.

You have my promise, that I won't do anything malicious to your pc.
But I can only keep that promise if you are sure to have downloaded pcHealth.bat from my repo: https://github.com/REALSDEALS/pcHealth 
Otherwise I can keep no promise to that statement.

1. Gather generic information about the system.
2. Show CPU, GPU and RAM information.
3. Run a scan for corrupt and/or missing files. (Windows ISO/DISM related)
4. When option 3. can't repair the corrupt/missing files, you can try this option. (DISM)
5. Option 3. and 4. combined. (Puts both commands behind eachother)
6. Generate a battery report. (To see how your laptop battery is doing)
7. Shortcut to Windows Update.
8. Open a menu regarding disk optimization, this is a standard Windows function.
9. Opens and starts a disk clean program, this is a standard Windows function.
10. Short ping test. (Do I have internet?)
11. Continues ping test. (Does my internet stop at certain times?)
12. Starts the function 'TRACERT' and traces how many hops your system has to make before establishing an connection with the host. (Google)
13. Fetches updates for system programs, updates them too if needed.
14. Fetches updates for HP software and hardware, by running the HPIA tool. This tool will only work on HPE devices, such as ProBooks, EliteBooks, ZBooks, etc. The source URL is hpia.hpcloud.hp.com. View full list of hardware supported by HPIA: https://ftp.ext.hp.com/pub/caps-softpaq/cmit/imagepal/ref/platformList.html
14. Re-enables the drivers, it restarts the audio drivers. (Having issues with sound?)
15. Re-open the battery report. (Can't find my generated report anymore? Try opening it this way)
16. Re-open the CBS.log (DISM log, report from option 4.) 
17. Get your Ninite! (Standard program downloader/updater; Chrome, Edge, VLC and 7Zip)
18. Check your Windows License Key.
19. BIOS password recovery.
20. Shutdown, reboot and/or logout from the system.
21. Open the other menu, it's called 'Programs'.
22. Returning to the previous menu, main-menu.
23. Close the script.


## Programs menu:
The entries that you may put in here will redirect you to the download page of the program.
This is a combination of winget packages and direct download links, since not all programs are available in winget.

While I understand that some of you may have questions about this decision, my goal was to simplify the process for you. You’re welcome to review the source code at any time to see exactly how it works. Additionally, if you prefer to download your software manually, that option is always available.

1. Hardware Info - This program will check which hardware is in your PC.
2. HWMonitor - This program will check the temperature of your hardware.
3. ADW Cleaner - This program will scan for malicious software (adware, malware, spyware).
4. CrystalDiskInfo - This program will check information about your HDD/SDD (serial etc.)
5. CrystalDiskMark - This program will test your HDD/SDD on possible malfunctions.
6. Prime95 - This program will stress test your CPU. Useful for overclocking and performance tests.
7. Windows PowerToys - Makes configuration in- and around Windows a tad easier. Adds some new features to your Windows.
8. Open the other menu, it's called 'Tools'.
9. Return to the previous menu. 
10. Close the script.

## KeyGrabber
The key grabber script does what it says!

It grabs the license key (windows) that's on your pc, and gives you an option to save it to your desktop.

## Questions
If you still have questions, you can send me a message on Discord as mentioned above.
My username is: **REALSDEALS**.

There is also a possibility to e-mail me, if that's what you desire (check my GitHub profile for that).

