Knock Lambda Builder
====================

This repository hosts the build tooling and starter development tooling
for Knock's serverless apps.

> ***Disclaimer:*** *This is currently an internal Knock tool exclusively as far as we are aware--if you are using it, let us know! Also, if something breaks because of Knock-specific assumptions, issues reports and PRs are more than welcome.*

Installation
------------

To get started, place the `Makefile` in a new project directory like so:

```bash
curl -O https://raw.githubusercontent.com/knockrentals/lambda-builder/master/Makefile
```

### macOS

The BSD flavor of tools present on macOS by default are incompatible with some
of the flags in their GNU counterparts. To resolve this, install the following
packages from homebrew:

```bash
brew install make --with-default-names
brew install findutils --with-default-names
brew install coreutils
brew install gnu-sed --with-default-names
```

Similarly you may need to expose the proper version of `pip` (i.e. 2.x or 3.x):

```bash
ln -s /usr/local/bin/pip3 /usr/local/bin/pip
```

You will also need to update your `~/.bash_profile` or `~/.zprofile` to bring
`coreutils` into your path:

```bash
PATH="/usr/local/opt/coreutils/libexec/gnubin:$PATH"
MANPATH="/usr/local/opt/coreutils/libexec/gnuman:$MANPATH"
```

Then you can run `make help` to get cooking.

### Quick-Start

```bash
# Ensure we have the right commands installed
make check
# Create base project files
make project
# Build project
make build
# Run server
./bin/run/server
# Invoke default server settings starter function
open http://localhost:3000/hello/world
```


Conventions
-----------

Our serverless apps are written with the following assumptions:

- We will be using python 3.6
- We will often be working on multiple related lambdas in tandem
- We will often be using Step Functions to co-ordinate them
- We will normally re-use dependendices between related lambdas
- We will normally be developing locally


### Project Structure

Our typical lambda projects look like this:

```
app
│
├── bin/                        <-- Executable project scripts
│   ├── install/deps            <---- Customize how dependencies are installed
│   └── run
│       ├── endpoint            <---- Runs project locally just like AWS would
│       ├── lambda              <---- Runs single lambda locally
│       ├── server              <---- Runs project with easily-accessible API 
│       └── watcher             <---- Re-builds project when files are changed
│
├── build/                      <-- Build artifacts get placed here
│   └── functions/
│       ├── AppHelloWorld.zip   <---- SAM-ready lambda
│       └── template.yml        <---- SAM-ready CloudFormation configuration
│
├── config/                     <-- CloudFormation configuration templates live here
│   ├── template.yml            <---- Top-level CloudFormation configuration
│   ├── resources.yml           <---- Additional CloudFormation resources
│   └── function.yml            <---- Template for your lambda function configuration
│
├── functions/                  <-- One file per lambda function, each defining a `handler` function
│   ├── hello/world.py          <---- Example function file
│   └── __init__.py             <---- Ensure `import functions` load `lib` directory
│
├── lib/                        <-- Common code here can be included into functions
│   └── api/routes.py           <---- Example lib file
│
├── requirements.txt            <-- Project-wide Python dependencies
├── README.md                   <-- About the project
└── .gitignore                  <-- Avoid checking in .pyc and build/ files
```


Build Commands
--------------

The Makefile provides several build-related commands.

It acts upon organization-wide assumptions about lambda project,
and should not be modified by hand outside of this repository.

It understands the commands:

- `make help`

  Information about make commands. Run this for guidance or further help hints.

- `make check`

  Check to see if Makefile's runtime dependencies are available.

- `make project`

  Ensure conventional project scaffolding exists.

- `make build`

  Build project code into lambda-friendly flat-file artifacts.

- `make clean`

  Remove all build artifacts.


Development Scripts
-------------------

Running `make setup` also installs several development scripts
into the `./bin` folder. These are expected to evolve alongside
the needs of the project, unlike the universal build commands.

They can be invoked by running `./bin/<cmd>`.
For more detail on each command, run `./bin/<cmd> help`.
For ultimate command-line fluency, add `./bin` to your `$PATH`.

- `./bin/install/deps`

  Script for locally building project dependencies in a lambda environment.

- `./bin/run/lambda`

  Execute an individual lambda function locally.

- `./bin/run/server`

  Start a local API Gateway to invoke lambda functions.

- `./bin/run/watcher`

  Auto-build artifacts when project code changes.

- `./bin/run/endpoint`

  Start up local endpoint that mimics production AWS lambda deployments.


Build Process
-------------

Lambdas must be packaged up with all their dependencies, whether executing them
locally or uploading to AWS. This entails some boilerplate that `make build` strives
to abstract away. We use `make` precisely because it is good at efficiently
doing the minimal work neccesary to update build artifacts base on file timestamps.

When you run `make build`:

  - Every lambda function receives a build folder in `build/function/` named after itself
  - Each function file is copied to a `function.py` in its build folder
  - All dependencies are updated and built against a lambda environment to the `build/dependencies` folder
  - All dependencies and `lib/` files are symlinked into every function's personal build folder
  - A CloudFormation template aware of all these locations is written to `build/template.yml`

Of course, `make` ensures only the files that have changed go through this process, reducing build time.
