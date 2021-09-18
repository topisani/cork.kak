# CORK.KAK
A fast git-based plugin manager for kakoune.

![image](https://user-images.githubusercontent.com/3133596/128006548-3f1acb2e-3ab0-490e-98ba-8d0cdf1412b4.png)


cork depends on [kakoune.cr](https://github.com/alexherbo2/kakoune.cr)

## Setup

#### 1. Install the cork script to your PATH
```sh
curl -o ~/.local/bin/cork https://raw.githubusercontent.com/topisani/cork.kak/master/cork.sh
chmod +x ~/.local/bin/cork
```

#### 2. In the beginning of your `kakrc`, after the kcr init call, add
```kak
evaluate-commands %sh{
  cork init
}
```

#### 3. Declare plugins in your kakrc using the `cork` command:
```kak
cork tmux https://github.com/alexherbo2/tmux.kak %{
  tmux-integration-enable
}
```
The first parameter is an arbitrary unique name for each plugin
The second parameter is the location of the git repository
The third parameter (usually a block) is optional, and contains
code that will be run when the plugin is loaded.

#### 4. Disable plugins in your kakrc using the `nop` command:
```kak
nop cork tmux https://github.com/alexherbo2/tmux.kak %{
  tmux-integration-enable
}
```

#### 5. Install/update plugins
Call `:cork-update` from kakoune, or run `cork update` in a kcr-connected terminal.
