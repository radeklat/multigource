# multigource

Script for generating video visualisation of git commit history by [gource], from multiple repositories. 

# Usage

1. Install [gource] and [ffmpeg].
1. Create a directory with all git repositories you want to visualise.
1. Copy `multigource.sh` into the same directory.
1. Run `multigource.sh` as:

        bash multigource.sh
    
   to use all repositories or:
   
        bash multigource.sh <repo1> ... <repoN>
        
   for one or more specific repositories (don't need to be in the same directory).
1. Both [gource] and [ffmpeg] have many options. Edit the `multigource.sh` to change the look and feel of the generated video, if you don't like the defaults.

# Features

* By default, generates each repository as top level node with a name, the rest of file names hidden.
* Allows easy merging/renaming of committers and repositories.
* Asks you for resolution (default is 1920x1080).
* Optionally fetches and pulls all repositories.

[gource]: https://gource.io/
[ffmpeg]: https://www.ffmpeg.org/ 