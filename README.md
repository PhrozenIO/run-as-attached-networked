# RunAsAttached (Networked) - 32bit / 64bit

RunAsAttached is a program to run a console as another user and keep new console attached to caller console. Support reverse shell mode (Ex: Netcat)

## Demo video (Click on bellow image)

[![Alt text](http://i3.ytimg.com/vi/nT8ub6Q1R0c/maxresdefault.jpg)](https://www.youtube.com/watch?v=nT8ub6Q1R0c)

## Changelogs

### 18/05/2020

- First release

### 20/05/2020

- Major bug fixed when using Netcat / Telnet etc..
- Stability improved

## Description

Unlike on UNIX based systems, on Microsoft Windows you can't run command as another user without spawning a new process then a new console window.

This is quite annoying while doing Penetration Testing but not only!

This application is a "hack" to run a new console attached to callers console. This is one method to achieve that goal.

This method is using Client / Server architecture to communicate between two processes. By default it will create a local server (listening on localhost and random port above 50 000) but you can decided to connect back to another address/port (Ex: a Netcat listener)

## Notes

It is a beta release, it is working fine, but many things requires some optimization including:

* Networking: This is the first technique that comes to my mind for different reasons, I will dig more about a better way. The main issue encoutered is related to disconnection. If remote conection is unexpectly (dirty) closed, it may not know about that, this is mainly because of the way I designed how I handled both Stdout/Stderr and Networking. I have some good ideas to solve that issue. It is still considered as minor, could be annoying tho.

* Argument Parsing: I will enhance the clarity of that part. 

## What you will learn

Even if you don't find useful this program, you may find some interesting piece of codes:

- Winsock2 Programming
- Global Mutex (Cross Users)
- Threading
- Windows API
- Pipes
