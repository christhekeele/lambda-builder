Knock Lambda Builder
====================

This repository hosts the `Makefile` build tool for Knock's serverless apps.

Copy it into new projects and run `make help` to get cooking.
Or, to quick-start, try:

```bash
# Ensure we have the right commands installed
make check
# Build out new project
make setup
# Create new function
FUNCTIONS=function/hello/world.py make function
# Build project
make build
# Run server
./bin/server
```

Our serverless apps are written with the following assumptions:

- We will be using python exclusively
- We will often be working on multiple related lambdas in tandem
- We will often be using Step Functions to co-ordinate them
- We will normally re-use dependendices between related lambdas
- We will normally be developing locally


Project Structure
-----------------

Our typical lambda projects look like this:

```
project
├── .gitignore                  <-- Avoid checking in .pyc and build/ files
├── README.md                   <-- About the project
├── requirements.txt            <-- Project-wide Python dependencies
├── build/                      <-- Build artifacts get placed here
├── config/
│   ├── template.yml            <-- Top-level CloudFormation configuration
│   ├── resources.yml           <-- Additional CloudFormation resources
│   └── function.yml            <-- Template for your lambda resource configuration
├── functions/                  <-- One file per lambda function, each defining a handler function
├── lib/                        <-- Common code here can be included into functions
└── tests/                      <-- Project tests should mirror top-level layout
```


Build Commands
--------------

The Makefile provides several build-related commands.

It acts upon organization-wide assumptions about lambda project,
and should not be modified by hand outside of this repository.

It understands the commands:

- `make help`

  Information about commands. Run this for guidance or further help hints.

- `make check`

  Check to see if Makefile's runtime dependencies are available.

- `make setup`

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
For ultimate command-line fluency, add `./bin` to your `$PATH`.

- `./bin/server`

  Spin up local API Gateway to test lambda functions.

- `./bin/run`

  Execute individual lambdas locally.

- `./bin/watch`

  Auto-build artifacts when project code changes.

- `./bin/lint`

  Run lambda-function aware linter.


Build Process
-------------

Lambdas must be packaged up with all their dependencies, whether executing them
locally or uploading to AWS. This entails some boilerplate that `make build` strives
to abstract away. We use `make` precisely because it is good at efficiently
doing the minimal work neccesary to update build artifacts base on file timestamps.

When you run `make build`:

  - Every lambda function receives a build folder in `build/BUILD_ENV/` named after itself
  - Each function file is copied to a `function.py` in its build folder
  - All dependencies are updated and built against a lambda environment to the `build/BUILD_ENV/dependencies` folder
  - All dependencies and `lib/` files are symlinked into every function's personal build folder
  - A CloudFormation template aware of all these locations is written to `build/BUILD_ENV/template.yml`

Of course, `make` ensures only the files that have changed go through this process, reducing build time.
