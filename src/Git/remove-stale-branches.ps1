# Really great article on cleaning up git branches: 
# http://railsware.com/blog/2014/08/11/git-housekeeping-tutorial-clean-up-outdated-branches-in-local-and-remote-repositories/

# But... some of this stuff is so linuxy I cannot read it.
# What I want to be able to do is delete all local branches that are
# merged into my current branch (i.e. dev-v7)
# but also exclude any master-* or dev-* branch names.
# You can do this with those linuxy scripts, or use Powershell :)

# To list all branches that are merged that are not master- or dev-
# you can run this:

git branch --merged |
    ForEach-Object { $_.Trim() } |
    Where-Object {$_ -NotMatch "^\*"} |
    Where-Object {-not ( $_ -Like "master-*" )} |
    Where-Object {-not ( $_ -Like "dev-*" )} |
    ForEach-Object { "branch = $_" }
	
# To delete all of these local branches, you can do:

git branch --merged |
    ForEach-Object { $_.Trim() } |
    Where-Object {$_ -NotMatch "^\*"} |
    Where-Object {-not ( $_ -Like "master-*" )} |
    Where-Object {-not ( $_ -Like "dev-*" )} |
    ForEach-Object { git branch -d $_ }
	
# whoohoo! clean repo :)
