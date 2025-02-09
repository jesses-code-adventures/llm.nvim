# llm.nvim

This is my fork of yacine's [dingllm.nvim](https://github.com/yacineMTB/dingllm.nvim), which adds a couple of features and takes a different approach to configuration.

# Credits

This extension woudln't exist if it weren't for https://github.com/melbaldove/llm.nvim

Yacine diff'd on a fork of it until it was basically a rewrite. Thanks @melbaldove!

I then did the same to [yacine's plugin](https://github.com/yacineMTB/dingllm.nvim), and the cycle continues.

# setup

## api keys

Add your API keys to your env (export it in zshrc or bashrc).

The following api key names are used for the supported providers.

```txt
OPENAI_API_KEY
ANTHROPIC_API_KEY
GOOGLE_API_KEY
DEEPSEEK_API_KEY
GROQ_API_KEY
```

## lazy config

````lua
return {
    {
        "jesses-code-adventurs/llm.nvim",
        dependencies = { 'nvim-lua/plenary.nvim' },
        excluded_providers = { 'openai' }, -- options: openai, deepseek, google, anthropic. any provider not in this list should have a corresponding API_KEY in the env
        opts = {
            replace_prompt =
            'You should replace the code that you are sent, only following the comments. Do not talk at all. Only output valid code. Do not provide any backticks that surround the code. Never ever output backticks like this ```. Any comment that is asking you for something should be removed after you satisfy them. Other comments should left alone. Do not output backticks. Include a newline ("\n") at the beginning of any answer..',
            help_prompt =
            'You are a helpful assistant. What I have sent are my notes so far. You are very curt, yet helpful.'
        },
        keys = {
            -- note: i prefer use these directly in the file i'm editing
            { '<leader>lr', function() require('llm').replace() end, { desc = 'llm replace codeblock' }, { mode = "n" } },
            { '<leader>lr', function() require('llm').replace() end, { desc = 'llm replace codeblock' }, { mode = "v" } },
            -- note: i prefer these when writing in chat mode
            { '<leader>lh', function() require('llm').help() end, { desc = 'llm helpful response' }, { mode = "n" } },
            { '<leader>lh', function() require('llm').help() end, { desc = 'llm helpful response' }, { mode = "n" } },
            -- use .models() to select your model, and toggle the reasoning window display
            { '<leader>lm', function() require('llm').models() end, { desc = 'llm model selector' } },
            -- use .chat() to open a sidepanel with a markdown file for chatting, and a small file allowing you to link source code for the llm to receive as context
            { '<leader>lc', function() require('llm').chat() end, { desc = 'llm chat' } },
        },
    }
}
````

# usage

there are two main workflows i use with this plugin, replacing code directly and chatting with my codebase.

## replacing code directly

it's easiest to go into visual line mode, and select a block of code with a prompt above or below it (i just type the prompt directly inline in the file, but you could put it in a comment), then run:

```lua
require('llm').replace()
```

you can also run this in normal mode, and the llm will receive the contents of the file up to the cursor, then generate code based on that input.

see the [lazy config](#lazy-config) for an approach to keymapping this function.

## helpful chat

In this case the llm will respond conversationally, so it can be nicer to use a markdown file for the project in which you can chat with your selected model. feel free to keep chat history in there so the model can retain context, if it makes sense for you. when you change topic and don't need the context any more, just delete the contents in your markdown file and start again.

There is also a smaller split above the markdown window, in which you can keep a list of files whose contents you want to pass as a system prompt. the llm will receive the path to the contents as you enter it, and the contents. This can be useful when working with larger codebases where code is shared across a few key files.

```lua
require('llm').chat() -- opens the chat window
require('llm').help() -- asks the llm to respond conversationally
```

see the [lazy config](#lazy-config) for an approach to keymapping these functions.
