# gits
A simple Dart CLI tool to run your own Git server and perform basic Git operations.

# Note
This is a repository hosted on a newer Gitserver build and mirrored on github.

# Features
clone – clone remote repositories
commit – create commits
push – push changes
publish – start a local Git server

# Requirements
Dart SDK ≥ 3.8.2
Installation
## Clone this repo and go inside:
git clone <your-repo-URL>
cd gits
## Build the executable:
Bash
Run
sh build.sh
This will produce git_server in the project root.
Usage
Bash
Run
./git_server <command> [options]
Examples:

Clone a repo:
./git_server clone http://url/user/repo.git

Commit changes:
./git_server commit --path ./repo --message "New feature"

Push to remote:
./git_server push --remote origin --branch main

Start server on port 8080:
./git_server publish --port 8080
