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
	Counting objects: 65, done.
	Delta compression using up to 4 threads.
	Compressing objects: 100% (40/40), done.
	Writing objects: 100% (65/65), 15.95 KiB, done.
	Total 65 (delta 19), reused 61 (delta 18)
	       Python app detected
	-----> No runtime.txt provided; assuming python-2.7.4.
	-----> Preparing Python runtime (python-2.7.4)

Once your application has been deployed, use `deis open` to view it in a browser. To find out more info about your application, use `deis info`.

## Scale your Application

To scale your application's [Docker](http://docker.io) containers, use `deis scale` and specify the number of containers for each process type defined in your application's `Procfile`. For example, `deis scale web=8`.

	$ deis scale web=8
	Scaling containers... but first, coffee!
	done in 16s
	
	=== <appName> Containers
	
	--- web: `gunicorn -b 0.0.0.0:$PORT app:app`
	web.1 up 2013-10-25T20:00:11.741Z (pythonFormation-runtime-1)
	web.2 up 2013-10-25T20:04:37.133Z (pythonFormation-runtime-1)
	web.3 up 2013-10-25T20:04:37.148Z (pythonFormation-runtime-1)
	web.4 up 2013-10-25T20:04:37.162Z (pythonFormation-runtime-1)
	web.5 up 2013-10-25T20:04:37.177Z (pythonFormation-runtime-1)
	web.6 up 2013-10-25T20:04:37.194Z (pythonFormation-runtime-1)
	web.7 up 2013-10-25T20:04:37.212Z (pythonFormation-runtime-1)
	web.8 up 2013-10-25T20:04:37.231Z (pythonFormation-runtime-1)


## Configure your Application

Deis applications are configured using environment variables. The example application includes a special `POWERED_BY` variable to help demonstrate how you would provide application-level configuration. 

	$ curl -s http://yourapp.yourformation.com
	Powered by Deis
	$ deis config:set POWERED_BY=Python
	=== <appName>
	POWERED_BY: Python
	$ curl -s http://yourapp.yourformation.com
	Powered by Python

`deis config:set` is also how you connect your application to backing services like databases, queues and caches. You can use `deis run` to execute one-off commands against your application for things like database administration, initial application setup and inspecting your container environment.

	$ deis run ls -la
	total 56
	drwxr-xr-x  4 root root 4096 Oct 25 20:03 .
	drwxr-xr-x 57 root root 4096 Oct 25 20:05 ..
	-rw-r--r--  1 root root  237 Oct 25 19:59 .gitignore
	drwxr-xr-x  3 root root 4096 Oct 25 19:59 .heroku
	drwxr-xr-x  2 root root 4096 Oct 25 19:59 .profile.d
	-rw-r--r--  1 root root   18 Oct 25 19:59 .release
	-rw-r--r--  1 root root  553 Oct 25 19:59 LICENSE
	-rw-r--r--  1 root root   39 Oct 25 19:59 Procfile
	-rw-r--r--  1 root root 7829 Oct 25 19:59 README.md
	-rw-r--r--  1 root root  330 Oct 25 19:59 app.py
	-rw-r--r--  1 root root  602 Oct 25 20:03 app.pyc
	-rw-r--r--  1 root root   40 Oct 25 19:59 requirements.txt
	-rw-r--r--  1 root root   13 Oct 25 19:59 runtime.txt

## Troubleshoot your Application

To view your application's log output, including any errors or stack traces, use `deis logs`.

    $ deis logs
    <show output>

## Additional Resources

* [Get Deis](http://deis.io/get-deis/)
* [GitHub Project](https://github.com/opdemand/deis)
* [Documentation](http://docs.deis.io/)
* [Blog](http://deis.io/blog/)
