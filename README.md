#Duplicate File Remover & Lister

Usage:
`
  duplicate_remover.pl  [ --list | --listduplicate| --remove ] [ Options ]
	--help                  Display this help message
	--list                  List all the files with hashes
	--listduplicates        List only duplicated files
	--dir "directory"       The directory where the execution will take place
	--remove                Remove duplicates (keeps the first file found)
	--recursive             If the search is recursive or not
	--blacklist "file"      A file containing regex of ignored files
`

Example:

`
perl duplicate_remover.pl --listduplicates -d test_dir --blacklist blacklist --recursive 
`
![output example](https://github.com/venam/duplicate-remover/raw/master/example.png)


