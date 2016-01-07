# <img align="right" src="https://travis-ci.org/bodil/pulp.svg?branch=master"> Pulp

[![Join the chat at https://gitter.im/bodil/pulp](https://badges.gitter.im/Join%20Chat.svg)](https://gitter.im/bodil/pulp?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

A build tool for PureScript.

![Jarvis Cocker dancing](http://24.media.tumblr.com/77b76c557515a801a7e99ca5507b6548/tumblr_n5cx52oT831r4ba6to1_400.gif)

<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->

  - [Installation](#installation)
  - [Getting Started with a Pulp Project](#getting-started-with-a-pulp-project)
    - [What if I need something a bit more complicated?](#what-if-i-need-something-a-bit-more-complicated)
  - [Pulp Commands](#pulp-commands)
    - [Global, Command Specific and Pass-Through Options](#global-command-specific-and-pass-through-options)
      - [Pass-Through Options](#pass-through-options)
  - [Building Projects](#building-projects)
    - [Making a JavaScript Bundle](#making-a-javascript-bundle)
    - [Running Your PureScript Project](#running-your-purescript-project)
    - [Running Test Suites](#running-test-suites)
    - [CommonJS Aware Builds](#commonjs-aware-builds)
      - [Optimising Code Size](#optimising-code-size)
      - [Reimporting Browserified Bundles](#reimporting-browserified-bundles)
    - [Building Documentation](#building-documentation)
    - [Launching a REPL](#launching-a-repl)
    - [Launching a Development Server](#launching-a-development-server)
      - [A Quick Example](#a-quick-example)
      - [I Need More](#i-need-more)
  - [Dependency Management](#dependency-management)
    - [Dependency Management Cheat Sheet](#dependency-management-cheat-sheet)
      - [Installing Dependencies](#installing-dependencies)
      - [Housekeeping](#housekeeping)
    - [Releasing Packages](#releasing-packages)
  - [Licence](#licence)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

## Installation

Assuming you already have [Node](https://nodejs.org/en/download/) set
up (and we recommend you also set up NPM to
[keep your global packages in your home directory](https://github.com/sindresorhus/guides/blob/master/npm-global-without-sudo.md)),
all you need to do to get a working PureScript environment is:

```sh
$ npm install -g purescript pulp bower
```

This installs the PureScript compiler, the Pulp build tool, and the
[Bower](http://bower.io/) package manager.

## Getting Started with a Pulp Project

The short version:

```sh
$ mkdir hello
$ cd hello
$ pulp init
$ pulp run
```

The structure of your project folder, after running `pulp init`, will
look like this:

```
  hello
  - bower.json
  - src/
  - test/
```

`pulp` works by convention. It expects all projects to contain a
`bower.json` file, which is needed for package management (which, in
PureScript, is handled by [Bower](http://bower.io/)). `pulp` itself
currently doesn't use this file for anything other than figuring out
where the project root is.

Your project source files go in the `src` folder. Your test files go
in the `test` folder. Project dependencies will be installed under the
Bower standard `bower_components` folder, and are expected to have the
same basic `src`/`test` structure. That's all there is to a `pulp`
project.

### What if I need something a bit more complicated?

If you want to change any of these defaults, you can—`pulp` offers a
number of command line flags to alter its behaviour—but you really
shouldn't. If you find that your project has more complex requirements
(which can easily happen if you're building web apps, but shouldn't if
you're building tooling or libraries), consider using a PureScript
plugin for a more generic build tool, such as
[gulp-purescript](https://github.com/purescript-contrib/gulp-purescript).

Another, often equally viable, alternative is to just
[use `npm` as your build tool](http://substack.net/task_automation_with_npm_run).
`pulp`'s numerous command line flags make it well suited for this,
though there's still a limit to how complicated you can get using just
`pulp`.

## Pulp Commands

To get a quick overview of the things `pulp` can do, you can ask it to
give you a list of its available commands:

```sh
$ pulp --help
```

This will print a list of `pulp`'s global command line options, and a
list of commands it will accept.

To see the available options for a specific command, you can invoke
the command with the `--help` flag, like this:

```sh
$ pulp build --help
```

This will give you an exhaustive list of ways you can modify the basic
behaviour of the command.

### Global, Command Specific and Pass-Through Options

Notice that there's a distinction between _global_ command line
options and command specific options. Global options must appear
_before_ the name of the command, and command specific options must
appear _after_ it.

Thus, if you want to run the `build` command in watch mode (where it
will run the command once, then wait and re-run the command whenever
you change a source file) you need to put the `--watch` flag _before_
the command itself, like so:

```sh
$ pulp --watch build
```

On the other hand, if you want to tell the build command to produce
optimised code (performing dead code elimination), using the command
specific option `--optimise`, the flag needs to come _after_ the
command name:

```sh
$ pulp build --optimise
```

#### Pass-Through Options

Finally, `pulp` commands sometimes allows you to pass flags through to
the `psc` compiler. Any unrecognised options appearing after any
command specific options will be passed through to the compiler, or
whichever process a `pulp` command spawns. For instance, if you want
to tell `psc` to skip applying tail call optimisations, you would
invoke `pulp build` like this:

```sh
$ pulp build --no-tco
```

The `--no-tco` flag isn't recognised by `pulp`, so it will simply
append it to the `psc` command line for you when it launches the
compiler. Take care, though, that such options should appear _after_
`pulp`'s own command specific options.

## Building Projects

At heart, `pulp` is just a frontend for the PureScript compiler,
`psc`. Its basic function is to compile your project, which you can do
by running `pulp build`. This will simply run `psc` with all your
source files, leaving the compiled JavaScript files in the `output`
folder. These files will all be CommonJS modules, which you can
`require()` using anything which supports CommonJS, such as `node`.

However, you will usually want to do more with your project than just
compile your PureScript code into a jumble of CommonJS modules. `pulp`
provides a number of commands and options for the most common use
cases.

### Making a JavaScript Bundle

`pulp build` can also call `psc-bundle` for you, which is a compiler
tool whose job it is to take the output from `psc`, remove the code
which isn't actually being used by your program, and bundle it all up
into a single compact JavaScript file.

There are two command line options you can give `pulp build` to
accomplish this, depending on where you want the resulting code. You
can use the `--optimise` flag (or its shorthand alias, `-O`), which
will send the bundled result to standard output, or you can use the
`--to` (or `-t`) option, passing it a file name, and `pulp` will store
the bundle in a file of that name.

So, you can use either of these methods, which in this example will
both have the same effect:

```sh
$ pulp build --optimise > hello.js
$ pulp build --to hello.js
```

Note that using both options (`pulp build --optimise --to hello.js`)
is superfluous. The presence of `--to` implies the presence of
`--optimise`.

### Running Your PureScript Project

If you're developing a Node project using PureScript, you can tell
`pulp` to run it after compiling using the `pulp run` command. This
command will first run `pulp build` for you, if necessary, then launch
your compiled code using `node`. If you have used any pass-through
command line options, these will be passed to the `node` process.

So, to run the hello world project you get from `pulp init`, you would
simply:

```sh
$ pulp run
```

If you want to pass command line arguments to your application, `pulp`
lets you do that too:

```sh
$ pulp run file1.txt file2.txt file3.txt
```

Beware, though, that these are processed as pass-through options by
`pulp`, so it will first consume any options it recognises as `pulp
run`'s command specific options; these will not be passed through to
your application.

If you want to run your application using something other than `node`,
`pulp` lets you do that too, with the `--runtime` option. For instance,
if you've written an application which runs on PhantomJS, you might
launch it like this:

```sh
$ pulp run --runtime phantomjs
```

### Running Test Suites

`pulp` has a command `pulp test`, which works much like `pulp run`,
except it will also compile the code you've placed in your `test`
folder, and instead of running the `main` function in your `Main`
module, it will use `Test.Main`. This module should be located in your
`test` folder.

`pulp` doesn't care what test framework you've chosen, as long as
there's a `main` function in your `Test.Main` module to be run. If the
process exits with a non-zero return code, that means your test suite
failed, as far as `pulp` is concerned, and it will itself exit with an
error.

In short, to run your tests:

```sh
$ pulp test
```

To continuously run your tests when you change the source code:

```sh
$ pulp --watch test
```

### Running Commands Before and After an Action

It's sometimes useful to kick off a command before or after an action,
particularly in combination with the `--watch` option above. To do
this, you can use `--before`, or `--then` and `--else` for successful
or failing actions respectively:

```sh
$ pulp --watch --before clear build       # Clears the screen before builds.
$ pulp --watch --then 'say Done' build    # On OS X, announces 'Done' after a successful build.
$ pulp --watch --else 'say Failed' build  # Announces 'Failed' if a build failed.

# A more long-winded example combining the three:
$ pulp --watch --before clear --then "say $(basename `pwd`) succeeded." --else 'say $(basename `pwd`) failed.' build
```


### CommonJS Aware Builds

Often, you'll want to go outside PureScript and leverage some of the
enormous body of JavaScript code available on
[NPM](https://www.npmjs.com/). This is such a common use case that
`pulp` provides a command for it: `pulp browserify`. As the name
suggests, this uses [Browserify](http://browserify.org/) to bundle up
your PureScript code with Node style CommonJS dependencies.

For instance, the majority of web UI libraries for PureScript these
days depend on either
[virtual-dom](https://github.com/Matt-Esch/virtual-dom) or
[React](https://facebook.github.io/react/) as a CommonJS dependency.
Here is how you would add React to your project and build a JS bundle
with React included (assuming your PureScript code `require`s it):

```sh
$ npm install react
$ pulp browserify --to hello.js
```

Essentially, `pulp browserify --to` works exactly like `pulp build
--to`, except it also resolves CommonJS dependencies and includes them
in the bundle. The resulting JS file can now be loaded directly into
the browser, and everything you need to run your application should be
included.

If you omit the `--to` option, the bundle is piped to standard output.
This would thus have the same effect as the example above:

```sh
$ pulp browserify > hello.js
```

#### Optimising Code Size

`pulp browserify` will pull code in at the module level by default, so
every file `require`d from your entry point will appear in the bundle.
The PureScript compiler, as we know, is able to perform dead code
elimination on your compiled PureScript code, and we can leverage this
in `pulp browserify` using the `--optimise` flag.

```sh
$ pulp browserify --optimise --to hello.js
```

Note that, unlike `pulp build`, `--to` doesn't automatically imply
`--optimise`. In fact, if you omit `--optimise`, `pulp browserify`
will not only omit the dead code elimination step, it will also run
Browserify as an incremental build, which means it will run
considerably faster. You should use `--optimise` only when you're
building production code—when you're developing, you'll probably
prefer the much faster compile times provided by Browserify's
incremental mode.

#### Reimporting Browserified Bundles

While browserified bundles are intended to be consumed directly by
browsers, you may sometimes prefer to access the bundle from some
external code. While it's generally preferable to consume CommonJS
modules directly, there are use cases where you might want to provide
a single JS file ready to be `require`d by a consumer without needing
to deal with installing and resolving dependencies. Browserify
provides the `--standalone` mechanism for that, and `pulp browserify`
supports it:

```sh
$ pulp browserify --standalone myBundle --to myBundle.js
```

This makes a bundle which comes wrapped in a UMD header (meaning it
supports both CommonJS and AMD, and will install itself in the global
namespace under the name you provided if neither is present), and the
exports it provides will be the same as those you export in your
`Main` module.

So, given the example above produces a bundle where a PureScript
function `Main.main` exists, you can access it from JavaScript via
CommonJS like this:

```javascript
var myBundle = require("./myBundle");
myBundle.main();
```

### Building Documentation

PureScript has an inline syntax for documentation, which can be
extracted into Markdown files using the `psc-docs` command. `pulp`
provides the `pulp docs` command to make this process easy:

```sh
$ pulp docs
```

This extracts the documentation from your source files, and places it
in the `docs` folder under your project's root folder.

You can also extract documentation from your tests, if you like:

```sh
$ pulp docs --with-tests
```

### Launching a REPL

The `psci` interactive shell for PureScript is fantastically useful,
but setting it up can be a bit of a chore, especially with a large
number of dependencies. That's where `pulp psci` comes in.

`pulp psci` will generate a `.psci` file for your project
automatically whenever you invoke it, and launch `psci` for you
directly. It's as simple as:

```sh
$ pulp psci
```

### Launching a Development Server

While technically out of scope for a build tool like `pulp`, a common
need when developing client side web apps is a tightly integrated
development web server, which takes care of compilation for you on the
fly. This is what the
[purs-loader](https://github.com/ethul/purs-loader) project is for: it
provides a PureScript loader for [Webpack](http://webpack.github.io/),
which works with Webpack's development server and makes recompilation
seamless: whenever you make a change to your source files, you just
switch to your browser and hit the refresh button, and the server will
compile and deliver your assets on the fly. No need to wait for the
PureScript compiler to finish before switching to the browser.

`pulp` provides the `pulp server` command to quickly set up a Webpack
development server for your project. It only provides the most basic
functionality: it will serve static assets from your project root, and
it will serve your compiled JS bundle from `/app.js`.

#### A Quick Example

To see how this works, let's set up a project for serving the default
hello world app through `pulp server`.

```sh
$ mkdir hello-server
$ cd hello-server
$ pulp init
```

We need an `index.html` file to load our compiled PureScript code.
Place this in your new `hello-server` folder:

```html
<!doctype html>
<html>
  <body>
    <h1>Hello sailor!</h1>
    <script src="/app.js"></script>
  </body>
</html>
```

Now, start the server:

```sh
$ pulp server
```

It will tell you that it's launched a web server at
[http://localhost:1337/](http://localhost:1337/), and after a little
while it will tell you that it's finished compiling (`bundle is now
VALID`). If you browse to
[http://localhost:1337/](http://localhost:1337/), you should, in
addition to the "Hello sailor!" header on the webpage, see that your
PureScript code has printed the text "Hello sailor!" to the console.

#### I Need More

As mentioned, this is a very bare bones development server. You're
likely to quickly need more features if you plan on doing any kind of
serious web development. At this point, you'll need to set up your own
Webpack configuration using
[purs-loader](https://github.com/ethul/purs-loader). Due to the way
Webpack works, it's not really useful to extend `pulp server` with
further configuration options. It's intended as a starting point only.

## Dependency Management

`pulp` is not a package manager, only a build tool. The PureScript
community has standardised on [Bower](http://bower.io/) as its package
manager.

Bower expects the presence of a `bower.json` file in your project
root, in which it records your project’s dependencies and other
metadata. `pulp init` will have installed a basic `bower.json` file
for you along with the project skeleton, but you should read the
[Bower documentation on the file format](https://github.com/bower/spec/blob/master/json.md)
and make sure you’ve configured it to your satisfaction before you
publish your package. In particular, mind that you’ve added a
`license` field.

### Dependency Management Cheat Sheet

This document isn't going to explain how Bower works, or go into
details about PureScript dependency management. However, a tl;dr is
often enough to get you started and productive without having to dive
into yet another package management system. It's going to be
especially easy if you're already used to `npm`. So, here we go.

#### Installing Dependencies

To install the `purescript-profunctor` package into your project:

```sh
$ bower install purescript-profunctor
```

To also record this as a dependency in the `bower.json` file:

```sh
$ bower install --save purescript-profunctor
```

To install every dependency which has been recorded in `bower.json` as
needed by your project:

```sh
$ bower install
```

#### Housekeeping

To remove an installed package:

```sh
$ bower rm purescript-profunctor
```

To remove it from `bower.json` as well:

```sh
$ bower rm --save purescript-profunctor
```

To list all packages installed in your project:

```sh
$ bower ls
```

To update all installed packages to the most recent version allowed by
`bower.json`:

```sh
$ bower update
```

### Releasing Packages

Bower packages are installed directly from Git repositories, and
versioning follows Git tags. Imagine you've created a new PureScript
library for working with zygohistomorphic prepromorphisms (because who
doesn't need zygohistomorphic prepromorphisms); this is how you would
register your new package in the Bower registry (we'll call the
package `purescript-zygo` to save typing):

```sh
$ bower register purescript-zygo git://github.com/me/purescript-zygo.git
```

Note the convention of prefixing PureScript package names with
`purescript-`. Please stick with that unless you have an especially
good reason not to, as `pulp` and many other tools expect installed
dependencies to follow this convention.

Once you're registered, all you need to do to make a new release
version is to make a Git tag. Bower provides a command for doing this
easily:

```sh
$ bower version patch
```

This will take your current version (as determined by the most recent
tag in your repository), increment the patch number by one, and make a
tagged Git commit for you recording the new version. All you need to
do to publish the new release is:

```sh
$ git push && git push --tags
```

The `patch` argument to `bower version` can be substituted with
`minor` or `major`, depending on what sort of release you want to
make.

## Licence

Copyright 2014 Bodil Stokke

This program is free software: you can redistribute it and/or modify
it under the terms of the GNU Lesser General Public License as
published by the Free Software Foundation, either version 3 of the
License, or (at your option) any later version.

See the [LICENSE](LICENSE.md) file for further details.
