# Git-Hunter

A tool to monitor possible key-leaks on Github, made by Ruby.

## Introduction

If you come from a company or an organization, and you are headache about your employee uploading some sensitive code to their own GitHub, e.g. AWS keys, DB password, company project code, you are in the right place. Git-Hunter is aimed to establish a monitor system to inform you at the first time once those bad things happen. 

![Git-Hunter](example1.png)

## Installation

Of course, you need a [Ruby](https://www.ruby-lang.org/en/documentation/installation/).

Also, you need a bundle installed. After installing Ruby:

```shell
$ gem install bundle
```

Then:

```shell
$ bundle install
```



## Usage

Git-Hunter main functions: 

#### 1. Monitor Specified Github users.

First:

```shell
$ cp user_list.txt.example user_list.txt
$ cp config.rb.example config.rb
$ vim user_list.txt
```

and add some Github users you wish to be monitored, one line each, for example:

```shell
# user_list.txt
Interfish superman # 1st column is Github username, 2nd column is nickname(optional)
https://github.com/rails batman # link is also supported
octocat # no nickname? fine
```

What's nickname? If you wish to set relation between GitHub user and some name in your company's personnel system, e.g. employee's real name, employee's job number, it could be convenient. No nickname is totally fine.  Just leave it blank. 



Then you may like to add some self-defined config. **Git-Hunter will try to find two things in repos - sensitive words and possible key-leaks**, and they are all in `config.rb`. 

Config for key-leaks is in `KEY_WORDS` and it's common to all users , so you don't need to change it at the first time. 

`SENSITIVE_WORDS` varys a lot. If you are from Google,  some of your company's project are named 'abc', 'def' and 'ghi', and some of your company's domain are 'dada.com', 'pope.com', you can add following items:

```ruby
# config.rb
SENSITIVE_WORDS = %w{
	google
	abc
	def
	ghi
	dada.com
	pope.com
}
```

Git-Hunter will use regular expression to match these words. Some try to think of some highly representative words you care about.

One more thing, don't forget to add [Github personal access token](https://github.com/settings/tokens), it's necessary for Git-Hunter to work:

```ruby
# config.rb
GITHUB_OAUTH_TOKEN = 'your github access token'.freeze
```

Ok! Time to Run,  just:

```shell
$ ruby ./git_hunter.rb run
```

Git-Hunter will automatically clone and analyse all users' repositories as listed in `user_list.txt` . When it finish, it will generate a HTML report and highlight the findings, if there is any.



If you wish to analyse only one user,  just:

```bash
$ ruby ./git_hunter.rb run user Interfish [some_nickname]
or
$ ruby ./git_hunter.rn run user https://github.com/Interfish [some_nickname]
# nickname is optional
```

One repo:

```shell
$ ruby ./git_hunter.rb run user Interfish git-hunter [some_nickname]
or
$ ruby ./git_hunter.rb run user https://github.com/Interfish/git-hunter [some_nickname]
# nickname is optional
```



#### 2. Keep findings and ignore false positive

All findings are stored in a local SQLite database. Of course, there are lots of 'false positive'. So CLI provide ways to mark them as false positive and they will not show up in your next generated HTML report.

For example, if you have already watched the HTML report of https://github.com/Interfish/git-hunter and you are very sure it does not contain sensitive words and possible key leaks, you can:

```shell
$ ruby ./git_hunter.rb mark repo Interfish git-hunter
```

Or, if you are sure all findings of Interfish are false positive:

```shell
$ ruby ./git_hunter.rb mark user Interfish
```

more, if all findings in DB are false positive:

```shell
$ ruby ./git_hunter.rn mark all
```

#### 3.Generate report

You can manually generate HTML report. It will fetch in-DB findings which has not been marked as false positive. All report will located in dir `reports`.

Generate for a single repo:

```shell
$ ruby ./git_hunter.rb report repo Interfish git_hunter
```

For a single user

```shell
$ ruby ./git_hunter.rb report user Interfish
```

For all findings in DB:

```shell
$ ruby ./git_hunter.rb report all
```

#### 4. Global search across the whole Github

You can't always include all users in your list. Usually some out-of-list users will do bad things, e.g. new employee who haven't submit their github url, your opponent, dark industry. Global search becomes extremly useful at this time.

First, configure `config.rb`:

```ruby
# config.rb
GLOBAL_SENSITIVE_WORD = %w{
	google
	abc
	def
	ghi
	dada.com
    pope.com
}
```

And then run:

```shell
$ ruby ./git_hunter.rb run global
```

Git-Hunter will search those global sensitive words across the whole Github using [Github API](https://developer.github.com/v3/) , and the result is the same as [Github commit search](https://github.com/search?q=google&type=Commits). You will get a HTML report once  finished.

Make sure all findings are harmless. Then you could mark them all as false positive:

```shell
$ ruby ./git_hunter.rb mark global
```


#### 5. NOTE!!!

`SENSITIVE_WORDS` and  `GLOBAL_SENSITIVE_WORD` vary a lot with different users come from different organization. **Try to use some highly representitive words and avoid common words.** For example, you should avoid words like 'google', 'apple' or 'banana' cause there are miliions of commits related to those words and you can get nothing from them. **Here's a principle of drafting proper sensitive words: once they appear in a repo, it's very likely that this repo leaks something from your comapny/organization.**



#### 6. Screenshot

![example](example2.png)



![example](example3.png)

## Machanism breif explanation

Git-Hunter dig depply into low-level Git system. It will iterate all branches in a repo and analyse/store base on blob. In DB, there are several tables:

```shell
  users - represent Github users
  repos - represent Github repos, belong to some user
  blobs - represent each blob in a repo, belong to a repo
  findings - represent findings in blobs, belong to a blob
  global_findings - represent global findings
  global_finding_words - record each global sensitive word count appears on Github. 
  
```
So for a normal run. You don't have to worry about user add/delete something in their repo. **Git-Hunter will use hash value on each blob to compare, and automatically async new changes.** All files in history will be included in search, no file will be missed. `sensitive_word` use regular expression to match words. `key_words` use combination of password-like pattern and string entrophy to find possible key-leaks.

For a global run, I found it hard to track what's new and what's old on Github cause there are too many. So I did a little trick - focusing on the total amount of the search result which is provided by github index engine. 

## Advanced Configuration

You may have noticed there's dozens of configuration in `config.rb`. To maximize the performance, here's explanation:

* GITHUB_OAUTH_TOKEN - [your Github personal access token](https://github.com/settings/tokens)
* SKIPPABLE_FILE_SIZE - skip if file size is larger than this. In bytes.
* SKIPPABLE_REPO - some repo name like 'GitHub.io', you may want to skip.
* SKIPPABLE_DIR - some dir like 'node_modules' you may want to skip.
* LINES_EACH_BLOCK - used for key-leaks detecting. usually 3 - 5 is okay.
* SHANNON_ENTROPHY_THRESHOLD - If word count in a string is larger than this, Git-Hunter will treate it as a potential password and calculate it's shannon entrophy.
* MIN_BLOCK_LEN_SKIPPABLE - if length of a code block is larger than this, skip it.
* SENSITIVE_WORDS - use them as regular expression to match in code.
* KEY_WORDS - password-like pattern.
* SUSPECTIBLE_FILE_PATTERN - if filename match one of them, it may be a leaked file.
* GLOBAL_ADDITION_MAX_SIZE - fetch some new indexed commits on each sensitive word when run global, but no more than this size.
* GlOBAL_FINDING_MAX_SIZE - restrict how much global finding you can store in DB.
* GLOBAL_SENSITIVE_WORDS - used to find related commits through Github search. 



## Advanced Managing DB

Git-Hunter use ActiveRecord to reflect DB. So, if you know how to use Ruby, you can:

```shell
$ irb -r ./git_hunter/git_hunter_base.rb
```

to open a interactive Ruby Shell, and then:

```ruby
GitHunterCore.new # establish connection
# then do whatever you want, like query a specific finding
finding = Finding.where(id: 2).first
finding.update(is_valid: false) # mark this finding as false positive
...
```

