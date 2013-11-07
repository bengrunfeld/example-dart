# Dart Quick Start Guide

This guide will walk you through deploying a Dart application on Deis.

## Prerequisites

* A [User Account](http://docs.deis.io/en/latest/client/register/) on a [Deis Controller](http://docs.deis.io/en/latest/terms/controller/).
* A [Deis Formation](http://docs.deis.io/en/latest/gettingstarted/concepts/#formations) that is ready to host applications

If you do not yet have a controller or a Deis formation, please review the [Deis installation](http://docs.deis.io/en/latest/gettingstarted/installation/) instructions.

## Setup your workstation

* Install [RubyGems](http://rubygems.org/pages/download) to get the `gem` command on your workstation
* Install [Foreman](http://ddollar.github.com/foreman/) with `gem install foreman`
* Copy the [Dart SDK](https://www.dartlang.org/tools/sdk/) into your root directory

## Clone your Application

If you want to use an existing application, no problem.  You can also use the Deis sample application located at <https://github.com/bengrunfeld/example-dart>.  Clone the example application to your local workstation:

    $ git clone https://github.com/opdemand/example-dart.git
    $ cd example-dart

## Prepare your Application

To use a Dart application with Deis, you will need to conform to 3 basic requirements:

 1. Use [Pub](http://pub.dartlang.org/doc/) to manage dependencies
 2. Use [Foreman](http://ddollar.github.com/foreman/) to manage processes
 3. Use [Environment Variables](https://help.ubuntu.com/community/EnvironmentVariables) to manage configuration inside your application

If you're deploying the example application, it already conforms to these requirements.

#### 1. Use Pub to manage dependencies

Pub requires that you explicitly declare your dependencies using a [pubspec.yaml](http://pub.dartlang.org/doc/) file. Here is a very basic example:

	name: dart_on_deis_demo
	dependencies:
	  http_server: any
	  route: any
	  path: any

Then run `pub install` to download the packages you need. Remember, if you are on a unix-based system, `pub` needs to be in your `$PATH`, so you may need to use:

	export PATH=$PATH:<path to sdk>/bin

#### 2. Use Foreman to manage processes

Deis relies on a [Foreman](http://ddollar.github.com/foreman/) `Procfile` that lives in the root of your repository.  This is where you define the command(s) used to run your application.  Here is an example `Procfile`:

	web: ./dart-sdk/bin/dart bin/main.dart

This tells Deis to run `web` workers using the command `./dart-sdk/bin/dart bin/main.dart`. You can test this locally by running `foreman start`.

	(venv)$ foreman start
	11:32:33 web.1  | started with pid 603
	11:32:33 web.1  | Server started on port: 5000

You should now be able to access your application locally at <http://localhost:5000>.

If you are running into permissions issues with forman, e.g. `Permission Denied`, you may need to `chmod 764` the directory or file that is causing problems.

#### 3. Use Environment Variables to manage configuration

Deis uses environment variables to manage your application's configuration. For example, your application listener must use the value of the `PORT` environment variable. The following code snippet demonstrates how this can work inside your application:

    String portEnv = Platform.environment['PORT'];

## Create a new Application

Per the prerequisites, we assume you have access to an existing Deis formation. If not, please review the Deis [installation instuctions](http://docs.deis.io/en/latest/gettingstarted/installation/).

Use the following command to create an application on an existing Deis formation.

    $ deis create --formation=<formationName> --id=<appName>
	Creating application... done, created <appName>
	Git remote deis added
    
If an ID is not provided, one will be auto-generated for you.

## Deploy your Application

Use `git push deis master` to deploy your application.

	$ git push deis master
	Counting objects: 491, done.
	Delta compression using up to 4 threads.
	Compressing objects: 100% (461/461), done.
	Writing objects: 100% (491/491), 9.31 MiB | 90 KiB/s, done.
	Total 491 (delta 28), reused 0 (delta 0)
	       Dart app detected
	-----> Welcome, this machine is: Linux e3a4efec79da 3.8.0-32-generic #47~precise1-Ubuntu SMP Wed Oct 2 16:19:35 UTC 2013 x86_64 x86_64 x86_64 GNU/Linux

Once your application has been deployed, use `deis open` to view it in a browser. To find out more info about your application, use `deis info`.

## Scale your Application

To scale your application's [Docker](http://docker.io) containers, use `deis scale` and specify the number of containers for each process type defined in your application's `Procfile`. For example, `deis scale web=8`.

	$ deis scale web=8
	Scaling containers... but first, coffee!
	done in 16s
	
	=== <appName> Containers
	
	--- web: `./dart-sdk/bin/dart bin/main.dart`
	web.1 up 2013-11-04T23:16:59.022Z (dev-runtime-1)
	web.2 up 2013-11-04T23:19:35.053Z (dev-runtime-1)
	web.3 up 2013-11-04T23:19:35.068Z (dev-runtime-1)
	web.4 up 2013-11-04T23:19:35.083Z (dev-runtime-1)
	web.5 up 2013-11-04T23:19:35.099Z (dev-runtime-1)
	web.6 up 2013-11-04T23:19:35.116Z (dev-runtime-1)
	web.7 up 2013-11-04T23:19:35.135Z (dev-runtime-1)
	web.8 up 2013-11-04T23:19:35.155Z (dev-runtime-1)


## Configure your Application

Deis applications are configured using environment variables. The example application includes a special `POWERED_BY` variable to help demonstrate how you would provide application-level configuration. 

	$ curl -s http://yourapp.yourformation.com
	Powered by Deis
	$ deis config:set POWERED_BY=Dart
	=== <appName>
	POWERED_BY: Dart
	$ curl -s http://yourapp.yourformation.com
	Powered by Dart

`deis config:set` is also how you connect your application to backing services like databases, queues and caches. You can use `deis run` to execute one-off commands against your application for things like database administration, initial application setup and inspecting your container environment.

	$ deis run ls -la
	total 56
	drwxr-xr-x  7 root root 4096 Nov  4 23:16 .
	drwxr-xr-x 57 root root 4096 Nov  4 23:19 ..
	-rw-r--r--  1 root root   41 Nov  4 23:16 .gitignore
	drwxr-xr-x  2 root root 4096 Nov  4 23:16 .profile.d
	-rw-r--r--  1 root root   63 Nov  4 23:16 .release
	-rw-r--r--  1 root root   39 Nov  4 23:16 Procfile
	-rw-r--r--  1 root root 7109 Nov  4 23:16 README.md
	drwxr-xr-x  2 root root 4096 Nov  4 23:16 bin
	drwxr-xr-x  6 root root 4096 Nov  4 23:16 dart-sdk
	drwxr-xr-x  2 root root 4096 Nov  4 23:16 packages
	-rw-r--r--  1 root root  714 Nov  4 23:16 pubspec.lock
	-rw-r--r--  1 root root   81 Nov  4 23:16 pubspec.yaml
	drwxr-xr-x  3 root root 4096 Nov  4 23:16 tmp

## Troubleshoot your Application

To view your application's log output, including any errors or stack traces, use `deis logs`.

    $ deis logs
	Nov  4 23:17:12 ip-172-31-3-111 breezy-aqualung[web.1]: import 'package:http_server/http_server.dart';
	Nov  4 23:17:12 ip-172-31-3-111 breezy-aqualung[web.1]: 

## Additional Resources

* [Get Deis](http://deis.io/get-deis/)
* [GitHub Project](https://github.com/opdemand/deis)
* [Documentation](http://docs.deis.io/)
* [Blog](http://deis.io/blog/)
